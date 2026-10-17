extends "res://tools/capture/scaffold_driver.gd"

class CameraRecorder:
	extends Recorder
	func step(inp: SimInput) -> void:
		super.step(inp)
		update_camera()

var stage: int = 41
var target: Vector2 = Vector2(923, 526)
var visited: Dictionary = {}
var width: int = 40
var depths: int = 160
var prefix: String = ""
var checkpoint: String = ""
var carry_reward: float=20
var require_carry: bool=false
var pickup: bool=false

func fresh() -> Recorder:
	var sim: Recorder = CameraRecorder.new() if stage==50 else Recorder.new()
	sim.rng.set_seed(7)
	sim.load_level(stage, LevelCodec.decode_document(JSON.parse_string(FileAccess.get_file_as_string(OUT+"/maps/slot_%d.json"%stage))),LevelLibrary.boss_kind_for_slot(stage))
	sim.rng.set_seed(7)
	sim.bullet_time_enabled = false
	return sim

func save_win(sim: Recorder) -> bool:
	if not sim.player.won or sim.player.dead: return false
	var check_sim: Recorder = fresh()
	var replay_input: ReplayInput = ReplayInput.new()
	replay_input.sim=check_sim
	replay_input.frames=JSON.parse_string(JSON.stringify(sim.frames))
	for f: int in replay_input.frames.size(): check_sim.step(replay_input.sample(Vector2.ZERO))
	if not check_sim.player.won or check_sim.player.dead:
		print("REPLAY REJECT")
		return false
	FileAccess.open(OUT+"/direct_%d.json"%stage,FileAccess.WRITE).store_string(JSON.stringify(sim.frames))
	print("SOLVED ",stage," frames=",sim.frames.size())
	return true

func key(sim: Recorder) -> String:
	return "%d,%d,%d,%d,%s,%d,%d"%[roundi(sim.player.x/12),roundi(sim.player.y/12),roundi(sim.player.vx/3),roundi(sim.player.vy/4),sim.player.has_block,sim.player.carried_block_type,sim.level.checksum()] + str(sim.projectiles.map(func(p: SimProjectile)->String:return "%d,%d,%d,%d"%[roundi(p.x/20),roundi(p.y/20),roundi(p.vx/3),roundi(p.vy/3)]))

func score(sim: Recorder) -> float:
	return Vector2(sim.player.x,sim.player.y).distance_to(target) + (0 if sim.player.has_block else carry_reward) + sim.frames.size()*0.008

func _ready() -> void:
	OUT="res://build/recordings/world5"
	for a: String in OS.get_cmdline_user_args():
		if a=="--require-carry": require_carry=true
		if a=="--pickup": pickup=true
		if a.begins_with("--stage="): stage=a.trim_prefix("--stage=").to_int()
		if a.begins_with("--target="):
			var xy: PackedStringArray=a.trim_prefix("--target=").split(",")
			target=Vector2(float(xy[0]),float(xy[1]))
		if a.begins_with("--width="): width=a.trim_prefix("--width=").to_int()
		if a.begins_with("--depths="): depths=a.trim_prefix("--depths=").to_int()
		if a.begins_with("--carry="): carry_reward=a.trim_prefix("--carry=").to_float()
		if a.begins_with("--checkpoint="): checkpoint=a.trim_prefix("--checkpoint=")
		if a.begins_with("--prefix="): prefix=a.trim_prefix("--prefix=")
	var base: Recorder=fresh()
	if not prefix.is_empty():
		var r: ReplayInput=ReplayInput.new()
		r.sim=base
		r.frames=JSON.parse_string(FileAccess.get_file_as_string(OUT+"/"+prefix+".json"))
		for i: int in r.frames.size(): base.step(r.sample(Vector2.ZERO))
	var beam: Array[Recorder]=[base]
	var best: Recorder=base
	for depth: int in depths:
		var next: Array[Recorder]=[]
		for source: Recorder in beam:
			var actions: Array[Dictionary]=[]
			for direction: int in [-1,0,1]:
				for jumping: bool in [false,true]: actions.append({"d":direction,"j":jumping,"n":12})
			if source.player.has_block:
				for angle: float in [-135.0,-90.0,-45.0,-0.01,22.5,45.0,67.5,90.0,112.5,135.0,157.5,180.01]:
					for direction: int in [0,1,-1]: actions.append({"d":direction,"j":true,"n":12,"s":angle})
			else:
				var pc: int=floori(source.player.center_x()/40)
				var pr: int=floori(source.player.center_y()/40)
				for r: int in range(pr-2,pr+3):
					for c: int in range(pc-2,pc+3):
						if Tile.is_eatable(source.level.get_cell(r,c)):
							for jumping: bool in [false,true]: actions.append({"d":0,"j":jumping,"n":24,"e":Vector2(c*40+20,r*40+20)})
			for a: Dictionary in actions:
				var sim: Recorder=clone(source)
				var count: int=a.n
				for t: int in count:
					var inp: SimInput=SimInput.new()
					inp.right=a.d>0
					inp.left=a.d<0
					inp.jump=a.j
					inp.jump_pressed=a.j and t==0
					if a.has("e"):
						inp.eat=true
						inp.mouse_x=a.e.x-sim.camera.x
						inp.mouse_y=a.e.y-sim.camera.y
					if a.has("s") and t==0:
						var degrees: float=a.s
						inp.shoot_released=true
						inp.mouse_x=sim.player.center_x()+cos(deg_to_rad(degrees))*200-sim.camera.x
						inp.mouse_y=sim.player.center_y()+sin(deg_to_rad(degrees))*200-sim.camera.y
					sim.step(inp)
					if sim.player.won or sim.player.dead: break
				if sim.player.dead: continue
				if not checkpoint.is_empty() and ((pickup and sim.player.has_block) or (not pickup and sim.player.grounded and (not require_carry or sim.player.has_block) and Vector2(sim.player.x,sim.player.y).distance_to(target)<30)):
					FileAccess.open(OUT+"/"+checkpoint+".json",FileAccess.WRITE).store_string(JSON.stringify(sim.frames))
					print("CHECKPOINT ",checkpoint," pos=",Vector2(sim.player.x,sim.player.y)," carry=",sim.player.has_block)
					get_tree().quit()
					return
				if save_win(sim):
					get_tree().quit()
					return
				var k: String=key(sim)
				if visited.has(k): continue
				visited[k]=true
				next.append(sim)
		if next.is_empty(): break
		next.sort_custom(func(a: Recorder,b: Recorder)->bool:return score(a)<score(b))
		beam.assign(next.slice(0,width))
		if score(beam[0])<score(best): best=beam[0]
		if depth%10==0:
			print("SEARCH ",stage," depth=",depth," pos=",Vector2(best.player.x,best.player.y)," score=",score(best)," visited=",visited.size())
			FileAccess.open(OUT+"/best_%d.json"%stage,FileAccess.WRITE).store_string(JSON.stringify(best.frames))
	print("UNSOLVED ",stage," best=",Vector2(best.player.x,best.player.y))
	get_tree().quit(1)

