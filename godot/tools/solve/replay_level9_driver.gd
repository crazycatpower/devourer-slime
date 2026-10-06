extends Node
## Real game input pipeline: no direct simulation steps, teleports or edits.
var held: Dictionary = {"left":false,"right":false,"jump":false,"eat":false,"shoot":false}

class AimedInput:
	extends PlayerInput
	var sim: GameSim
	var target: Vector2
	func sample(mouse: Vector2) -> SimInput:
		var inp: SimInput = super.sample(mouse)
		# Keep replay aim stable independently of the user's desktop pointer.
		inp.mouse_x = target.x-sim.camera.x
		inp.mouse_y = target.y-sim.camera.y
		return inp

func _ready() -> void:
	SavePaths.wipe_sandbox()
	Settings.bullet_time_enabled = false
	Settings.game_speed = 1.0
	var scene: PackedScene = load("res://src/app/app.tscn")
	var app: App = scene.instantiate()
	get_tree().root.add_child.call_deferred(app)
	await get_tree().process_frame
	await get_tree().process_frame
	app.play_official(9)
	await get_tree().process_frame
	var game: GameScreen = app.get("_screen") as GameScreen
	if game == null:
		push_error("No game screen")
		get_tree().quit(1)
		return
	var sim: GameSim = game.get("_sim")
	var aimed: AimedInput = AimedInput.new()
	aimed.sim = sim
	game.set("_input",aimed)
	var view: WorldView = game.get_node("%WorldView")
	var frames: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/level9_attempt.json"))
	var out: String = "res://tests/output/level9_attempt"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var index: int = 0
	for frame: Dictionary in frames:
		var mx: float = frame.mx
		var my: float = frame.my
		aimed.target = Vector2(mx,my)
		var pos: Vector2 = (Vector2(mx,my)-Vector2(sim.camera.x,sim.camera.y))*view.world_scale
		pos = get_tree().root.get_final_transform()*(view.get_global_transform_with_canvas()*pos)
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.position = pos
		motion.global_position = pos
		Input.parse_input_event(motion)
		for name: String in ["left","right","jump"]:
			var key: Key = KEY_A if name == "left" else KEY_D if name == "right" else KEY_W
			var pressed: bool = frame[name]
			var jump_pressed: bool = frame.jp
			var was_held: bool = held[name]
			if name == "jump" and jump_pressed and was_held:
				_key(key,false)
				held[name] = false
			if pressed != held[name]:
				_key(key,pressed)
				held[name] = pressed
		for name: String in ["eat","shoot"]:
			var pressed: bool = frame[name]
			if pressed != held[name]:
				var event: InputEventMouseButton = InputEventMouseButton.new()
				event.button_index = MOUSE_BUTTON_LEFT if name == "eat" else MOUSE_BUTTON_RIGHT
				event.position = pos
				event.global_position = pos
				event.pressed = pressed
				Input.parse_input_event(event)
				held[name] = pressed
		Input.flush_buffered_events()
		await get_tree().physics_frame
		index += 1
		if sim.player.won or sim.player.dead:
			break
		if index % 120 == 0:
			print("real input frame=",index," x=",sim.player.x," y=",sim.player.y," dead=",sim.player.dead," won=",sim.player.won)
	_key(KEY_A,false)
	_key(KEY_D,false)
	_key(KEY_W,false)
	print("ACTUAL RESULT won=",sim.player.won," dead=",sim.player.dead," x=",sim.player.x," y=",sim.player.y)
	game.set_physics_process(false)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out+"/result.png")
	get_tree().quit(0 if sim.player.won else 1)

func _key(key: Key,pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
