extends TestCase

func test_upward_spikes_rest_on_steel() -> void:
	for slot: int in [34, 35, 36, 37]:
		var grid: LevelGrid = LevelLibrary.built_in_level(slot).grid
		for r: int in grid.rows:
			for c: int in grid.cols:
				if grid.get_cell(r, c) == Tile.SPIKE_UP:
					check_eq(grid.get_cell(r + 1, c), Tile.STEEL, "stage %d spike %d,%d has a base" % [slot, r, c])

func test_routes_and_resource_reuse() -> void:
	var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/world4_mid_solutions.json"))
	var script: GDScript = load("res://tests/unit/test_world5_levels.gd") as GDScript
	var controller: RefCounted = script.new()
	for enabled: bool in [false, true]:
		for slot: int in [34, 35, 36, 37]:
			var rows: PackedStringArray = LevelLibrary.built_in_rows(slot)
			check_eq(LevelValidator.problem_with(rows), "")
			var sim: GameSim = GameSim.new()
			sim.load_level(slot, LevelCodec.decode(rows), BossState.Kind.NONE)
			sim.bullet_time_enabled = enabled
			for i: int in 15:
				sim.step(SimInput.new())
			for action: Dictionary in routes[str(slot)]:
				controller.call(&"_execute", sim, action)
				if sim.player.dead or sim.player.won:
					break
			check(sim.player.won and not sim.player.dead, "stage %d bullet=%s completes" % [slot, enabled])
			if slot == 35:
				check_eq(sim.level.get_cell(12, 9), Tile.AIR, "first bridge is retrieved")
				check_eq(sim.level.get_cell(12, 10), Tile.AIR, "other bridge block is retrieved")
				check_eq(sim.level.get_cell(12, 17), Tile.DIRT_EATEN_2, "two reclaimed blocks form the new bridge")
				check_eq(sim.level.get_cell(12, 18), Tile.DIRT_EATEN_2, "same block bridges second gap")
			if slot == 36:
				check_eq(sim.level.get_cell(13, 21), Tile.DIRT_EATEN_2, "new bridge supplies narrow landing")

func test_other_original_stages_are_preserved() -> void:
	for slot: int in range(11, 40):
		if slot not in [20, 30, 34, 35, 36, 37]:
			check_eq(LevelLibrary.built_in_rows(slot), Fixtures.legacy_rows(slot))

func test_high_platform_requires_more_than_regular_jump() -> void:
	var sim: GameSim = GameSim.new()
	sim.load_level(34, LevelLibrary.built_in_level(34), BossState.Kind.NONE)
	var script: GDScript = load("res://tests/unit/test_world5_levels.gd") as GDScript
	var controller: RefCounted = script.new()
	for i: int in 15:
		sim.step(SimInput.new())
	controller.call(&"_execute", sim, {"op":"walk", "x":163.0})
	controller.call(&"_execute", sim, {"op":"eat", "r":16, "c":5})
	controller.call(&"_execute", sim, {"op":"walk", "x":323.0})
	controller.call(&"_execute", sim, {"op":"jump", "x":443.0})
	check(sim.player.y > 480.0, "ordinary jump cannot bypass the launch block")
