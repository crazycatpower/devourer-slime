extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/world4_solutions.json"))
	var script: GDScript = load("res://tests/unit/test_world4_levels.gd") as GDScript
	var controller: RefCounted = script.new()
	var failed: bool = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var target_slot: int = -1
	if not args.is_empty():
		target_slot = args[0].to_int()

	var slots: Array = [target_slot] if target_slot in range(31, 40) else range(31, 40)

	for slot: int in slots:
		var sim: GameSim = GameSim.new()
		sim.load_level(slot, LevelLibrary.built_in_level(slot), BossState.Kind.NONE)
		sim.bullet_time_enabled = false
		for i: int in 15:
			sim.step(SimInput.new())
		var actions: Array = routes.get(str(slot), [])
		for action: Dictionary in actions:
			controller.call(&"_execute", sim, action)
			print(slot, " ", action, " pos=(", int(sim.player.x), ",", int(sim.player.y), ") carry=", sim.player.has_block, " dead=", sim.player.dead, " won=", sim.player.won)
			if action.op == "shoot":
				for r: int in sim.level.rows:
					for c: int in sim.level.cols:
						var t: int = sim.level.get_cell(r, c)
						if t in [Tile.DIRT_EATEN_1, Tile.DIRT_EATEN_2, Tile.BOUNCY_EATEN_1, Tile.BOUNCY_EATEN_2]:
							print("   landed block at r=", r, " c=", c, " type=", t)
			if sim.player.dead or sim.player.won:
				break
		if not sim.player.won:
			failed = true
			print(">>> FAILED slot ", slot, " dead=", sim.player.dead, " won=", sim.player.won)
		else:
			print(">>> SUCCESS slot ", slot)
	quit(1 if failed else 0)
