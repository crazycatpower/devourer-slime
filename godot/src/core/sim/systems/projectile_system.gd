class_name ProjectileSystem
extends RefCounted
## Flight and impact of spat blocks and boss shots.
##
## A projectile is swept along its velocity in steps of at most 10 units so
## it cannot tunnel through tiles. Whatever it hits decides its fate: it can
## plug a void, shatter glass, rebound off bouncy blocks, feed a boss, or
## settle as a new block in the last free cell it passed through.

## What a boss did to a player's block this sweep step.
enum BossHit {
	NONE,
	## The block was absorbed or destroyed.
	SPENT,
	## The block bounced off and keeps flying with its new velocity.
	DEFLECTED,
}

## The horizon is not a landing point. Callers must distinguish it from an
## actual contact or an airborne fuse expiry when drawing aiming feedback.
enum PreviewEnd { HORIZON, CONTACT, BOUNDARY, FUSE }

class Trajectory:
	extends RefCounted
	var points: PackedVector2Array = PackedVector2Array()
	var end: PreviewEnd = PreviewEnd.HORIZON

const MAX_STEP: float = 10.0
const GRAVITY_SCALE: float = 0.15
const BOUNCE_DAMPING: float = 0.9
## Boss shots further than this outside the level are discarded.
const CULL_MARGIN: float = 400.0
## Speed a block keeps when it is knocked off an occupied boss cell, and the
## upward kick it gets on top of that.
const DEFLECT_DAMPING: float = 0.8
const DEFLECT_POP: float = 1.5


static func update(sim: GameSim) -> void:
	MechanismSystem.update_tnt(sim)
	for i: int in range(sim.projectiles.size() - 1, -1, -1):
		var p: SimProjectile = sim.projectiles[i]
		if p.fuse_ticks > 0 and not p.dead and p.fuse_start_tick != sim.tick_count:
			p.fuse_ticks -= 1
			if p.fuse_ticks == 0:
				p.dead = true
				MechanismSystem.explode(sim, Vector2(p.x + p.w * 0.5, p.y + p.h * 0.5), true, p.returned_charge)
		if p.dead or _sweep(sim, p):
			sim.projectiles.remove_at(i)
		else:
			p.x += p.vx
			p.y += p.vy


## Moves [param p] through this tick's path. Returns true when it is spent.
static func _sweep(sim: GameSim, p: SimProjectile, preview: bool = false) -> bool:
	var level: LevelGrid = sim.level
	p.vy += GameConstants.GRAVITY * GRAVITY_SCALE
	var rx: float = p.x + p.w / 2.0
	var ry: float = p.y + p.h / 2.0
	var steps: int = maxi(1, ceili(sqrt(p.vx * p.vx + p.vy * p.vy) / MAX_STEP))
	var prev_c: int = floori(rx / Tile.SIZE)
	var prev_r: int = floori(ry / Tile.SIZE)

	var bounce_boundaries: bool = not p.is_enemy and p.type != Tile.TNT
	for fraction: float in _sweep_times(level, Vector2(rx, ry), Vector2(p.vx, p.vy), steps, bounce_boundaries, p.type == Tile.BOUNCY and p.bounce_count < 1):
		var cx: float = rx + p.vx * fraction
		var cy: float = ry + p.vy * fraction
		var c: int = floori(cx / Tile.SIZE)
		var r: int = floori(cy / Tile.SIZE)
		if not p.is_enemy and p.type in [Tile.ICE, Tile.SAND] and MechanismSystem.fragile_hits_spikes(level, Rect2(cx - p.w / 2.0, cy - p.h / 2.0, p.w, p.h)):
			p.x = cx - p.w / 2.0
			p.y = cy - p.h / 2.0
			if not preview:
				sim.spawn_particles(cx, cy, _block_color(p.type), 16, 4.5)
				sim.play(Sfx.Id.LAND)
			return true

		if p.is_enemy:
			if _enemy_step(sim, p, cx, cy, r, c, prev_r, prev_c):
				return true
			prev_c = c
			prev_r = r
			continue

		var boss_hit: BossHit = _hits_boss(sim, p, cx, cy, preview)
		if preview:
			# Stop at the first contact, including a bounce. Never mutate the
			# world or predict a moving boss beyond its current pose.
			var contact: bool = boss_hit != BossHit.NONE or not level.in_bounds(r, c)
			if not contact:
				var tile: int = level.get_cell(r, c)
				contact = Tile.is_solid(tile) or Tile.is_spike(tile)
			if contact:
				p.x = cx - p.w / 2.0
				p.y = cy - p.h / 2.0
				return true
			continue
		if p.type == Tile.TNT and boss_hit != BossHit.NONE:
			p.dead = true
			MechanismSystem.arm_tnt(sim, Vector2(cx, cy), p.fuse_ticks if p.fuse_ticks > 0 else MechanismSystem.TNT_FUSE_TICKS, false, p.returned_charge)
			return true
		match boss_hit:
			BossHit.SPENT:
				return true
			BossHit.DEFLECTED:
				return false

		if not level.in_bounds(r, c):
			return true  # Left the map.
		var cell_type: int = level.get_cell(r, c)
		if cell_type == Tile.TNT:
			p.dead = true
			MechanismSystem.detonate_cell(sim, Vector2i(c, r))
			if p.type == Tile.TNT:
				MechanismSystem.arm_tnt(sim, Vector2(cx, cy), p.fuse_ticks if p.fuse_ticks > 0 else MechanismSystem.TNT_FUSE_TICKS, false, p.returned_charge)
			return true
		if p.type == Tile.TNT and (Tile.is_solid(cell_type) or Tile.is_spike(cell_type)):
			p.dead = true
			MechanismSystem.arm_tnt(sim, Vector2(cx, cy), p.fuse_ticks if p.fuse_ticks > 0 else MechanismSystem.TNT_FUSE_TICKS, false, p.returned_charge)
			return true

		if Tile.is_spike(cell_type):
			var color: Color = _block_color(p.type)
			if cell_type == Tile.VOID:
				# A void swallows the block and becomes solid ground.
				level.set_cell(r, c, _worn_type(p.type))
				sim.spawn_particles(cx, cy, color, 20, 5.0)
			else:
				sim.spawn_particles(cx, cy, color, 15, 4.0)
			return true

		if not Tile.is_solid(cell_type):
			prev_c = c
			prev_r = r
			continue

		if cell_type == Tile.GLASS:
			level.set_cell(r, c, Tile.AIR)
			sim.spawn_particles(cx, cy, Palette.CYAN_500, 20, 5.0)
			return true

		if cell_type == Tile.ICE and c != prev_c and r == prev_r and absf(p.vx) > absf(p.vy):
			MechanismSystem.start_slide(sim, Vector2i(c, r), p.vx)
			return true

		var can_bounce: bool = Tile.is_bouncy(cell_type)
		if not can_bounce and p.type == Tile.BOUNCY and p.bounce_count < 1:
			# A bouncy block rebounds once off anything.
			can_bounce = true
			p.bounce_count += 1

		if can_bounce:
			var contact: Vector3 = _bounce_contact(level, Vector2(rx, ry), Vector2(p.vx, p.vy), c, r)
			var hit: Vector2 = Vector2(rx, ry) + Vector2(p.vx, p.vy) * contact.z
			# A moving block may cover a shot between ticks. Separate it onto
			# the chosen face before reflecting, avoiding repeated inside hits.
			if contact.z == 0.0:
				if contact.x != 0.0:
					hit.x = float(c if contact.x < 0.0 else c + 1) * Tile.SIZE
				if contact.y != 0.0:
					hit.y = float(r if contact.y < 0.0 else r + 1) * Tile.SIZE
			if contact.x != 0.0:
				p.vx = -p.vx * BOUNCE_DAMPING
			if contact.y != 0.0:
				p.vy = -p.vy * BOUNCE_DAMPING
			# update() adds the new velocity once; compensate for time already
			# spent reaching the face, preserving the continuous bounce position.
			p.x = hit.x - p.w / 2.0 - p.vx * contact.z + contact.x * Collision.SKIN
			p.y = hit.y - p.h / 2.0 - p.vy * contact.z + contact.y * Collision.SKIN
			sim.spawn_particles(cx, cy, Palette.PINK_500, 12, 3.0)
			sim.add_shake(2.0)
			sim.play(Sfx.Id.BOUNCE)
			return false

		_settle(sim, p, prev_r, prev_c, rx, ry)
		return true
	return false


## Swept point entry into the tile. Crossing two grid lines in one sample does
## not imply hitting both faces: the later crossing is the actual entry face.
## X/Y are outward normal components, Z is the fraction of this tick at impact.
static func _bounce_contact(level: LevelGrid, origin: Vector2, velocity: Vector2, c: int, r: int) -> Vector3:
	var tx: float = -INF
	var ty: float = -INF
	if velocity.x != 0.0:
		tx = (float(c if velocity.x > 0.0 else c + 1) * Tile.SIZE - origin.x) / velocity.x
	if velocity.y != 0.0:
		ty = (float(r if velocity.y > 0.0 else r + 1) * Tile.SIZE - origin.y) / velocity.y
	var normal: Vector2 = Vector2.ZERO
	if tx > ty + 0.00001:
		normal.x = -signf(velocity.x)
	elif ty > tx + 0.00001:
		normal.y = -signf(velocity.y)
	else:
		# Exact exposed corners reflect both axes. A seam in a continuous
		# floor/wall is internal, and must not introduce a sideways rebound.
		var beside: bool = Tile.is_solid(level.get_cell(r, c - int(signf(velocity.x))))
		var above: bool = Tile.is_solid(level.get_cell(r - int(signf(velocity.y)), c))
		normal.x = -signf(velocity.x) if not beside or above else 0.0
		normal.y = -signf(velocity.y) if not above or beside else 0.0
	return Vector3(normal.x, normal.y, clampf(maxf(tx, ty), 0.0, 1.0))


## Keep ordinary impact sampling, and also inspect bouncy tile boundaries. Otherwise a
## diagonal sample can skip a narrow contact just before a seam and mistake the
## next tile's internal edge for an exposed wall. The nudge enters either side
## of a boundary consistently, including travel to the left/up.
static func _sweep_times(level: LevelGrid, origin: Vector2, velocity: Vector2, steps: int, bounce_boundaries: bool, bouncy_shot: bool) -> Array[float]:
	var times: Array[float] = []
	for step: int in range(1, steps + 1):
		times.append(float(step) / float(steps))
	if not bounce_boundaries:
		return times
	for axis: int in 2:
		if velocity[axis] == 0.0:
			continue
		var end: float = origin[axis] + velocity[axis]
		var first: int = ceili(minf(origin[axis], end) / Tile.SIZE)
		var last: int = floori(maxf(origin[axis], end) / Tile.SIZE)
		for boundary: int in range(first, last + 1):
			var fraction: float = (float(boundary) * Tile.SIZE - origin[axis]) / velocity[axis]
			var sample_time: float = minf(1.0, fraction + 0.001 / maxf(velocity.length(), 1.0))
			var sample: Vector2 = origin + velocity * sample_time
			var tile: int = level.get_cell(floori(sample.y / Tile.SIZE), floori(sample.x / Tile.SIZE))
			if Tile.is_bouncy(tile) or (bouncy_shot and Tile.is_solid(tile) and tile not in [Tile.GLASS, Tile.TNT]):
				times.append(sample_time)
	times.sort()
	return times


## One sweep step of a boss shot. Returns true when it is spent.
static func _enemy_step(
	sim: GameSim, p: SimProjectile, cx: float, cy: float, r: int, c: int, prev_r: int, prev_c: int
) -> bool:
	var level: LevelGrid = sim.level
	var player: PlayerState = sim.player
	if level.get_cell(r, c) == Tile.TNT:
		p.dead = true
		MechanismSystem.detonate_cell(sim, Vector2i(c, r))
		return true
	var touches_player: bool = not (
		cx + p.w / 2.0 <= player.x or cx - p.w / 2.0 >= player.x + player.w
		or cy + p.h / 2.0 <= player.y or cy - p.h / 2.0 >= player.y + player.h
	)
	if touches_player:
		if sim.kill_player():
			sim.play(Sfx.Id.HURT)
			sim.spawn_particles(player.center_x(), player.center_y(), Palette.CYAN_500, 35, 7.5)
		return true

	if not level.in_bounds(r, c):
		# Shots may start just outside the arena; ones that stray far are lost.
		return (
			cx < -CULL_MARGIN or cx > level.pixel_width() + CULL_MARGIN
			or cy < -CULL_MARGIN or cy > level.pixel_height() + CULL_MARGIN
		)
	if not Tile.is_solid(level.get_cell(r, c)):
		return false

	# The shot turns into a block of its own type where it lands.
	var block_type: int = p.type if p.type != 0 else Tile.GLASS
	var color: Color = Palette.AMBER_600 if block_type == Tile.DIRT else Palette.CYAN_500
	if level.in_bounds(prev_r, prev_c) and level.get_cell(prev_r, prev_c) == Tile.AIR:
		level.set_cell(prev_r, prev_c, block_type)
		sim.spawn_particles(
			float(prev_c) * Tile.SIZE + 20.0, float(prev_r) * Tile.SIZE + 20.0, color, 20, 5.0
		)
		sim.play(Sfx.Id.LAND)
	else:
		sim.spawn_particles(cx, cy, color, 15, 4.0)
	return true


## Lets a player projectile at ([param cx], [param cy]) interact with the boss.
static func _hits_boss(sim: GameSim, p: SimProjectile, cx: float, cy: float, preview: bool = false) -> BossHit:
	var boss: BossState = sim.boss
	if not boss.active or boss.dead or boss.state == BossState.State.SUSPENDED:
		return BossHit.NONE

	if BossMechanism.is_kind(sim.boss_kind):
		return BossHit.SPENT if BossMechanism.hit_by_projectile(sim, p, cx, cy, preview) else BossHit.NONE

	if sim.boss_kind == BossState.Kind.GLASS_SLIME:
		if boss.state == BossState.State.INTRO:
			return BossHit.NONE
		return BossHit.SPENT if BossGlassSlime.hit_by_projectile(sim, cx, cy, preview) else BossHit.NONE

	var is_mud_golem: bool = sim.boss_kind == BossState.Kind.MUD_GOLEM
	var n: int = boss.grid_size
	var p_left: float = cx - p.w / 2.0
	var p_right: float = cx + p.w / 2.0
	var p_top: float = cy - p.h / 2.0
	var p_bottom: float = cy + p.h / 2.0
	# Only cells near the projectile can overlap it; the exact test follows.
	var first_r: int = maxi(0, boss.min_r + floori((p_top - boss.y) / Tile.SIZE) - 1)
	var last_r: int = mini(n - 1, boss.min_r + floori((p_bottom - boss.y) / Tile.SIZE) + 1)
	var first_c: int = maxi(0, boss.min_c + floori((p_left - boss.x) / Tile.SIZE) - 1)
	var last_c: int = mini(n - 1, boss.min_c + floori((p_right - boss.x) / Tile.SIZE) + 1)
	for br: int in range(first_r, last_r + 1):
		for bc: int in range(first_c, last_c + 1):
			if br == boss.center_r and bc == boss.center_c:
				continue
			var cell_x: float = boss.cell_x(bc)
			var cell_y: float = boss.cell_y(br)
			if (
				p_right <= cell_x or p_left >= cell_x + Tile.SIZE
				or p_bottom <= cell_y or p_top >= cell_y + Tile.SIZE
			):
				continue
			var val: int = boss.grid[br * n + bc]
			if val == 0:
				# Blocks only stick next to the body, never in mid-air.
				if not boss.has_occupied_neighbor(br, bc):
					continue
				if preview:
					return BossHit.SPENT
				BossVoidSlime.feed_cell(sim, p, br, bc, cell_x, cell_y)
				if is_mud_golem:
					BossMudGolem.update_bounds(sim)
				return BossHit.SPENT
			# An occupied cell is solid: the block is knocked away and stays
			# in play, to land somewhere as a block again.
			if preview:
				return BossHit.DEFLECTED
			_deflect(sim, p, cell_x, cell_y)
			sim.add_shake(3.0)
			sim.play(Sfx.Id.BOUNCE)
			sim.spawn_particles(
				cx, cy, Palette.PINK_500 if val == Tile.BOUNCY else Palette.AMBER_600, 8, 3.0
			)
			return BossHit.DEFLECTED
	return BossHit.NONE


## Bounces [param p] off the occupied boss cell at ([param cell_x],
## [param cell_y]): back the way it came and upward, or back down when it
## struck the cell from underneath.
static func _deflect(sim: GameSim, p: SimProjectile, cell_x: float, cell_y: float) -> void:
	p.vx = -p.vx * DEFLECT_DAMPING + (sim.rng.next_float() - 0.5) * 2.0
	var from_below: bool = p.y >= cell_y + Tile.SIZE
	if from_below:
		p.vy = absf(p.vy) * DEFLECT_DAMPING
	else:
		p.vy = -absf(p.vy) * DEFLECT_DAMPING - DEFLECT_POP
	# A boss that moved onto the block has it inside the cell already: lift
	# it out, or it would be deflected again every tick.
	var inside: bool = not (
		p.x + p.w <= cell_x or p.x >= cell_x + Tile.SIZE
		or p.y + p.h <= cell_y or p.y >= cell_y + Tile.SIZE
	)
	if inside:
		p.y = cell_y - p.h - 1.0


## Turns the projectile into a block in the last free cell it crossed, or
## lets it crumble when that cell is taken.
static func _settle(
	sim: GameSim, p: SimProjectile, prev_r: int, prev_c: int, rx: float, ry: float
) -> void:
	var level: LevelGrid = sim.level
	var player: PlayerState = sim.player
	if not (level.in_bounds(prev_r, prev_c) and level.get_cell(prev_r, prev_c) == Tile.AIR):
		sim.spawn_particles(
			rx, ry, Palette.PINK_500 if p.type == Tile.BOUNCY else Palette.SLATE_400, 20, 5.0
		)
		sim.add_shake(3.0)
		return

	var cell_l: float = float(prev_c) * Tile.SIZE
	var cell_r: float = cell_l + Tile.SIZE
	var cell_t: float = float(prev_r) * Tile.SIZE
	var cell_b: float = cell_t + Tile.SIZE
	var player_overlaps: bool = not (
		player.x + player.w <= cell_l or player.x >= cell_r
		or player.y + player.h <= cell_t or player.y >= cell_b
	)

	level.set_cell(prev_r, prev_c, _landed_type(p))
	sim.animate_tile_from(Vector2(p.x, p.y), Vector2i(prev_c, prev_r), MechanismSystem.SLIDE_TICKS)
	sim.sliding_cells.erase(Vector2i(prev_c, prev_r))
	if p.type in [Tile.SAND, Tile.ICE, Tile.TNT]:
		sim.mechanisms_enabled = true
	sim.spawn_particles(cell_l + 20.0, cell_t + 20.0, _block_color(p.type), 15, 3.0)
	sim.add_shake(4.0)

	if p.type == Tile.ICE or level.get_cell(prev_r + 1, prev_c) == Tile.ICE:
		var ceiling: bool = p.type == Tile.ICE and p.vy < 0.0 and Tile.is_solid(level.get_cell(prev_r - 1, prev_c))
		MechanismSystem.start_slide(sim, Vector2i(prev_c, prev_r), p.vx, ceiling)
	if not player_overlaps:
		return
	# The new block would trap the player: push them out against the shot's
	# direction, which is where the recoil is already sending them.
	var out_x: float = player.x
	var out_y: float = player.y
	if absf(p.vx) > absf(p.vy):
		out_x = cell_l - player.w - 0.1 if p.vx > 0.0 else cell_r + 0.1
	else:
		out_y = cell_t - player.h - 0.1 if p.vy > 0.0 else cell_b + 0.1
	if sim.solid_boxes(out_x, out_y, player.w, player.h).is_empty():
		player.x = out_x
		player.y = out_y
	else:
		# There is no room on that side (a tunnel, a shaft): the block
		# crumbles instead of shoving the player into the wall.
		level.set_cell(prev_r, prev_c, Tile.AIR)


## Tile a spat block settles as; it keeps the wear from being swallowed.
static func _landed_type(p: SimProjectile) -> int:
	if p.type == Tile.DIRT:
		if p.eaten_count == 1:
			return Tile.DIRT_EATEN_1
		if p.eaten_count == 2:
			return Tile.DIRT_EATEN_2
	elif p.type == Tile.BOUNCY:
		if p.eaten_count == 1:
			return Tile.BOUNCY_EATEN_1
		if p.eaten_count == 2:
			return Tile.BOUNCY_EATEN_2
	return p.type


## A block that plugs a void arrives one bite away from breaking.
static func _worn_type(type: int) -> int:
	if type == Tile.DIRT:
		return Tile.DIRT_EATEN_2
	if type == Tile.BOUNCY:
		return Tile.BOUNCY_EATEN_2
	return type


## Predicts only the first contact, using the same spawn and sweep as firing.
## Its private projectile is the only state modified by this query.
static func preview_path(sim: GameSim, aim: PlayerSystem.Aim, ticks: int = 40) -> PackedVector2Array:
	return preview_trajectory(sim, aim, ticks).points


static func preview_trajectory(sim: GameSim, aim: PlayerSystem.Aim, ticks: int = 40) -> Trajectory:
	var result: Trajectory = Trajectory.new()
	var origin: Vector2 = PlayerSystem.shot_origin(sim.player, sim.level, aim)
	var p: SimProjectile = SimProjectile.new()
	p.type = sim.player.carried_block_type if sim.player.carried_block_type != Tile.AIR else Tile.DIRT
	p.x = origin.x
	p.y = origin.y
	p.vx = aim.x * GameConstants.BULLET_SPEED
	p.vy = aim.y * GameConstants.BULLET_SPEED
	var half: Vector2 = Vector2(p.w, p.h) / 2.0
	result.points.append(origin + half)
	var fuse: int = MechanismSystem.TNT_FUSE_TICKS if p.type == Tile.TNT else 0
	for tick: int in ticks:
		# The firing tick advances flight but does not consume the new fuse.
		# Later ticks detonate before their sweep, as update() does.
		if fuse > 0 and tick > 0:
			fuse -= 1
			if fuse == 0:
				result.end = PreviewEnd.FUSE
				break
		var hit: bool = _sweep(sim, p, true)
		if not hit:
			p.x += p.vx
			p.y += p.vy
		var center: Vector2 = Vector2(p.x, p.y) + half
		result.points.append(center)
		if hit:
			result.end = PreviewEnd.CONTACT if sim.level.in_bounds(Tile.cell_of(center.y), Tile.cell_of(center.x)) else PreviewEnd.BOUNDARY
			break
	return result


static func _block_color(type: int) -> Color:
	return GameSim.debris_color(type)
