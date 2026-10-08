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
	var routes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/world4_mid_solutions.json"))
	var script: GDScript=load("res://tests/unit/test_world5_levels.gd") as GDScript
	var controller: RefCounted=script.new()
	var failed: bool=false
	for slot: int in [24,25,26,27]:
		var sim: Recorder=Recorder.new()
		sim.load_level(slot,LevelLibrary.built_in_level(slot),BossState.Kind.NONE)
		sim.bullet_time_enabled=false
		for i: int in 15:
			sim.step(SimInput.new())
		for action: Dictionary in routes[str(slot)]:
			controller.call(&"_execute",sim,action)
			print(slot," ",action," pos=",Vector2(sim.player.x,sim.player.y)," carry=",sim.player.has_block," dead=",sim.player.dead," won=",sim.player.won)
			if action.op == "shoot":
				for r: int in sim.level.rows:
					for c: int in sim.level.cols:
						if sim.level.get_cell(r,c) in [Tile.DIRT_EATEN_1,Tile.DIRT_EATEN_2]:
							print("placed ",r,",",c," type=",sim.level.get_cell(r,c))
			if slot == 27 and action.op == "shoot":
				print("gates ",sim.level.get_cell(10,16),",",sim.level.get_cell(12,16))
			if sim.player.dead or sim.player.won:
				break
		var output: FileAccess=FileAccess.open("res://tests/fixtures/level%d_attempt.json"%slot,FileAccess.WRITE)
		output.store_string(JSON.stringify(sim.frames))
		failed=failed or not sim.player.won
	quit(1 if failed else 0)
