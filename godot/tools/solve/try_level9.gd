extends SceneTree

class Recorder:
	extends GameSim
	var frames: Array[Dictionary] = []
	func step(p_input: SimInput) -> void:
		frames.append({"left":p_input.left,"right":p_input.right,"jump":p_input.jump,"eat":p_input.eat,"shoot":p_input.shoot,"jp":p_input.jump_pressed,"mx":p_input.mouse_x+camera.x,"my":p_input.mouse_y+camera.y})
		super.step(p_input)
		if frames.size() % 120 == 0:
			print("expected frame=",frames.size()," x=",player.x," y=",player.y)

var controller: RefCounted
func _initialize() -> void:
	_run.call_deferred()
func act(sim: GameSim, action: Dictionary) -> void:
	controller.call(&"_execute",sim,action)
	print(action," pos=",Vector2(sim.player.x,sim.player.y)," carry=",sim.player.has_block," dead=",sim.player.dead)
func shot(sim: GameSim, target: Vector2, recover: bool=false) -> void:
	var inp: SimInput = SimInput.new()
	inp.mouse_x=target.x-sim.camera.x
	inp.mouse_y=target.y-sim.camera.y
	inp.shoot=true
	sim.step(inp)
	inp.shoot=false
	inp.shoot_released=true
	sim.step(inp)
	for i: int in 90:
		var move: SimInput=SimInput.new()
		move.right=recover and sim.player.x<643
		sim.step(move)
func _run() -> void:
	var sim: Recorder = Recorder.new()
	sim.load_level(9,LevelLibrary.built_in_level(9),BossState.Kind.NONE)
	sim.bullet_time_enabled=false
	var script: GDScript=load("res://tests/unit/test_world5_levels.gd") as GDScript
	controller=script.new()
	for i: int in 80:
		sim.step(SimInput.new())
	for n: int in 5:
		act(sim,{"op":"walk","x":123.0+n*40.0})
		act(sim,{"op":"eat","r":11,"c":3+n})
		var r: int=1+n
		var c: int=17-n
		act(sim,{"op":"walk","x":c*40.0+3.0})
		if n==0:
			shot(sim,Vector2(c*40.0+20,0))
		else:
			var found: bool=false
			for offset: int in range(-100,101):
				var target: Vector2=Vector2((c+1)*40.0+offset*0.1,r*40.0-2.0)
				var trial: GameSim=_clone_sim(sim)
				shot(trial,target)
				if trial.level.get_cell(r,c)==Tile.DIRT_EATEN_1:
					print("SHOT FOUND ",r,",",c," target=",target)
					shot(sim,target)
					found=true
					break
			if not found:
				print("NO SHOT ",r,",",c)
				quit(1)
				return
	act(sim,{"op":"walk","x":383.0})
	var launch: SimInput=SimInput.new()
	launch.jump=true
	launch.jump_pressed=true
	sim.step(launch)
	launch.jump_pressed=false
	for i: int in 20:
		sim.step(launch)
	act(sim,{"op":"walk","x":323.0})
	act(sim,{"op":"eat","r":11,"c":8})
	var rise: SimInput=SimInput.new()
	rise.jump=true
	rise.jump_pressed=true
	rise.right=true
	sim.step(rise)
	rise.jump_pressed=false
	for i: int in 27:
		sim.step(rise)
	var down: SimInput=SimInput.new()
	down.mouse_x=sim.player.center_x()-sim.camera.x
	down.mouse_y=sim.player.center_y()+200-sim.camera.y
	down.shoot=true
	down.right=true
	sim.step(down)
	down.shoot=false
	down.shoot_released=true
	sim.step(down)
	act(sim,{"op":"walk","x":523.0})
	for n: int in 3:
		act(sim,{"op":"jump","x":563.0+n*40.0})
	act(sim,{"op":"eat","r":1,"c":17})
	var found: bool=false
	for k: int in range(600,1250):
		var target: Vector2=Vector2(840.0,k*0.1)
		var trial: GameSim=_clone_sim(sim)
		shot(trial,target)
		if trial.level.get_cell(2,20)==Tile.DIRT_EATEN_2:
			print("BRIDGE SHOT ",target)
			shot(sim,target)
			found=true
			break
	if not found:
		print("NO BRIDGE SHOT")
		quit(1)
		return
	act(sim,{"op":"walk","x":563.0})
	act(sim,{"op":"walk","x":540.0})
	act(sim,{"op":"eat","r":5,"c":13})
	act(sim,{"op":"jump","x":563.0})
	act(sim,{"op":"jump","x":603.0})
	act(sim,{"op":"jump","x":643.0})
	act(sim,{"op":"walk","x":670.0})
	shot(sim,Vector2(820,100))
	print("after bridge pos=",Vector2(sim.player.x,sim.player.y)," cells=",sim.level.get_cell(4,14),",",sim.level.get_cell(5,13)," bridge=",sim.level.get_cell(2,19))
	act(sim,{"op":"jump","x":603.0})
	act(sim,{"op":"walk","x":580.0})
	act(sim,{"op":"eat","r":4,"c":14})
	act(sim,{"op":"jump","x":603.0})
	act(sim,{"op":"jump","x":643.0})
	act(sim,{"op":"walk","x":670.0})
	shot(sim,Vector2(780,100),true)
	act(sim,{"op":"jump","x":643.0})
	act(sim,{"op":"walk","x":670.0})
	act(sim,{"op":"jump","x":723.0})
	act(sim,{"op":"walk","x":843.0})
	act(sim,{"op":"walk","x":923.0})
	print("RESULT won=",sim.player.won," pos=",Vector2(sim.player.x,sim.player.y))
	var output: FileAccess=FileAccess.open("res://tests/fixtures/level9_attempt.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(sim.frames))
	quit(0 if sim.player.won else 1)
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
	dst.boss = src.boss
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



