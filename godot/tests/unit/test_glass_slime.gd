extends TestCase
## The glass slime: its arena of glass and its three moves.


func test_bombs_start_inside_walls_even_when_shields_wind_up_outside() -> void:
	var sim: GameSim = _fighting()
	for spawn_x: float in [-80.0, sim.level.pixel_width() + 80.0]:
		BossGlassSlime._throw_bomb(sim, Vector2(spawn_x, 100.0))
		var bomb: GlassBomb = sim.boss.bombs.back()
		check(bomb.x - BossGlassSlime.BOMB_RADIUS >= Tile.SIZE, "left edge stays in the arena")
		check(bomb.x + BossGlassSlime.BOMB_RADIUS <= sim.level.pixel_width() - Tile.SIZE, "right edge stays in the arena")
		for _tick: int in 180:
			BossGlassSlime._fly_bomb(sim.level, bomb)
			check(bomb.x - BossGlassSlime.BOMB_RADIUS >= Tile.SIZE, "flight cannot leave the left wall")
			check(bomb.x + BossGlassSlime.BOMB_RADIUS <= sim.level.pixel_width() - Tile.SIZE, "flight cannot leave the right wall")


func test_fast_bomb_cannot_cross_an_interior_wall() -> void:
	var sim: GameSim = _loaded()
	# Reuse a steel cell in a test fixture to check swept collision.
	sim.level.set_cell(5, 10, Tile.STEEL)
	for direction: float in [-1.0, 1.0]:
		var bomb: GlassBomb = GlassBomb.new()
		bomb.x = 330.0 if direction > 0.0 else 510.0
		bomb.y = 220.0
		bomb.vx = direction * 200.0
		BossGlassSlime._fly_bomb(sim.level, bomb)
		if direction > 0.0:
			check(bomb.x + BossGlassSlime.BOMB_RADIUS <= 400.0, "cannot tunnel right through steel")
		else:
			check(bomb.x - BossGlassSlime.BOMB_RADIUS >= 440.0, "cannot tunnel left through steel")
		check_near(bomb.vx, 0.0, 0.0, "wall stops horizontal motion")


func test_arena_varies_with_seed_and_retry() -> void:
	var first: GameSim = _loaded()
	var second: GameSim = GameSim.new()
	second.rng.set_seed(27)
	second.load_level(40, LevelLibrary.built_in_level(40), BossState.Kind.GLASS_SLIME)
	check(not first.level.equals(second.level), "different seeds give different dirt positions")
	var before: LevelGrid = first.level.duplicate_grid()
	first.reset()
	check(not first.level.equals(before), "retry draws a new distribution")


func test_arena_randomness_keeps_ammo_sparse_and_attack_rng_independent() -> void:
	for seed_value: int in range(1, 21):
		var sim: GameSim = GameSim.new()
		sim.rng.set_seed(seed_value)
		sim.load_level(40, LevelLibrary.built_in_level(40), BossState.Kind.GLASS_SLIME)
		var counts: Dictionary[int, int] = _tile_counts(sim.level)
		var dirt_total: int = counts.get(Tile.DIRT, 0)
		var glass_total: int = counts.get(Tile.GLASS, 0)
		check(dirt_total * 20 < glass_total, "sparse dirt for seed %d" % seed_value)
		for row: int in range(sim.boss.arena_fill_row, sim.level.rows - 1):
			var dirt: int = 0
			for col: int in range(1, sim.level.cols - 1):
				if sim.level.get_cell(row, col) == Tile.DIRT:
					dirt += 1
			check(dirt >= (2 if row == sim.boss.arena_fill_row else 1), "ammo remains in each row")
		var draws: int = sim.rng.draw_count
		BossGlassSlime._deepen(sim, BossGlassSlime.ARENA_GROWTH)
		check_eq(sim.rng.draw_count, draws, "terrain extension cannot perturb attack randomness")


func test_winding_up_shields_keep_the_bomb_inside_both_walls() -> void:
	for left_wall: bool in [true, false]:
		var sim: GameSim = _fighting()
		var boss: BossState = sim.boss
		boss.x = Tile.SIZE if left_wall else sim.level.pixel_width() - Tile.SIZE - boss.w
		var shield: ShieldState = boss.shields[0]
		shield.winding_up = true
		shield.windup_timer = ShieldState.WINDUP_TICKS
		shield.hold_offset = Vector2(-85.0 if left_wall else 85.0, 0.0)
		for _tick: int in ShieldState.WINDUP_TICKS:
			BossGlassSlime._update_windups(sim)
			check(shield.cx - BossGlassSlime.BOMB_RADIUS >= Tile.SIZE, "windup stays inside the left wall")
			check(shield.cx + BossGlassSlime.BOMB_RADIUS <= sim.level.pixel_width() - Tile.SIZE, "windup stays inside the right wall")
		check_eq(boss.bombs.size(), 1, "a shield at the wall can still be thrown")


func test_body_contact_is_safe_in_every_attack_state() -> void:
	for state: BossState.State in [BossState.State.ACTIVE, BossState.State.CHARGING, BossState.State.JUMPING, BossState.State.STUNNED]:
		for side: int in 4:
			var sim: GameSim = _fighting()
			sim.boss.state = state
			sim.boss.x = 800.0
			sim.boss.y = 200.0
			match side:
				0: sim.player.place_at(768.0, 240.0)
				1: sim.player.place_at(918.0, 240.0)
				2: sim.player.place_at(840.0, 168.0)
				3: sim.player.place_at(840.0, 318.0)
			BossCollision.resolve(sim)
			check(not sim.player.dead, "state %d side %d: contact alone is safe" % [state, side])


func test_glass_contact_stops_motion_without_bounce_or_effects() -> void:
	for side: int in 4:
		var sim: GameSim = _fighting()
		sim.boss.x = 800.0
		sim.boss.y = 200.0
		var sounds: Array[int] = []
		sim.sfx_requested.connect(func(id: Sfx.Id, _param: float, _delay: float) -> void: sounds.append(id))
		match side:
			0: sim.player.place_at(768.0, 240.0)
			1: sim.player.place_at(918.0, 240.0)
			2: sim.player.place_at(840.0, 168.0)
			3: sim.player.place_at(840.0, 318.0)
		sim.player.vx = 6.0 if side == 0 else -6.0
		sim.player.vy = 12.0 if side == 2 else -7.0
		var particles_before: int = sim.particles.size()
		var shake_before: float = sim.camera.shake
		var scale_x_before: float = sim.player.scale_x
		var scale_y_before: float = sim.player.scale_y
		BossCollision.resolve(sim)
		if side < 2:
			check_near(sim.player.vx, 0.0, 0.0, "side contact stops horizontal motion")
			check_near(sim.player.vy, -7.0, 0.0, "side contact adds no upward kick")
		else:
			check_near(sim.player.vy, 0.0, 0.0, "vertical contact stops rather than reverses motion")
			check_eq(sim.player.grounded, side == 2, "only landing on top grounds the player")
		check_eq(sim.player.wall_bounce_timer, 0, "no wall bounce")
		check_near(sim.player.scale_x, scale_x_before, 0.0, "no bounce squash")
		check_near(sim.player.scale_y, scale_y_before, 0.0, "no bounce stretch")
		check_eq(sim.particles.size(), particles_before, "no bounce particles")
		check_near(sim.camera.shake, shake_before, 0.0, "no bounce shake")
		check(sounds.is_empty(), "no bounce sound")
		check(not sim.player.dead, "plain glass contact stays safe")


func test_player_can_stand_on_glass_boss_without_launching() -> void:
	var sim: GameSim = _fighting()
	sim.boss.state = BossState.State.STUNNED
	sim.boss.cooldown = 200
	sim.boss.x = 800.0
	sim.boss.y = 200.0
	sim.player.place_at(840.0, sim.boss.y - sim.player.h)
	for _tick: int in 40:
		sim.step(SimInput.new())
		check_near(sim.player.y, sim.boss.y - sim.player.h, 0.001, "top is a solid surface")
		check_near(sim.player.vy, 0.0, 0.0, "landing adds no bounce velocity")
		check(sim.player.grounded and not sim.player.dead, "safe grounded contact")


func test_body_can_crush_player_against_a_wall() -> void:
	var sim: GameSim = _fighting()
	sim.boss.state = BossState.State.JUMPING
	sim.boss.x = Tile.SIZE + sim.player.w - 2.0
	sim.boss.y = 200.0
	sim.player.place_at(Tile.SIZE, 240.0)
	BossCollision.resolve(sim)
	check(sim.player.dead, "a boss push blocked by steel is crushing")


func test_slam_damages_dirt_once_and_stuns() -> void:
	var types: Array[int] = [Tile.DIRT, Tile.DIRT_EATEN_1, Tile.DIRT_EATEN_2]
	var after: Array[int] = [Tile.DIRT_EATEN_1, Tile.DIRT_EATEN_2, Tile.AIR]
	for index: int in 3:
		var sim: GameSim = _fighting()
		sim.player.place_at(300.0, 100.0)
		sim.level.set_cell(8, 20, types[index])
		sim.boss.x = 800.0
		sim.boss.y = 190.0
		sim.boss.vy = 20.0
		sim.boss.state = BossState.State.JUMPING
		sim.boss.current_move = BossGlassSlime.Move.SLAM
		BossGlassSlime._update_slamming(sim)
		check_eq(sim.boss.state, BossState.State.STUNNED, "dirt stops the slam")
		check_eq(sim.level.get_cell(8, 20), after[index], "one durability lost on impact")
		for _tick: int in 10:
			BossSystem.update(sim)
		check_eq(sim.level.get_cell(8, 20), after[index], "stun does not repeatedly damage the dirt")


func test_swoop_damages_dirt_once_and_stuns() -> void:
	var types: Array[int] = [Tile.DIRT, Tile.DIRT_EATEN_1, Tile.DIRT_EATEN_2]
	var after: Array[int] = [Tile.DIRT_EATEN_1, Tile.DIRT_EATEN_2, Tile.AIR]
	for index: int in 3:
		var sim: GameSim = _fighting()
		sim.player.place_at(300.0, 100.0)
		sim.level.set_cell(8, 20, types[index])
		var boss: BossState = sim.boss
		boss.x = 800.0
		boss.y = 180.0
		boss.state = BossState.State.JUMPING
		boss.current_move = BossGlassSlime.Move.SWOOP
		boss.swoop_from = Vector2(boss.x, boss.y)
		boss.swoop_to = Vector2(1000.0, 180.0)
		boss.dive_x = 800.0
		boss.dive_floor_y = 400.0
		for _tick: int in 60:
			BossGlassSlime._update_swooping(sim)
			if boss.state != BossState.State.JUMPING:
				break
		check_eq(boss.state, BossState.State.STUNNED, "dirt interrupts the swoop")
		check_eq(sim.level.get_cell(8, 20), after[index], "one durability lost on impact")
		for _tick: int in 10:
			BossSystem.update(sim)
		check_eq(sim.level.get_cell(8, 20), after[index], "each collision damages only once")


func test_bomb_aim_is_scattered_but_reproducible() -> void:
	var sim: GameSim = _fighting()
	var other: GameSim = _fighting()
	var leftmost: float = INF
	var rightmost: float = -INF
	for _shot: int in 20:
		var origin: Vector2 = Vector2(800.0, 100.0)
		BossGlassSlime._throw_bomb(sim, origin)
		BossGlassSlime._throw_bomb(other, origin)
		var bomb: GlassBomb = sim.boss.bombs.back()
		var reproduced: GlassBomb = other.boss.bombs.back()
		var target_x: float = bomb.x + bomb.vx * BossGlassSlime.BOMB_FLIGHT_TICKS
		var offset: float = target_x - sim.player.center_x()
		leftmost = minf(leftmost, offset)
		rightmost = maxf(rightmost, offset)
		check(absf(offset) <= BossGlassSlime.BOMB_AIM_SPREAD_X, "aim stays within its declared spread")
		check_near(bomb.vx, reproduced.vx, 0.0, "seed reproduces horizontal aim")
		check_near(bomb.vy, reproduced.vy, 0.0, "seed reproduces vertical aim")
	check(rightmost - leftmost > 100.0, "throws no longer pinpoint the player")


func test_bomb_wall_contact_explodes_without_waiting() -> void:
	var sim: GameSim = _fighting()
	var bomb: GlassBomb = GlassBomb.new()
	bomb.x = Tile.SIZE + BossGlassSlime.BOMB_RADIUS
	bomb.y = 200.0
	bomb.vx = -100.0
	sim.boss.bombs.append(bomb)
	BossGlassSlime._update_bombs(sim)
	check(sim.boss.bombs.is_empty(), "wall impact explodes in the same tick")
	check(not sim.player.dead, "a distant explosion does not kill")


func test_repair_restores_only_phase_quota_after_warning() -> void:
	for durability: int in [3, 2, 1]:
		var sim: GameSim = _fighting()
		sim.boss.durability = durability
		BossGlassSlime.regenerate_shields(sim)
		for shield: ShieldState in sim.boss.shields:
			shield.active = false
		var before: LevelGrid = sim.level.duplicate_grid()
		_begin(sim, BossGlassSlime.Move.REPAIR)
		check_eq(sim.boss.state, BossState.State.CHARGING)
		check_eq(BossGlassSlime.repair_amount(sim.boss), 5 - durability)
		for tick: int in BossGlassSlime.REPAIR_WARNING_TICKS - 1:
			BossSystem.update(sim)
		check(not sim.boss.shields[0].active, "repair waits for the warning")
		BossSystem.update(sim)
		var count: int = 0
		for shield: ShieldState in sim.boss.shields:
			if shield.active:
				count += 1
		check_eq(count, 5 - durability, "restore 2/3/4 shields per phase")
		check_eq(sim.boss.durability, durability, "core health is unchanged")
		check(sim.level.equals(before), "repair never changes terrain")


func test_repair_keeps_existing_shields_and_respects_capacity() -> void:
	var sim: GameSim = _fighting()
	var existing: ShieldState = sim.boss.shields[0]
	sim.boss.shields[3].active = false
	check_eq(BossGlassSlime.repair_amount(sim.boss), 1, "intent shows actual available capacity")
	_begin(sim, BossGlassSlime.Move.REPAIR)
	for tick: int in BossGlassSlime.REPAIR_WARNING_TICKS:
		BossSystem.update(sim)
	check(sim.boss.shields[0] == existing, "existing shields are preserved")
	check_eq(sim.boss.shields.size(), 4, "repair cannot exceed phase limit")
	check(sim.boss.shields[3].active)
	check_eq(BossGlassSlime.repair_amount(sim.boss), 0)


func test_core_damage_interrupts_repair_and_reset_clears_cast() -> void:
	var sim: GameSim = _fighting()
	for shield: ShieldState in sim.boss.shields:
		shield.active = false
	_begin(sim, BossGlassSlime.Move.REPAIR)
	check(BossGlassSlime.hit_by_projectile(sim, sim.boss.center_x(), sim.boss.center_y()))
	check_eq(sim.boss.state, BossState.State.ACTIVE, "core hit interrupts repair")
	_begin(sim, BossGlassSlime.Move.REPAIR)
	sim.reset()
	check_eq(sim.boss.state, BossState.State.SUSPENDED)

func test_fight_escalates_as_durability_drops() -> void:
	check_eq(BossGlassSlime.shield_count_for(3), 4)
	check_eq(BossGlassSlime.shield_count_for(2), 8)
	check_eq(BossGlassSlime.shield_count_for(1), 12)
	check_eq(BossGlassSlime.bomb_count_for(3), 1)
	check_eq(BossGlassSlime.bomb_count_for(1), 3)
	check(BossGlassSlime.move_cooldown_for(1) < BossGlassSlime.move_cooldown_for(3), "moves come faster")
	check(BossGlassSlime.warning_ticks_for(1) < BossGlassSlime.warning_ticks_for(3), "with shorter warnings")
	check(BossGlassSlime.warning_ticks_for(1) >= 40, "but always long enough to move")
	check(BossGlassSlime.swoop_speed_for(1) > BossGlassSlime.swoop_speed_for(3), "the swoop is faster")
	check(BossGlassSlime.stun_ticks_for(1) >= 90, "while the opening after a slam stays usable")


func test_arena_is_an_open_top_over_deep_glass_with_a_little_dirt() -> void:
	var sim: GameSim = _loaded()
	var level: LevelGrid = sim.level
	var original: LevelGrid = LevelLibrary.built_in_level(40).grid
	var first_fill_row: int = sim.boss.arena_fill_row
	check_eq(first_fill_row, original.rows - 2, "the fill starts at the bottom of the room it came with")
	check_eq(level.rows, original.rows + BossGlassSlime.ARENA_START_DEPTH, "and goes far down from there")
	var glass: int = 0
	var dirt: int = 0
	for row: int in range(1, level.rows - 1):
		for col: int in range(1, level.cols - 1):
			var tile: int = level.get_cell(row, col)
			if row < first_fill_row:
				check_eq(tile, Tile.AIR, "the upper arena stays open (%d, %d)" % [row, col])
			elif tile == Tile.GLASS:
				glass += 1
			elif tile == Tile.DIRT:
				dirt += 1
			else:
				fail("only glass and dirt fill the lower arena, found %d at (%d, %d)" % [tile, row, col])
	check_eq(glass + dirt, (level.rows - 1 - first_fill_row) * (level.cols - 2), "the fill is solid from wall to wall")
	check(dirt >= 20, "there is still dirt to find (%d)" % dirt)
	check(dirt * 20 < glass, "dirt stays below five percent (%d dirt, %d glass)" % [dirt, glass])
	var top_dirt: int = 0
	for col: int in range(1, level.cols - 1):
		if level.get_cell(first_fill_row, col) == Tile.DIRT:
			top_dirt += 1
	check(top_dirt >= 2, "some of it lies on the surface, ready to eat")
	for row: int in level.rows:
		check_eq(level.get_cell(row, 0), Tile.STEEL, "the side walls run all the way down")
		check_eq(level.get_cell(row, level.cols - 1), Tile.STEEL)
	for col: int in level.cols:
		check_eq(level.get_cell(level.rows - 1, col), Tile.STEEL, "and a floor closes the bottom")

	var again: GameSim = _loaded()
	check(again.level.equals(level), "the same random seed reproduces the arena")


func test_arena_has_no_bottom_to_reach() -> void:
	var sim: GameSim = _fighting()
	var level: LevelGrid = sim.level
	var rows_before: int = level.rows
	# Far down, close to the floor.
	sim.player.place_at(805.0, float(level.rows - 4) * Tile.SIZE)
	_update_bombs_only(sim)
	check(level.rows > rows_before, "more arena appears below")
	check_eq((level.rows - rows_before) % BossGlassSlime.ARENA_GROWTH, 0, "a batch of rows at a time")
	var feet_row: int = Tile.cell_of(sim.player.y + sim.player.h)
	check(level.rows - 1 - feet_row >= BossGlassSlime.ARENA_DEPTH_AHEAD, "keeping plenty under the player")
	for row: int in range(rows_before - 1, level.rows - 1):
		check_eq(level.get_cell(row, 0), Tile.STEEL, "walled")
		for col: int in range(1, level.cols - 1):
			var tile: int = level.get_cell(row, col)
			check(tile == Tile.GLASS or tile == Tile.DIRT, "and filled like the rest (%d, %d)" % [row, col])
	for col: int in level.cols:
		check_eq(level.get_cell(level.rows - 1, col), Tile.STEEL, "with the floor moved down under it")


func test_boss_roams_high_instead_of_parking_overhead() -> void:
	var sim: GameSim = _fighting()
	var boss: BossState = sim.boss
	sim.player.place_at(1005.0, sim.player.y)
	var leftmost: float = INF
	var rightmost: float = -INF
	var closest: float = INF
	var overhead_ticks: int = 0
	var ticks: int = 900
	for _tick: int in ticks:
		sim.tick_count += 1
		_update_bombs_only(sim)
		var offset: float = boss.center_x() - sim.player.center_x()
		leftmost = minf(leftmost, offset)
		rightmost = maxf(rightmost, offset)
		closest = minf(closest, sim.player.y - (boss.y + boss.h))
		if absf(offset) < 60.0:
			overhead_ticks += 1
	check(rightmost > 250.0 and leftmost < -250.0, "it wanders well to both sides (%d to %d)" % [roundi(leftmost), roundi(rightmost)])
	check(overhead_ticks * 4 < ticks, "and spends little time right overhead (%d of %d ticks)" % [overhead_ticks, ticks])
	check(closest > 100.0 and closest < 200.0, "lower flight still leaves clearance (%d)" % roundi(closest))

func test_other_arenas_are_not_filled() -> void:
	var sim: GameSim = GameSim.new()
	sim.load_level(30, LevelLibrary.built_in_level(30), BossState.Kind.BOUNCY_SLIME)
	check(sim.level.equals(LevelLibrary.built_in_level(30).grid), "only the glass slime's arena changes")


func test_random_intents_are_reproducible_with_rare_repair() -> void:
	var sim: GameSim = _fighting()
	var replay: GameSim = _fighting()
	sim.boss.shields[0].active = false
	replay.boss.shields[0].active = false
	sim.rng.set_seed(24680)
	replay.rng.set_seed(24680)
	var counts: Array[int] = [0, 0, 0, 0]
	for draw: int in 1000:
		var move: BossGlassSlime.Move = BossGlassSlime.next_move(sim)
		check_eq(move, BossGlassSlime.next_move(replay), "same seed repeats intents")
		counts[move] += 1
	check(counts[BossGlassSlime.Move.REPAIR] >= 60 and counts[BossGlassSlime.Move.REPAIR] <= 140, "repair has roughly ten percent weight")
	for move: int in 3:
		check(counts[move] > counts[BossGlassSlime.Move.REPAIR], "each attack is more common than repair")


func test_random_intents_skip_unusable_bombs_and_full_shield_repair() -> void:
	var sim: GameSim = _fighting()
	for draw: int in 100:
		check(BossGlassSlime.next_move(sim) != BossGlassSlime.Move.REPAIR, "full shields need no repair")
	for shield: ShieldState in sim.boss.shields:
		shield.active = false
	for draw: int in 100:
		check(BossGlassSlime.next_move(sim) != BossGlassSlime.Move.BOMBS, "empty ring cannot throw bombs")

func test_slam_commits_to_a_column_and_smashes_down_through_the_glass() -> void:
	var sim: GameSim = _fighting()
	var boss: BossState = sim.boss
	var level: LevelGrid = sim.level
	sim.player.place_at(805.0, sim.player.y)
	_begin(sim, BossGlassSlime.Move.SLAM)
	check_eq(boss.state, BossState.State.CHARGING)
	var warning: int = boss.max_charge_timer
	check_eq(warning, BossGlassSlime.warning_ticks_for(3))

	# The mark follows the player at first... (to columns 6 to 8, where the
	# first dirt lies two rows down)
	sim.player.place_at(286.0, sim.player.y)
	for _tick: int in 10:
		BossSystem.update(sim)
	check_near(boss.dive_x, sim.player.center_x() - boss.w / 2.0, 0.01, "the mark follows the player")
	# ...then commits, so stepping aside late is enough.
	for _tick: int in ceili(float(warning) * BossGlassSlime.TRACKING_SHARE):
		BossSystem.update(sim)
	var committed: float = boss.dive_x
	sim.player.place_at(1205.0, sim.player.y)
	_run_until(sim, BossState.State.STUNNED)

	check_eq(boss.state, BossState.State.STUNNED)
	check_near(boss.x, committed, 0.01, "it came straight down on the committed column")
	check(not sim.player.dead, "a player who stepped aside lives")
	# It rests on the first thing under it that is not glass.
	var rest_row: int = roundi((boss.y + boss.h) / Tile.SIZE)
	var supported: bool = false
	for col: int in range(BossSystem.left_col(boss), BossSystem.right_col(boss) + 1):
		var under: int = level.get_cell(rest_row, col)
		supported = supported or (Tile.is_solid(under) and under != Tile.GLASS)
	check(supported, "something other than glass holds it up")
	var first_fill_row: int = sim.boss.arena_fill_row
	check(rest_row > first_fill_row, "it went down into the fill")
	for row: int in range(first_fill_row, rest_row):
		for col: int in range(BossSystem.left_col(boss), BossSystem.right_col(boss) + 1):
			check(level.get_cell(row, col) != Tile.GLASS, "the glass in its way is gone (%d, %d)" % [row, col])
	check_eq(boss.shields.size(), 4)
	for shield: ShieldState in boss.shields:
		check(shield.active, "it keeps its shields while stunned")
		check(BossGlassSlime.hit_by_projectile(sim, shield.cx, shield.cy, true), "and they still stop a block")

	check(BossGlassSlime.hit_by_projectile(sim, boss.center_x(), boss.center_y()), "a block that gets past them hits the core")
	check_eq(boss.durability, 2)
	check_eq(boss.state, BossState.State.ACTIVE, "one hit per opening: it takes off again")
	check_eq(boss.shields.size(), 8, "with a larger ring")


func test_slam_kills_a_player_who_stays_under_it() -> void:
	var sim: GameSim = _fighting()
	_begin(sim, BossGlassSlime.Move.SLAM)
	_run_until(sim, BossState.State.STUNNED)
	check(sim.player.dead, "the slam is fatal")


func test_stun_wears_off_and_the_ring_returns() -> void:
	var sim: GameSim = _fighting()
	sim.player.place_at(805.0, sim.player.y)
	_begin(sim, BossGlassSlime.Move.SLAM)
	for _tick: int in ceili(float(sim.boss.max_charge_timer) * BossGlassSlime.TRACKING_SHARE) + 2:
		BossSystem.update(sim)
	sim.player.place_at(1205.0, sim.player.y)
	_run_until(sim, BossState.State.STUNNED)
	var stun: int = sim.boss.cooldown
	check_eq(stun, BossGlassSlime.stun_ticks_for(3))
	for _tick: int in stun + 1:
		BossSystem.update(sim)
	check_eq(sim.boss.state, BossState.State.ACTIVE)
	check_eq(sim.boss.durability, 3, "nothing was lost")
	var active: int = 0
	for shield: ShieldState in sim.boss.shields:
		if shield.active:
			active += 1
	check_eq(active, 4, "the ring is whole again")


func test_slam_floor_ignores_glass() -> void:
	var level: LevelGrid = LevelGrid.new(20, 15)
	for col: int in 20:
		level.set_cell(13, col, Tile.STEEL)
		level.set_cell(11, col, Tile.GLASS)
	check_near(BossGlassSlime.slam_floor_y(level, 200.0, 120.0, 100.0), 13.0 * Tile.SIZE, 0.0, "glass does not stop it")
	level.set_cell(12, 6, Tile.DIRT)
	check_near(BossGlassSlime.slam_floor_y(level, 200.0, 120.0, 100.0), 12.0 * Tile.SIZE, 0.0, "dirt does")
	check_near(BossGlassSlime.slam_floor_y(level, 400.0, 120.0, 100.0), 13.0 * Tile.SIZE, 0.0, "but only under the boss")
	var bare: LevelGrid = LevelGrid.new(20, 15)
	check_near(BossGlassSlime.slam_floor_y(bare, 200.0, 120.0, 100.0), 14.0 * Tile.SIZE, 0.0, "no floor: the bottom row")


func test_swoop_flies_an_arc_through_where_the_player_stood() -> void:
	var sim: GameSim = _fighting()
	var boss: BossState = sim.boss
	var level: LevelGrid = sim.level
	# Isolate the deeper glass-only arc; dirt collision has a separate test.
	for row: int in level.rows:
		for col: int in level.cols:
			if level.get_cell(row, col) == Tile.DIRT:
				level.set_cell(row, col, Tile.GLASS)
	sim.player.place_at(805.0, sim.player.y)
	var feet: float = sim.player.y + sim.player.h
	var first_fill_row: int = sim.boss.arena_fill_row
	_begin(sim, BossGlassSlime.Move.SWOOP)
	check_eq(boss.state, BossState.State.CHARGING)
	for _tick: int in ceili(float(boss.max_charge_timer) * BossGlassSlime.TRACKING_SHARE) + 2:
		BossSystem.update(sim)
	var low_x: float = boss.dive_x
	check_near(low_x, sim.player.center_x() - boss.w / 2.0, 0.01, "the low point is where the player stands")
	check_near(boss.dive_floor_y, feet + BossGlassSlime.SWOOP_DIP, 0.01, "just below their feet")
	check(absf(boss.swoop_from.x - low_x) > 200.0, "it starts well off to one side")
	check(signf(boss.swoop_from.x - low_x) != signf(boss.swoop_to.x - low_x), "and ends on the other")

	sim.player.place_at(1605.0, sim.player.y)
	_run_until(sim, BossState.State.JUMPING)
	var from: Vector2 = Vector2(boss.x, boss.y)
	var lowest: float = boss.y
	var passed_low_point: bool = false
	for _tick: int in 400:
		BossSystem.update(sim)
		lowest = maxf(lowest, boss.y)
		passed_low_point = passed_low_point or absf(boss.x - low_x) < 12.0
		if boss.state != BossState.State.JUMPING:
			break
	check_eq(boss.state, BossState.State.ACTIVE, "it climbs away and hovers again: no stun after a swoop")
	check(passed_low_point, "it went through the low point")
	check_near(lowest + boss.h, feet + BossGlassSlime.SWOOP_DIP, 6.0, "dipping to floor level there")
	check(signf(boss.x - low_x) != signf(from.x - low_x), "and came out on the far side")
	check(not sim.player.dead, "a player who got clear lives")
	var shaved: int = 0
	for col: int in range(1, level.cols - 1):
		if level.get_cell(first_fill_row, col) == Tile.AIR:
			shaved += 1
	check(shaved >= 2, "it shaved glass off the top of the fill (%d cells)" % shaved)
	var deeper: bool = false
	for col: int in range(1, level.cols - 1):
		deeper = deeper or level.get_cell(first_fill_row + 1, col) == Tile.AIR
	check(deeper, "the swoop now digs below the surface")


func test_swoop_contact_without_terrain_does_not_kill() -> void:
	var sim: GameSim = _fighting()
	var boss: BossState = sim.boss
	boss.state = BossState.State.JUMPING
	boss.current_move = BossGlassSlime.Move.SWOOP
	boss.x = 800.0
	boss.y = 200.0
	sim.player.place_at(boss.x - sim.player.w + 2.0, boss.y + 40.0)
	BossCollision.resolve(sim)
	check(not sim.player.dead, "touching its side is safe when there is room to be pushed away")


func test_bomb_is_a_shield_that_flashes_draws_back_and_is_thrown() -> void:
	var sim: GameSim = _fighting()
	var boss: BossState = sim.boss
	sim.player.place_at(805.0, sim.player.y)
	_begin(sim, BossGlassSlime.Move.BOMBS)
	check_eq(boss.state, BossState.State.ACTIVE, "it keeps hovering while it bombs")
	check(boss.bombs.is_empty(), "nothing is thrown yet")
	var chosen: ShieldState = null
	for shield: ShieldState in boss.shields:
		if shield.winding_up:
			check(chosen == null, "one shield at full durability")
			chosen = shield
	check(chosen != null, "a shield starts winding up")
	if chosen == null:
		return
	check(chosen.windup_timer >= ShieldState.WINDUP_TICKS - 1, "with the whole wind-up still ahead of it")

	# Half way through it has drawn back, away from the player.
	for _tick: int in floori(float(ShieldState.WINDUP_TICKS) / 2.0):
		_update_bombs_only(sim)
	var held: Vector2 = Vector2(boss.center_x(), boss.center_y()) + chosen.hold_offset
	var to_player: Vector2 = Vector2(sim.player.center_x(), sim.player.center_y()) - held
	var moved: Vector2 = Vector2(chosen.cx, chosen.cy) - held
	check(moved.length() > 5.0, "it has moved off its place in the ring")
	check(moved.dot(to_player) < 0.0, "backward, away from the player")
	check(chosen.active and boss.bombs.is_empty(), "and is still a shield")

	for _tick: int in ShieldState.WINDUP_TICKS:
		_update_bombs_only(sim)
		if not boss.bombs.is_empty():
			break
	check_eq(boss.bombs.size(), 1, "then it is thrown as a bomb")
	check(not chosen.active, "and the shield is spent")
	var left: int = 0
	for shield: ShieldState in boss.shields:
		if shield.active:
			left += 1
	check_eq(left, 3, "leaving three in the ring")
	check(boss.bombs[0].vx * to_player.x > 0.0, "the bomb flies toward the player")


func test_bombs_stop_when_the_shields_run_out() -> void:
	var sim: GameSim = _fighting()
	var boss: BossState = sim.boss
	for shield: ShieldState in boss.shields:
		shield.active = false
	_begin(sim, BossGlassSlime.Move.BOMBS)
	check(boss.bombs.is_empty(), "nothing to throw")
	check_eq(boss.state, BossState.State.CHARGING, "unusable bomb intent falls back to slam")
	check_eq(boss.current_move, BossGlassSlime.Move.SLAM as int)


func test_bombs_burst_in_the_same_tick_as_impact() -> void:
	var sim: GameSim = _fighting()
	var boss: BossState = sim.boss
	var level: LevelGrid = sim.level
	sim.player.place_at(805.0, sim.player.y)
	var before: Dictionary[int, int] = _tile_counts(level)
	_begin(sim, BossGlassSlime.Move.BOMBS)
	_run_until_thrown(sim)
	check_eq(boss.bombs.size(), 1)
	if boss.bombs.is_empty():
		return
	var bomb: GlassBomb = boss.bombs[0]
	check(not bomb.landed, "thrown bomb is still in flight")

	sim.player.place_at(1605.0, sim.player.y)
	for _tick: int in 200:
		_update_bombs_only(sim)
		if boss.bombs.is_empty():
			break
	check(bomb.landed, "it comes to rest")
	var at: Vector2 = Vector2(bomb.x, bomb.y)
	check(boss.bombs.is_empty(), "removed on the landing tick, with no fuse delay")
	check(not sim.player.dead, "a player who walked away lives")
	var after: Dictionary[int, int] = _tile_counts(level)
	var glass_before: int = before.get(Tile.GLASS, 0)
	var glass_after: int = after.get(Tile.GLASS, 0)
	var dirt_before: int = before.get(Tile.DIRT, 0)
	var dirt_after: int = after.get(Tile.DIRT, 0)
	check(glass_after <= glass_before - 4, "a hole is blown in the glass (%d cells)" % (glass_before - glass_after))
	check_eq(dirt_after, dirt_before, "the dirt is left standing")
	for row: int in level.rows:
		for col: int in level.cols:
			var centre: Vector2 = (Vector2(col, row) + Vector2(0.5, 0.5)) * Tile.SIZE
			if centre.distance_to(at) <= BossGlassSlime.BLAST_GLASS_RADIUS:
				check(level.get_cell(row, col) != Tile.GLASS, "no glass survives inside the blast")


func test_bomb_kills_a_player_who_stays_beside_it() -> void:
	var sim: GameSim = _fighting()
	sim.player.place_at(805.0, sim.player.y)
	var bomb: GlassBomb = GlassBomb.new()
	bomb.x = sim.player.center_x()
	bomb.y = sim.player.y - BossGlassSlime.BOMB_RADIUS - 1.0
	bomb.vy = 2.0
	sim.boss.bombs.append(bomb)
	_update_bombs_only(sim)
	check(sim.player.dead, "the burst is fatal up close")
	check(sim.boss.bombs.is_empty(), "player contact explodes immediately")


func test_camera_looks_above_the_player_during_the_fight() -> void:
	var sim: GameSim = _fighting()
	# Deep enough that the level's top edge does not hold the camera back.
	sim.player.place_at(805.0, 900.0)
	sim.player.grounded = true
	for _tick: int in 240:
		sim.camera.follow(sim.player.center_x(), sim._camera_focus_y(), sim.level)
	var player_on_screen: float = sim.player.center_y() - sim.camera.y
	check_near(player_on_screen, GameConstants.VIEW_HEIGHT / 2.0 + BossGlassSlime.CAMERA_LIFT, 2.0, "the player sits low in the view")
	check(player_on_screen + sim.player.h < GameConstants.VIEW_HEIGHT, "but is still on screen")
	var hover_y: float = sim.player.y - BossGlassSlime.HOVER_HEIGHT
	check(hover_y - sim.camera.y > -sim.boss.h * 0.5, "and the height the boss roams at is in view")

	sim.boss.dead = true
	for _tick: int in 240:
		sim.camera.follow(sim.player.center_x(), sim._camera_focus_y(), sim.level)
	check_near(sim.player.center_y() - sim.camera.y, GameConstants.VIEW_HEIGHT / 2.0, 2.0, "it centres on the player again once the boss is beaten")


func test_goal_appears_beside_the_player_when_it_is_beaten() -> void:
	var sim: GameSim = _fighting()
	var boss: BossState = sim.boss
	boss.durability = 1
	check(BossGlassSlime.hit_by_projectile(sim, boss.center_x(), boss.center_y()))
	check(boss.dead, "the last hit beats it")
	var row: int = Tile.cell_of(sim.player.center_y())
	var col: int = Tile.cell_of(sim.player.center_x())
	var beside: bool = false
	for candidate: int in [col - 1, col, col + 1]:
		beside = beside or sim.level.get_cell(row, candidate) == Tile.GOAL
	check(beside, "the goal is within a step, however deep the player is")

func test_boss_never_makes_dirt() -> void:
	var sim: GameSim = _fighting()
	var level: LevelGrid = sim.level
	var counts: Dictionary[int, int] = _tile_counts(level)
	var dirt_at_start: int = counts.get(Tile.DIRT, 0)
	# Three full rounds of every move, with the player out of harm's way.
	for tick: int in 1500:
		sim.player.place_at(205.0 if floori(float(tick) / 150.0) % 2 == 0 else 1605.0, -400.0)
		BossSystem.update(sim)
		ProjectileSystem.update(sim)
		if tick % 25 != 0:
			continue
		counts = _tile_counts(level)
		var dirt_now: int = counts.get(Tile.DIRT, 0)
		if dirt_now > dirt_at_start:
			fail("dirt appeared by tick %d" % tick)
			return
	check(sim.boss.action_count >= 6, "the boss went through its moves (%d)" % sim.boss.action_count)
	check(sim.projectiles.is_empty(), "and fired nothing that lands as a block")


func test_multiple_projectiles_cannot_skip_damage_phases_in_one_tick() -> void:
	var sim: GameSim = _fighting()
	sim.boss.state = BossState.State.STUNNED
	sim.boss.cooldown = 60
	for _shot: int in 3:
		var projectile: SimProjectile = SimProjectile.new()
		projectile.x = sim.boss.center_x() - projectile.w / 2.0
		projectile.y = sim.boss.center_y() - projectile.h / 2.0
		sim.projectiles.append(projectile)
	sim.step(SimInput.new())
	check_eq(sim.boss.durability, 2, "one damage phase per opening")
	check(not sim.boss.dead, "overlapping shots cannot instantly defeat the boss")
	check(sim.projectiles.is_empty(), "blocked shots are consumed")


func test_defeated_core_does_not_take_more_damage() -> void:
	var sim: GameSim = _fighting()
	sim.boss.durability = 1
	check(BossGlassSlime.hit_by_projectile(sim, sim.boss.center_x(), sim.boss.center_y()))
	check(not BossGlassSlime.hit_by_projectile(sim, sim.boss.center_x(), sim.boss.center_y()))
	check_eq(sim.boss.durability, 0, "death cannot repeat")


func test_final_swoop_tick_without_crushing_is_safe() -> void:
	var sim: GameSim = _fighting()
	var boss: BossState = sim.boss
	boss.state = BossState.State.JUMPING
	boss.current_move = BossGlassSlime.Move.SWOOP
	boss.swoop_from = Vector2(600.0, 100.0)
	boss.swoop_to = Vector2(900.0, 100.0)
	boss.dive_x = 750.0
	boss.dive_floor_y = 380.0
	boss.swoop_progress = 0.999
	boss.x = 899.0
	boss.y = 101.0
	sim.player.place_at(920.0, 130.0)
	BossSystem.update(sim)
	check(not sim.player.dead, "even the final attack frame cannot kill by touch alone")


func test_core_recovery_expires_and_restart_clears_it() -> void:
	var sim: GameSim = _fighting()
	check(BossGlassSlime.hit_by_projectile(sim, sim.boss.center_x(), sim.boss.center_y()))
	var recovery: int = sim.boss.glass_hit_recovery
	check(BossGlassSlime.hit_by_projectile(sim, sim.boss.center_x(), sim.boss.center_y(), true))
	check_eq(sim.boss.glass_hit_recovery, recovery, "preview does not advance recovery")
	check_eq(sim.boss.durability, 2, "preview does not damage the core")
	for _tick: int in BossGlassSlime.HIT_RECOVERY_TICKS:
		sim.step(SimInput.new())
	check_eq(sim.boss.glass_hit_recovery, 0, "recovery ends in simulation time")
	check(BossGlassSlime.hit_by_projectile(sim, sim.boss.center_x(), sim.boss.center_y()))
	check_eq(sim.boss.durability, 1, "next opening can damage the core again")
	sim.reset()
	check_eq(sim.boss.glass_hit_recovery, 0, "restart clears recovery")
	check_eq(sim.boss.durability, 3, "restart restores all phases")
	check_eq(sim.boss.shields.size(), 4, "restart restores the initial shield ring")
	check(sim.boss.bombs.is_empty(), "restart leaves no bombs")


func test_projectile_defeat_leads_to_reachable_victory() -> void:
	var sim: GameSim = _fighting()
	for phase: int in 3:
		sim.boss.state = BossState.State.STUNNED
		sim.boss.cooldown = 1000
		var shot: SimProjectile = SimProjectile.new()
		shot.x = sim.boss.center_x() - shot.w / 2.0
		shot.y = sim.boss.center_y() - shot.h / 2.0
		sim.projectiles.append(shot)
		sim.step(SimInput.new())
		check_eq(sim.boss.durability, 2 - phase, "projectile advances one phase")
		if phase < 2:
			for _tick: int in BossGlassSlime.HIT_RECOVERY_TICKS:
				sim.step(SimInput.new())
	check(sim.boss.dead, "three spaced hits defeat the boss")
	var walk: SimInput = SimInput.new()
	walk.right = true
	for _tick: int in 30:
		sim.step(walk)
	check(sim.player.won, "the player can walk into the revealed goal")
	check(not sim.player.dead, "victory remains safe")


## The arena, loaded and nothing else.
func _loaded() -> GameSim:
	var sim: GameSim = GameSim.new()
	sim.rng.set_seed(1)
	sim.load_level(40, LevelLibrary.built_in_level(40), BossState.Kind.GLASS_SLIME)
	return sim


## The boss in the air above a player who is standing on the glass.
func _fighting() -> GameSim:
	var sim: GameSim = _loaded()
	for _tick: int in 60:
		sim.step(SimInput.new())
	sim.boss.state = BossState.State.ACTIVE
	sim.boss.triggered = true
	sim.boss.x = sim.player.center_x() - sim.boss.w / 2.0
	sim.boss.y = 50.0
	sim.boss.cooldown = BossGlassSlime.move_cooldown_for(3)
	BossGlassSlime.sync_orbiting_shields(sim)
	return sim


func _begin(sim: GameSim, move: BossGlassSlime.Move) -> void:
	BossGlassSlime._begin_move(sim, move)


func _run_until(sim: GameSim, state: BossState.State) -> void:
	var ticks: int = 0
	while sim.boss.state != state and ticks < 600:
		BossSystem.update(sim)
		ticks += 1


## Lets the shields that are winding up be thrown.
func _run_until_thrown(sim: GameSim) -> void:
	for _tick: int in ShieldState.WINDUP_TICKS * 3:
		_update_bombs_only(sim)
		if not sim.boss.bombs.is_empty():
			return


## Advances the bombs without letting the boss start anything else.
func _update_bombs_only(sim: GameSim) -> void:
	sim.boss.cooldown = 1000
	BossSystem.update(sim)


func _tile_counts(level: LevelGrid) -> Dictionary[int, int]:
	var counts: Dictionary[int, int] = {}
	for row: int in level.rows:
		for col: int in level.cols:
			var tile: int = level.get_cell(row, col)
			var seen: int = counts.get(tile, 0)
			counts[tile] = seen + 1
	return counts

