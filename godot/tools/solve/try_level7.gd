extends SceneTree

class Recorder:
	extends GameSim
	var frames: Array[Dictionary] = []
	func step(p_input: SimInput) -> void:
		frames.append({"left":p_input.left,"right":p_input.right,"jump":p_input.jump,"eat":p_input.eat,"shoot":p_input.shoot,"jp":p_input.jump_pressed,"mx":p_input.mouse_x+camera.x,"my":p_input.mouse_y+camera.y})
		super.step(p_input)
		if frames.size() % 120 == 0:
			print("expected frame=",frames.size()," x=",player.x," y=",player.y)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var sim: Recorder = Recorder.new()
	sim.load_level(7, LevelLibrary.built_in_level(7), BossState.Kind.NONE)
	sim.bullet_time_enabled = false
	var script: GDScript = load("res://tests/unit/test_world4_levels.gd") as GDScript
	var controller: RefCounted = script.new()
	for _i: int in 15:
		sim.step(SimInput.new())
	var route: Array[Dictionary] = [
		{"op":"walk","x":483.0},
		{"op":"jump","x":683.0},
		{"op":"eat","r":11,"c":18},
		{"op":"jump","x":483.0},
		{"op":"walk","x":363.0},
		{"op":"shoot","r":1,"c":9},
		{"op":"walk","x":550.0},
		{"op":"jump","x":691.0},
		{"op":"eat","r":11,"c":19},
		{"op":"jump","x":483.0},
		{"op":"walk","x":523.0},
		{"op":"shoot","r":0,"c":15},
		{"op":"walk","x":550.0},
		{"op":"jump","x":731.0},
		{"op":"walk","x":767.0},
		{"op":"eat","r":11,"c":20},
		{"op":"walk","x":731.0},
		{"op":"run_jump","x":483.0},
		{"op":"walk","x":523.0},
		{"op":"shoot","r":0,"c":14},
		{"op":"walk","x":550.0},
		{"op":"jump","x":731.0},
		{"op":"eat_move","r":11,"c":19},
		{"op":"jump","x":483.0},
		{"op":"walk","x":123.0},
		{"op":"recoil_jump","x":43.0},
		{"op":"walk","x":83.0},
		{"op":"jump","x":203.0},
		{"op":"walk","x":303.0},
		{"op":"eat","r":1,"c":9},
		{"op":"shoot","r":2,"c":10},
		{"op":"walk","x":316.0},
		{"op":"jump","x":363.0},
		{"op":"walk","x":523.0},
		{"op":"eat","r":1,"c":14},
		{"op":"shoot","r":2,"c":17},
		{"op":"walk","x":550.0},
		{"op":"eat","r":1,"c":15},
		{"op":"shoot","r":2,"c":16},
		{"op":"walk","x":556.0},
		{"op":"jump","x":603.0},
		{"op":"walk","x":923.0},
	]
	for action: Dictionary in route:
		if action.op == "run_jump":
			for _i: int in 6:
				var run: SimInput = SimInput.new()
				run.left = true
				sim.step(run)
			controller.call(&"_execute",sim,{"op":"jump","x":483.0})
		elif action.op == "eat_move":
			var col: float = action.c
			var row: float = action.r
			for i: int in 24:
				var inp: SimInput = SimInput.new()
				inp.mouse_x = (col+0.5)*40.0-sim.camera.x
				inp.mouse_y = (row+0.5)*40.0-sim.camera.y
				inp.eat = true
				inp.left = i>=19
				sim.step(inp)
		else:
			controller.call(&"_execute",sim,action)
		print(action," x=",sim.player.x," y=",sim.player.y," carry=",sim.player.has_block," dead=",sim.player.dead," won=",sim.player.won)
		if sim.player.dead or sim.player.won:
			break
	var output: FileAccess = FileAccess.open("res://tests/fixtures/level7_attempt.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(sim.frames))
	quit(0 if sim.player.won else 1)
