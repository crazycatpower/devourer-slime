extends "res://tools/capture/record_world1_driver.gd"
var copier: DeathRewind = DeathRewind.new()

func clone(source: Recorder) -> Recorder:
	var result: Recorder = Recorder.new()
	for property: Dictionary in source.get_property_list():
		var usage: int = property.usage
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var name: String = property.name
			result.set(name, source.frames.duplicate() if name == "frames" else copier._copy(source.get(name)))
	return result

func move(sim: Recorder, target: float, ticks: int, jump: bool = false, first_jump: bool = false) -> void:
	for tick: int in ticks:
		var inp: SimInput = SimInput.new()
		inp.right = sim.player.x < target - 3.0
		inp.left = sim.player.x > target + 3.0
		inp.jump = jump
		inp.jump_pressed = first_jump and tick == 0
		sim.step(inp)

func _ready() -> void:
	var sim: Recorder = Recorder.new()
	sim.rng.set_seed(7)
	sim.load_level(11, LevelLibrary.shipped_level(11), BossState.Kind.NONE)
	sim.bullet_time_enabled = false
	var actions: Array = JSON.parse_string(FileAccess.get_file_as_string("res://build/recordings/world2/partial_11.json"))
	var held: bool = false
	for action: String in actions:
		held = _macro(sim, action, held)
	move(sim, 800.0, 70, true, true)
	move(sim, 800.0, 80)
	print("BASE ",Vector2(sim.player.x,sim.player.y)," carry=",sim.player.has_block)
	for tier: int in 2:
		var found: Recorder
		for x: float in [790.0, 810.0, 770.0, 830.0]:
			for delay: int in range(12, 39, 2):
				for degrees: float in [22.5, 45.0, 67.5, 0.0, -22.5]:
					var trial: Recorder = clone(sim)
					if tier == 0:
						move(trial, x, 60)
					else:
						var row: int = floori((trial.player.y + trial.player.h + 2.0) / Tile.SIZE)
						var col: int = floori(trial.player.center_x() / Tile.SIZE)
						_macro(trial, "E%d,%d" % [row, col], false)
					var launch_x: float = trial.player.x
					move(trial, launch_x, delay, true, true)
					var inp: SimInput = SimInput.new()
					inp.right = true
					inp.jump = true
					inp.shoot_released = true
					var angle: float = deg_to_rad(degrees)
					inp.mouse_x = trial.player.center_x() + cos(angle)*100.0 - trial.camera.x
					inp.mouse_y = trial.player.center_y() + sin(angle)*100.0 - trial.camera.y
					trial.step(inp)
					move(trial, 843.0, 90, true)
					if trial.player.grounded and trial.player.y < sim.player.y - 105.0 and not trial.player.dead:
						if found == null or trial.player.y < found.player.y:
							found = trial
							print("TIER ",tier," x=",x," delay=",delay," angle=",degrees," pos=",Vector2(trial.player.x,trial.player.y))
		if found == null:
			print("NO TIER ",tier)
			get_tree().quit(1)
			return
		sim = found
	move(sim, 928.0, 90, true, true)
	move(sim, 928.0, 120)
	print("SCAFFOLD won=",sim.player.won," pos=",Vector2(sim.player.x,sim.player.y))
	if sim.player.won:
		FileAccess.open("res://build/recordings/world2/direct_11.json", FileAccess.WRITE).store_string(JSON.stringify(sim.frames))
	get_tree().quit(0 if sim.player.won else 1)
