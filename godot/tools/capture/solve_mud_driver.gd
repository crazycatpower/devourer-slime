extends "res://tools/capture/record_world1_driver.gd"

func _ready() -> void:
	for mode: int in 8:
		for offset: float in [35.0, 55.0, 75.0, 95.0]:
			var sim: Recorder = Recorder.new()
			sim.rng.set_seed(7)
			sim.load_level(20, LevelLibrary.shipped_level(20), BossState.Kind.MUD_GOLEM)
			sim.bullet_time_enabled = false
			var previous_jump: bool = false
			var evade_side: float = -1.0
			var was_jumping: bool = false
			for tick: int in 7200:
				var inp: SimInput = SimInput.new()
				var boss: BossState = sim.boss
				var core: Vector2 = Vector2(boss.cell_x(BossState.MUD_GOLEM_CENTER) + 20.0, boss.cell_y(BossState.MUD_GOLEM_CENTER) + 20.0)
				var side: float = -1.0 if sim.player.center_x()<core.x else 1.0
				var target_x: float = core.x + side * offset
				var jumping: bool = boss.state==BossState.State.JUMPING
				var evading: bool = jumping or boss.cooldown < (40 if mode<4 else 60)
				if jumping and not was_jumping:
					evade_side= -side
				was_jumping=jumping
				if evading:
					target_x=core.x + (evade_side if jumping and boss.y+boss.h<sim.player.y-15.0 else side)*280.0
				if not boss.has_initialized_reorg_grid or boss.reorg_timer > 0:
					target_x = core.x - 300.0
				if boss.dead:
					for r: int in sim.level.rows:
						for c: int in sim.level.cols:
							if sim.level.get_cell(r, c) == Tile.GOAL:
								core = (Vector2(c, r) + Vector2(0.5, 0.5)) * Tile.SIZE
					target_x = core.x
				inp.right = sim.player.center_x() < target_x - 5.0
				inp.left = sim.player.center_x() > target_x + 5.0
				inp.jump = not evading and (tick % (50 + (mode%4)*10)) < 40
				inp.jump_pressed = inp.jump and not previous_jump
				previous_jump = inp.jump
				inp.eat = not sim.player.has_block
				var aim: Vector2 = core
				if sim.player.has_block:
					inp.shoot_released = true
					aim = Vector2(sim.player.center_x() - signf(core.x - sim.player.center_x()) * 150.0, sim.player.center_y() + (100.0 if mode % 2 == 0 else 0.0))
				inp.mouse_x = aim.x - sim.camera.x
				inp.mouse_y = aim.y - sim.camera.y
				sim.step(inp)
				if sim.player.dead or sim.player.won:
					break
			print("MUD mode=", mode, " offset=", offset, " ticks=", sim.frames.size(), " won=",sim.player.won," dead=",sim.player.dead," bricks=",sim.boss.filled_count())
			if sim.player.won:
				FileAccess.open("res://build/recordings/world2/direct_20.json", FileAccess.WRITE).store_string(JSON.stringify(sim.frames))
				get_tree().quit(0)
				return
	get_tree().quit(1)

