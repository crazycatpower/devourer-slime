extends TestCase

func _route() -> Array:
	var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/world3_mid_solutions.json"))
	return routes["37"]

func _new_sim() -> GameSim:
	var sim: GameSim = GameSim.new()
	sim.load_level(37, LevelLibrary.built_in_level(37), BossState.Kind.NONE)
	sim.bullet_time_enabled = false
	for i: int in 15:
		sim.step(SimInput.new())
	return sim

func _controller() -> RefCounted:
	var script: GDScript = load("res://tests/unit/test_world4_levels.gd") as GDScript
	return script.new()

func test_durability_drives_each_materials_role() -> void:
	var sim: GameSim = _new_sim()
	var controller: RefCounted = _controller()
	var source_count: int = 0
	for r: int in sim.level.rows:
		for c: int in sim.level.cols:
			if sim.level.get_cell(r,c) == Tile.DIRT:
				source_count += 1
	check_eq(source_count, 3, "three original materials for the entire puzzle")
	for action: Dictionary in _route():
		controller.call(&"_execute", sim, action)
		if action.op == "shoot" and action.r == 7 and action.c == 9:
			check_eq(sim.level.get_cell(7,8), Tile.DIRT_EATEN_1, "A first becomes the entrance bridge")
		if action.op == "eat" and action.r == 7 and action.c == 8:
			check_eq(sim.player.carried_block_eaten_count, 2, "A can be moved once more")
		if action.op == "shoot" and action.r == 7 and action.c == 17:
			check_eq(sim.level.get_cell(7,16), Tile.DIRT_EATEN_2, "A becomes bridge and well cap")
		if action.op == "eat" and action.r == 7 and action.c == 16:
			check_eq(sim.level.get_cell(7,16), Tile.AIR, "third swallow opens the well")
			check(not sim.player.has_block, "third swallow digests A rather than providing ammo")
		if action.op == "eat" and action.r == 6 and action.c == 20:
			check_eq(sim.player.carried_block_eaten_count, 2, "B was stored while inventory was needed for A")
		if action.op == "shoot" and action.r == 8 and action.c == 21:
			check_eq(sim.level.get_cell(9,22), Tile.DIRT_EATEN_1, "C builds its own escape foothold")
		if action.op == "eat" and action.r == 9 and action.c == 22:
			check_eq(sim.player.carried_block_eaten_count, 2, "C must leave with the player")
			check_eq(sim.level.get_cell(9,22), Tile.AIR, "the return step is dismantled")
	check(sim.player.won and not sim.player.dead)
	check_eq(sim.level.get_cell(10,16), Tile.AIR, "B breaks the first glass seal")
	check_eq(sim.level.get_cell(12,16), Tile.AIR, "C breaks the last glass seal")

func test_omitting_reuse_steps_does_not_complete_the_route() -> void:
	# Verify actual geometry and durability, not merely the final goal flag.
	for omitted: Dictionary in [{"op":"shoot","r":7,"c":9}, {"op":"shoot","r":7,"c":17}, {"op":"eat","r":7,"c":16}, {"op":"shoot","r":8,"c":21}]:
		var sim: GameSim = _new_sim()
		var controller: RefCounted = _controller()
		for action: Dictionary in _route():
			if action.op == omitted.op and action.get("r",-1) == omitted.r and action.get("c",-1) == omitted.c:
				continue
			controller.call(&"_execute",sim,action)
			if sim.player.dead or sim.player.won:
				break
		check(not sim.player.won, "omitting %s cannot complete the route" % omitted)

func test_unbridged_entrance_cannot_be_crossed_with_a_normal_jump() -> void:
	# Several take-off positions catch the obvious run-forward bypass.
	for takeoff: float in [263.0, 267.0, 271.0, 275.0, 279.0]:
		var sim: GameSim = _new_sim()
		var controller: RefCounted = _controller()
		controller.call(&"_execute",sim,{"op":"walk","x":123.0})
		controller.call(&"_execute",sim,{"op":"eat","r":6,"c":4})
		controller.call(&"_execute",sim,{"op":"walk","x":takeoff})
		controller.call(&"_execute",sim,{"op":"jump","x":363.0})
		check(sim.player.dead or sim.player.x < 326.0, "unbridged two-cell gap at takeoff %.0f" % takeoff)

func test_side_spike_has_a_wall_mount() -> void:
	var sim: GameSim = _new_sim()
	check_eq(sim.level.get_cell(8,15), Tile.SPIKE_RIGHT)
	check_eq(sim.level.get_cell(8,14), Tile.STEEL)

func test_lower_branch_can_be_completed_before_upper_branch() -> void:
	var sim: GameSim = _new_sim()
	var controller: RefCounted = _controller()
	var route: Array = _route()
	var alternate: Array = route.slice(0,12)
	alternate.append_array([{"op":"walk","x":656}, {"op":"eat","r":7,"c":16}])
	alternate.append_array(route.slice(26,35))
	alternate.append_array([{"op":"walk","x":656}, {"op":"shoot","r":10,"c":16}])
	alternate.append_array(route.slice(12,19))
	alternate.append_array([{"op":"walk","x":656}, {"op":"shoot","r":12,"c":16}, {"op":"walk","x":643}, {"op":"walk","x":643}])
	for action: Dictionary in alternate:
		controller.call(&"_execute",sim,action)
	check(sim.player.won and not sim.player.dead, "lower-first branch order also works")
