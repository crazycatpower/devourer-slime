extends SceneTree
## Searches for a way to finish a level by running the real simulation.
##
## Usage:
##   godot --headless --path godot -s res://tools/solve/solve.gd -- <slot|file> [...]
##
## A number solves that built-in slot; anything else is read as a text file of
## level rows (one row per line). The search is a weighted best-first search
## over short input macros (walk, jump, swallow a block, spit in one of 16
## directions). It proves a level can be finished but not that it cannot, and
## the solution it finds is one possible route, not the intended one.

const MOVE_TICKS: int = 6
const EAT_TICKS: int = 25
const SPIT_AFTER_TICKS: int = 12
const NODE_LIMIT: int = 300000
const HEURISTIC_WEIGHT: float = 1.0
const SPIT_DIRECTIONS: int = 16
const EAT_REACH: float = 62.0

var _out: String = "res://build/recordings/world1"
var _goal: Vector2 = Vector2.ZERO
var _cols: int = 0
var _rows: int = 0
var _dist: PackedFloat32Array = PackedFloat32Array()
var _carry_required: bool = false


class Waypoint:
	extends RefCounted
	var cell: Vector2i = Vector2i.ZERO
	var carry: int = 0
	var airborne_ok: bool = false
	var is_goal: bool = false


class HeapItem:
	extends RefCounted
	var priority: float = 0.0
	var serial: int = 0
	var node: SearchNode = null


class SearchNode:
	extends RefCounted
	var sim: GameSim
	var ticks: int = 0
	var jump_held: bool = false
	var parent: SearchNode = null
	var action: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--world2" in args:
		_out = "res://build/recordings/world2"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var failed: bool = false
	for arg: String in args:
		if arg.begins_with("--"):
			continue
		var rows: PackedStringArray = PackedStringArray()
		var waypoints: Array[Waypoint] = []
		_load(arg, rows, waypoints)
		if rows.is_empty():
			print("%s: cannot load" % arg)
			failed = true
			continue
		if not _solve(arg, rows, waypoints):
			failed = true
	quit(1 if failed else 0)


## Reads [param arg]: a slot number, or a text file of level rows optionally
## followed by a "---" line and waypoints ("row,col" plus the flags "+b" = must
## carry a block, "-b" = must carry none, "a" = need not stand on the ground).
func _load(arg: String, rows: PackedStringArray, waypoints: Array[Waypoint]) -> void:
	if arg.is_valid_int():
		rows.append_array(LevelLibrary.shipped_rows(int(arg)))
		var checkpoints: Dictionary = {
			13: [Vector2i(14, 12), Vector2i(16, 9), Vector2i(17, 5), Vector2i(19, 2)],
			15: [Vector2i(3, 6), Vector2i(6, 6), Vector2i(17, 6), Vector2i(20, 6)],
			16: [Vector2i(3, 1), Vector2i(7, 1), Vector2i(13, 1), Vector2i(20, 1)],
			17: [Vector2i(13, 10), Vector2i(17, 10), Vector2i(12, 10), Vector2i(2, 4), Vector2i(5, 1), Vector2i(11, 1), Vector2i(17, 1)],
			11: [Vector2i(5, 13), Vector2i(8, 9), Vector2i(11, 6), Vector2i(14, 10), Vector2i(17, 13), Vector2i(21, 9), Vector2i(21, 5), Vector2i(23, 2)],
			2: [Vector2i(5, 10), Vector2i(8, 7)],
			4: [Vector2i(23, 9), Vector2i(17, 8), Vector2i(10, 6)],
			7: [Vector2i(8, 13), Vector2i(14, 13), Vector2i(20, 13), Vector2i(23, 10), Vector2i(17, 9), Vector2i(11, 9), Vector2i(5, 9), Vector2i(1, 6), Vector2i(7, 5), Vector2i(13, 5), Vector2i(19, 5)],
			6: [Vector2i(13, 10), Vector2i(19, 10), Vector2i(22, 13), Vector2i(26, 11), Vector2i(27, 10), Vector2i(33, 10), Vector2i(43, 8)],
			10: [Vector2i(17, 9), Vector2i(29, 12), Vector2i(30, 10), Vector2i(30, 5), Vector2i(33, 12), Vector2i(66, 7), Vector2i(74, 8), Vector2i(81, 9), Vector2i(114, 9), Vector2i(117, 6), Vector2i(111, 4), Vector2i(122, 1), Vector2i(127, 3), Vector2i(131, 3), Vector2i(135, 4), Vector2i(137, 2), Vector2i(141, 3), Vector2i(145, 3)],
			8: [Vector2i(14, 11), Vector2i(13, 8), Vector2i(10, 9), Vector2i(6, 9), Vector2i(2, 8), Vector2i(2, 5)],
			9: [Vector2i(3, 10), Vector2i(8, 10), Vector2i(12, 11), Vector2i(15, 10), Vector2i(18, 7), Vector2i(20, 4), Vector2i(16, 3), Vector2i(12, 3), Vector2i(8, 3)],
		}
		for cell: Vector2i in checkpoints.get(int(arg), []):
			var checkpoint: Waypoint = Waypoint.new()
			checkpoint.cell = cell
			if int(arg) == 11:
				checkpoint.airborne_ok = cell.x != 21
				if cell == Vector2i(17, 13):
					checkpoint.carry = 1
			if int(arg) == 15 and cell == Vector2i(6, 6):
				checkpoint.carry = 1
			if int(arg) == 16 and cell.x in [3, 7, 13]:
				checkpoint.carry = 1
			if int(arg) in [13, 15, 17]:
				checkpoint.airborne_ok = true
			if int(arg) == 13 and cell.x in [14, 16]:
				checkpoint.carry = 1
				checkpoint.airborne_ok = false
			if int(arg) == 17 and cell.x in [17, 12] and cell.y == 10:
				checkpoint.carry = 1
			if int(arg) == 6 and cell.x >= 22:
				checkpoint.carry = 1
				checkpoint.airborne_ok = cell.x == 27 or cell.x == 33
			if int(arg) == 10 and (cell.x in [17, 29, 33, 66, 74, 81, 122] or cell == Vector2i(30, 10)):
				checkpoint.carry = 1
			waypoints.append(checkpoint)
		return
	var in_rows: bool = true
	for line: String in FileAccess.get_file_as_string(arg).split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.is_empty():
			continue
		if trimmed == "---":
			in_rows = false
		elif in_rows:
			rows.append(line.strip_edges(false, true))
		else:
			var parts: PackedStringArray = trimmed.split(" ")
			var cell: PackedStringArray = parts[0].split(",")
			var wp: Waypoint = Waypoint.new()
			wp.cell = Vector2i(int(cell[1]), int(cell[0]))
			wp.carry = 1 if "+b" in parts else (-1 if "-b" in parts else 0)
			wp.airborne_ok = "a" in parts
			waypoints.append(wp)


func _solve(label: String, rows: PackedStringArray, waypoints: Array[Waypoint]) -> bool:
	var data: LevelData = LevelCodec.decode(rows)
	var root_sim: GameSim = GameSim.new()
	root_sim.rng.set_seed(7)
	root_sim.bullet_time_enabled = false
	root_sim.load_level(int(label) if label.is_valid_int() else 1, data, LevelLibrary.boss_kind_for_slot(int(label)) if label.is_valid_int() else BossState.Kind.NONE)
	var goal_cell: Vector2 = _find_goal(root_sim.level)
	var final_wp: Waypoint = Waypoint.new()
	final_wp.cell = Vector2i(floori(goal_cell.x / Tile.SIZE), floori(goal_cell.y / Tile.SIZE))
	final_wp.is_goal = true
	var stages: Array[Waypoint] = []
	stages.append_array(waypoints)
	stages.append(final_wp)

	var current: SearchNode = SearchNode.new()
	current.sim = root_sim
	var all_steps: PackedStringArray = PackedStringArray()
	var total_ticks: int = 0
	var started: int = Time.get_ticks_msec()
	var nodes: int = 0
	var resume_stage: int = 0
	var partial_path: String = _out + "/partial_" + label + ".json"
	if "--resume" in OS.get_cmdline_user_args() and FileAccess.file_exists(partial_path):
		var saved: Array = JSON.parse_string(FileAccess.get_file_as_string(partial_path))
		for action: String in saved:
			var selected: SearchNode = null
			for child: SearchNode in _expand(current):
				if child.action == action:
					selected = child
					break
			if selected == null:
				push_error("Cannot replay " + action)
				return false
			current = selected
			total_ticks += current.ticks
			current.parent = null
			current.ticks = 0
			all_steps.append(action)
		resume_stage = FileAccess.get_file_as_string(_out + "/checkpoint_" + label + ".txt").to_int()
		print("RESUMED ", label, " stage=", resume_stage, " pos=", Vector2(current.sim.player.x, current.sim.player.y))
	for index: int in stages.size():
		if index < resume_stage:
			continue
		var stage: Waypoint = stages[index]
		var result: SearchNode = _search(current, stage)
		nodes += _last_expanded
		if result == null:
			print(
				"%s: NO SOLUTION at stage %d (%d,%d) after %d ticks (%d nodes, closest %.0f)"
				% [
					label, index + 1, stage.cell.y, stage.cell.x, total_ticks, _last_expanded,
					_last_best,
				]
			)
			return false
		var chain: PackedStringArray = PackedStringArray()
		var cursor: SearchNode = result
		while cursor != current:
			chain.append(cursor.action)
			cursor = cursor.parent
		chain.reverse()
		all_steps.append_array(chain)
		FileAccess.open(_out + "/partial_" + label + ".json", FileAccess.WRITE).store_string(JSON.stringify(Array(all_steps)))
		FileAccess.open(_out + "/checkpoint_" + label + ".txt", FileAccess.WRITE).store_string(str(index + 1))
		total_ticks += result.ticks
		result.parent = null
		result.ticks = 0
		current = result
		print("CHECKPOINT ", label, " stage=", index + 1, " ticks=", total_ticks, " pos=", Vector2(current.sim.player.x, current.sim.player.y))
	print(
		"%s: SOLVED in %d ticks (%.1fs of play), %d nodes, %.1fs"
		% [
			label, total_ticks, float(total_ticks) / 60.0, nodes,
			float(Time.get_ticks_msec() - started) / 1000.0,
		]
	)
	print("  " + " ".join(all_steps))
	FileAccess.open(_out + "/route_" + label + ".json", FileAccess.WRITE).store_string(JSON.stringify(Array(all_steps)))
	return true


var _last_expanded: int = 0
var _last_best: float = 0.0


func _reached(sim: GameSim, wp: Waypoint) -> bool:
	var p: PlayerState = sim.player
	if wp.is_goal:
		return p.won
	if p.dead:
		return false
	var wx: float = (float(wp.cell.x) + 0.5) * Tile.SIZE
	var wy: float = (float(wp.cell.y) + 0.5) * Tile.SIZE
	if absf(p.center_x() - wx) > 20.0 or absf(p.center_y() - wy) > 24.0:
		return false
	if wp.carry == 1 and not p.has_block:
		return false
	if wp.carry == -1 and p.has_block:
		return false
	return p.grounded or wp.airborne_ok


## Best-first search from [param start] to [param wp]; null when the node limit
## runs out. [param start] must not be mutated; its descendants are clones.
func _search(start: SearchNode, wp: Waypoint) -> SearchNode:
	_carry_required = wp.carry == 1 and start.sim.slot <= 10 and (start.sim.boss_kind != BossState.Kind.STEEL_CHASE or wp.cell.x < 60)
	_goal = Vector2((float(wp.cell.x) + 0.5) * Tile.SIZE, (float(wp.cell.y) + 0.5) * Tile.SIZE)
	_build_distance_field(start.sim.level)
	var open: Array[HeapItem] = []
	var seen: Dictionary = {}
	var serial: int = 0
	_push(open, _item(_priority(start), serial, start))
	seen[_key(start)] = true
	var expanded: int = 0
	var best_h: float = _heuristic(start.sim)
	var best_position: Vector2 = Vector2.ZERO
	while not open.is_empty() and expanded < NODE_LIMIT:
		var node: SearchNode = _pop(open).node
		expanded += 1
		if expanded % 2000 == 0:
			print("SEARCH nodes=", expanded, " best=", best_h, " pos=", best_position)
		for child: SearchNode in _expand(node):
			if _reached(child.sim, wp):
				_last_expanded = expanded
				return child
			if child.sim.player.dead or child.sim.player.won:
				continue
			var key: String = _key(child)
			if seen.has(key):
				continue
			seen[key] = true
			if _heuristic(child.sim) < best_h:
				best_h = _heuristic(child.sim)
				best_position = Vector2(child.sim.player.x, child.sim.player.y)
			serial += 1
			_push(open, _item(_priority(child), serial, child))
	_last_expanded = expanded
	_last_best = best_h
	return null


func _find_goal(level: LevelGrid) -> Vector2:
	for r: int in level.rows:
		for c: int in level.cols:
			if level.get_cell(r, c) == Tile.GOAL:
				return Vector2((float(c) + 0.5) * Tile.SIZE, (float(r) + 0.5) * Tile.SIZE)
	return Vector2.ZERO


## Cost of walking through a cell when the search ignores physics: blocks can
## be eaten, voids plugged and spikes risked, but steel is a wall.
func _cell_cost(tile: int) -> float:
	if tile == Tile.STEEL:
		return INF
	if Tile.is_spike(tile):
		return 14.0 if tile != Tile.VOID else 6.0
	if Tile.is_eatable(tile) or tile == Tile.GLASS:
		return 2.5
	return 1.0


func _build_distance_field(level: LevelGrid) -> void:
	_cols = level.cols
	_rows = level.rows
	_dist = PackedFloat32Array()
	_dist.resize(_cols * _rows)
	_dist.fill(INF)
	var goal_c: int = floori(_goal.x / Tile.SIZE)
	var goal_r: int = floori(_goal.y / Tile.SIZE)
	var open: Array[Vector2i] = [Vector2i(goal_c, goal_r)]
	_dist[goal_r * _cols + goal_c] = 0.0
	while not open.is_empty():
		# Small grids: pick the cheapest entry linearly.
		var best_i: int = 0
		for i: int in open.size():
			var o: Vector2i = open[i]
			var b: Vector2i = open[best_i]
			if _dist[o.y * _cols + o.x] < _dist[b.y * _cols + b.x]:
				best_i = i
		var cur: Vector2i = open[best_i]
		open.remove_at(best_i)
		var cur_d: float = _dist[cur.y * _cols + cur.x]
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + step
			if n.x < 0 or n.y < 0 or n.x >= _cols or n.y >= _rows:
				continue
			var cost: float = _cell_cost(level.get_cell(n.y, n.x))
			if is_inf(cost):
				continue
			var nd: float = cur_d + cost
			if nd < _dist[n.y * _cols + n.x]:
				_dist[n.y * _cols + n.x] = nd
				open.append(n)


## Estimated ticks still needed, from the relaxed distance field.
func _heuristic(sim: GameSim) -> float:
	var p: PlayerState = sim.player
	var c: int = clampi(floori(p.center_x() / Tile.SIZE), 0, _cols - 1)
	var r: int = clampi(floori(p.center_y() / Tile.SIZE), 0, _rows - 1)
	var d: float = _dist[r * _cols + c]
	if is_inf(d):
		d = 400.0
	return d * 9.5


func _priority(node: SearchNode) -> float:
	return float(node.ticks) * (0.05 if node.sim.slot in range(11, 21) else 0.3) + _heuristic(node.sim) * HEURISTIC_WEIGHT


func _key(node: SearchNode) -> String:
	var p: PlayerState = node.sim.player
	var flying: String = ""
	for projectile: SimProjectile in node.sim.projectiles:
		flying += ";%d,%d,%d,%d" % [int(projectile.x / 10.0), int(projectile.y / 10.0), roundi(projectile.vx), roundi(projectile.vy)]
	return flying + "%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d" % [
		int(p.x / 5.0), int(p.y / 5.0), roundi(p.vx), roundi(p.vy / 2.0),
		1 if p.grounded else 0, p.carried_block_type + p.carried_block_eaten_count * 100
		if p.has_block else 0, node.sim.level.checksum(), 1 if node.jump_held else 0,
		node.sim.projectiles.size(), p.wall_bounce_timer,
		node.sim.boss.state, node.sim.boss.intro_timer, int(node.sim.boss.x / 3.0),
	]


# --- actions -----------------------------------------------------------------

func _expand(node: SearchNode) -> Array[SearchNode]:
	var out: Array[SearchNode] = []
	var sim: GameSim = node.sim
	var p: PlayerState = sim.player
	if sim.boss.state == BossState.State.INTRO:
		var count: int = sim.boss.intro_timer
		var child: SearchNode = _child(node, "W%d" % count)
		for tick: int in count:
			child.sim.step(SimInput.new())
		child.jump_held = false
		child.ticks = node.ticks + count
		out.append(child)
		return out
	# Walking and jumping.
	for dir: int in [-1, 0, 1]:
		for jump: int in [0, 1]:
			var child: SearchNode = _child(node, "%s%s" % [["L", "-", "R"][dir + 1], "J" if jump == 1 else ""])
			var held: bool = node.jump_held
			for i: int in MOVE_TICKS:
				var inp: SimInput = _input(dir, jump == 1)
				inp.jump_pressed = jump == 1 and not held
				held = jump == 1
				child.sim.step(inp)
				if child.sim.player.dead or child.sim.player.won:
					break
			child.jump_held = held
			child.ticks = node.ticks + MOVE_TICKS
			out.append(child)
	if p.has_block and not _carry_required:
		for i: int in SPIT_DIRECTIONS:
			var angle: float = TAU * float(i) / float(SPIT_DIRECTIONS)
			var child: SearchNode = _child(node, "S%d" % roundi(360.0 * float(i) / float(SPIT_DIRECTIONS)))
			var inp: SimInput = _input(0, false)
			_aim(child.sim, inp, p.center_x() + cos(angle) * 100.0, p.center_y() + sin(angle) * 100.0)
			inp.shoot_released = true
			child.sim.step(inp)
			for t: int in SPIT_AFTER_TICKS:
				child.sim.step(_input(0, false))
				if child.sim.player.dead or child.sim.player.won:
					break
			child.jump_held = false
			child.ticks = node.ticks + 1 + SPIT_AFTER_TICKS
			out.append(child)
		# A release while steering is a normal gameplay input, needed when
		# recoil must clear a tall ledge without losing horizontal movement.
		for dir: int in [-1, 1]:
			for angle_deg: int in [0, 45, 90, 135, 180, 225, 270, 315]:
				var angle: float = deg_to_rad(float(angle_deg))
				var child: SearchNode = _child(node, "S%d%s" % [angle_deg, "R" if dir > 0 else "L"])
				var inp: SimInput = _input(dir, node.jump_held)
				_aim(child.sim, inp, p.center_x() + cos(angle) * 100.0, p.center_y() + sin(angle) * 100.0)
				inp.shoot_released = true
				child.sim.step(inp)
				for tick: int in SPIT_AFTER_TICKS:
					child.sim.step(_input(dir, node.jump_held))
					if child.sim.player.dead or child.sim.player.won:
						break
				child.jump_held = node.jump_held
				child.ticks = node.ticks + 1 + SPIT_AFTER_TICKS
				out.append(child)
	elif not p.dead:
		for target: Vector2i in _eat_targets(sim):
			var child: SearchNode = _child(node, "E%d,%d" % [target.y, target.x])
			var wx: float = (float(target.x) + 0.5) * Tile.SIZE
			var wy: float = (float(target.y) + 0.5) * Tile.SIZE
			for t: int in EAT_TICKS:
				var inp: SimInput = _input(0, false)
				inp.eat = true
				_aim(child.sim, inp, wx, wy)
				child.sim.step(inp)
				if child.sim.player.dead:
					break
			child.jump_held = false
			child.ticks = node.ticks + EAT_TICKS
			out.append(child)
	return out


func _eat_targets(sim: GameSim) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var p: PlayerState = sim.player
	var cx: float = p.center_x()
	var cy: float = p.center_y()
	var r0: int = floori((cy - EAT_REACH) / Tile.SIZE)
	var r1: int = floori((cy + EAT_REACH) / Tile.SIZE)
	var c0: int = floori((cx - EAT_REACH) / Tile.SIZE)
	var c1: int = floori((cx + EAT_REACH) / Tile.SIZE)
	for r: int in range(r0, r1 + 1):
		for c: int in range(c0, c1 + 1):
			if not sim.level.in_bounds(r, c) or not Tile.is_eatable(sim.level.get_cell(r, c)):
				continue
			var dx: float = (float(c) + 0.5) * Tile.SIZE - cx
			var dy: float = (float(r) + 0.5) * Tile.SIZE - cy
			if sqrt(dx * dx + dy * dy) <= EAT_REACH:
				out.append(Vector2i(c, r))
	return out


func _child(node: SearchNode, action: String) -> SearchNode:
	var child: SearchNode = SearchNode.new()
	child.sim = _clone_sim(node.sim)
	child.parent = node
	child.action = action
	return child


func _input(dir: int, jump: bool) -> SimInput:
	var inp: SimInput = SimInput.new()
	inp.left = dir < 0
	inp.right = dir > 0
	inp.jump = jump
	return inp


## Points the mouse at world position ([param wx], [param wy]).
func _aim(sim: GameSim, inp: SimInput, wx: float, wy: float) -> void:
	inp.mouse_x = wx - sim.camera.x
	inp.mouse_y = wy - sim.camera.y


# --- cloning -----------------------------------------------------------------

var _prop_cache: Dictionary = {}


func _props_of(obj: Object) -> PackedStringArray:
	var script: Script = obj.get_script()
	if _prop_cache.has(script):
		return _prop_cache[script]
	var names: PackedStringArray = PackedStringArray()
	for prop: Dictionary in obj.get_property_list():
		if (prop["usage"] as int) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			names.append(prop["name"] as String)
	_prop_cache[script] = names
	return names


func _clone_sim(src: GameSim) -> GameSim:
	var dst: GameSim = GameSim.new()
	for name: String in _props_of(src):
		if name == "particles" or name == "boss" or name == "fx_rng":
			continue
		if name == "_source":
			dst.set(name, src.get(name))
			continue
		dst.set(name, _clone_value(src.get(name)))
	dst.boss = _clone_value(src.boss)
	return dst


func _clone_value(value: Variant) -> Variant:
	if value is LevelGrid:
		return (value as LevelGrid).duplicate_grid()
	if value is RefCounted:
		var obj: RefCounted = value
		var script: GDScript = obj.get_script()
		var copy: RefCounted = script.new()
		for name: String in _props_of(obj):
			copy.set(name, _clone_value(obj.get(name)))
		return copy
	if value is Array:
		var arr: Array = (value as Array).duplicate()
		for i: int in arr.size():
			arr[i] = _clone_value(arr[i])
		return arr
	return value


# --- min-heap ---------------------------------------------------------------

func _item(priority: float, serial: int, node: SearchNode) -> HeapItem:
	var item: HeapItem = HeapItem.new()
	item.priority = priority
	item.serial = serial
	item.node = node
	return item


func _push(heap: Array[HeapItem], item: HeapItem) -> void:
	heap.append(item)
	var i: int = heap.size() - 1
	while i > 0:
		var parent: int = (i - 1) >> 1
		if _less(heap[i], heap[parent]):
			var tmp: HeapItem = heap[i]
			heap[i] = heap[parent]
			heap[parent] = tmp
			i = parent
		else:
			break


func _pop(heap: Array[HeapItem]) -> HeapItem:
	var top: HeapItem = heap[0]
	var last: HeapItem = heap.pop_back()
	if not heap.is_empty():
		heap[0] = last
		var i: int = 0
		var n: int = heap.size()
		while true:
			var l: int = i * 2 + 1
			var r: int = l + 1
			var m: int = i
			if l < n and _less(heap[l], heap[m]):
				m = l
			if r < n and _less(heap[r], heap[m]):
				m = r
			if m == i:
				break
			var tmp: HeapItem = heap[i]
			heap[i] = heap[m]
			heap[m] = tmp
			i = m
	return top


func _less(a: HeapItem, b: HeapItem) -> bool:
	if a.priority != b.priority:
		return a.priority < b.priority
	return a.serial < b.serial




