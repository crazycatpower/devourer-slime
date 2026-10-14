extends "res://tools/capture/solve_shipped.gd"

func _take(node: SearchNode, action: String) -> SearchNode:
	for child: SearchNode in _expand(node):
		if child.action == action:
			return child
	return null

func _run() -> void:
	var target_col: int = 74
	var target_row: int = 8
	var checkpoint: int = 7
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--gap-col="):
			target_col = argument.trim_prefix("--gap-col=").to_int()
		if argument.begins_with("--gap-row="):
			target_row = argument.trim_prefix("--gap-row=").to_int()
		if argument.begins_with("--checkpoint="):
			checkpoint = argument.trim_prefix("--checkpoint=").to_int()
	var eat_action: String = "E%d,%d" % [target_row, target_col]
	var saved: Array = JSON.parse_string(FileAccess.get_file_as_string("res://build/recordings/world1/partial_10.json"))
	var start: SearchNode = SearchNode.new()
	start.sim = GameSim.new()
	start.sim.bullet_time_enabled = false
	start.sim.load_level(10, LevelLibrary.shipped_level(10), BossState.Kind.STEEL_CHASE)
	for action: String in saved:
		start = _take(start, action)
		start.parent = null
	print("GAP start=", Vector2(start.sim.player.x, start.sim.player.y), " carry=", start.sim.player.has_block)
	var best: float = 0.0
	for walk: int in 4:
		for delay: int in range(1, 10):
			var node: SearchNode = start
			var route: Array = saved.duplicate()
			for step: int in walk:
				node = _take(node, "R")
				route.append("R")
			for step: int in delay:
				node = _take(node, "RJ")
				route.append("RJ")
			node = _take(node, "S180R")
			route.append("S180R")
			for step: int in 20:
				if node.sim.player.dead:
					break
				best = maxf(best, node.sim.player.x)
				if node.sim.player.grounded and node.sim.player.x > target_col * Tile.SIZE - 34.0 and node.sim.player.x < (target_col + 1) * Tile.SIZE:
					print("LAND walk=", walk, " delay=", delay, " pos=", Vector2(node.sim.player.x, node.sim.player.y))
					var eat: SearchNode = _take(node, eat_action)
					if eat != null and eat.sim.player.has_block and not eat.sim.player.dead:
						route.append(eat_action)
						FileAccess.open("res://build/recordings/world1/partial_10.json", FileAccess.WRITE).store_string(JSON.stringify(route))
						FileAccess.open("res://build/recordings/world1/checkpoint_10.txt", FileAccess.WRITE).store_string(str(checkpoint))
						print("GAP PASS")
						quit(0)
						return
					node = eat if eat != null else node
					break
				node = _take(node, "RJ")
				route.append("RJ")
			print("TRY ",walk,",",delay," end=",Vector2(node.sim.player.x,node.sim.player.y)," dead=",node.sim.player.dead)
	print("GAP failed best=", best)
	quit(1)
