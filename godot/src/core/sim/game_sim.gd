class_name GameSim
extends RefCounted
## Deterministic fixed-step simulation of one level.
##
## The simulation owns all gameplay state and advances it one tick at a time
## (60 ticks per second of game time). It has no dependency on nodes, input
## devices, rendering or audio: input arrives as a [SimInput], sound effects
## leave as [signal sfx_requested], and renderers only read the state. That
## separation is what makes the game frame-rate independent and testable.
##
## Velocities are in world units per tick.

signal sfx_requested(id: Sfx.Id, param: float, delay_sec: float)
signal level_reset

## Ticks the death screen stays up before the level restarts by itself.
const DEATH_RESTART_TICKS: int = 75

var slot: int = 1
var boss_kind: BossState.Kind = BossState.Kind.NONE
var level: LevelGrid = LevelGrid.new()
var camera: SimCamera = SimCamera.new()
var player: PlayerState = PlayerState.new()
var boss: BossState = BossState.create(BossState.Kind.NONE)
var projectiles: Array[SimProjectile] = []
## Primed charges remain visible at their trigger position until the fuse ends.
class TntCharge:
	var center: Vector2
	var returned_charge: bool = false
	var boss_owned: bool = false
	var explode_tick: int

var tnt_charges: Array[TntCharge] = []
var particles: Array[SimParticle] = []
var falling_blocks: Array[SimFallingBlock] = []
var mechanisms_enabled: bool = false
var powered_cells: Dictionary[Vector2i, bool] = {}
## Cache validity is based on source coverage and grid signal connectivity.
var signal_grid: LevelGrid
var signal_revision: int = -1
var signal_sources: Array[Vector2i] = []
var signal_detectors: Array[Vector2i] = []
var sliding_cells: Dictionary[Vector2i, int] = {}
## Ice attached to the underside of a ceiling while it slides.
var ceiling_slides: Dictionary[Vector2i, bool] = {}
## A block on its way from one cell to the next: carried by a rail, falling or
## sliding. The grid already holds it in its destination cell, but it is drawn
## and collided with where it is at the moment. It follows the same simulation
## clock as mechanisms and bullet time.
class TileMotion:
	var origin: Vector2
	var destination: Vector2i
	var type: int
	var start_tick: int
	var duration: int
	## True for a block being moved from cell to cell by a mechanism: it is solid
	## where it has got to. False for a spat block easing into the cell it landed
	## in, which is only drawn that way and is solid in its cell at once.
	var transport: bool = false
	func position_at(time: float) -> Vector2:
		return origin.lerp(Vector2(destination) * Tile.SIZE, clampf((time - start_tick) / maxf(1.0, duration), 0.0, 1.0))

var tile_motions: Dictionary[Vector2i, TileMotion] = {}
var death_timer: int = 0
## GameScreen can restore a safe history snapshot instead of resetting the level.
var external_death_recovery: bool = false
## Ticks simulated since this object was created; never reset, so it can
## serve as the gameplay clock.
var tick_count: int = 0
var bullet_time_enabled: bool = true
## True once the boss of this level has made its entrance; survives restarts
## so that a retry does not sit through the whole entrance again.
var boss_intro_seen: bool = false
## Input of the tick being simulated.
var input: SimInput = SimInput.new()
var rng: SimRandom = SimRandom.new()
## Separate stream for cosmetic effects requested by the presentation layer,
## so that rendering can never perturb gameplay randomness.
var fx_rng: SimRandom = SimRandom.new()

var _source: LevelData = LevelData.new()


## Sets the level to play and resets the simulation onto it.
func load_level(p_slot: int, data: LevelData, p_boss_kind: BossState.Kind) -> void:
	slot = p_slot
	boss_kind = p_boss_kind
	_source = data.duplicate_level()
	boss_intro_seen = false
	reset()


## Restarts the current level from its pristine layout.
func reset() -> void:
	level = _source.grid.duplicate_grid()
	player = PlayerState.new()
	player.place_at(_source.start_x(), _source.start_y())
	projectiles.clear()
	tnt_charges.clear()
	particles.clear()
	falling_blocks.clear()
	powered_cells.clear()
	signal_grid = null
	signal_revision = -1
	signal_sources.clear()
	signal_detectors.clear()
	sliding_cells.clear()
	ceiling_slides.clear()
	tile_motions.clear()
	MechanismSystem.initialize(self)
	death_timer = 0
	boss = BossState.create(boss_kind)
	if boss.active:
		boss.x = BossSystem.spawn_x(level, boss.w)
		boss.prev_x = boss.x
	if boss_kind == BossState.Kind.GLASS_SLIME:
		BossGlassSlime.build_arena(self)
		BossGlassSlime.sync_orbiting_shields(self)
	if boss_kind == BossState.Kind.MUD_GOLEM:
		BossMudGolem.build_arena(self)
	if boss_kind == BossState.Kind.STEEL_CHASE:
		BossSteelChase.setup(self)
	if BossMechanism.is_kind(boss_kind):
		BossMechanism.setup(self)
	camera.shake = 0.0
	camera.snap_to(player.center_x(), _camera_focus_y(), level)
	level_reset.emit()


## Height the camera centres on. It is the player, except in the glass slime's
## arena, where the view is lifted so the boss roaming overhead stays in sight.
func _camera_focus_y() -> float:
	if boss_kind == BossState.Kind.GLASS_SLIME and boss.active and not boss.dead:
		return player.center_y() - BossGlassSlime.CAMERA_LIFT
	return player.center_y()


## Advances the simulation by one tick.
func step(p_input: SimInput) -> void:
	input = p_input
	tick_count += 1
	_store_previous_positions()

	if not player.dead and not player.won:
		# Blocks in transit move first, taking whoever stands on them along.
		MechanismSystem.carry_player(self)
		PlayerSystem.update(self)
		BossSystem.update(self)
	ProjectileSystem.update(self)
	if not player.dead and not player.won:
		MechanismSystem.update(self)
	_prune_tile_motions()
	_update_particles()

	if player.dead:
		player.in_bullet_time = false
		death_timer += 1
		if death_timer > DEATH_RESTART_TICKS and not external_death_recovery:
			reset()
	if player.won:
		player.in_bullet_time = false


## Moves the camera toward the player. Call once per 60 Hz frame.
func update_camera() -> void:
	camera.follow(player.center_x(), _camera_focus_y(), level)


## Gameplay clock in milliseconds. Pauses and slows down with the simulation.
func clock_ms() -> float:
	return float(tick_count) * 1000.0 / float(GameConstants.TICKS_PER_SECOND)


func play(id: Sfx.Id, param: float = 0.0, delay_sec: float = 0.0) -> void:
	sfx_requested.emit(id, param, delay_sec)


func add_shake(amount: float) -> void:
	camera.shake = maxf(camera.shake, amount)


func spawn_particles(px: float, py: float, color: Color, count: int, speed: float) -> void:
	_spawn_particles_with(rng, px, py, color, count, speed)


## Particle burst for presentation-only effects; leaves [member rng] untouched.
func spawn_cosmetic_particles(px: float, py: float, color: Color, count: int, speed: float) -> void:
	_spawn_particles_with(fx_rng, px, py, color, count, speed)


func add_particle(
	px: float, py: float, pvx: float, pvy: float, max_life: float, color: Color, size: float
) -> void:
	var pt: SimParticle = SimParticle.new()
	pt.x = px
	pt.y = py
	pt.prev_x = px
	pt.prev_y = py
	pt.vx = pvx
	pt.vy = pvy
	pt.max_life = max_life
	pt.color = color
	pt.w = size
	particles.append(pt)


## Marks the player dead. Returns false when they were already dead or had won.
func kill_player() -> bool:
	if player.dead or player.won:
		return false
	player.dead = true
	death_timer = 0
	return true


## Out-of-range rows above and columns to either side count as walls; rows
## below the level are open so things can fall out of the map.
func is_solid_or_boundary(r: int, c: int) -> bool:
	if r < 0 or c < 0 or c >= level.cols:
		return true
	if r >= level.rows:
		return false
	return Tile.is_solid(level.get_cell(r, c))


## Wears a block down one stage, shattering it on the last one.
func damage_cell_at(row: int, col: int) -> void:
	if not level.in_bounds(row, col):
		return
	var block_type: int = level.get_cell(row, col)
	if block_type <= 0 or block_type == Tile.STEEL:
		return

	var next_type: int = block_type
	var should_break: bool = false
	match block_type:
		Tile.TNT:
			MechanismSystem.detonate_cell(self, Vector2i(col, row))
			return
		Tile.SAND, Tile.ICE:
			should_break = true
		Tile.GLASS:
			should_break = true
		Tile.DIRT:
			next_type = Tile.DIRT_EATEN_1
		Tile.DIRT_EATEN_1:
			next_type = Tile.DIRT_EATEN_2
		Tile.DIRT_EATEN_2:
			should_break = true
		Tile.BOUNCY:
			next_type = Tile.BOUNCY_EATEN_1
		Tile.BOUNCY_EATEN_1:
			next_type = Tile.BOUNCY_EATEN_2
		Tile.BOUNCY_EATEN_2:
			should_break = true

	var cx: float = float(col) * Tile.SIZE + Tile.SIZE / 2.0
	var cy: float = float(row) * Tile.SIZE + Tile.SIZE / 2.0
	var color: Color = debris_color(block_type)
	if should_break:
		level.set_cell(row, col, Tile.AIR)
		spawn_particles(cx, cy, color, 25, 6.0)
		add_shake(14.0)
		play(Sfx.Id.BOUNCE)
	else:
		level.set_cell(row, col, next_type)
		spawn_particles(cx, cy, color, 12, 3.0)
		add_shake(6.0)


## Damages the breakable tiles in floor row [param r_floor] under the boss.
func damage_tiles_under_boss(r_floor: int) -> void:
	if boss.state == BossState.State.SUSPENDED:
		return
	var start_col: int = floori((boss.x - Tile.SIZE / 2.0) / Tile.SIZE)
	var end_col: int = floori((boss.x + boss.w + Tile.SIZE / 2.0 - 1.0) / Tile.SIZE)
	for col: int in range(start_col, end_col + 1):
		if level.in_bounds(r_floor, col):
			var block_type: int = level.get_cell(r_floor, col)
			if block_type > 0 and block_type != Tile.STEEL and Tile.is_solid(block_type):
				damage_cell_at(r_floor, col)


## Debris colour for a block type: pink for bouncy, cyan for glass, else amber.
static func debris_color(block_type: int) -> Color:
	if Tile.is_bouncy(block_type):
		return Palette.PINK_500
	if block_type == Tile.GLASS or block_type == Tile.ICE:
		return Palette.CYAN_500
	if block_type == Tile.TNT:
		return Palette.RED_500
	return Palette.AMBER_600


## Nearest eatable block along the aim direction, or null.
##
## Samples the ray every 3.25 units up to 65 units from ([param cx], [param cy]).
func get_eat_target(cx: float, cy: float, nx: float, ny: float) -> EatTarget:
	var is_mud_golem: bool = boss_kind == BossState.Kind.MUD_GOLEM
	if is_mud_golem and boss.reorg_timer > 0:
		return null
	var scan_boss: bool = (
		(is_mud_golem or boss_kind in [BossState.Kind.SENSOR_SENTINEL, BossState.Kind.SAND_COLOSSUS, BossState.Kind.RAIL_CARRIER]) and boss.active and not boss.dead and boss.state not in [BossState.State.SUSPENDED, BossState.State.INTRO]
	)
	for i: int in range(1, 21):
		var f: float = float(i) / 20.0
		var ptx: float = cx + nx * (65.0 * f)
		var pty: float = cy + ny * (65.0 * f)

		if boss_kind == BossState.Kind.TNT_FURNACE:
			for charge: TntCharge in tnt_charges:
				if charge.boss_owned and Rect2(charge.center - Vector2.ONE * Tile.SIZE * 0.5, Vector2.ONE * Tile.SIZE).has_point(Vector2(ptx, pty)):
					var target: EatTarget = EatTarget.make(Tile.cell_of(charge.center.y), Tile.cell_of(charge.center.x), Tile.TNT, false)
					target.charge = charge
					return target
		if scan_boss:
			for r: int in range(boss.min_r, boss.max_r + 1):
				for c: int in range(boss.min_c, boss.max_c + 1):
					var val: int = boss.grid[r * boss.grid_size + c]
					if boss_kind == BossState.Kind.SAND_COLOSSUS and (r != boss.center_r or c != boss.center_c):
						continue
					if boss_kind == BossState.Kind.SENSOR_SENTINEL and not boss.mechanism.covered_ports.has(Vector2i(c, r)):
						continue
					if boss_kind == BossState.Kind.RAIL_CARRIER and (r != 0 or c not in [0, 2] or val != Tile.DIRT):
						continue
					if val > 0:
						var cell_x: float = boss.cell_x(c)
						var cell_y: float = boss.cell_y(r)
						if boss_kind == BossState.Kind.SENSOR_SENTINEL and r == 0 and c == 1:
							cell_y -= Tile.SIZE * 0.5
						if (
							ptx >= cell_x and ptx <= cell_x + Tile.SIZE
							and pty >= cell_y and pty <= cell_y + Tile.SIZE
						):
							return EatTarget.make(r, c, val, true)

		var col: int = floori(ptx / Tile.SIZE)
		var row: int = floori(pty / Tile.SIZE)
		if level.in_bounds(row, col) and Tile.is_eatable(level.get_cell(row, col)):
			return EatTarget.make(row, col, level.get_cell(row, col), false)
	return null


## Solid boxes overlapping the given rectangle: level tiles, blocks in transit
## at the place they have reached, then the blocks that make up the mud golem.
func solid_boxes(rect_x: float, rect_y: float, rect_w: float, rect_h: float) -> Array[SolidBox]:
	var list: Array[SolidBox] = []
	var left: int = floori((rect_x + 0.001) / Tile.SIZE)
	var right: int = floori((rect_x + rect_w - 0.001) / Tile.SIZE)
	var top: int = floori((rect_y + 0.001) / Tile.SIZE)
	var bottom: int = floori((rect_y + rect_h - 0.001) / Tile.SIZE)
	for r: int in range(top, bottom + 1):
		for c: int in range(left, right + 1):
			if level.in_bounds(r, c):
				var t: int = level.get_cell(r, c)
				# A block still on its way is not in this cell yet; see below.
				if Tile.is_solid(t) and not is_tile_in_transit(Vector2i(c, r)):
					list.append(SolidBox.make(float(c) * Tile.SIZE, float(r) * Tile.SIZE, t))
	for cell: Vector2i in tile_motions:
		if not is_tile_in_transit(cell):
			continue
		var motion: TileMotion = tile_motions[cell]
		if not Tile.is_solid(motion.type):
			continue
		var at: Vector2 = tile_position_now(motion)
		if (
			at.x < rect_x + rect_w - 0.001 and at.x + Tile.SIZE > rect_x + 0.001
			and at.y < rect_y + rect_h - 0.001 and at.y + Tile.SIZE > rect_y + 0.001
		):
			list.append(SolidBox.make(at.x, at.y, motion.type))

	if (
		boss_kind == BossState.Kind.MUD_GOLEM and boss.active and not boss.dead
		and boss.state != BossState.State.SUSPENDED
	):
		for r: int in range(boss.min_r, boss.max_r + 1):
			for c: int in range(boss.min_c, boss.max_c + 1):
				var val: int = boss.grid[r * boss.grid_size + c]
				if val > 0:
					var cell_x: float = boss.cell_x(c)
					var cell_y: float = boss.cell_y(r)
					if not (
						rect_x + rect_w <= cell_x or rect_x >= cell_x + Tile.SIZE
						or rect_y + rect_h <= cell_y or rect_y >= cell_y + Tile.SIZE
					):
						list.append(SolidBox.make(cell_x, cell_y, val))
	return list


func _spawn_particles_with(
	source: SimRandom, px: float, py: float, color: Color, count: int, speed: float
) -> void:
	for _i: int in count:
		var pvx: float = (source.next_float() - 0.5) * speed * 2.0
		var pvy: float = (source.next_float() - 0.5) * speed * 2.0
		var max_life: float = source.next_float() * 20.0 + 10.0
		var size: float = source.next_float() * 4.0 + 4.0
		add_particle(px, py, pvx, pvy, max_life, color, size)


func _store_previous_positions() -> void:
	player.prev_x = player.x
	player.prev_y = player.y
	if boss.active:
		boss.prev_x = boss.x
		boss.prev_y = boss.y
		for shield: ShieldState in boss.shields:
			shield.prev_cx = shield.cx
			shield.prev_cy = shield.cy
	for p: SimProjectile in projectiles:
		p.prev_x = p.x
		p.prev_y = p.y
	for pt: SimParticle in particles:
		pt.prev_x = pt.x
		pt.prev_y = pt.y
	for fb: SimFallingBlock in falling_blocks:
		fb.prev_x = fb.x
		fb.prev_y = fb.y


func _update_particles() -> void:
	for i: int in range(particles.size() - 1, -1, -1):
		var pt: SimParticle = particles[i]
		pt.vy += GameConstants.GRAVITY * 0.2
		pt.x += pt.vx
		pt.y += pt.vy
		pt.life += 1.0
		if pt.life > pt.max_life:
			particles.remove_at(i)


func animate_tile_move(from: Vector2i, to: Vector2i, duration: int) -> void:
	var origin: Vector2 = tile_motions[from].position_at(tick_count - 1) if tile_motions.has(from) else Vector2(from) * Tile.SIZE
	tile_motions.erase(from)
	animate_tile_from(origin, to, duration)
	tile_motions[to].transport = true


func animate_tile_from(origin: Vector2, to: Vector2i, duration: int) -> void:
	var motion: TileMotion = TileMotion.new()
	motion.origin = origin
	motion.destination = to
	motion.type = level.get_cell(to.y, to.x)
	motion.start_tick = tick_count - 1
	motion.duration = duration
	tile_motions[to] = motion


## Top-left of a block in transit, as collisions see it this tick. It is the
## same place the block is drawn at once the tick is over.
func tile_position_now(motion: TileMotion) -> Vector2:
	return motion.position_at(float(tick_count))


## True while the block that the grid holds in [param cell] has not arrived
## there yet.
func is_tile_in_transit(cell: Vector2i) -> bool:
	if not tile_motions.has(cell):
		return false
	var motion: TileMotion = tile_motions[cell]
	if not motion.transport or level.get_cell(cell.y, cell.x) != motion.type:
		return false
	return not tile_position_now(motion).is_equal_approx(Vector2(cell) * Tile.SIZE)

func _prune_tile_motions() -> void:
	for cell: Vector2i in tile_motions.keys():
		var motion: TileMotion = tile_motions[cell]
		if level.get_cell(cell.y, cell.x) != motion.type or tick_count - 1 - motion.start_tick >= motion.duration:
			tile_motions.erase(cell)
