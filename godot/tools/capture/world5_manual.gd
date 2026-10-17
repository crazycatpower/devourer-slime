extends "res://tools/capture/world5_driver.gd"

func aim_step(sim: Recorder, pos: Vector2, eat: bool, shoot: bool, dir: int=0, jump: bool=false, jp: bool=false) -> void:
	var inp: SimInput=SimInput.new()
	inp.eat=eat
	inp.shoot_released=shoot
	inp.right=dir>0
	inp.left=dir<0
	inp.jump=jump
	inp.jump_pressed=jp
	inp.mouse_x=pos.x-sim.camera.x
	inp.mouse_y=pos.y-sim.camera.y
	sim.step(inp)

func solve41() -> void:
	OUT="res://build/recordings/world5"
	stage=41
	var base: Recorder=fresh()
	for i: int in 25: aim_step(base,Vector2(60,500),true,false)
	print("BASE ",Vector2(base.player.x,base.player.y)," carry=",base.player.has_block)
	move(base,303,100)
	move(base,923,32,true,true)
	aim_step(base,Vector2(base.player.center_x()+200,base.player.center_y()+200),false,true,1,true)
	for t: int in 90:
		move(base,443,1,true)
		if base.player.dead or base.player.grounded: break
	print("STEP ",Vector2(base.player.x,base.player.y))
	move(base,63,160,true,true)
	for i: int in 25: aim_step(base,Vector2(60,540),true,false)
	print("SECOND ",Vector2(base.player.x,base.player.y)," carry=",base.player.has_block," dead=",base.player.dead)
	move(base,323,100)
	move(base,443,70,true,true)
	print("RETURN ",Vector2(base.player.x,base.player.y)," carry=",base.player.has_block," dead=",base.player.dead)
	FileAccess.open(OUT+"/step41.json",FileAccess.WRITE).store_string(JSON.stringify(base.frames))
	for delay: int in range(0,45):
		for angle: float in [90.0,110.0,125.0,135.0,145.0,160.0,180.01]:
			var sim: Recorder=clone(base)
			move(sim,923,delay,true,true)
			aim_step(sim,Vector2(sim.player.center_x(),sim.player.center_y())+Vector2.from_angle(deg_to_rad(angle))*200,false,true,1,true)
			move(sim,923,220,true)
			if save_win(sim):
				print("ROUTE ",delay," ",angle)
				get_tree().quit()
				return
	print("MANUAL FAILED")
	get_tree().quit(1)

func _ready() -> void:
	OUT="res://build/recordings/world5"
	var plan: String=""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--stage="): stage=a.trim_prefix("--stage=").to_int()
		if a.begins_with("--plan="): plan=a.trim_prefix("--plan=")
	if plan.is_empty():
		if stage==46:
			if "--finish" in OS.get_cmdline_user_args():
				finish46()
				return
			if "--supply" in OS.get_cmdline_user_args():
				supply46()
				return
			solve46()
			return
		if stage==49 and "--air" in OS.get_cmdline_user_args():
			solve_air()
			return
		if stage==42 or stage==45 or stage==49:
			solve42()
			return
		solve41()
		return
	var sim: Recorder=fresh()
	var doc: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"/"+plan+".json"))
	if doc.has("prefix"):
		var r: ReplayInput=ReplayInput.new()
		r.sim=sim
		r.frames=JSON.parse_string(FileAccess.get_file_as_string(OUT+"/"+str(doc.prefix)+".json"))
		for i: int in r.frames.size(): sim.step(r.sample(Vector2.ZERO))
	print("STATE pos=",Vector2(sim.player.x,sim.player.y)," vel=",Vector2(sim.player.vx,sim.player.vy)," carry=",sim.player.has_block," boss=",Vector2(sim.boss.x,sim.boss.y))
	if stage==50:
		for r: int in 3: print("CELLS ",sim.boss.cell(r,0),",",sim.boss.cell(r,1),",",sim.boss.cell(r,2))
	for a: Dictionary in doc.actions:
		var n: int=a.get("n",1)
		if a.has("bounce"):
			var bx: float=a.bounce
			for i: int in 500:
				move(sim,bx,1)
				if sim.player.dead or (sim.player.y>450 and sim.player.vy < -12): break
		elif a.has("x"):
			var x: float=a.x
			var j: bool=a.get("j",false)
			move(sim,x,n,j,j)
		elif a.has("eat") or a.has("shoot"):
			var xy: Array=a.get("eat",a.get("shoot",[]))
			var x: float=xy[0]
			var y: float=xy[1]
			for i: int in n: aim_step(sim,Vector2(x,y),a.has("eat"),a.has("shoot"))
		else:
			for i: int in n: sim.step(SimInput.new())
		print("ACTION ",a," pos=",Vector2(sim.player.x,sim.player.y)," carry=",sim.player.has_block," dead=",sim.player.dead," won=",sim.player.won)
		if sim.player.dead or sim.player.won: break
	for r: int in sim.level.rows:
		var line: String=""
		for c: int in sim.level.cols: line+=str(sim.level.get_cell(r,c))+","
		print(line)
	FileAccess.open(OUT+"/"+plan+"_out.json",FileAccess.WRITE).store_string(JSON.stringify(sim.frames))
	save_win(sim)
	get_tree().quit()

func solve42() -> void:
	var base: Recorder=fresh()
	var output: String="bridge42"
	var minimum: float=320
	var start_x: float=123
	var loaded: bool=false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="): output=a.trim_prefix("--out=")
		if a.begins_with("--minimum="): minimum=a.trim_prefix("--minimum=").to_float()
		if a.begins_with("--prefix="):
			var rr: ReplayInput=ReplayInput.new()
			rr.sim=base
			rr.frames=JSON.parse_string(FileAccess.get_file_as_string(OUT+"/"+a.trim_prefix("--prefix=")+".json"))
			for i: int in rr.frames.size(): base.step(rr.sample(Vector2.ZERO))
			loaded=true
	if not loaded:
		for i: int in 25: aim_step(base,Vector2(140,300) if stage in [45,49] else Vector2(180,500),true,false)
	start_x=base.player.x
	for delay: int in range(0,45,2):
		for angle: float in [22.5,30.0,40.0,50.0,60.0,70.0,80.0]:
			for offset: float in [160.0,200.0,240.0,280.0]:
				var landing_x: float=start_x+offset
				var sim: Recorder=clone(base)
				move(sim,923,delay,true,true)
				aim_step(sim,Vector2(sim.player.center_x(),sim.player.center_y())+Vector2.from_angle(deg_to_rad(angle))*200,false,true,1,true)
				for t: int in 130:
					move(sim,landing_x,1,true)
					if sim.player.dead: break
					if (sim.player.grounded or (stage in [45,49] and sim.player.vy < -12 and sim.player.y>450)) and sim.player.x>minimum:
						print("BRIDGE ",delay," ",angle," ",landing_x," at=",Vector2(sim.player.x,sim.player.y))
						FileAccess.open(OUT+"/"+output+".json",FileAccess.WRITE).store_string(JSON.stringify(sim.frames))
						get_tree().quit()
						return
	print("BRIDGE FAILED")
	get_tree().quit(1)

func solve_air() -> void:
	for wait: int in range(0,61,5):
		for eat_pos: Vector2 in [Vector2(100,300),Vector2(140,300),Vector2(100,340)]:
			var base: Recorder=fresh()
			for t: int in wait: base.step(SimInput.new())
			for t: int in 25: aim_step(base,eat_pos,true,false)
			if base.player.dead or not base.player.has_block: continue
			for delay: int in range(0,111,3):
				var launch: Recorder=clone(base)
				move(launch,883,delay,true,true)
				if launch.player.dead: continue
				for angle: float in [-0.01,22.5,45.0,67.5,90.0,112.5,135.0,157.5,180.01]:
					var sim: Recorder=clone(launch)
					aim_step(sim,Vector2(sim.player.center_x(),sim.player.center_y())+Vector2.from_angle(deg_to_rad(angle))*200,false,true,1,true)
					move(sim,883,300,true)
					if save_win(sim):
						print("AIR ROUTE ",wait," ",eat_pos," ",delay," ",angle)
						get_tree().quit()
						return
	print("AIR FAILED")
	get_tree().quit(1)

func solve46() -> void:
	var base: Recorder=fresh()
	var rr: ReplayInput=ReplayInput.new()
	rr.sim=base
	rr.frames=JSON.parse_string(FileAccess.get_file_as_string(OUT+"/ammo46.json"))
	for i: int in rr.frames.size(): base.step(rr.sample(Vector2.ZERO))
	move(base,323,30)
	for run: int in range(22,28):
		for delay: int in range(10,42,2):
			for angle: float in [100.0,110.0,120.0,130.0,140.0,150.0,160.0,170.0,180.01]:
				var sim: Recorder=clone(base)
				move(sim,923,run)
				move(sim,690,delay,true,true)
				aim_step(sim,Vector2(sim.player.center_x(),sim.player.center_y())+Vector2.from_angle(deg_to_rad(angle))*200,false,true,1,true)
				for t: int in 120:
					move(sim,690,1,true)
					if sim.player.dead: break
					if sim.player.grounded and sim.player.x>680:
						print("LEDGE ",run," ",delay," ",angle," pos=",Vector2(sim.player.x,sim.player.y))
						FileAccess.open(OUT+"/ledge46.json",FileAccess.WRITE).store_string(JSON.stringify(sim.frames))
						get_tree().quit()
						return
	print("LEDGE FAILED")
	get_tree().quit(1)

func supply46() -> void:
	var base: Recorder=fresh()
	var rr: ReplayInput=ReplayInput.new()
	rr.sim=base
	rr.frames=JSON.parse_string(FileAccess.get_file_as_string(OUT+"/plan46floor_out.json"))
	for i: int in rr.frames.size(): base.step(rr.sample(Vector2.ZERO))
	move(base,323,30)
	for delay: int in range(18,40):
		for y: float in [320.0,330.0,340.0,350.0,360.0]:
			var sim: Recorder=clone(base)
			move(sim,443,23)
			move(sim,443,delay,true,true)
			aim_step(sim,Vector2(740,y),false,true)
			move(sim,323,120)
			if sim.player.dead or not sim.player.grounded: continue
			if sim.level.get_cell(8,17)!=Tile.DIRT_EATEN_1: continue
			move(sim,243,40)
			for t: int in 25: aim_step(sim,Vector2(220,380),true,false)
			if not sim.player.has_block: continue
			print("SUPPLY ",delay," ",y," pos=",Vector2(sim.player.x,sim.player.y))
			FileAccess.open(OUT+"/ammo46.json",FileAccess.WRITE).store_string(JSON.stringify(sim.frames))
			get_tree().quit()
			return
	get_tree().quit(1)

func finish46() -> void:
	var base: Recorder=fresh()
	var rr: ReplayInput=ReplayInput.new()
	rr.sim=base
	rr.frames=JSON.parse_string(FileAccess.get_file_as_string(OUT+"/plan46enter_out.json"))
	for i: int in rr.frames.size(): base.step(rr.sample(Vector2.ZERO))
	for x: float in [750.0,754.0,758.0]:
		for delay: int in range(15,45):
			for angle: float in [145.0,150.0,155.0,160.0,165.0,170.0,175.0,180.01]:
				var sim: Recorder=clone(base)
				move(sim,x,15)
				move(sim,x,delay,true,true)
				aim_step(sim,Vector2(sim.player.center_x(),sim.player.center_y())+Vector2.from_angle(deg_to_rad(angle))*200,false,true,1,true)
				move(sim,963,100,true)
				if save_win(sim):
					print("FINAL ",x," ",delay," ",angle)
					get_tree().quit()
					return
	print("FINAL FAILED")
	get_tree().quit(1)
