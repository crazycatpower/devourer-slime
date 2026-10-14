extends "res://tools/capture/world3_driver.gd"

func shot(sim: Recorder, degrees: float, direction: int = 1) -> void:
	# Avoid an exactly horizontal aim changing sign after camera/JSON rounding.
	if degrees == 0.0:
		degrees = -0.01
	elif degrees == 180.0:
		degrees = 180.01
	var inp: SimInput = SimInput.new()
	inp.right = direction > 0
	inp.left = direction < 0
	inp.jump = true
	inp.shoot_released = true
	inp.mouse_x = sim.player.center_x()+cos(deg_to_rad(degrees))*200-sim.camera.x
	inp.mouse_y = sim.player.center_y()+sin(deg_to_rad(degrees))*200-sim.camera.y
	sim.step(inp)

func _ready() -> void:
	OUT = "res://build/recordings/world3"
	if "--28" in OS.get_cmdline_user_args():
		roof_route()
		return
	if "--30" in OS.get_cmdline_user_args():
		roof_boss()
		return
	if "--26" in OS.get_cmdline_user_args():
		outside_shaft()
		return
	if "--27" in OS.get_cmdline_user_args():
		diagonal_bridge()
		return
	if "--29" in OS.get_cmdline_user_args():
		maze_route()
		return
	var base: Recorder = fresh(24)
	move(base,83,16)
	move(base,203,70,true,true)
	_macro(base,"E13,6",false)
	for tick: int in 1000:
		var inp: SimInput = SimInput.new()
		inp.jump = true
		inp.jump_pressed = base.player.grounded or base.player.coyote_timer == 2
		base.step(inp)
		if base.player.y < 316 and base.player.vy > -2:
			break
	print("BASE24 ",Vector2(base.player.x,base.player.y)," dead=",base.player.dead," carry=",base.player.has_block)
	for angle: float in [90.0,100.0,110.0,120.0,130.0,140.0]:
		var sim: Recorder = clone(base)
		move(sim,283,18,true)
		shot(sim,angle)
		var phase: int = 1
		for tick: int in 1600:
			if sim.player.x > 465 and sim.player.vy < -12:
				phase = 2
			var target: float = 483.0 if phase == 1 else 923.0
			var inp: SimInput = SimInput.new()
			inp.right = sim.player.x < target-3
			inp.left = sim.player.x > target+3
			inp.jump = true
			inp.jump_pressed = sim.player.grounded or sim.player.coyote_timer == 2
			inp.eat = phase == 2 and not sim.player.has_block
			inp.mouse_x = sim.player.center_x()-sim.camera.x-60
			inp.mouse_y = sim.player.center_y()-sim.camera.y+100
			inp.shoot_released = sim.player.has_block and sim.player.vy > -2 and sim.player.y < 280
			sim.step(inp)
			if sim.player.dead or sim.player.won:
				break
		if finish(sim,24):
			get_tree().quit()
			return
		print("TRY ",angle," phase=",phase," pos=",Vector2(sim.player.x,sim.player.y)," dead=",sim.player.dead)
	get_tree().quit()

func solve_corridor() -> void:
	var beam: Array[Recorder] = [fresh(28)]
	for depth: int in 180:
		var candidates: Array[Recorder] = []
		var seen: Dictionary = {}
		for source: Recorder in beam:
			for direction: int in [1,0,-1]:
				var sim: Recorder = clone(source)
				for tick: int in 10:
					var inp: SimInput = SimInput.new()
					inp.right = direction > 0
					inp.left = direction < 0
					sim.step(inp)
				if sim.player.dead:
					continue
				if finish(sim,28):
					get_tree().quit()
					return
				var key: String = "%d,%d,%d" % [roundi(sim.player.x/10),roundi(sim.player.y/12),roundi(sim.player.vy/3)]
				if not seen.has(key):
					seen[key] = true
					candidates.append(sim)
		candidates.sort_custom(func(a: Recorder,b: Recorder) -> bool: return a.player.x > b.player.x)
		beam.assign(candidates.slice(0,60))
		if beam.is_empty():
			break
		if depth % 10 == 0:
			print("BEAM28 ",depth," x=",beam[0].player.x)
	get_tree().quit()

func solve_boss() -> void:
	for parking: float in [803.0,603.0,1203.0,403.0,1403.0,1003.0,1603.0]:
		var sim: Recorder = fresh(30)
		for tick: int in 7000:
			var target: float = parking
			if not sim.boss.triggered:
				target = sim.boss.center_x()-200
			if sim.boss.dead:
				target = 963.0
			var inp: SimInput = SimInput.new()
			inp.right = sim.player.x < target-3
			inp.left = sim.player.x > target+3
			inp.jump = true
			inp.jump_pressed = sim.player.grounded
			if sim.boss.dead:
				inp.eat = not sim.player.has_block
				inp.mouse_x = 980-sim.camera.x
				inp.mouse_y = 380-sim.camera.y
				inp.shoot_released = sim.player.has_block and tick % 30 == 0
				if inp.shoot_released:
					inp.mouse_x = sim.player.center_x()-sim.camera.x
					inp.mouse_y = sim.player.center_y()+200-sim.camera.y
			sim.step(inp)
			if sim.player.won or sim.player.dead:
				break
		if finish(sim,30):
			get_tree().quit()
			return
		print("BOSS ",parking," hp=",sim.boss.durability," dead=",sim.player.dead," pos=",Vector2(sim.player.x,sim.player.y)," bossdead=",sim.boss.dead)
	get_tree().quit()

func dig_shaft() -> void:
	var sim: Recorder = fresh(26)
	move(sim,323,100)
	for tick: int in 30000:
		var inp: SimInput = SimInput.new()
		var target: float = 443.0 if sim.player.y > 2260 else 323.0
		inp.right = sim.player.x < target-2
		inp.left = sim.player.x > target+2
		inp.eat = not sim.player.has_block
		inp.mouse_x = sim.player.center_x()-sim.camera.x
		inp.mouse_y = sim.player.center_y()+100-sim.camera.y
		inp.shoot_released = sim.player.has_block and tick % 3 == 0
		if inp.shoot_released:
			inp.mouse_y += 0
		sim.step(inp)
		if sim.player.dead or sim.player.won:
			break
	finish(sim,26)
	print("DIG26 carry=",sim.player.has_block," eat=",sim.player.eating_progress," vy=",sim.player.vy," block=",sim.level.get_cell(floori((sim.player.y+40)/40),8)," pos=",Vector2(sim.player.x,sim.player.y)," dead=",sim.player.dead," won=",sim.player.won)
	get_tree().quit()

func bridge_probe() -> void:
	var base: Recorder = fresh(27)
	move(base,83,20)
	_macro(base,"E2,3",false)
	shot(base,0,0)
	for wait_ticks: int in range(0,31):
		var loaded: Recorder = clone(base)
		move(loaded,83,wait_ticks)
		_macro(loaded,"E2,2",false)
		for delay: int in [0,2,4,8,12,18]:
			for angle: float in [90.0,110.0,130.0,150.0,170.0,180.0,200.0]:
				var sim: Recorder = clone(loaded)
				move(sim,923,delay,true)
				shot(sim,angle)
				move(sim,923,300,true)
				if finish(sim,27):
					print("PINBALL27 wait=",wait_ticks," delay=",delay," angle=",angle)
					get_tree().quit()
					return
	get_tree().quit()

func roof_route() -> void:
	var base: Recorder = fresh(28)
	_macro(base,"E1,0",false)
	move(base,-30,21)
	move(base,-70,1)
	move(base,-70,15,true,true)
	move(base,2363,740,true)
	shot(base,0,0)
	move(base,2363,30)
	_macro(base,"E1,59",false)
	shot(base,0,0)
	for duration: int in range(1,31):
		var sim: Recorder = clone(base)
		move(sim,2405,duration,true,true)
		for tick: int in 180:
			var target: float = 2363 if sim.player.y > 0 else 2405
			move(sim,target,1)
			if sim.player.y > 45 and sim.player.x < 2370:
				break
		if sim.player.dead:
			continue
		print("ROOF ENTER ",duration," ",Vector2(sim.player.x,sim.player.y))
		move(sim,2375,12)
		_macro(sim,"E2,59",false)
		shot(sim,-90,0)
		_macro(sim,"E3,59",false)
		for tick: int in 300:
			if sim.player.has_block and sim.player.y > 95 and sim.player.vy > 0:
				break
			var inp: SimInput = SimInput.new()
			inp.eat = not sim.player.has_block
			inp.mouse_x = 2380-sim.camera.x
			inp.mouse_y = 140-sim.camera.y
			sim.step(inp)
		print("ROOF LAUNCH ",Vector2(sim.player.x,sim.player.y)," carry= ",sim.player.has_block," vy= ",sim.player.vy," cells= ",[sim.level.get_cell(2,59),sim.level.get_cell(3,59)])
		shot(sim,10,-1)
		move(sim,2243,160)
		print("ROOF FINAL ",Vector2(sim.player.x,sim.player.y)," dead=",sim.player.dead)
		if finish(sim,28):
			print("ROOF SUCCESS jump=",duration)
			get_tree().quit()
			return
	get_tree().quit()

func outside_shaft() -> void:
	var base: Recorder = fresh(26)
	move(base,323,100)
	print("OUT A ",Vector2(base.player.x,base.player.y))
	_macro(base,"E4,8",false)
	print("OUT B ",Vector2(base.player.x,base.player.y))
	for tick: int in 200:
		if base.player.y > 160 and base.player.vy > 0:
			break
		move(base,283,1)
	shot(base,0,-1)
	for tick: int in 30:
		var inp: SimInput = SimInput.new()
		inp.left = base.player.x > 285
		inp.right = base.player.x < 281
		inp.eat = true
		inp.mouse_x = 340-base.camera.x
		inp.mouse_y = 220-base.camera.y
		base.step(inp)
	print("OUT C ",Vector2(base.player.x,base.player.y))
	for tick: int in 300:
		if base.player.y > 1900:
			break
		move(base,283,1)
	print("OUTSIDE BASE ",Vector2(base.player.x,base.player.y)," carry=",base.player.has_block)
	for variant: int in 210:
		var threshold: int = 2220 + floori(float(variant) / 21.0) * 2
		var hover_angle: float = 80.0 + variant % 21
		var hovering: Recorder = clone(base)
		for tick: int in 100:
			if hovering.player.y >= threshold:
				break
			move(hovering,283,1)
		shot(hovering,hover_angle,0)
		for tick: int in 180:
			var inp: SimInput = SimInput.new()
			inp.eat = true
			inp.right = hovering.player.x < 282
			inp.left = hovering.player.x > 284
			inp.mouse_x = 340-hovering.camera.x
			inp.mouse_y = 2220-hovering.camera.y
			hovering.step(inp)
			if hovering.player.has_block and hovering.player.y >= 2200 and hovering.player.vy > 0:
				break
		if hovering.player.y > 2206 or hovering.level.get_cell(55,8) != Tile.AIR:
			continue
		for angle: float in [160.0,165.0,170.0,175.0,178.0,180.0]:
			var sim: Recorder = clone(hovering)
			shot(sim,angle)
			move(sim,443,220)
			if finish(sim,26):
				print("OUTSIDE26 ",threshold," ",angle)
				get_tree().quit()
				return
	get_tree().quit()

func maze_route() -> void:
	if FileAccess.file_exists(OUT+"/maze29_glass.json"):
		maze_climb()
		return
	var sim: Recorder = fresh(29)
	move(sim,203,120)
	move(sim,203,8,true,true)
	_macro(sim,"E11,6",false)
	shot(sim,180,1)
	move(sim,1430,600,true,true)
	for col: int in range(34,29,-1):
		for tick: int in 300:
			if sim.player.has_block:
				break
			var inp: SimInput = SimInput.new()
			inp.left = sim.player.x > (col+1)*40+3
			inp.eat = true
			inp.mouse_x = col*40+20-sim.camera.x
			inp.mouse_y = 460-sim.camera.y
			inp.jump = true
			inp.jump_pressed = sim.player.grounded or sim.player.coyote_timer == 1
			sim.step(inp)
		print("GLASS AMMO ",col," ",Vector2(sim.player.x,sim.player.y)," has=",sim.player.has_block)
		if not sim.player.has_block:
			break
		move(sim,1483,150)
		shot(sim,-90,0)
		move(sim,1483,100)
		print("GLASS SHOT ",col," bottom=",sim.level.get_cell(6,37)," top=",sim.level.get_cell(2,37))
	FileAccess.open(OUT+"/maze29_glass.json",FileAccess.WRITE).store_string(JSON.stringify(sim.frames))
	get_tree().quit()

func roof_boss() -> void:
	var base: Recorder = fresh(30)
	_macro(base,"E0,2",false)
	shot(base,180,1)
	for col: int in range(5,10):
		for tick: int in 1200:
			if base.player.has_block or base.player.dead:
				break
			var inp: SimInput = SimInput.new()
			inp.right = base.player.x < col*40+1
			inp.left = base.player.x > col*40+5
			inp.eat = base.player.eating_progress > 0 or (base.player.y > 525 and base.player.vy < 0)
			inp.mouse_x = col*40+20-base.camera.x
			inp.mouse_y = 620-base.camera.y
			base.step(inp)
		print("PREDIG ",col," cell=",base.level.get_cell(15,col)," carry=",base.player.has_block," pos=",Vector2(base.player.x,base.player.y)," dead=",base.player.dead)
		if not base.player.has_block or base.player.dead:
			get_tree().quit()
			return
		if col < 9:
			shot(base,180,1)
	for tick: int in 1200:
		if base.player.y < 55 and base.player.vy < 0 and absf(base.player.x-83)<4:
			break
		move(base,83,1)
	print("ROOF BOSS LAUNCH ",Vector2(base.player.x,base.player.y)," carry= ",base.player.has_block," hole= ",base.level.get_cell(0,2))
	shot(base,90,0)
	for tick: int in 100:
		if base.player.y < -35:
			break
		move(base,83,1)
	print("ROOF BOSS CLEAR ",Vector2(base.player.x,base.player.y))
	move(base,163,40,true)
	print("BOSS ROOF ",Vector2(base.player.x,base.player.y)," dead=",base.player.dead)
	for parking: float in [303.0,243.0,343.0,203.0,403.0,603.0,803.0,1203.0,1603.0]:
		var sim: Recorder = clone(base)
		for tick: int in 10000:
			var target: float = parking if sim.boss.triggered else 803.0
			if sim.boss.dead:
				target = 963.0
			var inp: SimInput = SimInput.new()
			inp.right = sim.player.x < target-3
			inp.left = sim.player.x > target+3
			inp.jump = not sim.boss.dead
			inp.jump_pressed = inp.jump and (sim.player.grounded or sim.player.coyote_timer == 2)
			if sim.boss.dead:
				inp.eat = not sim.player.has_block
				inp.mouse_x = 980-sim.camera.x
				inp.mouse_y = 380-sim.camera.y
				inp.shoot_released = sim.player.has_block and tick % 3 == 0
				if inp.shoot_released:
					inp.mouse_x = sim.player.center_x()+200-sim.camera.x
					inp.mouse_y = sim.player.center_y()-0.03-sim.camera.y
			sim.step(inp)
			if sim.player.dead or sim.player.won:
				break
		if finish(sim,30):
			print("BOSS ROOF WON parking=",parking)
			get_tree().quit()
			return
		print("ROOF BOSS TRY ",parking," hp=",sim.boss.durability," bossdead=",sim.boss.dead," pos=",Vector2(sim.player.x,sim.player.y)," dead=",sim.player.dead)
	get_tree().quit()

func diagonal_bridge() -> void:
	if FileAccess.file_exists(OUT+"/partial_27.json"):
		continue_bridge()
		return
	var base: Recorder = fresh(27)
	move(base,123,30)
	for tick: int in 5000:
		var inp: SimInput = SimInput.new()
		inp.right = base.player.x < 121
		inp.left = base.player.x > 125
		inp.eat = not base.player.has_block and base.level.get_cell(8,3) != Tile.AIR
		inp.mouse_x = base.player.center_x()-base.camera.x
		inp.mouse_y = base.player.center_y()+100-base.camera.y
		inp.shoot_released = base.player.has_block and tick % 3 == 0
		if inp.shoot_released:
			inp.mouse_y -= 200
		base.step(inp)
		if base.player.y > 320 and base.player.grounded and not base.player.has_block:
			break
	print("DIAGONAL BASE ",Vector2(base.player.x,base.player.y)," dead=",base.player.dead," floor=",base.level.get_cell(9,3))
	_macro(base,"E8,2",false)
	for delay: int in range(6,25):
		for angle: float in [90.0,97.0,105.0,115.0,125.0,135.0]:
			var sim: Recorder = clone(base)
			move(sim,203,delay,true,true)
			shot(sim,angle)
			move(sim,163,100,true)
			if not sim.player.dead and sim.player.x > 150 and sim.player.grounded and sim.player.y < 320:
				print("DIAGONAL STEP ",delay," ",angle," pos=",Vector2(sim.player.x,sim.player.y))
				FileAccess.open(OUT+"/partial_27.json",FileAccess.WRITE).store_string(JSON.stringify(sim.frames))
				get_tree().quit()
				return
	get_tree().quit()

func seek(source: Recorder, target: Vector2, harvest: bool) -> Recorder:
	var beam: Array[Recorder] = [source]
	for depth: int in 65:
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
					for col: int in range(1,4):
						if not Tile.is_eatable(state.level.get_cell(row,col)):
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
				if sim.player.dead or sim.player.x > maxf(target.x+160,source.player.x+40) or sim.player.x < 35:
					continue
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
		beam.assign(candidates.slice(0,45))
		if beam.is_empty():
			break
	return null

func continue_bridge() -> void:
	if FileAccess.file_exists(OUT+"/stair27_6.json"):
		bridge_walk()
		return
	var current: Recorder = fresh(27)
	var replay: ReplayInput = ReplayInput.new()
	replay.sim = current
	replay.frames = JSON.parse_string(FileAccess.get_file_as_string(OUT+"/stair27_5.json"))
	for tick: int in replay.frames.size():
		current.step(replay.sample(Vector2.ZERO))
	for tier: int in range(6,7):
		var endpoint: Vector2 = Vector2(123+tier*40,326-tier*40)
		print("HARVEST TIER ",tier," pos=",Vector2(current.player.x,current.player.y))
		var loaded: Recorder = seek(current,Vector2(123,206),true)
		if loaded == null:
			print("NO MUD")
			break
		var staged: Recorder = seek(loaded,endpoint,false)
		if staged == null:
			print("NO RETURN ",Vector2(loaded.player.x,loaded.player.y))
			break
		var found: Recorder
		for delay: int in range(9,24):
			for angle: float in [97.0,90.0,105.0,115.0,125.0,135.0]:
				var sim: Recorder = clone(staged)
				move(sim,endpoint.x+80,delay,true,true)
				shot(sim,angle)
				move(sim,endpoint.x+40,100,true)
				if not sim.player.dead and sim.player.grounded and absf(sim.player.x-endpoint.x-40)<4 and absf(sim.player.y-endpoint.y+40)<4:
					found = sim
					break
			if found != null:
				break
		if found == null:
			print("NO STAIR")
			break
		current = found
		FileAccess.open(OUT+"/stair27_%d.json"%tier,FileAccess.WRITE).store_string(JSON.stringify(current.frames))
		print("STAIR ",tier+1," pos=",Vector2(current.player.x,current.player.y)," ticks=",current.frames.size())
	get_tree().quit()


















func bridge_walk() -> void:
	var current: Recorder = fresh(27)
	var replay: ReplayInput = ReplayInput.new()
	replay.sim = current
	replay.frames = JSON.parse_string(FileAccess.get_file_as_string(OUT+"/walk27_11.json"))
	for tick: int in replay.frames.size():
		current.step(replay.sample(Vector2.ZERO))
	for col: int in range(12,20):
		move(current,col*40-21,10)
		_macro(current,"E2,%d"%(col-1),false)
		move(current,col*40+3,10)
		if not current.player.has_block:
			print("RECYCLE EMPTY")
			break
		print("WALK AMMO ",col," carry=",current.player.has_block," pos=",Vector2(current.player.x,current.player.y))
		if not current.player.has_block:
			break
		# First try a direct recoil crossing from the current edge.
		for delay: int in range(0,40):
			for angle: float in [120.0,135.0,150.0,165.0,175.0]:
				var fly: Recorder = clone(current)
				move(fly,923,delay,true,true)
				shot(fly,angle)
				move(fly,923,220,true)
				if finish(fly,27):
					print("BRIDGE FLY ",col," ",delay," ",angle)
					get_tree().quit()
					return
		var found: Recorder
		for delay: int in range(1,30):
			for angle: float in [120.0,135.0,150.0,165.0,175.0,180.0]:
				var sim: Recorder = clone(current)
				move(sim,(col+2)*40+3,delay)
				shot(sim,angle)
				move(sim,(col+1)*40+3,100,true)
				if not sim.player.dead and sim.player.grounded and absf(sim.player.x-((col+1)*40+3))<4 and absf(sim.player.y-46)<4:
					found = sim
					print("WALK PLACE ",delay," ",angle)
					break
			if found != null:
				break
		if found == null:
			print("NO WALK")
			break
		current = found
		FileAccess.open(OUT+"/walk27_%d.json"%col,FileAccess.WRITE).store_string(JSON.stringify(current.frames))
	get_tree().quit()

func replay_file(stage: int, name: String) -> Recorder:
	var sim: Recorder = fresh(stage)
	var replay: ReplayInput = ReplayInput.new()
	replay.sim = sim
	replay.frames = JSON.parse_string(FileAccess.get_file_as_string(OUT+"/"+name))
	for tick: int in replay.frames.size():
		sim.step(replay.sample(Vector2.ZERO))
	return sim

func maze_ammo(sim: Recorder, col: int) -> void:
	for tick: int in 500:
		if sim.player.has_block:
			return
		var inp: SimInput = SimInput.new()
		inp.left = sim.player.x > (col+1)*40+3
		inp.eat = true
		inp.mouse_x = col*40+20-sim.camera.x
		inp.mouse_y = 460-sim.camera.y
		inp.jump = true
		inp.jump_pressed = sim.player.grounded or sim.player.coyote_timer == 2
		sim.step(inp)

func maze_climb() -> void:
	var base: Recorder = replay_file(29,"maze29_glass.json")
	maze_ammo(base,29)
	move(base,1483,180)
	shot(base,-90,0)
	move(base,1483,180)
	print("BOUNCE FLOOR ",base.level.get_cell(13,37)," pos=",Vector2(base.player.x,base.player.y))
	maze_ammo(base,28)
	move(base,1483,180)
	print("CLIMB BASE ",Vector2(base.player.x,base.player.y)," carry=",base.player.has_block)
	FileAccess.open(OUT+"/maze29_launch.json",FileAccess.WRITE).store_string(JSON.stringify(base.frames))
	var phase: int = 0
	for tick: int in 3000:
		var inp: SimInput = SimInput.new()
		inp.left = base.player.x > 1484
		inp.right = base.player.x < 1482
		inp.jump = true
		inp.jump_pressed = base.player.grounded or base.player.coyote_timer == 2
		if phase == 0 and base.player.y < 300 and base.player.vy > -0.5:
			inp.shoot_released = true
			phase = 1
			print("BOOST ONE ",Vector2(base.player.x,base.player.y))
		elif phase == 1 and base.player.y > 450 and base.player.vy < -5:
			phase = 2
			print("RECATCH START ",Vector2(base.player.x,base.player.y))
		if phase == 2:
			inp.eat = true
			if base.player.has_block:
				phase = 3
				print("RECATCH DONE ",Vector2(base.player.x,base.player.y))
		if phase == 3 and base.player.vy > -0.5 and base.player.y < 220:
			inp.shoot_released = true
			phase = 4
			print("BOOST TWO ",Vector2(base.player.x,base.player.y))
		inp.mouse_x = base.player.center_x()-base.camera.x
		inp.mouse_y = base.player.center_y()+200-base.camera.y
		base.step(inp)
		if base.player.won or base.player.dead:
			break
	print("MAZE FINAL phase=",phase," pos=",Vector2(base.player.x,base.player.y))
	finish(base,29)
	get_tree().quit()
