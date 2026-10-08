extends TestCase
## Boss regression scenarios use the existing official arenas unchanged.


func test_interrupted_devouring_can_resume_and_finish() -> void:
	var sim: GameSim = _sim(50)
	var boss: BossState = sim.boss
	boss.state = BossState.State.ACTIVE
	boss.x = 800.0
	boss.y = 400.0
	boss.grid.fill(Tile.DIRT)
	boss.set_cell(1, 1, Tile.GOAL)
	sim.player.place_at(730.0, 440.0)
	var eat: SimInput = SimInput.new()
	eat.eat = true
	eat.mouse_x = boss.center_x() - sim.camera.x
	eat.mouse_y = boss.center_y() - sim.camera.y
	sim.input = eat
	for _i: int in 36:
		BossVoidSlime.update(sim)
	check(boss.filled_count() < 8, "some cells have been consumed")
	var remaining: int = boss.filled_count()
	sim.input = SimInput.new()
	for _i: int in 120:
		BossVoidSlime.update(sim)
	check_near(boss.eating_progress, float(8 - remaining) / 10.0, 0.000001, "consumed cells establish a checkpoint")
	sim.input = eat
	for _i: int in 110:
		if not boss.dead:
			BossVoidSlime.update(sim)
	check(boss.dead and not boss.active, "resuming completes the fight")
	var goals: int = 0
	for r: int in sim.level.rows:
		for c: int in sim.level.cols:
			if sim.level.get_cell(r, c) == Tile.GOAL:
				goals += 1
	check(goals > 0, "defeat leaves a reachable goal")


func test_consumed_void_cells_do_not_kill_during_devouring() -> void:
	var sim: GameSim = _sim(50)
	sim.boss.state = BossState.State.ACTIVE
	sim.boss.x = 800.0
	sim.boss.y = 400.0
	sim.player.place_at(805.0, 405.0)
	sim.boss.eating_progress = 0.3
	BossCollision.resolve(sim)
	check(not sim.player.dead, "consumed empty cells stay harmless")
	sim.boss.eating_progress = 0.0
	sim.player.place_at(805.0, 405.0)
	BossCollision.resolve(sim)
	check(sim.player.dead, "unfed void remains lethal before devouring")


func test_touching_an_unfilled_void_cell_kills() -> void:
	# The body pushes the player out, so contact is never deeper than a sliver.
	var on_top: GameSim = _sim(50)
	on_top.boss.state = BossState.State.ACTIVE
	on_top.boss.x = 800.0
	on_top.boss.y = 400.0
	on_top.player.place_at(804.0, 400.0 - on_top.player.h + 0.4)
	BossCollision.resolve(on_top)
	check(on_top.player.dead, "landing on an empty cell kills")

	var beside: GameSim = _sim(50)
	beside.boss.state = BossState.State.ACTIVE
	beside.boss.x = 800.0
	beside.boss.y = 400.0
	beside.player.place_at(800.0 - beside.player.w + 0.4, 405.0)
	BossCollision.resolve(beside)
	check(beside.player.dead, "walking into an empty cell kills")

	var fed: GameSim = _sim(50)
	fed.boss.state = BossState.State.ACTIVE
	fed.boss.x = 800.0
	fed.boss.y = 400.0
	fed.boss.set_cell(0, 0, Tile.DIRT)
	fed.player.place_at(804.0, 400.0 - fed.player.h + 0.4)
	BossCollision.resolve(fed)
	check(not fed.player.dead, "a filled cell is safe to stand on")
	check(fed.player.grounded, "and carries the player")

	var apart: GameSim = _sim(50)
	apart.boss.state = BossState.State.ACTIVE
	apart.boss.x = 800.0
	apart.boss.y = 400.0
	apart.player.place_at(700.0, 405.0)
	BossCollision.resolve(apart)
	check(not apart.player.dead, "not touching is safe")


func test_new_shields_exist_at_the_boss_immediately() -> void:
	var sim: GameSim = _sim(40)
	for shield: ShieldState in sim.boss.shields:
		check_near(Vector2(shield.cx - sim.boss.center_x(), shield.cy - sim.boss.center_y()).length(), 85.0)
	sim.boss.state = BossState.State.ACTIVE
	sim.boss.x = 800.0
	sim.boss.y = 200.0
	sim.boss.shields.clear()
	check(BossGlassSlime.hit_by_projectile(sim, sim.boss.center_x(), sim.boss.center_y()))
	check_eq(sim.boss.durability, 2)
	check_eq(sim.boss.shields.size(), 8)
	for shield: ShieldState in sim.boss.shields:
		check_near(Vector2(shield.cx - sim.boss.center_x(), shield.cy - sim.boss.center_y()).length(), 85.0)
	var first: ShieldState = sim.boss.shields[0]
	check(BossGlassSlime.hit_by_projectile(sim, first.cx, first.cy), "same-tick shot hits the new shield")
	check(not first.active)
	check_eq(sim.boss.durability, 2, "shield hit does not damage core")


func test_pinball_speed_is_bounded_and_wall_contact_is_directional() -> void:
	var sim: GameSim = _sim(30)
	sim.boss.state = BossState.State.JUMPING
	sim.boss.x = 800.0
	sim.boss.y = 200.0
	sim.boss.vx = 90.0
	sim.boss.vy = -90.0
	BossBouncySlime.update(sim)
	check(absf(sim.boss.vx) <= BossBouncySlime.MAX_HORIZONTAL_SPEED)
	check(absf(sim.boss.vy) <= BossBouncySlime.MAX_VERTICAL_SPEED)
	# The official floor has multiple occupied columns under this box.
	check_eq(BossBouncySlime.wall_contact_column(sim.level, 800.0, 560.0, 120.0, 40.0, 6.0), 20)
	check_eq(BossBouncySlime.wall_contact_column(sim.level, 800.0, 560.0, 120.0, 40.0, -6.0), 22)
	check_eq(BossBouncySlime.wall_contact_column(sim.level, 800.0, 560.0, 120.0, 40.0, 0.0), -1)


func test_lost_boss_returns_without_resetting_fight_or_player_control() -> void:
	for slot: int in [20, 50]:
		var sim: GameSim = _sim(slot)
		sim.boss.state = BossState.State.FALLING
		sim.boss.y = sim.level.pixel_height() + 100.0
		var grid: int = sim.boss.grid_checksum()
		BossSystem.update(sim)
		check_eq(sim.boss.state, BossState.State.INTRO)
		check_eq(sim.boss.intro_timer, BossSystem.RETRY_INTRO_TICKS)
		check(not sim.boss.intro_freezes_player)
		check_eq(sim.boss.grid_checksum(), grid)
		check_near(sim.boss.prev_y, sim.boss.y, 0.0, "return does not interpolate across the whole scene")


func test_side_and_underneath_trampoline_contact_clear_grounded() -> void:
	for slot: int in [30, 40]:
		for from_side: bool in [true, false]:
			var sim: GameSim = _sim(slot)
			sim.boss.state = BossState.State.ACTIVE
			sim.boss.x = 800.0
			sim.boss.y = 300.0
			sim.player.place_at(790.0 if from_side else 840.0, 340.0 if from_side else 410.0)
			sim.player.grounded = true
			sim.player.recoil_vx = 8.0
			BossCollision.resolve(sim)
			check(not sim.player.grounded)
			check_near(sim.player.recoil_vx, 0.0)
			check(not sim.player.dead)


func _sim(slot: int) -> GameSim:
	var sim: GameSim = GameSim.new()
	sim.rng.set_seed(1)
	sim.load_level(slot, LevelLibrary.built_in_level(slot), LevelLibrary.boss_kind_for_slot(slot))
	return sim
