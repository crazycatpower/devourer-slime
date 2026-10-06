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
var particles: Array[SimParticle] = []
var falling_blocks: Array[SimFallingBlock] = []
var death_timer: int = 0
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
	particles.clear()
	falling_blocks.clear()
	death_timer = 0
	boss = BossState.create(boss_kind)
	if boss.active:
		boss.x = BossSystem.spawn_x(level, boss.w)
		boss.prev_x = boss.x
	if boss_kind == BossState.Kind.WORLD_3:
		BossWorld3.sync_orbiting_shields(self)
	if boss_kind == BossState.Kind.WORLD_1:
		BossWorld1.build_arena(self)
	if boss_kind == BossState.Kind.STEEL_CHASE:
		BossSteelChase.setup(self)
	camera.shake = 0.0
	camera.snap_to(player.center_x(), player.center_y(), level)
	level_reset.emit()


## Advances the simulation by one tick.
func step(p_input: SimInput) -> void:
	input = p_input
	tick_count += 1
	_store_previous_positions()

	if not player.dead and not player.won:
		PlayerSystem.update(self)
		BossSystem.update(self)
	ProjectileSystem.update(self)
	_update_particles()

	if player.dead:
		player.in_bullet_time = false
		death_timer += 1
		if death_timer > DEATH_RESTART_TICKS:
			reset()
	if player.won:
		player.in_bullet_time = false


## Moves the camera toward the player. Call once per 60 Hz frame.
func update_camera() -> void:
	camera.follow(player.center_x(), player.center_y(), level)


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
	if block_type == Tile.GLASS:
		return Palette.CYAN_500
	return Palette.AMBER_600


## Nearest eatable block along the aim direction, or null.
##
## Samples the ray every 3.25 units up to 65 units from ([param cx], [param cy]).
func get_eat_target(cx: float, cy: float, nx: float, ny: float) -> EatTarget:
	var is_world_1: bool = boss_kind == BossState.Kind.WORLD_1
	if is_world_1 and boss.reorg_timer > 0:
		return null
	var scan_boss: bool = (
		is_world_1 and boss.active and not boss.dead and boss.state != BossState.State.SUSPENDED
	)
	for i: int in range(1, 21):
		var f: float = float(i) / 20.0
		var ptx: float = cx + nx * (65.0 * f)
		var pty: float = cy + ny * (65.0 * f)

		if scan_boss:
			for r: int in range(boss.min_r, boss.max_r + 1):
				for c: int in range(boss.min_c, boss.max_c + 1):
					var val: int = boss.grid[r * boss.grid_size + c]
					if val > 0:
						var cell_x: float = boss.cell_x(c)
						var cell_y: float = boss.cell_y(r)
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


## Solid boxes overlapping the given rectangle: level tiles, then the blocks
## that make up the World 1 boss.
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
				if Tile.is_solid(t):
					list.append(SolidBox.make(float(c) * Tile.SIZE, float(r) * Tile.SIZE, t))

	if (
		boss_kind == BossState.Kind.WORLD_1 and boss.active and not boss.dead
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
