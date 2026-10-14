extends TestCase
## Full encounters and world integration on the existing standard rooms.

const SLOTS: Array[int] = [60, 70, 80, 90, 100]


func _sim(slot: int, fighting: bool = true) -> GameSim:
	var sim: GameSim = GameSim.new()
	sim.load_level(slot, LevelLibrary.built_in_level(slot), LevelLibrary.boss_kind_for_slot(slot))
	if fighting:
		sim.boss.y = sim.boss.mechanism.floor_y - sim.boss.h
		sim.boss.prev_y = sim.boss.y
		sim.boss.state = BossState.State.ACTIVE
		sim.boss.triggered = true
		sim.player.place_at(100.0, 510.0)
	return sim


func _shot(type: int = Tile.DIRT) -> SimProjectile:
	var shot: SimProjectile = SimProjectile.new()
	shot.type = type
	return shot


func _ticks(sim: GameSim, count: int) -> void:
	for tick: int in count:
		sim.tick_count += 1
		BossMechanism.update(sim)


func test_all_five_worlds_ship_ten_slots_with_unchanged_boss_rooms() -> void:
	var repo: LevelRepository = LevelRepository.new("user://test_tmp/new_worlds")
	var expected: Array[int] = [Tile.SENSOR, Tile.ICE, Tile.SAND, Tile.RAIL_RIGHT, Tile.TNT]
	for world: int in range(6, 11):
		check(repo.world_has_levels(world))
		check_eq(WorldCatalog.icon_tile(world), expected[world - 6])
		for index: int in range(1, 11):
			var slot: int = (world - 1) * 10 + index
			check(repo.has_level(slot))
			check(not LevelLibrary.is_placeholder(slot))
			if index == 10:
				check_eq(LevelLibrary.built_in_rows(slot), LevelLibrary.boss_rows())
			else:
				check(LevelLibrary.has_authored_layout(slot))
			check_eq(LevelLibrary.is_boss_slot(slot), index == 10)
		check(not WorldCatalog.lesson(world, 1).is_empty())
	check_eq(repo.next_campaign_slot(50), 51)
	check_eq(repo.next_campaign_slot(60), 61)
	check_eq(repo.next_campaign_slot(90), 91)
	check_eq(repo.next_campaign_slot(100), 0)
	check_eq(repo.level_count(), 100)


func test_intros_are_smooth_freeze_and_retry_without_terrain_edits() -> void:
	for slot: int in SLOTS:
		var sim: GameSim = _sim(slot, false)
		var original: LevelGrid = sim.level.duplicate_grid()
		sim.player.place_at(sim.boss.x - 150.0, 510.0)
		sim.step(SimInput.new())
		check_eq(sim.boss.state, BossState.State.INTRO)
		check_eq(sim.boss.intro_duration, BossMechanism.INTRO_TICKS)
		var x: float = sim.player.x
		var input: SimInput = SimInput.new()
		input.right = true
		sim.step(input)
		check_near(sim.player.x, x, 0.001)
		_ticks(sim, 89)
		check_eq(sim.boss.state, BossState.State.ACTIVE)
		check_near(sim.boss.y, sim.boss.mechanism.floor_y - sim.boss.h, 0.001)
		check(sim.level.equals(original), "entrance never generates an arena layout")
		check(slot == 100 or not sim.falling_blocks.is_empty(), "entrance supplies ammunition; furnace supplies live charges during its attack")
		sim.reset()
		check(sim.level.equals(original))
		check(sim.falling_blocks.is_empty())
		sim.player.place_at(sim.boss.x - 150.0, 510.0)
		sim.step(SimInput.new())
		check_eq(sim.boss.intro_duration, BossSystem.RETRY_INTRO_TICKS)


func test_warnings_lock_target_and_ordinary_damage_cannot_win_new_encounters() -> void:
	for slot: int in SLOTS:
		var sim: GameSim = _sim(slot)
		if slot != 90:
			BossMechanism._begin_attack(sim)
			sim.boss.charge_timer = 25
			var target: Vector2 = sim.boss.mechanism.target
			sim.player.x += 180.0
			_ticks(sim, 1)
			check_eq(sim.boss.mechanism.target, target)
		for index: int in 6:
			BossMechanism.hit_by_projectile(sim, _shot(), sim.boss.center_x(), sim.boss.center_y())
			BossMechanism.hit_by_blast(sim, Vector2(sim.boss.center_x(), sim.boss.center_y()))
		check(not sim.boss.dead, "ordinary damage cannot bypass world %d objective" % (slot / 10.0))
		check_eq(sim.boss.durability, 3)


func test_sensor_requires_three_simultaneous_covers_can_undo_and_overloads() -> void:
	var sim: GameSim = _sim(60)
	for cell: Vector2i in BossMechanism.sensor_ports():
		var at: Vector2 = BossMechanism.port_rect(sim.boss, cell).get_center()
		check(BossMechanism.hit_by_projectile(sim, _shot(), at.x, at.y, true))
		check_eq(sim.boss.mechanism.covered_ports.size(), BossMechanism.sensor_ports().find(cell))
		BossMechanism.hit_by_projectile(sim, _shot(), at.x, at.y)
		BossMechanism.hit_by_projectile(sim, _shot(), at.x, at.y)
	check_eq(sim.boss.mechanism.covered_ports.size(), 3, "duplicate cover does not count twice")
	_ticks(sim, 40)
	check(not sim.boss.dead)
	var cell: Vector2i = Vector2i(0, 1)
	sim.player.place_at(sim.boss.x - 38.0, sim.boss.y + 40.0)
	sim.input.eat = true
	var aim: PlayerSystem.Aim = PlayerSystem.Aim.new()
	for tick: int in 24:
		PlayerSystem._update_eating(sim, aim)
	check(sim.player.has_block, "covering block can be swallowed from the sensor")
	check_eq(sim.boss.mechanism.covered_ports.size(), 2)
	_ticks(sim, 60)
	check(not sim.boss.dead, "removing a cover interrupts overload")
	check_eq(sim.boss.mechanism.dock_timer, 0)
	var at: Vector2 = BossMechanism.port_rect(sim.boss, cell).get_center()
	BossMechanism.hit_by_projectile(sim, _shot(), at.x, at.y)
	_ticks(sim, 89)
	check(not sim.boss.dead)
	_ticks(sim, 1)
	check(sim.boss.dead, "all three covered ports held for ninety ticks overload the circuit")
	_assert_goal_reset(sim)


func test_ice_is_curling_with_directional_impulses_reverse_braking_and_three_docks() -> void:
	var sim: GameSim = _sim(70)
	var shot: SimProjectile = _shot(Tile.ICE)
	shot.vx = 12.0
	BossMechanism.hit_by_projectile(sim, shot, sim.boss.center_x(), sim.boss.center_y(), true)
	check_near(sim.boss.vx, 0.0, 0.001)
	BossMechanism.hit_by_projectile(sim, shot, sim.boss.center_x(), sim.boss.center_y())
	check(sim.boss.vx > 3.0, "shot direction pushes the ice boss")
	var old_speed: float = sim.boss.vx
	shot.vx = -6.0
	BossMechanism.hit_by_projectile(sim, shot, sim.boss.center_x(), sim.boss.center_y())
	check(sim.boss.vx < old_speed, "opposite shot brakes the boss")
	for stage: int in 3:
		var station: Vector2 = BossMechanism.cooling_station(sim)
		sim.boss.x = station.x - sim.boss.w * 0.5
		sim.boss.vx = 2.0
		BossMechanism._skate(sim)
		check_eq(sim.boss.mechanism.progress, stage, "passing at speed does not count")
		sim.boss.x = station.x - sim.boss.w * 0.5
		sim.boss.vx = 0.0
		for tick: int in 59:
			BossMechanism._skate(sim)
		check_eq(sim.boss.mechanism.progress, stage)
		BossMechanism._skate(sim)
		check_eq(sim.boss.mechanism.progress, stage + 1)
	check(sim.boss.dead)
	_assert_goal_reset(sim)


func test_sand_core_must_be_stolen_carried_home_and_cannot_be_duplicated() -> void:
	var sim: GameSim = _sim(80)
	sim.player.place_at(sim.boss.x - 38.0, sim.boss.y + 80.0)
	sim.input.eat = true
	var aim: PlayerSystem.Aim = PlayerSystem.Aim.new()
	for tick: int in 24:
		PlayerSystem._update_eating(sim, aim)
	check(sim.player.has_sand_core and sim.player.has_block)
	check_eq(sim.player.carried_block_type, Tile.SAND)
	check(sim.boss.mechanism.core_stolen)
	check_eq(sim.boss.cell(2, 0), Tile.AIR)
	check(not sim.boss.dead, "stealing the core begins escape rather than winning")
	PlayerSystem._fire(sim, aim)
	check(not sim.player.has_sand_core)
	check(not sim.boss.mechanism.core_stolen)
	check_eq(sim.boss.cell(2, 0), Tile.SAND, "spitting returns the original core and prevents duplication")
	sim.player.has_block = false
	for tick: int in 24:
		PlayerSystem._update_eating(sim, aim)
	check(sim.player.has_sand_core)
	BossMechanism._begin_attack(sim)
	check_eq(sim.boss.mechanism.zones.size(), 3, "stolen core starts an angry three-column sand chase")
	sim.player.place_at(100.0, 510.0)
	BossMechanism.update(sim)
	check(sim.boss.dead, "carrying the original core to the entrance wins")
	sim.step(SimInput.new())
	check(sim.player.won)
	_assert_goal_reset(sim)
	check(not sim.player.has_sand_core)


func test_rail_requires_signal_and_rider_and_pauses_when_player_falls_off() -> void:
	var sim: GameSim = _sim(90)
	var before: Vector2 = Vector2(sim.boss.x, sim.boss.y)
	_ticks(sim, 60)
	check_eq(Vector2(sim.boss.x, sim.boss.y), before, "carrier waits for a passenger and signal")
	for station: int in 3:
		sim.player.place_at(sim.boss.x + 50.0, sim.boss.y - sim.player.h)
		check(BossMechanism.riding(sim))
		var at: Vector2 = BossMechanism.detector_rect(sim.boss).get_center()
		BossMechanism.hit_by_projectile(sim, _shot(), at.x, at.y)
		BossMechanism.update(sim)
		check_eq(sim.boss.state, BossState.State.CHARGING)
		_ticks(sim, 45)
		check_eq(sim.boss.state, BossState.State.JUMPING)
		sim.player.x = 100.0
		before = Vector2(sim.boss.x, sim.boss.y)
		_ticks(sim, 4)
		check_eq(Vector2(sim.boss.x, sim.boss.y), before, "vehicle pauses without its passenger")
		sim.player.place_at(sim.boss.x + 50.0, sim.boss.y - sim.player.h)
		for tick: int in 300:
			before = Vector2(sim.boss.x, sim.boss.y)
			var old_player: Vector2 = Vector2(sim.player.x, sim.player.y)
			BossMechanism.update(sim)
			var delta: Vector2 = Vector2(sim.boss.x, sim.boss.y) - before
			check(delta.length() <= 4.21, "corners remain continuous")
			check_near((Vector2(sim.player.x, sim.player.y) - old_player).distance_to(delta), 0.0, 0.001, "passenger follows the carrier")
			if sim.boss.mechanism.progress > station:
				break
		check_eq(sim.boss.mechanism.progress, station + 1)
	check(sim.boss.dead)
	sim.step(SimInput.new())
	check(sim.player.won)
	_assert_goal_reset(sim)


func test_tnt_demolition_requires_defusing_own_ammo_and_real_returned_spits() -> void:
	var sim: GameSim = _sim(100)
	var aim: PlayerSystem.Aim = PlayerSystem.Aim.new()
	for stage: int in 3:
		sim.player.place_at(sim.boss.x - 160.0, sim.boss.mechanism.floor_y - sim.player.h)
		var center: Vector2 = Vector2(sim.player.center_x() + 40.0, sim.player.center_y())
		MechanismSystem.arm_tnt(sim, center, 24, true)
		sim.input.eat = true
		for tick: int in 7:
			PlayerSystem._update_eating(sim, aim)
		check(not sim.player.has_block, "defuse needs eight bites")
		PlayerSystem._update_eating(sim, aim)
		check(sim.player.has_block and sim.player.has_furnace_charge)
		check(sim.tnt_charges.is_empty(), "swallowing cancels the enemy fuse")
		check_eq(sim.boss.durability, 3 - stage)
		var direction: Vector2 = (Vector2(sim.boss.center_x(), sim.boss.center_y()) - Vector2(sim.player.center_x(), sim.player.center_y())).normalized()
		aim.x = direction.x
		aim.y = direction.y
		PlayerSystem._fire(sim, aim)
		check(sim.projectiles[0].returned_charge, "defused identity survives the real spit")
		for tick: int in 24:
			sim.tick_count += 1
			ProjectileSystem.update(sim)
		check_eq(sim.boss.durability, 2 - stage)
		check(not sim.player.dead, "safe distance protects the thrower")
		sim.boss.mechanism.recovery = 0
		aim.x = 1.0
		aim.y = 0.0
	check(sim.boss.dead)
	_assert_goal_reset(sim)


func test_tnt_expired_or_abandoned_defuse_clears_eating_state() -> void:
	var sim: GameSim = _sim(100)
	sim.player.place_at(100.0, 510.0)
	MechanismSystem.arm_tnt(sim, Vector2(157.0, 527.0), 24, true)
	sim.input.eat = true
	var aim: PlayerSystem.Aim = PlayerSystem.Aim.new()
	PlayerSystem._update_eating(sim, aim)
	check(sim.player.eating_charge != null)
	sim.tnt_charges.clear()
	PlayerSystem._update_eating(sim, aim)
	check(sim.player.eating_charge == null)
	check_near(sim.player.eating_progress, 0.0, 0.001)


func test_fixed_material_falls_and_safe_supply_never_entomb_collector() -> void:
	for slot: int in [60, 70, 80, 90]:
		var sim: GameSim = _sim(slot)
		BossMechanism._supply(sim)
		var block: SimFallingBlock = sim.falling_blocks[0]
		check(not block.lethal)
		var col: int = Tile.cell_of(block.x)
		sim.player.place_at(float(col) * Tile.SIZE, sim.boss.mechanism.floor_y - sim.player.h)
		for tick: int in 80:
			FallingBlockSystem.update(sim)
		check(not sim.player.dead)
		check(sim.solid_boxes(sim.player.x, sim.player.y, sim.player.w, sim.player.h).is_empty(), "ammunition safely separates its collector on landing")
		check_eq(sim.level.get_cell(Tile.cell_of(sim.boss.mechanism.floor_y) - 1, col), block.type)
	var sand: GameSim = _sim(80)
	BossMechanism._begin_attack(sand)
	BossMechanism._launch(sand)
	check(sand.falling_blocks.size() > 0)
	check((sand.falling_blocks.back() as SimFallingBlock).fixed_landing_type)


func _assert_goal_reset(sim: GameSim) -> void:
	var goals: int = 0
	for row: int in sim.level.rows:
		for col: int in sim.level.cols:
			if sim.level.get_cell(row, col) == Tile.GOAL:
				goals += 1
	check_eq(goals, 1, "defeat produces one reachable goal")
	check(sim.falling_blocks.is_empty())
	sim.reset()
	check(sim.level.equals(LevelLibrary.built_in_level(sim.slot).grid))
	check_eq(sim.boss.state, BossState.State.SUSPENDED)
	check(sim.tnt_charges.is_empty())
	check(not sim.player.has_sand_core and not sim.player.has_furnace_charge)


func test_rail_rider_survives_real_player_gravity_and_all_three_stops() -> void:
	var sim: GameSim = _sim(90)
	sim.player.place_at(sim.boss.x + 50.0, sim.boss.y - sim.player.h)
	for tick: int in 450:
		if sim.boss.state == BossState.State.ACTIVE:
			var at: Vector2 = BossMechanism.detector_rect(sim.boss).get_center()
			BossMechanism.hit_by_projectile(sim, _shot(), at.x, at.y)
		sim.step(SimInput.new())
		if sim.player.won or sim.player.dead:
			break
	check(not sim.player.dead)
	check(sim.boss.dead and sim.player.won, "real gravity, carrier motion and goal collision complete the ride")


func test_rail_replenishes_roof_ammo_and_recovers_a_stranded_passenger() -> void:
	var sim: GameSim = _sim(90)
	sim.player.place_at(sim.boss.x + 42.0, sim.boss.y - sim.player.h)
	var target: Vector2 = Vector2(sim.boss.x + 20.0, sim.boss.y + 20.0)
	var direction: Vector2 = (target - Vector2(sim.player.center_x(), sim.player.center_y())).normalized()
	var aim: PlayerSystem.Aim = PlayerSystem.Aim.new()
	aim.x = direction.x
	aim.y = direction.y
	sim.input.eat = true
	for bite: int in 24:
		PlayerSystem._update_eating(sim, aim)
	check(sim.player.has_block, "passenger can swallow roof ammo without leaving the carrier")
	check_eq(sim.boss.cell(0, 0), Tile.AIR)
	BossMechanism._supply(sim)
	check_eq(sim.boss.cell(0, 0), Tile.DIRT, "station resupply restores swallowed ammunition")
	sim.boss.y -= 150.0
	sim.player.place_at(100.0, sim.boss.mechanism.floor_y - sim.player.h)
	for tick: int in 150:
		BossMechanism.update(sim)
	check_near(sim.boss.y, sim.boss.mechanism.floor_y - sim.boss.h, 0.01, "carrier returns within jumping range after passenger falls")
	check_eq(sim.boss.mechanism.progress, 0, "rescue does not award transport progress")


func _aim_input(sim: GameSim, at: Vector2) -> SimInput:
	var inp: SimInput = SimInput.new()
	inp.mouse_x = at.x - sim.camera.x
	inp.mouse_y = at.y - sim.camera.y
	return inp


func test_rail_complete_route_using_only_walk_jump_swallow_and_spit_inputs() -> void:
	var sim: GameSim = _sim(90, false)
	for tick: int in 400:
		var inp: SimInput = SimInput.new()
		inp.right = sim.player.x < sim.boss.x - 60.0
		sim.step(inp)
		if sim.boss.state == BossState.State.ACTIVE and sim.player.x >= sim.boss.x - 60.0:
			break
	check_eq(sim.boss.state, BossState.State.ACTIVE)
	for attempt: int in 3:
		sim.step(SimInput.new())
		for tick: int in 70:
			var inp: SimInput = SimInput.new()
			inp.jump = true
			inp.jump_pressed = tick == 0
			inp.right = sim.player.x < sim.boss.x + 42.0
			sim.step(inp)
			if tick > 10 and BossMechanism.riding(sim):
				break
		if BossMechanism.riding(sim):
			break
	check(BossMechanism.riding(sim), "player can board from the standard room floor")
	for tick: int in 40:
		var walk: SimInput = SimInput.new()
		walk.right = sim.player.x < sim.boss.x + 42.0
		sim.step(walk)
	for station: int in 3:
		for align_tick: int in 35:
			var align: SimInput = SimInput.new()
			align.left = sim.player.x > sim.boss.x + 44.0
			align.right = sim.player.x < sim.boss.x + 40.0
			sim.step(align)
		var supply: Vector2 = Vector2(sim.boss.x + 20.0, sim.boss.y + 20.0)
		for bite: int in 28:
			var inp: SimInput = _aim_input(sim, supply)
			inp.eat = true
			sim.step(inp)
			if sim.player.has_block:
				break
		check(sim.player.has_block, "real aim swallows station %d roof supply" % station)
		var detector: Vector2 = BossMechanism.detector_rect(sim.boss).get_center()
		sim.step(_aim_input(sim, detector))
		var fire: SimInput = _aim_input(sim, detector)
		fire.shoot_released = true
		sim.step(fire)
		for tick: int in 250:
			sim.step(SimInput.new())
			if sim.boss.mechanism.progress > station or sim.player.dead:
				break
		check_eq(sim.boss.mechanism.progress, station + 1, "real spit sends departure signal")
		check(not sim.player.dead)
	for tick: int in 30:
		sim.step(SimInput.new())
	check(sim.player.won, "ordinary inputs finish the entire carrier encounter")


func test_stopping_on_carrier_edge_does_not_snap_player_off_the_roof() -> void:
	var sim: GameSim = _sim(90)
	sim.player.place_at(sim.boss.x - sim.player.w + 0.9, sim.boss.y - sim.player.h)
	sim.player.grounded = true
	var before: float = sim.player.x
	for tick: int in 30:
		sim.step(SimInput.new())
	check_near(sim.player.x, before, 0.01, "terrain alignment must not pull a passenger away from a boss roof")
	check(BossMechanism.riding(sim))


func test_sand_core_escape_using_only_movement_and_swallow_inputs() -> void:
	var sim: GameSim = _sim(80, false)
	for tick: int in 500:
		var inp: SimInput = SimInput.new()
		inp.right = true
		inp.jump = sim.player.x > sim.boss.x - 250.0 and sim.player.x < sim.boss.x - 100.0
		inp.jump_pressed = inp.jump and sim.player.grounded
		sim.step(inp)
		if sim.player.x >= sim.boss.x - sim.player.w - 1.0:
			break
	check_eq(sim.boss.state, BossState.State.ACTIVE)
	for tick: int in 50:
		var inp: SimInput = _aim_input(sim, Vector2(sim.boss.x + 20.0, sim.boss.y + 100.0))
		inp.eat = true
		sim.step(inp)
		if sim.player.has_sand_core:
			break
	check(sim.player.has_sand_core, "normal swallowing steals the exposed sand core")
	for tick: int in 500:
		var inp: SimInput = SimInput.new()
		inp.left = true
		var next_col: int = Tile.cell_of(sim.player.x - 10.0)
		var floor_row: int = Tile.cell_of(sim.boss.mechanism.floor_y) - 1
		inp.jump_pressed = sim.player.grounded and Tile.is_solid(sim.level.get_cell(floor_row, next_col))
		inp.jump = inp.jump_pressed or sim.player.is_jumping
		sim.step(inp)
		if sim.player.won or sim.player.dead:
			break
	check(not sim.player.dead, "warned sand can be evaded while carrying the core")
	check(sim.player.won, "normal movement takes the unique core back to the entrance")


func test_furnace_full_attack_defuse_return_cycle_with_real_inputs() -> void:
	var sim: GameSim = _sim(100, false)
	for tick: int in 1800:
		var inp: SimInput = SimInput.new()
		inp.right = sim.player.x < sim.boss.x - 164.0
		inp.left = sim.player.x > sim.boss.x - 154.0
		if sim.player.has_furnace_charge:
			inp = _aim_input(sim, Vector2(sim.boss.center_x(), sim.boss.center_y()))
			inp.shoot_released = not sim.player.waiting_for_shoot_release
		elif not sim.tnt_charges.is_empty():
			var closest: GameSim.TntCharge = null
			var distance: float = INF
			for charge: GameSim.TntCharge in sim.tnt_charges:
				var d: float = charge.center.distance_to(Vector2(sim.player.center_x(), sim.player.center_y()))
				if charge.boss_owned and d < distance:
					closest = charge
					distance = d
			if closest != null:
				inp = _aim_input(sim, closest.center)
				inp.eat = true
		sim.step(inp)
		if sim.boss.dead:
			break
		if sim.player.dead:
			break
	check(not sim.player.dead, "defusing the marked charge and firing from outside blast range is viable")
	check(sim.boss.dead, "three actual enemy attacks can be defused and returned without injected ammo")


func test_ice_reverse_shots_brake_without_overshoot_and_docks_offer_a_breather() -> void:
	var sim: GameSim = _sim(70)
	var shot: SimProjectile = _shot(Tile.ICE)
	shot.vx = -12.0
	sim.boss.vx = 0.8
	BossMechanism.hit_by_projectile(sim, shot, sim.boss.center_x(), sim.boss.center_y())
	check_near(sim.boss.vx, 0.0, 0.001, "braking cannot unexpectedly reverse the boss")
	BossMechanism.hit_by_projectile(sim, shot, sim.boss.center_x(), sim.boss.center_y())
	check(sim.boss.vx < 0.0, "a second shot deliberately starts the opposite direction")
	BossMechanism._begin_attack(sim)
	var station: Vector2 = BossMechanism.cooling_station(sim)
	sim.boss.x = station.x - sim.boss.w * 0.5
	sim.boss.vx = 0.0
	for tick: int in 60:
		BossMechanism._skate(sim)
	check_eq(sim.boss.mechanism.progress, 1)
	check_eq(sim.boss.state, BossState.State.ACTIVE)
	check(sim.boss.mechanism.zones.is_empty(), "successful cooling cancels the pending attack")
	check(sim.boss.cooldown >= BossMechanism.rest_ticks(sim.boss) + 60, "cooling offers time to prepare the next station")
	check(not sim.falling_blocks.is_empty(), "station completion requests fresh ammunition")
