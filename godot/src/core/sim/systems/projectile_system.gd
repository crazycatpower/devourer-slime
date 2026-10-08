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
	for i: int in range(sim.projectiles.size() - 1, -1, -1):
		var p: SimProjectile = sim.projectiles[i]
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

	for s: int in range(1, steps + 1):
		var cx: float = rx + (p.vx * float(s) / float(steps))
		var cy: float = ry + (p.vy * float(s) / float(steps))
		var c: int = floori(cx / Tile.SIZE)
		var r: int = floori(cy / Tile.SIZE)

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
		match boss_hit:
			BossHit.SPENT:
				return true
			BossHit.DEFLECTED:
				return false

		if not level.in_bounds(r, c):
			return true  # Left the map.
		var cell_type: int = level.get_cell(r, c)

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

		var can_bounce: bool = Tile.is_bouncy(cell_type)
		if not can_bounce and p.type == Tile.BOUNCY and p.bounce_count < 1:
			# A bouncy block rebounds once off anything.
			can_bounce = true
			p.bounce_count += 1

		if can_bounce:
			var bounce_x: bool = c != prev_c
			var bounce_y: bool = r != prev_r
			if not bounce_x and not bounce_y:
				bounce_x = true
				bounce_y = true
			if bounce_x:
				p.vx = -p.vx * BOUNCE_DAMPING
			if bounce_y:
				p.vy = -p.vy * BOUNCE_DAMPING
			# Restart from the last free cell so the hit cannot trigger twice.
			p.x = float(prev_c) * Tile.SIZE
			p.y = float(prev_r) * Tile.SIZE
			sim.spawn_particles(cx, cy, Palette.PINK_500, 12, 3.0)
			sim.add_shake(2.0)
			sim.play(Sfx.Id.BOUNCE)
			return false

		_settle(sim, p, prev_r, prev_c, rx, ry)
		return true
	return false


## One sweep step of a boss shot. Returns true when it is spent.
static func _enemy_step(
	sim: GameSim, p: SimProjectile, cx: float, cy: float, r: int, c: int, prev_r: int, prev_c: int
) -> bool:
	var level: LevelGrid = sim.level
	var player: PlayerState = sim.player
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
	sim.spawn_particles(cell_l + 20.0, cell_t + 20.0, _block_color(p.type), 15, 3.0)
	sim.add_shake(4.0)

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
	var origin: Vector2 = PlayerSystem.shot_origin(sim.player, sim.level, aim)
	var p: SimProjectile = SimProjectile.new()
	p.x = origin.x
	p.y = origin.y
	p.vx = aim.x * GameConstants.BULLET_SPEED
	p.vy = aim.y * GameConstants.BULLET_SPEED
	var half: Vector2 = Vector2(p.w, p.h) / 2.0
	var points: PackedVector2Array = PackedVector2Array([origin + half])
	for tick: int in ticks:
		var hit: bool = _sweep(sim, p, true)
		if not hit:
			p.x += p.vx
			p.y += p.vy
		points.append(Vector2(p.x, p.y) + half)
		if hit:
			break
	return points


static func _block_color(type: int) -> Color:
	return Palette.PINK_500 if type == Tile.BOUNCY else Palette.AMBER_600
