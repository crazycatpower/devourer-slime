class_name BossMudGolem
extends RefCounted
## The mud golem, boss of the second world: it is made of the blocks it absorbs.
##
## It drops onto a mound of dirt, swallows it, packs itself into a square and
## then leaps at the player. Any eatable block it touches joins its body. The
## player wins by eating through the body and swallowing the goal core.

const GRAVITY: float = 0.25
const INTRO_TICKS: int = 75
const JUMP_COOLDOWN_TICKS: int = 120
const JUMP_SPEED: float = 7.5 * 1.732
const MAX_JUMP_VX: float = 6.5
const PHASE_2_FILLED: int = 24
const PHASE_3_FILLED: int = 36
## Every this many landings the body is repacked into a square.
const JUMPS_PER_REORG: int = 5
## Blocks that make up the first, 5x5 body (the core is the 25th cell).
const INITIAL_BRICK_COUNT: int = 24

## The dirt mound the boss feeds on when the fight starts.
const MOUND_FIRST_ROW: int = 11
const MOUND_LAST_ROW: int = 13
const MOUND_FIRST_COL: int = 21
const MOUND_LAST_COL: int = 28


## Places the starting mound in the arena.
static func build_arena(sim: GameSim) -> void:
	for r: int in range(MOUND_FIRST_ROW, MOUND_LAST_ROW + 1):
		for c: int in range(MOUND_FIRST_COL, MOUND_LAST_COL + 1):
			BossSystem.set_interior_cell(sim.level, r, c, Tile.DIRT)


static func update(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	if boss.damage_flash > 0.0:
		boss.damage_flash -= 0.05
	if boss.reorg_timer > 0:
		boss.reorg_timer -= 1

	if not boss.has_initial_reorg and _should_start_first_reorg(sim):
		boss.has_initial_reorg = true
		boss.jump_count = 0
		arrange_grid_to_square(sim)

	boss.scale_x += (1.0 - boss.scale_x) * 0.1
	boss.scale_y += (1.0 - boss.scale_y) * 0.1

	match boss.state:
		BossState.State.SUSPENDED:
			if BossSystem.player_in_trigger_range(sim):
				BossSystem.begin_intro(sim, INTRO_TICKS)
				sim.camera.shake = 12.0
				sim.play(Sfx.Id.BOUNCE)
		BossState.State.INTRO:
			_update_intro(sim)
		BossState.State.FALLING:
			_update_falling(sim)
		_:
			_update_fighting(sim)

	_absorb_dirt(sim)


## Repacks the body into the smallest centred square that holds its blocks,
## restoring every block to full health.
static func arrange_grid_to_square(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var level: LevelGrid = sim.level
	var n: int = boss.grid_size
	var center: int = BossState.MUD_GOLEM_CENTER

	var is_initial: bool = not boss.has_initialized_reorg_grid
	if is_initial:
		boss.has_initialized_reorg_grid = true
		# Whatever is left of the mound disappears with the first repack.
		for r: int in range(MOUND_FIRST_ROW, MOUND_LAST_ROW + 1):
			for c: int in range(MOUND_FIRST_COL, MOUND_LAST_COL + 1):
				if Tile.is_eatable(level.get_cell(r, c)):
					level.set_cell(r, c, Tile.AIR)

	# 1. Gather every block except the core.
	var bricks: Array[ReorgAnimCell] = []
	for r: int in n:
		for c: int in n:
			var val: int = boss.grid[r * n + c]
			if val > 0 and val != Tile.GOAL:
				var brick: ReorgAnimCell = ReorgAnimCell.new()
				brick.val = Tile.BOUNCY if Tile.is_bouncy(val) else val
				if val == Tile.DIRT_EATEN_1 or val == Tile.DIRT_EATEN_2:
					brick.val = Tile.DIRT
				brick.from_r = r
				brick.from_c = c
				bricks.append(brick)

	if is_initial:
		# The first body is always a full 5x5 square.
		while bricks.size() < INITIAL_BRICK_COUNT:
			var filler: ReorgAnimCell = ReorgAnimCell.new()
			filler.val = Tile.DIRT
			filler.from_r = center
			filler.from_c = center
			bricks.append(filler)
		if bricks.size() > INITIAL_BRICK_COUNT:
			bricks.resize(INITIAL_BRICK_COUNT)

	# 2. Clear everything except the core.
	for i: int in boss.grid.size():
		if boss.grid[i] != Tile.GOAL:
			boss.grid[i] = Tile.AIR

	# 3. Pack the blocks bottom-up into a 3x3, 5x5 or 7x7 square.
	var half: int = 3
	if bricks.size() <= 8:
		half = 1
	elif bricks.size() <= 24:
		half = 2

	var delay_gap: int = 1
	var cell_duration: int = 5
	var index: int = 0
	var anim_cells: Array[ReorgAnimCell] = []
	for r: int in range(center + half, center - half - 1, -1):
		for c: int in range(center - half, center + half + 1):
			if r == center and c == center:
				continue
			if index < bricks.size():
				var brick: ReorgAnimCell = bricks[index]
				boss.grid[r * n + c] = brick.val
				brick.to_r = r
				brick.to_c = c
				brick.start_frame = index * delay_gap
				brick.end_frame = index * delay_gap + cell_duration
				anim_cells.append(brick)
				index += 1
			else:
				boss.grid[r * n + c] = Tile.AIR

	boss.reorg_cells = anim_cells
	var total: int = anim_cells.size()
	boss.reorg_timer = (total - 1) * delay_gap + cell_duration if total > 0 else 35

	# 4. Body size and position follow the new shape.
	update_bounds(sim)

	sim.add_shake(20.0)
	sim.play(Sfx.Id.BOUNCE)
	sim.spawn_particles(boss.center_x(), boss.center_y(), Palette.AMBER_400, 25, 5.5)
	sim.spawn_particles(boss.center_x(), boss.center_y(), Palette.GREEN_400, 15, 4.5)


## Recomputes the body's bounding box after its grid changed, moving and
## resizing the boss so that every block stays where it was in the world.
## An empty grid means the boss has been eaten whole.
static func update_bounds(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var n: int = boss.grid_size
	var min_r: int = n
	var max_r: int = -1
	var min_c: int = n
	var max_c: int = -1
	for r: int in n:
		for c: int in n:
			if boss.grid[r * n + c] > 0:
				min_r = mini(min_r, r)
				max_r = maxi(max_r, r)
				min_c = mini(min_c, c)
				max_c = maxi(max_c, c)
	if max_r < 0:
		kill_and_reveal_goal(sim)
		return

	var offset: Vector2 = Vector2(min_c - boss.min_c, min_r - boss.min_r) * Tile.SIZE
	boss.x += offset.x
	boss.y += offset.y
	# Rebase both snapshots: resizing is not movement, and must not make
	# unchanged blocks slide from the old bounding-box origin for one frame.
	boss.prev_x += offset.x
	boss.prev_y += offset.y
	boss.w = float(max_c - min_c + 1) * Tile.SIZE
	boss.h = float(max_r - min_r + 1) * Tile.SIZE
	boss.min_r = min_r
	boss.min_c = min_c
	boss.max_r = max_r
	boss.max_c = max_c


static func kill_and_reveal_goal(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	BossSystem.defeat(sim)
	sim.camera.shake = 30.0
	sim.play(Sfx.Id.HURT)
	sim.play(Sfx.Id.WIN, 0.0, 0.1)
	sim.spawn_particles(boss.center_x(), boss.center_y(), Palette.AMBER_600, 40, 8.0)
	sim.spawn_particles(boss.center_x(), boss.center_y(), Palette.AMBER_400, 40, 8.0)
	sim.spawn_particles(boss.center_x(), boss.center_y(), Palette.EMERALD_400, 40, 8.0)
	BossSystem.reveal_goal_at_boss(sim)


static func phase_profile(sim: GameSim) -> Dictionary:
	var filled: int = sim.boss.filled_count()
	if filled >= PHASE_3_FILLED:
		return {"phase": 2}
	if filled >= PHASE_2_FILLED:
		return {"phase": 1}
	return {"phase": 0}


static func _should_start_first_reorg(sim: GameSim) -> bool:
	var boss: BossState = sim.boss
	if boss.count_blocks() >= INITIAL_BRICK_COUNT + 1:
		return true
	var mound_dirt: int = 0
	for r: int in range(MOUND_FIRST_ROW, MOUND_LAST_ROW + 1):
		for c: int in range(MOUND_FIRST_COL, MOUND_LAST_COL + 1):
			if sim.level.get_cell(r, c) == Tile.DIRT:
				mound_dirt += 1
	if mound_dirt == 0:
		return true
	return boss.state == BossState.State.ACTIVE and boss.grounded


static func _update_intro(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	boss.intro_timer -= 1
	if boss.y < 80.0:
		boss.y += 1.3
	if boss.intro_timer % 2 == 0:
		BossSystem.spawn_converging_spark(sim, 120.0, 25.0, Palette.AMBER_600, 3.0, 4.0)
	if boss.intro_timer <= 0:
		BossSystem.finish_intro(sim, 30.0, Palette.AMBER_600, 40, 7.0)


## The opening drop passes through eatable blocks (absorbing them on the way)
## and only stops on tiles the boss cannot eat.
static func _update_falling(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var level: LevelGrid = sim.level
	boss.vy += GRAVITY
	boss.y += boss.vy

	var r_floor: int = BossSystem.floor_row(boss)
	var landed: bool = false
	if r_floor >= 1:
		for col: int in range(BossSystem.left_col(boss), BossSystem.right_col(boss) + 1):
			var tile: int = level.get_cell(r_floor, col) if level.in_bounds(r_floor, col) else Tile.STEEL
			if tile == Tile.STEEL or (Tile.is_solid(tile) and not Tile.is_eatable(tile)):
				landed = true
				break
	if landed:
		boss.y = float(r_floor) * Tile.SIZE - boss.h
		boss.vy = 0.0
		boss.state = BossState.State.ACTIVE
		boss.grounded = true
		boss.scale_y = 0.5
		boss.scale_x = 1.6
		sim.camera.shake = 28.0
		sim.play(Sfx.Id.LAND)
		sim.spawn_particles(boss.center_x(), boss.y + boss.h, Palette.AMBER_600, 35, 6.0)


static func _update_fighting(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var level: LevelGrid = sim.level
	boss.vy += GRAVITY
	boss.y += boss.vy
	boss.x += boss.vx

	# Keep the boss inside the arena.
	if boss.y < Tile.SIZE:
		boss.y = Tile.SIZE
		if boss.vy < 0.0:
			boss.vy = 0.0
	if boss.x < Tile.SIZE:
		boss.x = Tile.SIZE
		boss.vx = 0.0
	elif boss.x + boss.w > level.pixel_width() - Tile.SIZE:
		boss.x = level.pixel_width() - Tile.SIZE - boss.w
		boss.vx = 0.0

	var r_floor: int = BossSystem.floor_row(boss)
	if BossSystem.rests_on_floor(sim, r_floor) and boss.vy >= 0.0:
		boss.y = float(r_floor) * Tile.SIZE - boss.h
		boss.vy = 0.0
		boss.vx = 0.0
		if not boss.grounded:
			boss.grounded = true
			if boss.state == BossState.State.JUMPING:
				boss.jump_count += 1
				if boss.jump_count % JUMPS_PER_REORG == 0:
					arrange_grid_to_square(sim)
			boss.state = BossState.State.ACTIVE
			boss.scale_y = 0.5
			boss.scale_x = 1.6
			sim.add_shake(12.0)
			sim.play(Sfx.Id.LAND)
			sim.spawn_particles(boss.center_x(), boss.y + boss.h, Palette.AMBER_400, 20, 5.0)
	else:
		boss.grounded = false

	if boss.grounded:
		boss.cooldown -= 1
		if boss.cooldown <= 0:
			boss.cooldown = JUMP_COOLDOWN_TICKS
			# Aim the leap so that it lands on the player's current position.
			var dx: float = BossSystem.player_dx(sim)
			boss.vy = -JUMP_SPEED
			var flight_time: float = BossSystem.leap_flight_ticks(boss.y, JUMP_SPEED, GRAVITY)
			boss.vx = maxf(-MAX_JUMP_VX, minf(MAX_JUMP_VX, dx / flight_time))
			boss.state = BossState.State.JUMPING
			boss.grounded = false
			boss.scale_y = 1.6
			boss.scale_x = 0.6
			sim.add_shake(8.0)
			sim.play(Sfx.Id.JUMP)


## Pulls every eatable level block that touches the body into the grid.
static func _absorb_dirt(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var level: LevelGrid = sim.level
	if not boss.active or boss.dead or boss.state == BossState.State.SUSPENDED:
		return
	var n: int = boss.grid_size
	var absorbed_any: bool = false
	for r: int in n:
		for c: int in n:
			if boss.grid[r * n + c] != 0 or not boss.has_occupied_neighbor(r, c):
				continue
			var level_c: int = floori((boss.cell_x(c) + Tile.SIZE / 2.0) / Tile.SIZE)
			var level_r: int = floori((boss.cell_y(r) + Tile.SIZE / 2.0) / Tile.SIZE)
			if not level.is_interior(level_r, level_c):
				continue
			var tile: int = level.get_cell(level_r, level_c)
			if Tile.is_eatable(tile):
				level.set_cell(level_r, level_c, Tile.AIR)
				boss.grid[r * n + c] = tile
				sim.spawn_particles(
					float(level_c) * Tile.SIZE + Tile.SIZE / 2.0,
					float(level_r) * Tile.SIZE + Tile.SIZE / 2.0,
					Palette.PINK_500 if tile == Tile.BOUNCY else Palette.AMBER_600, 12, 3.5
				)
				absorbed_any = true

	if absorbed_any:
		sim.play(Sfx.Id.EAT)
		boss.damage_flash = 0.8
		boss.scale_x = 1.3
		boss.scale_y = 0.7
		sim.add_shake(8.0)
		update_bounds(sim)
