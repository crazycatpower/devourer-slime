extends "res://tools/capture/scaffold_driver.gd"

func fresh(stage: int) -> Recorder:
	var path: String = OUT + "/maps/slot_%d.json" % stage
	if not FileAccess.file_exists(path):
		FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(LevelCodec.encode_document(LevelLibrary.shipped_level(stage))))
	var sim: Recorder = Recorder.new()
	sim.load_level(stage, LevelCodec.decode_document(JSON.parse_string(FileAccess.get_file_as_string(path))), LevelLibrary.boss_kind_for_slot(stage))
	sim.rng.set_seed(7)
	sim.bullet_time_enabled = false
	return sim

func finish(sim: Recorder, stage: int) -> bool:
	if not sim.player.won or sim.player.dead:
		return false
	var replay_sim: Recorder = fresh(stage)
	var replay: ReplayInput = ReplayInput.new()
	replay.sim = replay_sim
	replay.frames = JSON.parse_string(JSON.stringify(sim.frames))
	for tick: int in replay.frames.size():
		replay_sim.step(replay.sample(Vector2.ZERO))
	if not replay_sim.player.won or replay_sim.player.dead:
		print("REPLAY REJECT ",stage," pos=",Vector2(replay_sim.player.x,replay_sim.player.y))
		return false
	FileAccess.open(OUT + "/direct_%d.json" % stage, FileAccess.WRITE).store_string(JSON.stringify(sim.frames))
	print("SOLVED ",stage," ticks=",sim.frames.size())
	return true

func _ready() -> void:
	OUT = "res://build/recordings/world3"
	for delay: int in range(1,25):
		var stage: int = 24
		var highest: float = 1000
		var sim: Recorder = fresh(stage)
		if stage == 26:
			move(sim,393,95)
		if stage == 25:
			move(sim,280,75)
			_macro(sim,"E13,8",false)
		if stage == 23:
			move(sim,163,45)
			for destination: float in [323.0,483.0,643.0,803.0]:
				move(sim,destination,80,true,true)
			print("ISLANDS ",Vector2(sim.player.x,sim.player.y)," dead=",sim.player.dead)
			for tick: int in 80:
				var inp: SimInput = SimInput.new()
				inp.jump = true
				inp.jump_pressed = tick == 0
				inp.eat = true
				inp.mouse_x = 860 - sim.camera.x
				inp.mouse_y = 420 - sim.camera.y
				sim.step(inp)
			print("PICKUP ",sim.player.has_block," pos=",Vector2(sim.player.x,sim.player.y))
			for destination: float in [643.0,483.0,323.0,163.0]:
				for tick: int in 300:
					if sim.player.y > 480 and sim.player.vy < -10:
						break
					sim.step(SimInput.new())
				move(sim,destination,50,true)
				print("HOP ",destination," pos=",Vector2(sim.player.x,sim.player.y)," ground=",sim.player.grounded)
			print("RETURN ",Vector2(sim.player.x,sim.player.y)," dead=",sim.player.dead)
		if stage == 24:
			move(sim,83,16)
			move(sim,243,70,true,true)
		if stage == 27:
			move(sim,90,10)
		var phase: int = 0
		for tick: int in 1800:
			highest = minf(highest,sim.player.y)
			var inp: SimInput = SimInput.new()
			var target: float = 923.0 if sim.player.y < 150 else 883.0
			if stage in [23,24]:
				target = 923.0
				if stage == 24:
					if sim.player.y < 130:
						phase = 1
					target = 483.0 if phase == 1 else 203.0
					if sim.player.x > 465 and sim.player.vy < -12:
						phase = 2
					if phase == 2:
						target = 923.0
				if stage == 23:
					target = 43.0 if sim.player.y < 245 else 163.0
			if stage == 21:
				if sim.player.vy < -15 and phase == 0:
					phase = 1
				if sim.player.x > 465 and sim.player.vy < -15 and phase == 1:
					phase = 2
				if sim.player.x > 830 and sim.player.vy < -15 and phase == 2:
					phase = 3
				target = [123.0,483.0,843.0,923.0][phase]
			if stage == 25:
				target = 43.0 if sim.player.y < 130 else 283.0
			if stage == 26:
				target = 393.0
				if sim.player.y > 300 and sim.player.y < 720:
					target = 483.0
				if sim.player.y > 980 and sim.player.y < 1880:
					target = 483.0
				if sim.player.y > 1680 and sim.player.y < 1880:
					target = 483.0
				if sim.player.y > 2140:
					target = 443.0
			inp.right = sim.player.x < target - 3
			inp.left = sim.player.x > target + 3
			inp.jump = true
			inp.jump_pressed = sim.player.grounded
			if stage in [23,24]:
				inp.jump_pressed = sim.player.grounded or sim.player.coyote_timer == delay
			inp.mouse_x = sim.player.center_x() - sim.camera.x
			inp.mouse_y = sim.player.center_y() + 100 - sim.camera.y
			inp.eat = not sim.player.has_block
			inp.shoot_released = sim.player.has_block and sim.player.vy > -2.0 and sim.player.y < 450
			if stage == 24:
				inp.shoot_released = inp.shoot_released and phase == 2
			if stage == 24 and not sim.player.has_block:
				var nearest: float = 110.0
				for r: int in sim.level.rows:
					for c: int in sim.level.cols:
						if Tile.is_bouncy(sim.level.get_cell(r,c)):
							var point: Vector2 = Vector2(c*40+20,r*40+20)
							var distance: float = point.distance_to(Vector2(sim.player.center_x(),sim.player.center_y()))
							if distance < nearest:
								nearest = distance
								inp.mouse_x = point.x - sim.camera.x
								inp.mouse_y = point.y - sim.camera.y
			if stage == 25 and not sim.player.has_block:
				inp.mouse_x += 100
				inp.mouse_y -= 100
			if stage in [21,26]:
				inp.jump = false
				inp.jump_pressed = false
				inp.eat = false
			sim.step(inp)
			if sim.player.won or sim.player.dead:
				break
		if not finish(sim,stage):
			print("PROBE delay=",delay," highest=",highest," stage=",stage," pos=",Vector2(sim.player.x,sim.player.y)," dead=",sim.player.dead," carry=",sim.player.has_block)
	get_tree().quit()



