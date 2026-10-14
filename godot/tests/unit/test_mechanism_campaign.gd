extends "res://tests/unit/test_world5_levels.gd"
## Replay commissioned maps with actual movement, aim, swallow and spit inputs.


func test_mechanism_maps_are_valid_distinct_and_keep_all_layers() -> void:
	var hashes: Array[int] = []
	for slot: int in range(51, 100):
		if LevelLibrary.is_boss_slot(slot):
			continue
		var data: LevelData = LevelLibrary.built_in_level(slot)
		check(LevelLibrary.has_authored_layout(slot), "authored %d" % slot)
		check(not LevelLibrary.is_standard_stage(slot))
		check_eq(LevelValidator.problem_with_document(LevelCodec.encode_document(data)), "")
		check(not hashes.has(data.grid.checksum()), "distinct map %d" % slot)
		hashes.append(data.grid.checksum())
		check(LevelCodec.decode_document(LevelCodec.encode_document(data)).equals(data))
		check(not LevelLibrary.stage_name(slot).is_empty())
		check(not LevelLibrary.stage_hint(slot).is_empty())
		if GameConstants.world_of_slot(slot) == 6:
			check(not data.grid.sensors.is_empty() and not data.grid.wires.is_empty(), "real wired circuit %d" % slot)
		if GameConstants.world_of_slot(slot) == 9:
			check(not data.grid.rails.is_empty(), "actual transport route %d" % slot)
	check_eq(hashes.size(), 45)
	for slot: int in [60, 70, 80, 90, 100]:
		check_eq(LevelLibrary.built_in_rows(slot), LevelLibrary.boss_rows())


func test_every_mechanism_route_wins_with_and_without_bullet_time() -> void:
	var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/mechanism_solutions.json"))
	for enabled: bool in [false, true]:
		for key: String in routes:
			var slot: int = key.to_int()
			var sim: GameSim = GameSim.new()
			sim.rng.set_seed(7)
			sim.load_level(slot, LevelLibrary.built_in_level(slot), BossState.Kind.NONE)
			sim.bullet_time_enabled = enabled
			for tick: int in 15:
				sim.step(SimInput.new())
			for action: Dictionary in routes[key]:
				if sim.player.dead or sim.player.won:
					break
				_execute(sim, action)
				if sim.player.dead:
					print("mechanism death ", slot, " action ", action, " pos ", Vector2(sim.player.x, sim.player.y))
			check(not sim.player.dead and sim.player.won, "slot %d bullet=%s completes at (%.1f, %.1f)" % [slot, enabled, sim.player.x, sim.player.y])
			sim.reset()
			check(sim.level.equals(LevelLibrary.built_in_level(slot).grid), "retry restores all stage layers")


func _execute(sim: GameSim, action: Dictionary) -> void:
	if action.op == "brake":
		for tick: int in 180:
			if sim.player.dead or sim.player.won or absf(sim.player.vx) < 0.2:
				break
			var input: SimInput = SimInput.new()
			input.left = sim.player.vx > 0.0
			input.right = sim.player.vx < 0.0
			sim.step(input)
	elif action.op == "verify":
		for col: int in action.open_gates:
			check_eq(sim.level.get_cell(13, col), Tile.AIR, "receiver opened by the intended operation in slot %d" % sim.slot)
		for coordinates: Array in action.covered:
			check(Tile.is_solid(sim.level.get_cell(coordinates[1] as int, coordinates[0] as int)), "sensor actually covered in slot %d" % sim.slot)
		for coordinates: Array in action.spent_tnt:
			check(sim.level.get_cell(coordinates[1] as int, coordinates[0] as int) != Tile.TNT, "TNT actually consumed or exploded in slot %d" % sim.slot)
	elif action.op == "wait":
		for tick: int in action.ticks:
			if sim.player.dead or sim.player.won:
				break
			sim.step(SimInput.new())
	else:
		super._execute(sim, action)


func test_circuit_sources_are_required_and_independent() -> void:
	var sim: GameSim = GameSim.new()
	sim.load_level(51, LevelLibrary.built_in_level(51), BossState.Kind.NONE)
	_execute(sim, {"op": "walk", "x": 27.0 * Tile.SIZE + 3.0})
	check(not sim.player.won, "walking and jumping cannot bypass the unpowered tutorial door")
	check_eq(sim.level.get_cell(13, 12), Tile.GLASS)
	sim.load_level(58, LevelLibrary.built_in_level(58), BossState.Kind.NONE)
	sim.level.set_cell(13, 5, Tile.DIRT)
	for tick: int in 120:
		sim.step(SimInput.new())
	check_eq(sim.level.get_cell(13, 15), Tile.DIRT, "first circuit delivers cargo to the collection station")
	check_eq(sim.level.get_cell(13, 25), Tile.GLASS, "cargo circuit does not accidentally energize the door circuit")
	sim.level.set_cell(13, 19, Tile.DIRT)
	for tick: int in 72:
		sim.step(SimInput.new())
	check_eq(sim.level.get_cell(13, 25), Tile.AIR, "only covering the separate switch opens the door")


func test_reworked_stations_wait_for_player_operations() -> void:
	# Arrival alone cannot start the next leg; transport stages have actual work.
	for entry: Array in [[83, 4, 13], [84, 14, 10], [88, 16, 13], [89, 14, 10]]:
		var sim: GameSim = GameSim.new()
		var slot: int = entry[0] as int
		sim.load_level(slot, LevelLibrary.built_in_level(slot), BossState.Kind.NONE)
		for tick: int in 400:
			sim.step(SimInput.new())
		check_eq(sim.level.get_cell(entry[2] as int, entry[1] as int), Tile.DIRT, "unstarted train remains at its station in %d" % slot)
		check(not sim.player.won)
	for entry: Array in [[52, 24], [55, 2], [82, 24], [94, 2], [99, 33]]:
		var slot: int = entry[0] as int
		var sim: GameSim = GameSim.new()
		sim.load_level(slot, LevelLibrary.built_in_level(slot), BossState.Kind.NONE)
		for tick: int in 15:
			sim.step(SimInput.new())
		var destination: float = (entry[1] as int) * Tile.SIZE + 3.0
		_execute(sim, {"op": "walk", "x": destination})
		check(not sim.player.won, "walking with automatic obstacle jumps does not solve %d" % slot)
