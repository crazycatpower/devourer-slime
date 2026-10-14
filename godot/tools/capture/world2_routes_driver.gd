extends "res://tools/capture/scaffold_driver.gd"

func fresh(stage: int, partial: bool = false) -> Recorder:
	var sim: Recorder = Recorder.new()
	sim.load_level(stage, LevelLibrary.shipped_level(stage), LevelLibrary.boss_kind_for_slot(stage))
	sim.rng.set_seed(7)
	sim.bullet_time_enabled = false
	if partial:
		var actions: Array = JSON.parse_string(FileAccess.get_file_as_string("res://build/recordings/world2/partial_%d.json" % stage))
		var held: bool = false
		for action: String in actions:
			held = _macro(sim, action, held)
	return sim

func fire(sim: Recorder, degrees: float, direction: int = 0) -> void:
	var inp: SimInput = SimInput.new()
	inp.left = direction < 0
	inp.right = direction > 0
	inp.jump = true
	inp.shoot_released = true
	var angle: float = deg_to_rad(degrees)
	inp.mouse_x = sim.player.center_x() + cos(angle)*200.0 - sim.camera.x
	inp.mouse_y = sim.player.center_y() + sin(angle)*200.0 - sim.camera.y
	sim.step(inp)

func finish(sim: Recorder, stage: int) -> void:
	print("RESULT slot=", stage, " won=",sim.player.won," dead=",sim.player.dead," pos=",Vector2(sim.player.x,sim.player.y)," ticks=",sim.frames.size())
	if sim.player.won and not sim.player.dead:
		FileAccess.open("res://build/recordings/world2/direct_%d.json" % stage, FileAccess.WRITE).store_string(JSON.stringify(sim.frames))
	get_tree().quit(0 if sim.player.won else 1)

func gap15() -> void:
	var base: Recorder = fresh(15, true)
	print("BASE ",Vector2(base.player.x,base.player.y)," carry=",base.player.has_block)
	var best: float = 0.0
	for launch: float in [255.0, 265.0, 275.0, 279.0]:
		var start: Recorder = clone(base)
		move(start, launch, 40)
		for delay: int in range(1, 57):
			for angle: float in [112.5, 125.0, 135.0, 145.0, 157.5, 170.0, 180.0]:
				var trial: Recorder = clone(start)
				move(trial, 930.0, delay, true, true)
				fire(trial, angle, 1)
				move(trial, 930.0, 180, true)
				if trial.player.x > best and trial.player.y < 310.0:
					best = trial.player.x
					print("BEST ",launch," ",delay," ",angle," pos=",Vector2(trial.player.x,trial.player.y))
				if trial.player.won:
					finish(trial, 15)
					return
	finish(base,15)

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "16" in args:
		bridge16()
	elif "12" in args:
		road12()
	elif "13" in args:
		stairs13()
	elif "17" in args:
		upper17()
	elif "19" in args:
		diagonal19()
	elif "14" in args:
		recycle14()
	elif "18" in args:
		middle18()
	else:
		gap15()

func bridge16() -> void:
	var base: Recorder = fresh(16)
	move(base, 103.0, 30)
	_macro(base, "E1,3", false)
	move(base, 143.0, 20)
	print("BRIDGE BASE ",Vector2(base.player.x,base.player.y)," carry=",base.player.has_block)
	for angle: int in range(10,81,2):
		var trial: Recorder = clone(base)
		fire(trial, float(angle))
		move(trial,143.0,80)
		if Tile.is_solid(trial.level.get_cell(2,5)) or Tile.is_solid(trial.level.get_cell(2,4)):
			print("PLACED angle=",angle," tiles=",trial.level.get_cell(2,4),",",trial.level.get_cell(2,5)," pos=",Vector2(trial.player.x,trial.player.y))
			move(trial,250.0,4)
			print("EDGE ",Vector2(trial.player.x,trial.player.y))
			move(trial, 250.0, 45,true,true)
			print("AFTER JUMP ",Vector2(trial.player.x,trial.player.y))
			if trial.player.y > 47.0:
				continue
			_macro(trial,"E2,5" if Tile.is_solid(trial.level.get_cell(2,5)) else "E2,4",false)
			print("CROSSED carry=",trial.player.has_block," pos=",Vector2(trial.player.x,trial.player.y))
			move(trial,463.0,75)
			move(trial,515.0,4)
			move(trial,515.0,23,true,true)
			move(trial,745.0,75)
			print("FINAL GAP ",Vector2(trial.player.x,trial.player.y)," carry=",trial.player.has_block)
			for second: int in range(10,81,2):
				var end: Recorder = clone(trial)
				fire(end,float(second))
				move(end,745.0,70)
				move(end,850.0,4)
				move(end,850.0,45,true,true)
				move(end,930.0,40)
				if end.player.won:
					print("SECOND ANGLE ",second)
					finish(end,16)
					return
	finish(base,16)

func stairs13() -> void:
	var sim: Recorder = fresh(13)
	var actions: Array = JSON.parse_string(FileAccess.get_file_as_string("res://build/recordings/world2/partial_13.json"))
	var held: bool = false
	for i: int in actions.size():
		held = _macro(sim,str(actions[i]),held)
		if str(actions[i])=="E13,13":
			break
	move(sim,603.0,25)
	move(sim,631.0,70,true,true)
	print("STAIRS BASE ",Vector2(sim.player.x,sim.player.y)," carry=",sim.player.has_block)
	for tier: int in 2:
		var found: Recorder
		for x: float in ([620.0,630.0,640.0] if tier==0 else [660.0]):
			for delay: int in range(6,39,2):
				for angle: float in [0.0,22.5,45.0,67.5,90.0]:
					var trial: Recorder = clone(sim)
					if tier==0:
						move(trial,x,25)
					else:
						var row: int = floori((trial.player.y+trial.player.h+2.0)/40.0)
						var col: int = floori(trial.player.center_x()/40.0)
						_macro(trial,"E%d,%d"%[row,col],false)
					move(trial,trial.player.x,delay,true,true)
					fire(trial,angle,1)
					move(trial,663.0 if tier==0 else 703.0,90,true)
					if trial.player.grounded and trial.player.y < sim.player.y-105.0 and not trial.player.dead:
						var support: int = trial.level.get_cell(floori((trial.player.y+trial.player.h+2.0)/40.0),floori(trial.player.center_x()/40.0))
						if tier == 0 and not Tile.is_eatable(support):
							continue
						if found==null or trial.player.y < found.player.y:
							found=trial
							print("STAIR ",tier," delay=",delay," angle=",angle," pos=",Vector2(trial.player.x,trial.player.y))
		if found==null:
			finish(sim,13)
			return
		sim=found
	move(sim,930.0,100,true,true)
	move(sim,930.0,100)
	finish(sim,13)

func place_road(sim: Recorder, col: int) -> Recorder:
	for half_angle: int in range(-120,51):
		var trial: Recorder = clone(sim)
		fire(trial,float(half_angle)*0.5)
		move(trial,sim.player.x,110)
		if not trial.player.dead and Tile.is_eatable(trial.level.get_cell(5,col)):
			print("ROAD col=",col," angle=",float(half_angle)*0.5," pos=",Vector2(trial.player.x,trial.player.y))
			return trial
	print("ROAD FAILED col=",col," pos=",Vector2(sim.player.x,sim.player.y)," carry=",sim.player.has_block)
	return null

func road12() -> void:
	var sim: Recorder = fresh(12)
	move(sim,123.0,90)
	for placed: int in 13:
		var row: int = floori((sim.player.y+sim.player.h+2.0)/40.0)
		var col: int = floori(sim.player.center_x()/40.0)
		_macro(sim,"E%d,%d"%[row,col],false)
		move(sim,sim.player.x,20)
		var top: Vector2i = Vector2i(3,20)
		for c: int in [3,2,1]:
			for r: int in range(5,14):
				if Tile.is_solid(sim.level.get_cell(r,c)):
					if r<top.y:
						top=Vector2i(c,r)
					break
		move(sim,float(top.x)*40.0+3.0,75,true,true)
		print("HARVEST ",placed," pos=",Vector2(sim.player.x,sim.player.y)," carry=",sim.player.has_block)
		if placed>=6:
			for launch: float in [sim.player.x,143.0,153.0]:
				var start: Recorder = clone(sim)
				move(start,launch,40)
				for delay: int in range(16,53,2):
					for angle: float in [90.0,105.0,115.0,125.0,135.0,145.0]:
						var trial: Recorder = clone(start)
						move(trial,930.0,delay,true,true)
						fire(trial,angle,1)
						move(trial,930.0,250,true)
						if trial.player.won:
							finish(trial,12)
							return
		sim=place_road(sim,20-placed)
		if sim==null:
			get_tree().quit(1)
			return
	finish(sim,12)

func place_cell(sim: Recorder, cell: Vector2i, jump_arc: bool = false) -> Recorder:
	for delay: int in ([18,24,30,36] if jump_arc else [0]):
		for half_angle: int in (range(180,360) if jump_arc else range(-358,1)):
			var trial: Recorder = clone(sim)
			if delay>0:
				move(trial,sim.player.x,delay,true,true)
			fire(trial,float(half_angle)*0.5)
			move(trial,sim.player.x,110)
			if not trial.player.dead and Tile.is_eatable(trial.level.get_cell(cell.y,cell.x)):
				print("CELL ",cell," angle=",float(half_angle)*0.5," delay=",delay," pos=",Vector2(trial.player.x,trial.player.y))
				return trial
	print("NO CELL ",cell," pos=",Vector2(sim.player.x,sim.player.y)," carry=",sim.player.has_block)
	return null

func upper17() -> void:
	var sim: Recorder = fresh(17,true)
	move(sim,500.0,75,true,true)
	move(sim,123.0,130)
	print("RETURN ",Vector2(sim.player.x,sim.player.y)," carry=",sim.player.has_block)
	sim=place_cell(sim,Vector2i(9,2))
	if sim==null:
		get_tree().quit(1)
		return
	move(sim,523.0,110)
	move(sim,723.0,75,true,true)
	move(sim,743.0,15)
	_macro(sim,"E11,19",false)
	move(sim,743.0,2)
	print("SECOND ",Vector2(sim.player.x,sim.player.y)," carry=",sim.player.has_block)
	sim=place_cell(sim,Vector2i(14,2))
	if sim==null:
		get_tree().quit(1)
		return
	move(sim,803.0,70,true,true)
	_macro(sim,"E11,20",false)
	move(sim,723.0,65,true,true)
	print("HOP BACK ",Vector2(sim.player.x,sim.player.y)," grounded=",sim.player.grounded)
	move(sim,713.0,4)
	move(sim,500.0,85,true,true)
	move(sim,523.0,20)
	print("THIRD ",Vector2(sim.player.x,sim.player.y)," carry=",sim.player.has_block)
	sim=place_cell(sim,Vector2i(16,2))
	if sim==null:
		get_tree().quit(1)
		return
	move(sim,723.0,75,true,true)
	move(sim,713.0,8)
	_macro(sim,"E11,18",false)
	move(sim,500.0,80,true,true)
	move(sim,123.0,130)
	move(sim,123.0,2)
	fire(sim,90.0)
	move(sim,123.0,65)
	print("CLIMB BASE ",Vector2(sim.player.x,sim.player.y)," carry=",sim.player.has_block)
	var found: Recorder
	for delay: int in range(20,36):
		for steer_delay: int in range(10,31,2):
			var trial: Recorder = clone(sim)
			_macro(trial,"E10,3",false)
			move(trial,123.0,delay,true,true)
			fire(trial,90.0)
			move(trial,123.0,steer_delay,true)
			move(trial,83.0,70,true)
			if not trial.player.dead and trial.player.grounded and trial.player.y<180.0:
				found=trial
				print("CLIMBED ",Vector2(trial.player.x,trial.player.y)," delay=",delay," steer=",steer_delay)
				break
		if found!=null:
			break
	if found==null:
		finish(sim,17)
		return
	sim=found
	for launch: float in [100.0,108.0,113.0]:
		for delay: int in range(14,25):
			var trial: Recorder=clone(sim)
			move(trial,launch,20)
			move(trial,launch,delay,true,true)
			move(trial,183.0,70,true)
			if trial.player.y>47.0:
				continue
			move(trial,303.0,40)
			move(trial,383.0,4)
			move(trial,383.0,35,true,true)
			move(trial,583.0,60)
			move(trial,683.0,4)
			move(trial,683.0,40,true,true)
			move(trial,930.0,100)
			if trial.player.won:
				finish(trial,17)
				return
	finish(sim,17)

func diagonal19() -> void:
	var sim: Recorder = fresh(19)
	move(sim,323.0,100)
	print("SOURCE START ",Vector2(sim.player.x,sim.player.y)," row=",Array(sim.level._cells.slice(11*25,12*25)))
	for stair: int in 6:
		var source_col: int = 8-stair
		if stair>0:
			for c: int in range(9+stair,8,-1):
				move(sim,float(c)*40.0+3.0,35)
			move(sim,float(source_col)*40.0+3.0,100)
		_macro(sim,"E11,%d"%source_col,false)
		print("EAT SOURCE ",Vector2(sim.player.x,sim.player.y)," row=",Array(sim.level._cells.slice(11*25,12*25)))
		move(sim,323.0,110)
		print("JUMP START ",Vector2(sim.player.x,sim.player.y)," grounded=",sim.player.grounded)
		move(sim,323.0,22,true,true)
		move(sim,383.0,70,true)
		for c: int in range(10,10+stair):
			move(sim,float(c)*40.0+3.0,65,true,true)
		print("DIAGONAL BASE ",stair," pos=",Vector2(sim.player.x,sim.player.y)," carry=",sim.player.has_block," dead=",sim.player.dead)
		var cell: Vector2i = Vector2i(10+stair,10-stair)
		var found: Recorder
		for delay: int in range(6,47,2):
			for angle: int in range(95,166):
				var trial: Recorder=clone(sim)
				move(trial,float(cell.x)*40.0+43.0,delay,true,true)
				fire(trial,float(angle),1)
				move(trial,float(cell.x)*40.0+3.0,90,true)
				if not trial.player.dead and trial.player.grounded and trial.player.y<float(cell.y)*40.0 and Tile.is_eatable(trial.level.get_cell(cell.y,cell.x)):
					found=trial
					print("DIAGONAL ",cell," delay=",delay," angle=",angle," pos=",Vector2(trial.player.x,trial.player.y))
					break
			if found!=null:
				break
		if found==null:
			finish(sim,19)
			return
		sim=found
	var row: int = floori((sim.player.y+sim.player.h+2.0)/40.0)
	var col: int = floori(sim.player.center_x()/40.0)
	_macro(sim,"E%d,%d"%[row,col],false)
	for delay: int in range(8,47,2):
		for angle: float in [90.0,105.0,115.0,125.0,135.0,145.0]:
			var trial: Recorder=clone(sim)
			move(trial,930.0,delay,true,true)
			fire(trial,angle,1)
			move(trial,930.0,160,true)
			if trial.player.won:
				finish(trial,19)
				return
	finish(sim,19)

func recycle14() -> void:
	var sim: Recorder=fresh(14)
	move(sim,83.0,90)
	_macro(sim,"E6,2",false)
	move(sim,83.0,40)
	move(sim,483.0,160)
	print("RECYCLE BASE ",Vector2(sim.player.x,sim.player.y)," carry=",sim.player.has_block," dead=",sim.player.dead)
	var found: Recorder
	for delay: int in range(10,37,2):
		for angle: float in [0.0,22.5,45.0,67.5,90.0]:
			var trial: Recorder=clone(sim)
			move(trial,483.0,delay,true,true)
			fire(trial,angle,1)
			move(trial,503.0,90,true)
			if trial.player.grounded and trial.player.y<410.0 and not trial.player.dead:
				var row: int=floori((trial.player.y+trial.player.h+2.0)/40.0)
				var col: int=floori(trial.player.center_x()/40.0)
				if Tile.is_eatable(trial.level.get_cell(row,col)):
					found=trial
					print("FIRST FOOT ",Vector2(trial.player.x,trial.player.y)," delay=",delay," angle=",angle)
					break
		if found!=null:
			break
	if found==null:
		finish(sim,14)
		return
	sim=found
	_macro(sim,"E%d,%d"%[floori((sim.player.y+sim.player.h+2.0)/40.0),floori(sim.player.center_x()/40.0)],false)
	move(sim,563.0,70,true,true)
	print("NATURAL ",Vector2(sim.player.x,sim.player.y)," carry=",sim.player.has_block)
	found=null
	for delay: int in range(8,37,2):
		for angle: int in range(0,91,5):
			var trial: Recorder=clone(sim)
			move(trial,563.0,delay,true,true)
			fire(trial,float(angle),1)
			move(trial,563.0,90,true)
			if not trial.player.dead and trial.player.grounded and absf(trial.player.y-205.999)<1.0 and Tile.is_eatable(trial.level.get_cell(6,14)):
				found=trial
				print("SECOND FOOT ",Vector2(trial.player.x,trial.player.y)," delay=",delay," angle=",angle)
				break
		if found!=null:
			break
	if found==null:
		finish(sim,14)
		return
	sim=found
	move(sim,523.0,65)
	move(sim,539.0,65,true,true)
	print("HARVEST NATURAL ",Vector2(sim.player.x,sim.player.y))
	found=null
	for launch: float in [530.0,532.0,534.0,536.0]:
		for left_ticks: int in range(5,24):
			var trial: Recorder=clone(sim)
			move(trial,launch,20)
			_macro(trial,"E9,14",false)
			move(trial,523.0,left_ticks,true,true)
			move(trial,563.0,75,true)
			if trial.player.grounded and trial.player.y<210.0 and trial.player.has_block:
				found=trial
				print("CARRY UP ",Vector2(trial.player.x,trial.player.y)," left=",left_ticks," launch=",launch)
				break
		if found!=null:
			break
	if found==null:
		finish(sim,14)
		return
	sim=found
	move(sim,643.0,70,true,true)
	move(sim,883.0,110)
	print("EXIT BASE ",Vector2(sim.player.x,sim.player.y)," carry=",sim.player.has_block," dead=",sim.player.dead)
	for delay: int in range(16,39):
		var trial: Recorder=clone(sim)
		move(trial,883.0,delay,true,true)
		fire(trial,90.0,1)
		move(trial,930.0,100,true)
		if trial.player.won:
			finish(trial,14)
			return
	finish(sim,14)

func diagonal_step(sim: Recorder, cell: Vector2i) -> Recorder:
	for delay: int in range(6,37,2):
		for angle: int in range(95,151):
			var trial: Recorder=clone(sim)
			move(trial,float(cell.x)*40.0+43.0,delay,true,true)
			fire(trial,float(angle),1)
			move(trial,float(cell.x)*40.0+3.0,90,true)
			if not trial.player.dead and trial.player.grounded and trial.player.y<float(cell.y)*40.0 and Tile.is_eatable(trial.level.get_cell(cell.y,cell.x)):
				print("STEP ",cell," delay=",delay," angle=",angle," pos=",Vector2(trial.player.x,trial.player.y))
				return trial
	print("STEP FAILED ",cell," base=",Vector2(sim.player.x,sim.player.y)," carry=",sim.player.has_block)
	return null

func middle18() -> void:
	var sim: Recorder=fresh(18)
	move(sim,123.0,70)
	move(sim,283.0,70)
	move(sim,283.0,65,true,true)
	_macro(sim,"E11,7",false)
	move(sim,323.0,70,true,true)
	print("MIDDLE BASE ",Vector2(sim.player.x,sim.player.y)," carry=",sim.player.has_block," dead=",sim.player.dead)
	sim=diagonal_step(sim,Vector2i(9,10))
	if sim==null:
		get_tree().quit(1)
		return
	move(sim,323.0,50)
	_macro(sim,"E11,8",false)
	move(sim,363.0,70,true,true)
	sim=diagonal_step(sim,Vector2i(10,9))
	if sim==null:
		get_tree().quit(1)
		return
	move(sim,663.0,90,true,true)
	_macro(sim,"E11,17",false)
	move(sim,663.0,2)
	print("RIGHT SOURCE ",Vector2(sim.player.x,sim.player.y)," carry=",sim.player.has_block," dead=",sim.player.dead)
	sim=place_cell(sim,Vector2i(11,8),true)
	if sim==null:
		get_tree().quit(1)
		return
	move(sim,643.0,20)
	_macro(sim,"E11,16",false)
	var found: Recorder
	for delay: int in range(8,45,2):
		for angle: float in [22.5,35.0,45.0,55.0,67.5,80.0,90.0]:
			var trial: Recorder=clone(sim)
			move(trial,443.0,delay,true,true)
			fire(trial,angle,-1)
			move(trial,443.0,100,true)
			if not trial.player.dead and trial.player.grounded and trial.player.y<290.0:
				found=trial
				print("RETURN HIGH ",Vector2(trial.player.x,trial.player.y)," delay=",delay," angle=",angle)
				break
		if found!=null:
			break
	if found==null:
		finish(sim,18)
		return
	sim=found
	_macro(sim,"E8,11",false)
	for delay: int in range(16,36):
		for steer_delay: int in range(14,30):
			var trial: Recorder=clone(sim)
			move(trial,403.0,delay,true,true)
			fire(trial,90.0)
			move(trial,403.0,steer_delay,true)
			move(trial,63.0,160,true)
			if trial.player.won:
				finish(trial,18)
				return
	finish(sim,18)

