extends "res://tools/capture/world3_routes.gd"

func fresh(stage: int) -> Recorder:
	if stage != 40:return super.fresh(stage)
	var path: String=OUT+"/maps/slot_40.json"
	if not FileAccess.file_exists(path):
		FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(LevelCodec.encode_document(LevelLibrary.shipped_level(stage))))
	var sim: Recorder=Recorder.new()
	sim.rng.set_seed(7)
	sim.load_level(stage,LevelCodec.decode_document(JSON.parse_string(FileAccess.get_file_as_string(path))),LevelLibrary.boss_kind_for_slot(stage))
	sim.rng.set_seed(7)
	sim.bullet_time_enabled=false
	return sim

func _ready() -> void:
	OUT = "res://build/recordings/world4"
	for stage: int in range(31,41):
		var sim: Recorder = fresh(stage)
		print("MAP ",stage," ",sim.level.cols,"x",sim.level.rows)
	if "--31" in OS.get_cmdline_user_args():
		solve31()
	if "--32" in OS.get_cmdline_user_args():
		solve32()
	if "--33" in OS.get_cmdline_user_args():
		solve33()
	if "--33wall" in OS.get_cmdline_user_args():
		wall33()
	if "--33end" in OS.get_cmdline_user_args():
		var sim: Recorder = fresh(33)
		var replay: ReplayInput = ReplayInput.new()
		replay.sim=sim
		replay.frames=JSON.parse_string(FileAccess.get_file_as_string(OUT+"/wall33_3.json"))
		for tick: int in replay.frames.size():sim.step(replay.sample(Vector2.ZERO))
		var base: Recorder = seek4(sim,Vector2(123,566),false)
		if base == null:
			print("33 RETURN FAILED")
			get_tree().quit()
			return
		for tick: int in 25:
			var inp: SimInput = SimInput.new()
			inp.jump=true
			inp.jump_pressed=tick==0
			inp.eat=true
			inp.mouse_x=140-base.camera.x
			inp.mouse_y=620-base.camera.y
			base.step(inp)
		move(base,43,70,true)
		print("33 RECYCLE BASE ",Vector2(base.player.x,base.player.y)," carry=",base.player.has_block)
		for yy: float in [365.999,245.999,165.999]:
			base=wall_hop(base,yy)
			if base==null:
				print("33 RECYCLE HOP FAILED ",yy)
				get_tree().quit()
				return
		for tick: int in 40:
			if base.player.x>=80:break
			move(base,83,1)
		for delay: int in range(0,25):
			for angle: float in [110.0,125.0,140.0,155.0,170.0]:
				var trial: Recorder=clone(base)
				move(trial,283,delay,true,true)
				shot(trial,angle,1)
				move(trial,283,100,true)
				if finish(trial,33):
					print("33 FINAL RECOIL ",delay," ",angle)
					get_tree().quit()
					return
		print("33 FINAL GAP FAILED")
	if "--34" in OS.get_cmdline_user_args():
		solve34()
	if "--35" in OS.get_cmdline_user_args():
		solve35()
	if "--35lower" in OS.get_cmdline_user_args():
		lower35()
	if "--35bridge" in OS.get_cmdline_user_args():
		bridge35()
	if "--35second" in OS.get_cmdline_user_args():
		second35()
	if "--35end" in OS.get_cmdline_user_args():
		end35()
	if "--35last" in OS.get_cmdline_user_args():
		var sim: Recorder=fresh(35)
		var replay: ReplayInput=ReplayInput.new()
		replay.sim=sim
		replay.frames=JSON.parse_string(FileAccess.get_file_as_string(OUT+"/opened35.json"))
		for tick: int in replay.frames.size():sim.step(replay.sample(Vector2.ZERO))
		finish35(sim)
	if "--37" in OS.get_cmdline_user_args():
		solve37()
	if "--37right" in OS.get_cmdline_user_args():
		right37()
	if "--37end" in OS.get_cmdline_user_args():
		end37()
	if "--37steps" in OS.get_cmdline_user_args():
		steps37()
	if "--37jump" in OS.get_cmdline_user_args():
		var base: Recorder=fresh(37)
		var replay: ReplayInput=ReplayInput.new()
		replay.sim=base
		replay.frames=JSON.parse_string(FileAccess.get_file_as_string(OUT+"/top37.json"))
		for tick: int in replay.frames.size():base.step(replay.sample(Vector2.ZERO))
		for approach: int in range(20,46):
			var trial: Recorder=clone(base)
			move(trial,803,approach)
			move(trial,843,100,true,true)
			if trial.player.x<880 and trial.player.y<260 and trial.player.grounded:
				print("37 EDGE JUMP PASS ",approach," ",Vector2(trial.player.x,trial.player.y))
				FileAccess.open(OUT+"/return37.json",FileAccess.WRITE).store_string(JSON.stringify(trial.frames))
				get_tree().quit()
				return
		print("37 EDGE JUMP FAILED")
	if "--38" in OS.get_cmdline_user_args():
		solve38()
	if "--39" in OS.get_cmdline_user_args():
		solve39()
	if "--39end" in OS.get_cmdline_user_args():
		end39()
	if "--40" in OS.get_cmdline_user_args():
		solve40()
	if "--36" in OS.get_cmdline_user_args():
		solve36()
	if "--36bottom" in OS.get_cmdline_user_args():
		bottom36()
	if "--36higher" in OS.get_cmdline_user_args():
		higher36()
	if "--36return" in OS.get_cmdline_user_args():
		return36()
	if "--36end" in OS.get_cmdline_user_args():
		end36()
	get_tree().quit()

func solve31() -> void:
	var base: Recorder = fresh(31)
	move(base,483,170)
	_macro(base,"E13,13",false)
	print("PICKUP ",Vector2(base.player.x,base.player.y)," ",base.player.has_block)
	move(base,323,70)
	for delay: int in range(5,45):
		for angle: float in [110.0,130.0,150.0,170.0,180.0]:
			var sim: Recorder = clone(base)
			move(sim,283,delay,true,true)
			shot(sim,angle,-1)
			move(sim,283,100,true)
			if sim.player.dead or not sim.player.grounded or sim.player.y > 400:
				continue
			for row: int in range(9,14):
				if Tile.is_eatable(sim.level.get_cell(row,8)):
					_macro(sim,"E%d,8"%row,false)
			if not sim.player.has_block:
				continue
			shot(sim,-90,0)
			move(sim,283,40)
			move(sim,283,100,true,true)
			if finish(sim,31):
				print("RECYCLE TOWER ",delay," ",angle)
				return
	print("31 PENDING")

func solve32() -> void:
	var base: Recorder = fresh(32)
	_macro(base,"E12,1",false)
	move(base,243,100,true,true)
	print("32 BASE ",Vector2(base.player.x,base.player.y)," carry=",base.player.has_block)
	var opened: Recorder
	for degrees: int in range(-20,16):
		var trial: Recorder = clone(base)
		shot(trial,float(degrees),0)
		move(trial,243,120)
		if trial.level.get_cell(13,22) == Tile.AIR and not trial.player.dead:
			opened = trial
			print("GATE OPEN ",degrees)
			break
	if opened == null:
		print("NO GATE")
		return
	move(opened,123,60)
	_macro(opened,"E13,2",false)
	move(opened,343,90)
	print("CROSS BASE ",Vector2(opened.player.x,opened.player.y)," carry=",opened.player.has_block)
	for delay: int in range(0,40):
		for degrees: float in [120.0,135.0,150.0,165.0,175.0]:
			var sim: Recorder = clone(opened)
			move(sim,923,delay,true,true)
			shot(sim,degrees,1)
			move(sim,923,220,true)
			if finish(sim,32):
				print("RECOIL GAP ",delay," ",degrees)
				return
	print("32 PENDING")

func seek4(source: Recorder, target: Vector2, harvest: bool) -> Recorder:
	var protected: Array[Vector2i] = []
	if harvest:
		for rr: int in source.level.rows:
			for cc: int in source.level.cols:
				var tile: int = source.level.get_cell(rr,cc)
				if Tile.is_eatable(tile) and (tile != Tile.DIRT or (source.level.cols == 10 and source.level.rows == 20 and rr == 15 and cc == 3) or (rr == floori((source.player.y+35)/40) and cc == floori(source.player.center_x()/40))):
					protected.append(Vector2i(cc,rr))
	var beam: Array[Recorder] = [source]
	for depth: int in 90:
		var candidates: Array[Recorder] = []
		var seen: Dictionary = {}
		for state: Recorder in beam:
			var actions: Array[Vector3] = []
			for direction: int in [-1,0,1]:
				for jump: int in [0,1]:
					actions.append(Vector3(direction,jump,0))
			if harvest and not state.player.has_block:
				var center: Vector2 = Vector2(state.player.center_x(),state.player.center_y())
				for row: int in state.level.rows:
					for col: int in range(1,state.level.cols-1):
						if state.level.get_cell(row,col) != Tile.DIRT or (row == floori((source.player.y+35)/40) and col == floori(source.player.center_x()/40)):
							continue
						var point: Vector2 = Vector2(clampf(center.x,col*40+1,col*40+39),clampf(center.y,row*40+1,row*40+39))
						if center.distance_to(point) < 64:
							actions.append(Vector3(point.x,point.y,1))
			if harvest and state.player.has_block and Tile.is_bouncy(state.player.carried_block_type):
				actions.append(Vector3(0,0,2))
			for action: Vector3 in actions:
				var sim: Recorder = clone(state)
				if action.z == 2:
					sim.step(SimInput.new())
					shot(sim,-90,0)
				elif action.z == 1:
					for tick: int in 25:
						var inp: SimInput = SimInput.new()
						inp.eat = true
						inp.mouse_x = action.x-sim.camera.x
						inp.mouse_y = action.y-sim.camera.y
						sim.step(inp)
				else:
					for tick: int in 6:
						var inp: SimInput = SimInput.new()
						inp.left = action.x < 0
						inp.right = action.x > 0
						inp.jump = action.y > 0
						inp.jump_pressed = inp.jump and tick == 0
						sim.step(inp)
				if sim.player.dead or sim.player.x > maxf(target.x+160,source.player.x+40) or sim.player.x < 0:
					continue
				if sim.player.won:return sim
				var damaged: bool = false
				for cell: Vector2i in protected:
					if sim.level.get_cell(cell.y,cell.x) != source.level.get_cell(cell.y,cell.x):
						damaged = true
				if damaged:continue
				var position: Vector2 = Vector2(sim.player.x,sim.player.y)
				if harvest and sim.player.has_block and not Tile.is_bouncy(sim.player.carried_block_type):
					return sim
				if not harvest and position.distance_to(target) < 5 and sim.player.grounded:
					return sim
				var key: String = "%d,%d,%d,%d,%d" % [roundi(position.x/8),roundi(position.y/8),roundi(sim.player.vy/3),sim.player.carried_block_type,hash(sim.level._cells)]
				if not seen.has(key):
					seen[key] = true
					candidates.append(sim)
		candidates.sort_custom(func(a: Recorder,b: Recorder) -> bool: return Vector2(a.player.x,a.player.y).distance_to(target) < Vector2(b.player.x,b.player.y).distance_to(target))
		beam.assign(candidates.slice(0,60))
		if beam.is_empty():
			break
	return null

func solve33() -> void:
	var base: Recorder = fresh(33)
	move(base,83,25,true,true)
	move(base,123,90,true)
	for tick: int in 30:
		if base.player.x<=86:break
		move(base,83,1)
	move(base,83,20,true,true)
	move(base,123,80,true)
	print("33 TOP ",Vector2(base.player.x,base.player.y))
	for tier: int in range(5):
		var endpoint: Vector2 = Vector2(base.player.x,base.player.y)
		var loaded: Recorder = seek4(base,Vector2(203,646),true)
		if loaded == null:
			print("33 NO AMMO ",tier)
			return
		var staging: Recorder = seek4(loaded,Vector2(123,566),false)
		var staged: Recorder = seek4(staging,endpoint,false) if staging != null else null
		if staged == null:
			print("33 NO RETURN ",tier," ",Vector2(loaded.player.x,loaded.player.y))
			return
		var direction: int = 1 if tier<3 else -1
		var target: float = endpoint.x+40*direction
		var found: Recorder
		for delay: int in range(5,30):
			for angle: float in ([97.0,105.0,115.0,125.0,135.0,150.0,165.0] if direction>0 else [83.0,75.0,65.0,55.0,45.0,30.0,15.0]):
				var sim: Recorder = clone(staged)
				move(sim,endpoint.x+80*direction,delay,true,true)
				shot(sim,angle,direction)
				move(sim,target,100,true)
				if not sim.player.dead and sim.player.grounded and absf(sim.player.x-target)<5 and sim.player.y<endpoint.y-30:
					found = sim
					break
			if found != null:break
		if found == null:
			print("33 NO STAIR ",tier)
			return
		base = found
		print("33 STAIR ",tier," ",Vector2(base.player.x,base.player.y))
		FileAccess.open(OUT+"/partial33_%d.json"%tier,FileAccess.WRITE).store_string(JSON.stringify(base.frames))
	print("33 READY ",Vector2(base.player.x,base.player.y))

func wall33() -> void:
	var base: Recorder = fresh(33)
	move(base,83,25,true,true)
	move(base,123,90,true)
	for tick: int in 30:
		if base.player.x<=86:break
		move(base,83,1)
	move(base,83,20,true,true)
	move(base,123,80,true)
	var loaded: Recorder = seek4(base,Vector2(203,646),true)
	if loaded == null:
		print("WALL NO AMMO")
		return
	var staged: Recorder = seek4(loaded,Vector2(123,566),false)
	if staged == null:
		print("WALL NO RETURN")
		return
	print("WALL BASE ",Vector2(staged.player.x,staged.player.y))
	var best: Recorder
	for row: int in [12]:
		for delay: int in range(5,36):
			for angle: float in [110.0,130.0,150.0,160.0,170.0,175.0,180.01,-170.0,-150.0,-130.0,-110.0]:
				var trial: Recorder = clone(staged)
				move(trial,123,delay,true,true)
				shot(trial,angle,-1)
				move(trial,43,100,true)
				if trial.player.grounded and trial.player.x<55 and trial.player.y<530 and (best == null or trial.player.y < best.player.y-1):
					print("WALL LANDED ",Vector2(trial.player.x,trial.player.y)," delay=",delay," angle=",angle," row=",row)
					best = trial
		print("WALL SEARCH DONE ",row)
	if best != null:
		FileAccess.open(OUT+"/wall33.json",FileAccess.WRITE).store_string(JSON.stringify(best.frames))
		var holes: Array[float] = [best.player.y]
		for tier: int in range(1,5):
			loaded = seek4(best,Vector2(203,646),true)
			if loaded == null:
				print("WALL AMMO FAIL ",tier)
				return
			staged = seek4(loaded,Vector2(123,566),false)
			if staged == null:
				print("WALL BASE RETURN FAIL ",tier)
				return
			for yy: float in holes:
				staged = wall_hop(staged,yy)
				if staged == null:
					print("WALL HOP FAIL ",tier," y=",yy)
					return
			var origin_y: float = staged.player.y
			for tick: int in 40:
				if staged.player.x>=80:break
				move(staged,83,1)
			var next: Recorder
			for delay: int in range(5,36):
				for angle: float in [110.0,130.0,150.0,160.0,170.0,175.0,180.01]:
					var trial: Recorder = clone(staged)
					move(trial,83,delay,true,true)
					shot(trial,angle,-1)
					move(trial,43,100,true)
					if trial.player.grounded and trial.player.x<55 and trial.player.y<origin_y-60 and (next==null or trial.player.y<next.player.y-1):
						next=trial
			if next==null:
				print("WALL NEXT FAIL ",tier," ",Vector2(staged.player.x,staged.player.y))
				return
			best=next
			holes.append(best.player.y)
			print("WALL NEXT ",tier," ",Vector2(best.player.x,best.player.y))
			FileAccess.open(OUT+"/wall33_%d.json"%tier,FileAccess.WRITE).store_string(JSON.stringify(best.frames))
		var goal: Recorder = seek4(best,Vector2(283,86),false)
		if goal != null:finish(goal,33)

func wall_hop(source: Recorder, target_y: float) -> Recorder:
	var base: Recorder = clone(source)
	if base.player.x < 80:
		for tick: int in 40:
			if base.player.x>=80:break
			move(base,83,1)
	for delay: int in range(5,36):
		var trial: Recorder = clone(base)
		move(trial,maxf(83,base.player.x),delay,true,true)
		move(trial,43,90,true)
		if trial.player.grounded and trial.player.x<55 and absf(trial.player.y-target_y)<2:
			return trial
	return null

func solve34() -> void:
	var sim: Recorder = fresh(34)
	for target: Vector2 in [Vector2(283,206),Vector2(203,86)]:
		var nav: Recorder = seek4(sim,target,false)
		if nav == null:
			print("34 NO NAV ",target)
			return
		sim = nav
		print("34 NAV ",Vector2(sim.player.x,sim.player.y))
	_macro(sim,"E4,5",false)
	print("34 AMMO ",sim.player.has_block)
	shot(sim,-90,0)
	move(sim,203,30)
	var nav: Recorder = seek4(sim,Vector2(443,86),false)
	if nav == null:
		print("34 NO RIGHT")
		return
	sim = nav
	_macro(sim,"E4,11",false)
	print("34 SECOND ",sim.player.has_block)
	move(sim,483,35)
	var opened: Recorder
	for angle_index: int in range(-250,-79):
		var trial: Recorder = clone(sim)
		shot(trial,float(angle_index)/10.0,0)
		move(trial,483,100)
		if trial.level.get_cell(0,23) == Tile.AIR:
			opened = trial
			print("34 EXIT OPEN ",angle_index)
			break
	if opened == null:
		print("34 NO EXIT SHOT")
		return
	sim = opened
	nav = seek4(sim,Vector2(203,86),false)
	if nav == null:
		print("34 NO RETURN")
		return
	sim = nav
	move(sim,203,25,true,true)
	move(sim,923,260,true)
	print("34 ROOF ",Vector2(sim.player.x,sim.player.y))
	shot(sim,90,0)
	move(sim,923,160)
	print("34 END ",Vector2(sim.player.x,sim.player.y)," carry=",sim.player.has_block," roof=",sim.level.get_cell(0,23)," dead=",sim.player.dead)
	FileAccess.open(OUT+"/partial34.json",FileAccess.WRITE).store_string(JSON.stringify(sim.frames))
	finish(sim,34)

func solve38() -> void:
	var sim: Recorder = fresh(38)
	move(sim,83,30)
	_macro(sim,"E32,3",false)
	move(sim,163,40)
	move(sim,203,75,true,true)
	print("38 START ",Vector2(sim.player.x,sim.player.y)," carry=",sim.player.has_block)
	shot(sim,-90,0)
	move(sim,203,35)
	move(sim,203,25,true,true)
	move(sim,243,60,true)
	print("38 LAYER1 ",Vector2(sim.player.x,sim.player.y)," dead=",sim.player.dead)
	move(sim,283,20)
	move(sim,403,70,true,true)
	_macro(sim,"E28,11",false)
	move(sim,483,40)
	move(sim,523,75,true,true)
	print("38 AMMO2 ",Vector2(sim.player.x,sim.player.y)," carry=",sim.player.has_block)
	shot(sim,-90,0)
	move(sim,523,35)
	move(sim,523,25,true,true)
	move(sim,483,60,true)
	move(sim,363,40)
	move(sim,243,90,true,true)
	print("38 LAYER2 ",Vector2(sim.player.x,sim.player.y)," dead=",sim.player.dead)
	_macro(sim,"E24,5",false)
	move(sim,163,40)
	move(sim,123,75,true,true)
	print("38 AMMO3 ",Vector2(sim.player.x,sim.player.y)," carry=",sim.player.has_block)
	shot(sim,-90,0)
	move(sim,123,35)
	move(sim,123,25,true,true)
	move(sim,243,60,true)
	move(sim,283,20)
	move(sim,403,70,true,true)
	move(sim,603,90)
	print("38 END ",Vector2(sim.player.x,sim.player.y)," dead=",sim.player.dead)
	finish(sim,38)

func solve35() -> void:
	var sim: Recorder = fresh(35)
	_macro(sim,"E11,3",false)
	move(sim,283,90)
	move(sim,283,14,true,true)
	shot(sim,0,1)
	move(sim,283,70)
	print("35 GATE ",sim.level.get_cell(8,8)," ",Vector2(sim.player.x,sim.player.y))
	var nav: Recorder = seek4(sim,Vector2(443,366),false)
	if nav==null:
		print("35 UPPER ENTRY FAILED")
		return
	sim=nav
	print("35 UPPER ENTERED")
	for target: Vector2 in [Vector2(523,366),Vector2(603,286),Vector2(683,326),Vector2(843,326),Vector2(923,246)]:
		nav=seek4(sim,target,false)
		if nav==null:
			print("35 NAV FAILED ",target)
			return
		sim=nav
		print("35 NAV ",Vector2(sim.player.x,sim.player.y))
	var loaded: Recorder = seek4(sim,Vector2(903,166),true)
	if loaded==null:
		print("35 CAGE PICKUP FAILED")
		return
	print("35 CAGE AMMO ",Vector2(loaded.player.x,loaded.player.y))
	FileAccess.open(OUT+"/partial35.json",FileAccess.WRITE).store_string(JSON.stringify(loaded.frames))

func lower35() -> void:
	var sim: Recorder = fresh(35)
	var replay: ReplayInput = ReplayInput.new()
	replay.sim=sim
	replay.frames=JSON.parse_string(FileAccess.get_file_as_string(OUT+"/partial35.json"))
	for tick: int in replay.frames.size():sim.step(replay.sample(Vector2.ZERO))
	for target: Vector2 in [Vector2(843,326),Vector2(683,326),Vector2(603,286),Vector2(523,366),Vector2(363,366),Vector2(283,446)]:
		sim=seek4(sim,target,false)
		if sim==null:
			print("35 RETURN FAIL ",target)
			return
	shot(sim,0,0)
	move(sim,283,50)
	print("35 LOWER GATE ",sim.level.get_cell(11,8))
	for target: Vector2 in [Vector2(443,366),Vector2(523,366),Vector2(603,286),Vector2(683,326),Vector2(843,326),Vector2(923,246)]:
		sim=seek4(sim,target,false)
		if sim==null:
			print("35 SECOND NAV FAIL ",target)
			return
	sim=seek4(sim,Vector2(903,126),true)
	if sim==null:
		print("35 SECOND AMMO FAIL")
		return
	for target: Vector2 in [Vector2(843,326),Vector2(683,326),Vector2(603,286),Vector2(523,366),Vector2(363,366),Vector2(283,446)]:
		sim=seek4(sim,target,false)
		if sim==null:
			print("35 SECOND RETURN FAIL ",target)
			return
	FileAccess.open(OUT+"/lower35.json",FileAccess.WRITE).store_string(JSON.stringify(sim.frames))
	print("35 LOWER READY ",Vector2(sim.player.x,sim.player.y))
	sim=seek4(sim,Vector2(483,446),false)
	if sim==null:
		print("35 FIRST GAP FAIL")
		return
	print("35 FIRST GAP PASS")
	FileAccess.open(OUT+"/gap35.json",FileAccess.WRITE).store_string(JSON.stringify(sim.frames))

func bridge35() -> void:
	var base: Recorder=fresh(35)
	var replay: ReplayInput=ReplayInput.new()
	replay.sim=base
	replay.frames=JSON.parse_string(FileAccess.get_file_as_string(OUT+"/lower35.json"))
	for tick: int in replay.frames.size():base.step(replay.sample(Vector2.ZERO))
	move(base,323,40)
	for angle: int in range(1,40):
		var trial: Recorder=clone(base)
		shot(trial,float(angle),0)
		move(trial,323,50)
		if not Tile.is_eatable(trial.level.get_cell(12,10)) and not Tile.is_eatable(trial.level.get_cell(12,9)):continue
		for delay: int in range(0,20):
			var cross: Recorder=clone(trial)
			move(cross,483,delay)
			move(cross,483,90,true,true)
			if not cross.player.dead and cross.player.x>440 and cross.player.grounded:
				print("35 BRIDGE PASS angle=",angle," delay=",delay," ",Vector2(cross.player.x,cross.player.y))
				FileAccess.open(OUT+"/bridge35.json",FileAccess.WRITE).store_string(JSON.stringify(cross.frames))
				return
	print("35 NO BRIDGE")

func second35() -> void:
	var sim: Recorder=fresh(35)
	var replay: ReplayInput=ReplayInput.new()
	replay.sim=sim
	replay.frames=JSON.parse_string(FileAccess.get_file_as_string(OUT+"/bridge35.json"))
	for tick: int in replay.frames.size():sim.step(replay.sample(Vector2.ZERO))
	for target: Vector2 in [Vector2(283,446),Vector2(443,366),Vector2(523,366),Vector2(603,286)]:
		sim=seek4(sim,target,false)
		if sim==null:
			print("35 THIRD NAV FAIL ",target)
			return
	sim=seek4(sim,Vector2(663,166),true)
	if sim==null:
		print("35 THIRD AMMO FAIL")
		return
	print("35 THIRD AMMO ",Vector2(sim.player.x,sim.player.y))
	for target: Vector2 in [Vector2(523,366),Vector2(363,366),Vector2(283,446),Vector2(603,446)]:
		sim=seek4(sim,target,false)
		if sim==null:
			print("35 THIRD RETURN FAIL ",target)
			return
	print("35 SECOND BRIDGE READY")
	FileAccess.open(OUT+"/second35.json",FileAccess.WRITE).store_string(JSON.stringify(sim.frames))
	for angle: int in range(1,35):
		var trial: Recorder=clone(sim)
		shot(trial,float(angle),0)
		move(trial,603,50)
		if not Tile.is_eatable(trial.level.get_cell(12,18)) and not Tile.is_eatable(trial.level.get_cell(12,17)):continue
		print("35 SECOND PLACED ",angle)
		FileAccess.open(OUT+"/placed35.json",FileAccess.WRITE).store_string(JSON.stringify(trial.frames))
		return
		for delay: int in range(0,22):
			var cross: Recorder=clone(trial)
			move(cross,803,delay)
			move(cross,803,110,true,true)
			if not cross.player.dead and cross.player.x>760 and cross.player.grounded:
				print("35 SECOND BRIDGE PASS ",angle," ",delay)
				FileAccess.open(OUT+"/bridges35.json",FileAccess.WRITE).store_string(JSON.stringify(cross.frames))
				return
	print("35 SECOND BRIDGE FAIL")

func end35() -> void:
	var sim: Recorder=fresh(35)
	var replay: ReplayInput=ReplayInput.new()
	replay.sim=sim
	replay.frames=JSON.parse_string(FileAccess.get_file_as_string(OUT+"/placed35.json"))
	for tick: int in replay.frames.size():sim.step(replay.sample(Vector2.ZERO))
	for target: Vector2 in [Vector2(283,446),Vector2(443,366),Vector2(523,366),Vector2(603,286)]:
		sim=seek4(sim,target,false)
		if sim==null:
			print("35 LAST NAV FAIL ",target)
			return
	sim=seek4(sim,Vector2(663,126),true)
	if sim==null:
		print("35 LAST AMMO FAIL")
		return
	for target: Vector2 in [Vector2(523,366),Vector2(363,366),Vector2(283,446),Vector2(603,446)]:
		sim=seek4(sim,target,false)
		if sim==null:
			print("35 LAST RETURN FAIL ",target)
			return
	FileAccess.open(OUT+"/last35.json",FileAccess.WRITE).store_string(JSON.stringify(sim.frames))
	var bridge: Recorder
	for angle: int in range(1,40):
		var trial: Recorder=clone(sim)
		shot(trial,float(angle),0)
		move(trial,603,60)
		if Tile.is_eatable(trial.level.get_cell(12,17)) and Tile.is_eatable(trial.level.get_cell(12,18)):
			bridge=trial
			print("35 BOTH BRIDGES ",angle)
			break
	if bridge==null:
		print("35 CENTER PLACE FAIL")
		return
	sim=bridge
	move(sim,443,80)
	_macro(sim,"E12,10",false)
	print("35 FIRST RECOVER ",sim.player.has_block," count=",sim.player.carried_block_eaten_count)
	move(sim,603,60)
	var opened: Recorder
	for angle_index: int in range(-150,11):
		var trial: Recorder=clone(sim)
		shot(trial,float(angle_index)/10.0,0)
		move(trial,603,100)
		if trial.level.get_cell(11,24)==Tile.AIR:
			opened=trial
			print("35 LONG GLASS ",angle_index)
			break
	if opened==null:
		print("35 FIRST GLASS FAIL")
		return
	sim=opened
	for rr: int in [11,12]:
		var cells: String=""
		for cc: int in range(8,26):cells+=" %d:%d"%[cc,sim.level.get_cell(rr,cc)]
		print("35 ROW ",rr,cells)
	FileAccess.open(OUT+"/opened35.json",FileAccess.WRITE).store_string(JSON.stringify(sim.frames))
	finish35(sim)

func finish35(sim: Recorder) -> void:
	move(sim,803,8)
	move(sim,803,110,true,true)
	print("35 SECOND CROSS ",Vector2(sim.player.x,sim.player.y)," dead=",sim.player.dead)
	move(sim,723,45)
	for tick: int in 25:
		var inp: SimInput=SimInput.new()
		inp.eat=true
		inp.mouse_x=718-sim.camera.x
		inp.mouse_y=481-sim.camera.y
		sim.step(inp)
	print("35 RECOVER CENTER ",Vector2(sim.player.x,sim.player.y)," carry=",sim.player.has_block)
	move(sim,883,65)
	shot(sim,0,0)
	move(sim,883,50)
	print("35 SECOND GLASS ",sim.level.get_cell(11,25))
	move(sim,763,50)
	_macro(sim,"E12,18",false)
	move(sim,883,50)
	shot(sim,0,0)
	move(sim,1163,140)
	print("35 END ",Vector2(sim.player.x,sim.player.y)," dead=",sim.player.dead)
	finish(sim,35)

func solve37() -> void:
	var base: Recorder=fresh(37)
	move(base,123,25)
	_macro(base,"E6,4",false)
	move(base,243,60)
	shot(base,9,0)
	move(base,243,50)
	move(base,403,6)
	move(base,403,90,true,true)
	print("37 FIRST BRIDGE ",Vector2(base.player.x,base.player.y)," dead=",base.player.dead)
	print("37 BLOCKS ",base.level.get_cell(7,7)," ",base.level.get_cell(7,8))
	move(base,363,25)
	_macro(base,"E7,8",false)
	move(base,523,65)
	print("37 RECOVER ",base.player.has_block," ",Vector2(base.player.x,base.player.y))
	for delay: int in range(15,65):
		for angle: float in [60.0,70.0,80.0,90.0,100.0,110.0,120.0]:
			var trial: Recorder=clone(base)
			move(trial,683,delay)
			shot(trial,angle,1)
			move(trial,683,100,true)
			if not trial.player.dead and trial.player.grounded and trial.player.x>675 and trial.player.y<260 and trial.level.get_cell(11,16)==Tile.AIR:
				print("37 PLUNGE RECOIL ",delay," ",angle)
				FileAccess.open(OUT+"/partial37.json",FileAccess.WRITE).store_string(JSON.stringify(trial.frames))
				return
	print("37 PLUNGE FAILED")

func right37() -> void:
	var base: Recorder=fresh(37)
	var replay: ReplayInput=ReplayInput.new()
	replay.sim=base
	replay.frames=JSON.parse_string(FileAccess.get_file_as_string(OUT+"/partial37.json"))
	for tick: int in replay.frames.size():base.step(replay.sample(Vector2.ZERO))
	move(base,1043,170)
	_macro(base,"E11,27",false)
	print("37 RIGHT AMMO ",Vector2(base.player.x,base.player.y)," ",base.player.has_block)
	for angle: int in range(-55,-9):
		var trial: Recorder=clone(base)
		shot(trial,float(angle),0)
		move(trial,1043,60)
		move(trial,1163,100,true,true)
		if trial.player.grounded and trial.player.x>1155 and trial.player.y<380 and trial.player.y>=300:
			print("37 RIGHT STEP ",angle," ",Vector2(trial.player.x,trial.player.y))
			FileAccess.open(OUT+"/right37.json",FileAccess.WRITE).store_string(JSON.stringify(trial.frames))
			return
	print("37 RIGHT STEP FAIL")

func rise37(sim: Recorder, recover: bool) -> void:
	for tick: int in 25:
		if sim.player.x<=1126:break
		var inp: SimInput=SimInput.new()
		inp.left=true
		inp.eat=recover
		inp.mouse_x=1180-sim.camera.x
		inp.mouse_y=380-sim.camera.y
		sim.step(inp)
	for tick: int in 20:
		var inp: SimInput=SimInput.new()
		inp.jump=true
		inp.jump_pressed=tick==0
		inp.eat=recover
		inp.mouse_x=1180-sim.camera.x
		inp.mouse_y=380-sim.camera.y
		sim.step(inp)
	move(sim,1163,65,true)
	print("37 RISE ",Vector2(sim.player.x,sim.player.y)," carry=",sim.player.has_block)
	move(sim,1163,20,true,true)
	move(sim,1123,60,true)
	print("37 TOP ",Vector2(sim.player.x,sim.player.y))

func end37() -> void:
	var sim: Recorder=fresh(37)
	var replay: ReplayInput=ReplayInput.new()
	replay.sim=sim
	replay.frames=JSON.parse_string(FileAccess.get_file_as_string(OUT+"/right37.json"))
	for tick: int in replay.frames.size():sim.step(replay.sample(Vector2.ZERO))
	rise37(sim,false)
	_macro(sim,"E2,27",false)
	print("37 UPPER AMMO ",sim.player.has_block)
	FileAccess.open(OUT+"/top37.json",FileAccess.WRITE).store_string(JSON.stringify(sim.frames))
	var nav: Recorder = seek4(sim,Vector2(843,246),false)
	if nav == null:
		print("37 RETURN JUMP FAILED")
		return
	sim=nav
	print("37 RETURN PLATFORM ",Vector2(sim.player.x,sim.player.y)," dead=",sim.player.dead)
	move(sim,683,50)
	for tick: int in 20:
		if sim.player.x<=650:break
		move(sim,643,1)
	shot(sim,90,1)
	move(sim,683,80,true)
	print("37 SECOND GLASS ",sim.level.get_cell(12,16)," ",Vector2(sim.player.x,sim.player.y))
	move(sim,1043,170)
	move(sim,1163,100,true,true)
	rise37(sim,true)
	nav=seek4(sim,Vector2(843,246),false)
	if nav == null:
		print("37 FINAL RETURN JUMP FAILED")
		return
	sim=nav
	move(sim,683,50)
	for tick: int in 20:
		if sim.player.x<=650:break
		move(sim,643,1)
	shot(sim,90,0)
	move(sim,643,170,true)
	print("37 FINAL ",Vector2(sim.player.x,sim.player.y)," dead=",sim.player.dead," glass=",sim.level.get_cell(13,16))
	finish(sim,37)

func steps37() -> void:
	var base: Recorder=fresh(37)
	var replay: ReplayInput=ReplayInput.new()
	replay.sim=base
	replay.frames=JSON.parse_string(FileAccess.get_file_as_string(OUT+"/top37.json"))
	for tick: int in replay.frames.size():base.step(replay.sample(Vector2.ZERO))
	move(base,923,120)
	var sim: Recorder
	for angle: int in range(-165,-99):
		var trial: Recorder=clone(base)
		shot(trial,float(angle),0)
		move(trial,923,50)
		move(trial,883,100,true,true)
		if trial.player.grounded and trial.player.y<380 and trial.player.y>300:
			sim=trial
			print("37 LEFT STEP ",angle," ",Vector2(sim.player.x,sim.player.y))
			break
	if sim==null:
		print("37 LEFT STEP FAIL")
		return
	move(sim,1043,100)
	move(sim,1163,100,true,true)
	_macro(sim,"E9,29",false)
	move(sim,1163,50)
	print("37 BOTTOM RECOVER ",sim.player.has_block," ",Vector2(sim.player.x,sim.player.y))
	move(sim,923,100)
	move(sim,883,100,true,true)
	move(sim,883,20,true,true)
	move(sim,843,65,true)
	print("37 LEFT CLIMB ",Vector2(sim.player.x,sim.player.y))
	move(sim,683,70)
	for tick: int in 20:
		if sim.player.x<=650:break
		move(sim,643,1)
	shot(sim,90,1)
	move(sim,683,80,true)
	print("37 SECOND OPEN ",sim.level.get_cell(12,16))
	move(sim,923,110)
	move(sim,883,100,true,true)
	for tick: int in 25:
		var inp: SimInput=SimInput.new()
		inp.jump=true
		inp.jump_pressed=tick==0
		inp.left=tick>=20
		inp.eat=true
		inp.mouse_x=900-sim.camera.x
		inp.mouse_y=420-sim.camera.y
		sim.step(inp)
	move(sim,843,60,true)
	print("37 FINAL RECOVER ",sim.player.has_block," ",Vector2(sim.player.x,sim.player.y))
	move(sim,683,70)
	for tick: int in 20:
		if sim.player.x<=650:break
		move(sim,643,1)
	shot(sim,90,0)
	move(sim,643,170,true)
	print("37 END ",Vector2(sim.player.x,sim.player.y)," dead=",sim.player.dead," glass=",sim.level.get_cell(13,16))
	finish(sim,37)

func solve36() -> void:
	var base: Recorder=fresh(36)
	_macro(base,"E16,1",false)
	shot(base,-90,0)
	move(base,83,50)
	_macro(base,"E17,1",false)
	shot(base,-90,0)
	move(base,83,50)
	print("36 OPEN SHAFT ",base.level.get_cell(15,2)," ",base.level.get_cell(14,2))
	for tick: int in 80:
		var inp: SimInput=SimInput.new()
		inp.jump=true
		inp.jump_pressed=tick==0
		inp.eat=true
		inp.mouse_x=170-base.camera.x
		inp.mouse_y=580-base.camera.y
		base.step(inp)
	print("36 THIRD AMMO ",base.player.has_block," ",Vector2(base.player.x,base.player.y))
	for angle: int in range(-140,-94):
		var trial: Recorder=clone(base)
		shot(trial,float(angle),0)
		move(trial,83,60)
		if not Tile.is_eatable(trial.level.get_cell(16,2)):continue
		move(trial,83,90,true,true)
		print("36 STEP ",angle," ",Vector2(trial.player.x,trial.player.y))
		if trial.player.y>610:continue
		move(trial,83,22,true,true)
		move(trial,123,80,true)
		print("36 UPPER ",Vector2(trial.player.x,trial.player.y))
		FileAccess.open(OUT+"/partial36.json",FileAccess.WRITE).store_string(JSON.stringify(trial.frames))
		return
	print("36 INITIAL CLIMB FAIL")

func jump_eat(sim: Recorder, row: int, col: int) -> void:
	for tick: int in 70:
		var inp: SimInput=SimInput.new()
		inp.jump=true
		inp.jump_pressed=tick==0
		inp.eat=true
		inp.mouse_x=col*40+20-sim.camera.x
		inp.mouse_y=row*40+20-sim.camera.y
		sim.step(inp)

func bottom36() -> void:
	var sim: Recorder=fresh(36)
	_macro(sim,"E16,1",false)
	shot(sim,0,0)
	move(sim,163,100)
	jump_eat(sim,14,4)
	print("36 FLOOR AMMO ",sim.player.has_block," ",Vector2(sim.player.x,sim.player.y))
	move(sim,443,150)
	shot(sim,0,0)
	move(sim,443,50)
	jump_eat(sim,14,11)
	print("36 SECOND AMMO ",sim.player.has_block," ",Vector2(sim.player.x,sim.player.y))
	shot(sim,-90,0)
	move(sim,443,50)
	move(sim,443,24,true,true)
	move(sim,403,90,true)
	print("36 FIRST FLOOR ",Vector2(sim.player.x,sim.player.y))
	_macro(sim,"E14,12",false)
	FileAccess.open(OUT+"/bottom36.json",FileAccess.WRITE).store_string(JSON.stringify(sim.frames))

func higher36() -> void:
	var sim: Recorder=fresh(36)
	var replay: ReplayInput=ReplayInput.new()
	replay.sim=sim
	replay.frames=JSON.parse_string(FileAccess.get_file_as_string(OUT+"/bottom36.json"))
	for tick: int in replay.frames.size():sim.step(replay.sample(Vector2.ZERO))
	print("36 UPPER AMMO ",sim.player.has_block)
	move(sim,563,70,true,true)
	shot(sim,-90,0)
	move(sim,563,50)
	sim=exit_jump(sim,603,446)
	if sim==null:
		print("36 MIDDLE EXIT FAIL")
		return
	print("36 MIDDLE ",Vector2(sim.player.x,sim.player.y))
	_macro(sim,"E10,14",false)
	print("36 MIDDLE AMMO ",sim.player.has_block)
	shot(sim,-90,0)
	move(sim,603,50)
	sim=exit_jump(sim,563,326)
	if sim==null:
		print("36 CENTRAL EXIT FAIL")
		return
	print("36 CENTRAL ",Vector2(sim.player.x,sim.player.y))
	move(sim,523,25)
	jump_eat(sim,6,11)
	print("36 LEFT AMMO ",sim.player.has_block)
	move(sim,523,9,true,true)
	shot(sim,180.01,-1)
	move(sim,523,60)
	move(sim,523,9,true,true)
	move(sim,443,100,true)
	print("36 LEFT ROOM ",Vector2(sim.player.x,sim.player.y))
	FileAccess.open(OUT+"/higher36.json",FileAccess.WRITE).store_string(JSON.stringify(sim.frames))

func exit_jump(base: Recorder, target_x: float, target_y: float) -> Recorder:
	for delay: int in range(0,36):
		var trial: Recorder=clone(base)
		move(trial,base.player.x,delay,true,true)
		move(trial,target_x,90,true,delay==0)
		if trial.player.grounded and absf(trial.player.x-target_x)<5 and absf(trial.player.y-target_y)<2:
			print("EXIT JUMP ",delay)
			return trial
	return null

func return36() -> void:
	var sim: Recorder=fresh(36)
	var replay: ReplayInput=ReplayInput.new()
	replay.sim=sim
	replay.frames=JSON.parse_string(FileAccess.get_file_as_string(OUT+"/higher36.json"))
	for tick: int in replay.frames.size():sim.step(replay.sample(Vector2.ZERO))
	move(sim,563,100)
	move(sim,603,65)
	move(sim,563,65)
	move(sim,443,80)
	move(sim,83,180)
	_macro(sim,"E17,1",false)
	print("36 SPARE ",sim.player.has_block," ",Vector2(sim.player.x,sim.player.y))
	move(sim,443,170)
	sim=exit_jump(sim,403,566)
	if sim==null:
		print("36 SPARE FLOOR FAIL")
		return
	move(sim,563,70,true,true)
	sim=exit_jump(sim,603,446)
	if sim==null:return
	sim=exit_jump(sim,563,326)
	if sim==null:return
	move(sim,523,25)
	sim=exit_jump(sim,443,246)
	if sim==null:
		print("36 SPARE TOP FAIL")
		return
	move(sim,203,100)
	shot(sim,180.01,0)
	move(sim,203,50)
	move(sim,163,35)
	_macro(sim,"E6,3",false)
	move(sim,443,130)
	print("36 LEFT UNLOCKED ",sim.player.has_block," ",Vector2(sim.player.x,sim.player.y))
	FileAccess.open(OUT+"/spare36.json",FileAccess.WRITE).store_string(JSON.stringify(sim.frames))
	var best: Recorder
	for delay: int in range(0,26):
		for angle: float in [35.0,40.0,45.0,50.0,55.0,60.0,65.0,70.0]:
			var trial: Recorder=clone(sim)
			move(trial,443,delay,true,true)
			shot(trial,angle,1)
			move(trial,483,110,true)
			if trial.player.grounded and absf(trial.player.x-483)<5 and absf(trial.player.y-166)<2:
				best=trial
				print("36 NICHE ",delay," ",angle)
				break
		if best!=null:break
	if best==null:
		print("36 NICHE FAIL")
		return
	FileAccess.open(OUT+"/niche36.json",FileAccess.WRITE).store_string(JSON.stringify(best.frames))

func cross36(source: Recorder, direction: int) -> Recorder:
	var base: Recorder=clone(source)
	for tick: int in 50:
		if (direction>0 and base.player.x>=520) or (direction<0 and base.player.x<=646):break
		move(base,683 if direction>0 else 483,1)
	for delay: int in range(0,5):
		var trial: Recorder=clone(base)
		move(trial,683 if direction>0 else 483,delay)
		move(trial,683 if direction>0 else 483,110,true,true)
		if trial.player.grounded and absf(trial.player.y-166)<2 and absf(trial.player.x-(683 if direction>0 else 483))<5:
			print("36 CROSS ",direction," delay=",delay)
			return trial
	return null

func end36() -> void:
	var sim: Recorder=fresh(36)
	var replay: ReplayInput=ReplayInput.new()
	replay.sim=sim
	replay.frames=JSON.parse_string(FileAccess.get_file_as_string(OUT+"/niche36.json"))
	for tick: int in replay.frames.size():sim.step(replay.sample(Vector2.ZERO))
	move(sim,443,50)
	_macro(sim,"E6,10",false)
	sim=exit_jump(sim,483,166)
	if sim==null:
		print("36 NICHE RETURN FAIL")
		return
	sim=cross36(sim,1)
	if sim==null:
		print("36 FORWARD GAP FAIL")
		return
	shot(sim,-30,0)
	move(sim,683,60)
	print("36 WALL19 ",sim.level.get_cell(3,19))
	FileAccess.open(OUT+"/wall36.json",FileAccess.WRITE).store_string(JSON.stringify(sim.frames))
	sim=cross36(sim,-1)
	if sim==null:
		print("36 BACK GAP FAIL")
		return
	move(sim,123,150)
	_macro(sim,"E6,2",false)
	move(sim,443,150)
	sim=exit_jump(sim,483,166)
	if sim==null:return
	sim=cross36(sim,1)
	if sim==null:return
	move(sim,763,70)
	print("36 RIGHT ROOM ",Vector2(sim.player.x,sim.player.y))
	move(sim,1003,130)
	shot(sim,-30,0)
	move(sim,1003,60)
	print("36 WALL27 ",sim.level.get_cell(3,27))
	sim=exit_jump(sim,1083,126)
	if sim==null:
		print("36 WALL27 CLIMB FAIL")
		return
	move(sim,1123,60)
	move(sim,1163,90,true,true)
	print("36 FINAL ",Vector2(sim.player.x,sim.player.y)," dead=",sim.player.dead)
	finish(sim,36)

func solve39() -> void:
	var base: Recorder=fresh(39)
	_macro(base,"E2,9",false)
	move(base,443,120)
	move(base,403,35)
	var sim: Recorder
	for delay: int in range(15,36):
		for angle_index: int in range(200,601,5):
			var trial: Recorder=clone(base)
			move(trial,403,delay,true,true)
			shot(trial,float(angle_index)/10.0,-1)
			move(trial,203,120,true)
			if not trial.player.dead and trial.level.get_cell(11,16)==Tile.AIR and trial.player.grounded and trial.player.y<300:
				sim=trial
				print("39 FIRST SHOT ",delay," ",angle_index)
				break
		if sim!=null:break
	if sim==null:
		print("39 FIRST SHOT FAIL")
		return
	move(sim,83,50)
	_macro(sim,"E7,1",false)
	print("39 LEFT AMMO ",Vector2(sim.player.x,sim.player.y)," ",sim.player.has_block)
	var second: Recorder
	for delay: int in range(0,30):
		for angle: int in range(10,46):
			var trial: Recorder=clone(sim)
			move(trial,83,delay,true,true)
			shot(trial,float(angle),1)
			move(trial,83,110)
			if not trial.player.dead and trial.level.get_cell(11,17)==Tile.AIR:
				second=trial
				print("39 SECOND SHOT ",delay," ",angle)
				break
		if second!=null:break
	if second==null:
		print("39 SECOND SHOT FAIL")
		return
	FileAccess.open(OUT+"/partial39.json",FileAccess.WRITE).store_string(JSON.stringify(second.frames))

func end39() -> void:
	var sim: Recorder=fresh(39)
	var replay: ReplayInput=ReplayInput.new()
	replay.sim=sim
	replay.frames=JSON.parse_string(FileAccess.get_file_as_string(OUT+"/partial39.json"))
	for tick: int in replay.frames.size():sim.step(replay.sample(Vector2.ZERO))
	for col: int in [6,5]:
		move(sim,343,180)
		move(sim,283,40)
		_macro(sim,"E16,%d"%col,false)
		move(sim,343,40)
		print("39 LOWER AMMO ",col," ",sim.player.has_block," ",Vector2(sim.player.x,sim.player.y))
		var step: Recorder
		for angle: int in range(-80,-19):
			var trial: Recorder=clone(sim)
			shot(trial,float(angle),0)
			move(trial,343,60)
			if angle % 10==0:
				var blocks: String=""
				for rr: int in range(11,17):blocks+=" %d:%d"%[rr,trial.level.get_cell(rr,9)]
				print("39 STEP TILES ",angle,blocks)
			if Tile.is_eatable(trial.level.get_cell(15,9)):
				move(trial,323,20)
				step=exit_jump(trial,363,566)
				if step!=null:
					print("39 STEP ",angle)
					break
		if step==null:
			print("39 STEP FAIL")
			return
		sim=step
		for tick: int in 25:
			var inp: SimInput=SimInput.new()
			inp.jump=true
			inp.jump_pressed=tick==0
			inp.right=tick>=20
			inp.eat=true
			inp.mouse_x=380-sim.camera.x
			inp.mouse_y=620-sim.camera.y
			sim.step(inp)
		move(sim,403,70,true)
		print("39 RECOVERED ",sim.player.has_block," ",Vector2(sim.player.x,sim.player.y))
		move(sim,643,110)
		shot(sim,0,0)
		move(sim,643,50)
		print("39 WALL ",24-col," =",sim.level.get_cell(11,24-col))
	move(sim,883,140)
	finish(sim,39)

func solve40() -> void:
	for variant: int in range(40):
		var sim: Recorder=fresh(40)
		var dirt: Vector2=Vector2(300,520)
		var last_hp: int=3
		for tick: int in 18000:
			if sim.player.dead or sim.player.won:break
			var p: PlayerState=sim.player
			var b: BossState=sim.boss
			var center: Vector2=Vector2(p.center_x(),p.center_y())
			var core: Vector2=Vector2(b.center_x(),b.center_y())
			if tick%20==0 and not p.has_block:
				var best: float=INF
				for rr: int in range(maxi(0,floori(p.y/40)-3),mini(sim.level.rows,floori(p.y/40)+8)):
					for cc: int in range(1,sim.level.cols-1):
						if not Tile.is_eatable(sim.level.get_cell(rr,cc)):continue
						var point: Vector2=Vector2(cc*40+20,rr*40+20)
						var distance: float=center.distance_to(point)
						if distance<best:
							best=distance
							dirt=point
			var target_x: float=dirt.x-17
			if b.state==BossState.State.SUSPENDED:target_x=900
			if p.has_block:
				if b.state==BossState.State.STUNNED or center.distance_to(core)<350:
					target_x=b.x-35 if center.x<core.x else b.x+b.w+1
				else:target_x=p.x
			if b.state==BossState.State.CHARGING and b.current_move==BossGlassSlime.Move.SLAM and b.charge_timer<b.max_charge_timer*0.4:
				target_x=b.dive_x-120 if center.x<core.x else b.dive_x+b.w+100
			for bomb: GlassBomb in b.bombs:
				if absf(bomb.x-center.x)<85 and bomb.y<p.y+34 and bomb.y+bomb.vy*18>p.y-40:
					target_x=p.x+(110 if center.x>bomb.x else -110)
			target_x=clampf(target_x,43,sim.level.pixel_width()-77)
			var inp: SimInput=SimInput.new()
			inp.right=p.x<target_x-4
			inp.left=p.x>target_x+4
			inp.eat=not p.has_block
			inp.mouse_x=dirt.x-sim.camera.x
			inp.mouse_y=dirt.y-sim.camera.y
			if p.has_block and center.distance_to(core)<float(80+variant*5 if b.durability==1 else 101) and b.state not in [BossState.State.INTRO,BossState.State.SUSPENDED] and b.glass_hit_recovery==0:
				inp.shoot_released=true
				inp.mouse_x=core.x+b.vx-sim.camera.x
				inp.mouse_y=core.y+b.vy-sim.camera.y
			var direction: int=1 if inp.right else (-1 if inp.left else 0)
			if direction!=0 and p.grounded and Tile.is_solid(sim.level.get_cell(floori((p.y+10)/40),floori((p.center_x()+direction*27)/40))):
				inp.jump=true
				inp.jump_pressed=true
			sim.step(inp)
			if b.durability<last_hp:
				last_hp=b.durability
				print("40 HIT variant=",variant," tick=",tick," hp=",last_hp," ",Vector2(p.x,p.y))
			if b.dead:
				var goal_x: float=p.x
				for rr: int in sim.level.rows:
					for cc: int in sim.level.cols:
						if sim.level.get_cell(rr,cc)==Tile.GOAL:goal_x=cc*40+3
				for tail: int in 100:
					move(sim,goal_x,1)
				if finish(sim,40):return
				break
		print("40 TRY ",variant," ticks=",sim.frames.size()," hp=",sim.boss.durability," dead=",sim.player.dead," pos=",Vector2(sim.player.x,sim.player.y)," carry=",sim.player.has_block)


