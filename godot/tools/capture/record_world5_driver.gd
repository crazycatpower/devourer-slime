extends Node
## Records inputs first, then plays them through the real GameScreen at 60 Hz.
## No terrain edits, teleports, forced victory or replacement simulation.

var OUT: String = "res://build/recordings/world1"

class Recorder:
	extends GameSim
	var frames: Array[Dictionary] = []
	func step(inp: SimInput) -> void:
		# Candidate routes end at the first death; never search through a reset.
		if player.dead or player.won:
			return
		frames.append({"left": inp.left, "right": inp.right, "jump": inp.jump,
			"jp": inp.jump_pressed, "eat": inp.eat, "shoot": inp.shoot,
			"released": inp.shoot_released, "mx": inp.mouse_x + camera.x, "my": inp.mouse_y + camera.y})
		super.step(inp)

class ReplayInput:
	extends PlayerInput
	var sim: GameSim
	var frames: Array
	var index: int = 0
	var current: SimInput = SimInput.new()
	func sample(_mouse: Vector2) -> SimInput:
		current = SimInput.new()
		if index >= frames.size() or sim.player.won or sim.player.dead:
			return current
		var frame: Dictionary = frames[index]
		index += 1
		current.left = frame.left
		current.right = frame.right
		current.jump = frame.jump
		current.jump_pressed = frame.jp
		current.eat = frame.eat
		current.shoot = frame.shoot
		current.shoot_released = frame.released
		var mx: float = frame.mx
		var my: float = frame.my
		current.mouse_x = mx - sim.camera.x
		current.mouse_y = my - sim.camera.y
		return current
	func is_held(action: StringName) -> bool:
		return current.shoot if action == InputBindings.SHOOT else (current.eat if action == InputBindings.EAT else false)

var app: App
var game: GameScreen
var replay: ReplayInput
var slot: int = 1
var done_frames: int = 0
var records: Dictionary
var results: Array[Dictionary] = []
var movie_frame: int = 0
var start_frame: int = 0
var ending: bool = false
var first_slot: int = 1
var last_slot: int = 10

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--first="):
			first_slot = argument.trim_prefix("--first=").to_int()
		if argument.begins_with("--last="):
			last_slot = argument.trim_prefix("--last=").to_int()
	if "--world2" in OS.get_cmdline_user_args():
		OUT = "res://build/recordings/world2"
		if first_slot == 1:
			first_slot = 11
		if last_slot == 10:
			last_slot = 20
	slot = first_slot
	if "--world3" in OS.get_cmdline_user_args():
		OUT = "res://build/recordings/world3"
		if first_slot == 1:
			first_slot = 21
		if last_slot == 10:
			last_slot = 30
		slot = first_slot
	if "--world4" in OS.get_cmdline_user_args():
		OUT = "res://build/recordings/world4"
		if first_slot == 1:
			first_slot = 31
		if last_slot == 10:
			last_slot = 40
		slot = first_slot
	OUT = "res://build/recordings/world5"
	if first_slot == 1: first_slot = 41
	if last_slot == 10: last_slot = 50
	slot = first_slot
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if "--prepare" in OS.get_cmdline_user_args():
		_prepare()
		return
	SavePaths.wipe_sandbox()
	if true:
		for stage: int in range(first_slot, last_slot + 1):
			var imported: LevelRepository.ImportResult = LevelStore.import_text(FileAccess.get_file_as_string(OUT + "/maps/slot_%d.json" % stage), stage)
			if not imported.ok:
				get_tree().quit(2)
				return
	Settings.bullet_time_enabled = false
	Settings.game_speed = 1.0
	records = JSON.parse_string(FileAccess.get_file_as_string(OUT + "/inputs.json"))
	app = (load("res://src/app/app.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(app)
	await get_tree().process_frame
	await get_tree().process_frame
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 720)
	_begin()

func recording_level(stage: int) -> LevelData:
	if true:
		return LevelCodec.decode_document(JSON.parse_string(FileAccess.get_file_as_string(OUT + "/maps/slot_%d.json" % stage)))
	return LevelLibrary.shipped_level(stage)

func _prepare() -> void:
	var data: Dictionary = {}
	for stage: int in range(first_slot, last_slot + 1):
		var direct_path: String = OUT + "/direct_%d.json" % stage
		if FileAccess.file_exists(direct_path):
			var direct_sim: GameSim = GameSim.new()
			if stage == 50:direct_sim.rng.set_seed(7)
			direct_sim.load_level(stage, recording_level(stage), LevelLibrary.boss_kind_for_slot(stage))
			direct_sim.rng.set_seed(7)
			direct_sim.bullet_time_enabled = false
			var direct: ReplayInput = ReplayInput.new()
			direct.sim = direct_sim
			direct.frames = JSON.parse_string(FileAccess.get_file_as_string(direct_path))
			for tick: int in direct.frames.size():
				direct_sim.step(direct.sample(Vector2.ZERO))
				if stage==50: direct_sim.update_camera()
				if direct_sim.player.dead or direct_sim.player.won:
					break
			print("DIRECT slot=%d won=%s dead=%s ticks=%d pos=%s" % [stage,direct_sim.player.won,direct_sim.player.dead,direct.index,Vector2(direct_sim.player.x,direct_sim.player.y)])
			if not direct_sim.player.won or direct_sim.player.dead:
				get_tree().quit(1)
				return
			data[str(stage)] = direct.frames.slice(0, direct.index)
			continue
		var route_path: String = OUT + "/route_%d.json" % stage
		if not FileAccess.file_exists(route_path):
			print("PENDING slot=", stage)
			break
		var sim: Recorder = Recorder.new()
		sim.rng.set_seed(7)
		sim.load_level(stage, recording_level(stage), LevelLibrary.boss_kind_for_slot(stage))
		sim.bullet_time_enabled = false
		var actions: Array = JSON.parse_string(FileAccess.get_file_as_string(route_path))
		var held: bool = false
		for action: String in actions:
			if sim.player.won or sim.player.dead:
				break
			held = _macro(sim, action, held)
		print("PREPARE slot=%d won=%s dead=%s ticks=%d" % [stage, sim.player.won, sim.player.dead, sim.frames.size()])
		if not sim.player.won or sim.player.dead:
			get_tree().quit(1)
			return
		data[str(stage)] = sim.frames
	FileAccess.open(OUT + "/inputs.json", FileAccess.WRITE).store_string(JSON.stringify(data))
	get_tree().quit(0)

func _macro(sim: Recorder, action: String, held: bool) -> bool:
	if action.begins_with("W"):
		for tick: int in action.substr(1).to_int():
			sim.step(SimInput.new())
		return false
	if action.begins_with("E"):
		var cell: PackedStringArray = action.substr(1).split(",")
		var target: Vector2 = Vector2(float(cell[1]) + 0.5, float(cell[0]) + 0.5) * Tile.SIZE
		for tick: int in 25:
			var inp: SimInput = SimInput.new()
			inp.eat = true
			inp.mouse_x = target.x - sim.camera.x
			inp.mouse_y = target.y - sim.camera.y
			sim.step(inp)
		return false
	if action.begins_with("S"):
		var steering: bool = action.ends_with("R") or action.ends_with("L")
		var angle: float = float(roundi(action.substr(1).to_float() / 22.5)) * TAU / 16.0
		var inp: SimInput = SimInput.new()
		inp.left = action.ends_with("L")
		inp.right = action.ends_with("R")
		inp.jump = held and steering
		inp.mouse_x = sim.player.center_x() + cos(angle) * 100.0 - sim.camera.x
		inp.mouse_y = sim.player.center_y() + sin(angle) * 100.0 - sim.camera.y
		inp.shoot_released = true
		sim.step(inp)
		for tick: int in 12:
			if sim.player.won or sim.player.dead:
				break
			var move: SimInput = SimInput.new()
			move.left = inp.left
			move.right = inp.right
			move.jump = inp.jump
			sim.step(move)
		return held and steering
	for tick: int in 6:
		var inp: SimInput = SimInput.new()
		inp.left = action.begins_with("L")
		inp.right = action.begins_with("R")
		inp.jump = action.ends_with("J")
		inp.jump_pressed = inp.jump and not held
		held = inp.jump
		sim.step(inp)
		if sim.player.won or sim.player.dead:
			break
	return held

func _begin() -> void:
	app.play_official(slot)
	game = app.get("_screen") as GameScreen
	if true:
		assert(JSON.stringify(LevelCodec.encode_document(LevelStore.get_level(slot))) == JSON.stringify(LevelCodec.encode_document(recording_level(slot))), "Recording map differs from snapshot")
	# Retain the real win animation, but advance only after recording its result.
	for connection: Dictionary in game.completed.get_connections():
		var callback: Callable = connection.callable
		game.completed.disconnect(callback)
	replay = ReplayInput.new()
	replay.sim = game.get("_sim")
	if slot == 50:
		# Reproduce the original arena's random distribution before its first frame.
		replay.sim.rng.set_seed(7)
		replay.sim.load_level(slot,recording_level(slot),LevelLibrary.boss_kind_for_slot(slot))
	replay.sim.rng.set_seed(7)
	replay.frames = records[str(slot)]
	game.set("_input", replay)
	done_frames = 0
	start_frame = movie_frame
	print("RECORD start slot=", slot)

func _process(_delta: float) -> void:
	if game == null or ending:
		return
	movie_frame += 1
	# A desktop focus change must not inject a pause into offline movie output.
	if get_tree().paused:
		get_tree().paused = false
		(game.get_node("%PauseMenu") as Control).hide()
	var sim: GameSim = replay.sim
	if sim.player.dead or (replay.index >= replay.frames.size() and not sim.player.won):
		push_error("RECORD failed slot=%d input=%d dead=%s" % [slot, replay.index, sim.player.dead])
		get_tree().quit(1)
		return
	if not sim.player.won:
		return
	done_frames += 1
	if done_frames < 120:
		return
	print("RECORD PASS slot=%d won=%s dead=%s ticks=%d" % [slot, sim.player.won, sim.player.dead, replay.index])
	results.append({"slot": slot, "won": sim.player.won, "dead": sim.player.dead,
		"input_ticks": replay.index, "start_frame": start_frame, "end_frame": movie_frame})
	FileAccess.open(OUT + "/results_%d-%d.json" % [first_slot, last_slot], FileAccess.WRITE).store_string(JSON.stringify(results, "  "))
	if slot == last_slot:
		ending = true
		get_tree().quit(0)
	else:
		slot += 1
		_begin()


