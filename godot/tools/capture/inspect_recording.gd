extends "res://tools/capture/solve_shipped.gd"
func _run() -> void:
	var stage: int = int(OS.get_cmdline_user_args()[0])
	var node: SearchNode = SearchNode.new()
	node.sim = GameSim.new()
	node.sim.load_level(stage, LevelLibrary.shipped_level(stage), LevelLibrary.boss_kind_for_slot(stage))
	node.sim.rng.set_seed(7)
	var path: String = "res://build/recordings/world2/partial_%d.json" % stage
	if FileAccess.file_exists(path):
		var actions: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
		for action: String in actions:
			var found: bool = false
			for child: SearchNode in _expand(node):
				if child.action == action:
					node = child
					found = true
					break
			if not found:
				print("FAILED ",action)
				quit(1)
				return
	print("PLAYER ", Vector2(node.sim.player.x, node.sim.player.y), " carry=", node.sim.player.has_block)
	var data: LevelData = LevelData.new()
	data.grid = node.sim.level
	for row: String in LevelCodec.encode(data):
		print(row)
	quit()