class_name BossSystem
extends RefCounted
## Per-tick entry point for boss fights, plus helpers shared by the bosses.

## Horizontal distance at which a suspended boss notices the player.
const TRIGGER_DISTANCE: float = 350.0
## Longest entrance once the player has already watched it on this level.
const RETRY_INTRO_TICKS: int = 30
## Safety bound for [method leap_flight_ticks].
const MAX_LEAP_TICKS: int = 600


static func update(sim: GameSim) -> void:
	FallingBlockSystem.update(sim)
	var boss: BossState = sim.boss
	if not boss.active or boss.dead:
		return
	match sim.boss_kind:
		BossState.Kind.WORLD_1:
			BossWorld1.update(sim)
		BossState.Kind.WORLD_2:
			BossWorld2.update(sim)
		BossState.Kind.WORLD_3:
			BossWorld3.update(sim)
		BossState.Kind.WORLD_4:
			BossWorld4.update(sim)
	BossCollision.resolve(sim)


## Horizontal offset from the boss centre to the player centre.
static func player_dx(sim: GameSim) -> float:
	return sim.player.center_x() - sim.boss.center_x()


static func player_in_trigger_range(sim: GameSim) -> bool:
	return absf(player_dx(sim)) < TRIGGER_DISTANCE


## Starts the entrance that opens the fight. It lasts [param full_ticks] the
## first time; after a death the player has seen it, so it is cut short.
static func begin_intro(sim: GameSim, full_ticks: int) -> void:
	var boss: BossState = sim.boss
	boss.state = BossState.State.INTRO
	boss.intro_timer = mini(full_ticks, RETRY_INTRO_TICKS) if sim.boss_intro_seen else full_ticks
	boss.triggered = true
	sim.boss_intro_seen = true


## Ticks a leap launched from rest at upward speed [param speed] stays in the
## air before the boss is back at the height it left from. Bosses stop rising
## at the arena ceiling, which shortens high leaps considerably; aiming with
## the free-flight time would make them fall well short of their target.
static func leap_flight_ticks(boss_y: float, speed: float, gravity: float) -> float:
	var y: float = boss_y
	var vy: float = -speed
	var ticks: int = 0
	while ticks < MAX_LEAP_TICKS:
		ticks += 1
		vy += gravity
		y += vy
		if y < Tile.SIZE:
			y = Tile.SIZE
			if vy < 0.0:
				vy = 0.0
		if y >= boss_y:
			break
	return float(ticks)


## Level row directly under the boss's feet.
static func floor_row(boss: BossState) -> int:
	return floori((boss.y + boss.h) / Tile.SIZE)


static func left_col(boss: BossState) -> int:
	return floori(boss.x / Tile.SIZE)


## Rightmost level column the boss body actually covers.
static func right_col(boss: BossState) -> int:
	return floori((boss.x + boss.w - 0.001) / Tile.SIZE)


## True when any tile under the boss in [param r_floor] can carry it.
static func rests_on_floor(sim: GameSim, r_floor: int) -> bool:
	if r_floor < 1:
		return false
	for col: int in range(left_col(sim.boss), right_col(sim.boss) + 1):
		if sim.is_solid_or_boundary(r_floor, col):
			return true
	return false


## Applies gravity and keeps a resting boss on the floor. Used by the states
## in which a boss simply stands and waits.
static func settle_on_floor(sim: GameSim, gravity: float) -> void:
	var boss: BossState = sim.boss
	boss.vy += gravity
	boss.y += boss.vy
	var r_floor: int = floor_row(boss)
	if rests_on_floor(sim, r_floor) and boss.vy >= 0.0:
		boss.y = float(r_floor) * Tile.SIZE - boss.h
		boss.vy = 0.0
		boss.grounded = true
	else:
		boss.grounded = false


## Spark that flies toward the boss centre from a random point around it.
static func spawn_converging_spark(
	sim: GameSim, min_radius: float, max_life: float, color: Color, size_range: float, size_min: float
) -> void:
	var boss: BossState = sim.boss
	var angle: float = sim.rng.next_float() * PI * 2.0
	var radius: float = min_radius + sim.rng.next_float() * 80.0
	var px: float = boss.center_x() + cos(angle) * radius
	var py: float = boss.center_y() + sin(angle) * radius
	sim.add_particle(
		px, py,
		-cos(angle) * (radius / 15.0), -sin(angle) * (radius / 15.0),
		max_life, color, sim.rng.next_float() * size_range + size_min
	)


## Marks the boss defeated.
static func defeat(sim: GameSim) -> void:
	sim.boss.dead = true
	sim.boss.active = false


## Replaces the boss's remains with a goal tile and clears the cells around
## it so the player can always reach it.
static func reveal_goal_at_boss(sim: GameSim) -> void:
	var level: LevelGrid = sim.level
	var boss: BossState = sim.boss
	var goal_col: int = clampi(floori(boss.center_x() / Tile.SIZE), 1, level.cols - 2)
	var goal_row: int = clampi(floori(boss.center_y() / Tile.SIZE), 1, level.rows - 2)
	level.set_cell(goal_row, goal_col, Tile.GOAL)
	for dr: int in range(-1, 2):
		for dc: int in range(-1, 2):
			var row: int = goal_row + dr
			var col: int = goal_col + dc
			if level.is_interior(row, col) and level.get_cell(row, col) != Tile.GOAL:
				level.set_cell(row, col, Tile.AIR)


## Writes [param tile] only inside the level's border.
static func set_interior_cell(level: LevelGrid, row: int, col: int, tile: int) -> void:
	if level.is_interior(row, col):
		level.set_cell(row, col, tile)


## X position a boss of width [param boss_w] hangs at before the fight. It is
## the stock arena's spawn column, pulled inside levels too narrow for it.
static func spawn_x(level: LevelGrid, boss_w: float) -> float:
	var rightmost: float = maxf(Tile.SIZE, level.pixel_width() - Tile.SIZE - boss_w)
	return clampf(float(BossState.SPAWN_COLUMN) * Tile.SIZE, Tile.SIZE, rightmost)


## Centre cell (column, row) of the 3x3 trophy a defeated boss leaves behind:
## the stock arena's cell, pulled inside levels too small for it.
static func trophy_cell(level: LevelGrid, stock_row: int, stock_col: int) -> Vector2i:
	return Vector2i(
		clampi(stock_col, 2, maxi(2, level.cols - 3)), clampi(stock_row, 2, maxi(2, level.rows - 3))
	)


## Clears the area around the trophy cell, then places [param ring_tile]
## around a goal. [param clear_below] is how many rows under the trophy
## centre are cleared.
static func place_trophy(
	level: LevelGrid, center: Vector2i, ring_tile: int, clear_below: int
) -> void:
	for r: int in range(center.y - 2, center.y + clear_below + 1):
		for c: int in range(center.x - 4, center.x + 5):
			set_interior_cell(level, r, c, Tile.AIR)
	for dr: int in range(-1, 2):
		for dc: int in range(-1, 2):
			var tile: int = Tile.GOAL if dr == 0 and dc == 0 else ring_tile
			set_interior_cell(level, center.y + dr, center.x + dc, tile)
