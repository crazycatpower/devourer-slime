extends TestCase


func _new_sim() -> GameSim:
	var sim: GameSim = GameSim.new()
	sim.load_level(10, LevelLibrary.built_in_level(10), LevelLibrary.boss_kind_for_slot(10))
	return sim


func test_entrance_waits_for_distance_and_retry_resets() -> void:
	var sim: GameSim = _new_sim()
	for _i: int in 180:
		sim.step(SimInput.new())
	check(not sim.boss.triggered, "waiting at spawn does not trigger pursuit")
	var run: SimInput = SimInput.new()
	run.right = true
	for _i: int in 45:
		sim.step(run)
	check(sim.boss.triggered, "running a short distance triggers entrance")
	check_eq(sim.boss.state, BossState.State.INTRO)
	var x: float = sim.player.x
	var y: float = sim.player.y
	var boss_x: float = sim.boss.x
	run.jump = true
	run.jump_pressed = true
	run.eat = true
	run.shoot = true
	for _i: int in 10:
		sim.step(run)
	check_eq(sim.player.x, x, "warning freezes horizontal movement")
	check_eq(sim.player.y, y, "warning freezes vertical movement")
	check(not sim.player.in_bullet_time and not sim.player.has_block)
	check(sim.boss.x > boss_x, "boss slowly enters while player is frozen")
	for _i: int in 600:
		sim.step(SimInput.new())
		if sim.player.dead:
			break
	check(sim.player.dead, "waiting is caught by the steel face")
	for _i: int in GameSim.DEATH_RESTART_TICKS + 1:
		sim.step(SimInput.new())
	check(not sim.player.dead)
	check(not sim.boss.triggered, "automatic restart re-arms distance trigger")
	check_eq(sim.boss.state, BossState.State.SUSPENDED)


func test_retry_warning_is_exactly_one_second_and_entry_is_continuous() -> void:
	var sim: GameSim = _new_sim()
	var run: SimInput = SimInput.new()
	run.right = true
	for attempt: int in 3:
		for _i: int in 100:
			if sim.boss.triggered:
				break
			sim.step(run)
		var duration: int = BossSteelChase.WARNING_TICKS if attempt == 0 else 60
		check_eq(sim.boss.intro_timer, duration)
		var x: float = sim.player.x
		var y: float = sim.player.y
		for tick: int in duration:
			var previous_x: float = sim.boss.x
			sim.step(run)
			check_eq(sim.player.x, x)
			check_eq(sim.player.y, y)
			check(sim.boss.x > previous_x and sim.boss.x - previous_x < 3.0, "smooth entry independent of chase speed")
			if tick < duration - 1:
				check_eq(sim.boss.state, BossState.State.INTRO)
		check_eq(sim.boss.state, BossState.State.ACTIVE)
		check_near(sim.boss.x, Tile.SIZE, 0.001)
		sim.step(run)
		check(sim.player.x > x, "controls resume after the warning")
		sim.reset()
	# Loading another play session restores the full first entrance.
	sim.load_level(10, LevelLibrary.built_in_level(10), BossState.Kind.STEEL_CHASE)
	check(not sim.boss_intro_seen)


func test_parkour_route_reaches_goal_using_only_run_and_jump() -> void:
	for bullet_time: bool in [false, true]:
		var sim: GameSim = _new_sim()
		sim.bullet_time_enabled = bullet_time
		var hold: int = 0
		for _i: int in 1800:
			if sim.player.dead or sim.player.won:
				break
			var inp: SimInput = SimInput.new()
			inp.right = true
			var ahead: int = floori((sim.player.x + sim.player.w + 65.0) / Tile.SIZE)
			var row: int = floori((sim.player.y + sim.player.h - 2.0) / Tile.SIZE)
			var tile: int = sim.level.get_cell(row, ahead)
			if sim.player.grounded and (Tile.is_solid(tile) or Tile.is_spike(tile)):
				inp.jump_pressed = true
				hold = 40
			inp.jump = hold > 0
			hold = maxi(0, hold - 1)
			sim.step(inp)
		check(sim.player.won and not sim.player.dead, "run/jump wins x=%.1f y=%.1f" % [sim.player.x, sim.player.y])
		check(sim.boss.dead, "escape ends pursuit")
		check(sim.player.x > 95.0 * Tile.SIZE, "goal is at the far right")
		sim.reset()
		check(not sim.player.won and not sim.boss.triggered)


func test_distance_adjusts_chase_speed_within_fifty_percent() -> void:
	var sim: GameSim = _new_sim()
	sim.boss.state = BossState.State.ACTIVE
	var previous_speed: float = 0.0
	for gap: float in [0.0, 2.0, 100.0, 200.0, 300.0, 398.0, 400.0, 1200.0]:
		sim.player.dead = false
		sim.player.x = sim.boss.x + sim.boss.w + BossSteelChase.SPIKE_LENGTH + gap
		var before: float = sim.boss.x
		BossSteelChase.update(sim)
		check(sim.boss.vx >= 0.8 - 0.0001 and sim.boss.vx <= 2.4 + 0.0001, "speed stays within +/-50% of base speed")
		check(sim.boss.vx >= previous_speed, "greater gap never reduces pursuit speed")
		check_near(sim.boss.x - before, sim.boss.vx, 0.0001)
		if gap == 0.0:
			check_near(sim.boss.vx, 0.8, 0.0001)
		elif gap == 200.0:
			check_near(sim.boss.vx, 1.6, 0.0001)
		elif gap >= 400.0:
			check_near(sim.boss.vx, 2.4, 0.0001)
		elif gap == 2.0:
			check(sim.boss.vx - 0.8 < 0.001, "smooth transition at near boundary")
		elif gap == 398.0:
			check(2.4 - sim.boss.vx < 0.001, "smooth transition at far boundary")
		previous_speed = sim.boss.vx


func test_course_contains_only_steel_and_spikes() -> void:
	var rows: PackedStringArray = LevelLibrary.built_in_rows(10)
	check_eq(LevelValidator.problem_with(rows), "")
	for row: String in rows:
		for tile: String in row:
			check(tile in ["@", "~", ".", "P", "$"], "steel/spike course")
