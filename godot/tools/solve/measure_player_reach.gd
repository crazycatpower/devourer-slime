extends SceneTree
## Capability measurements on a flat test floor, using the production simulation.
func _initialize() -> void:
	for carried: bool in [false,true]:
		for hold: int in [1,6,999]:
			measure(carried,hold,0,-1,Vector2.DOWN)
		for clearance: int in [1,2,3]:
			measure(carried,999,clearance,-1,Vector2.DOWN)
	for shot: int in [0,15,30]:
		measure(true,999,0,shot,Vector2.DOWN)
	measure(true,999,0,1,Vector2.LEFT)
	quit()

func measure(carried: bool, hold: int, clearance: int, shot: int, direction: Vector2) -> void:
	var rows: PackedStringArray = PackedStringArray()
	for r: int in 32:
		rows.append("@".repeat(120) if r == 30 else ".".repeat(120))
	rows[29] = ".".repeat(10) + "P" + ".".repeat(109)
	if clearance > 0:
		rows[29-clearance] = "@".repeat(120)
	var sim: GameSim = GameSim.new()
	sim.load_level(1,LevelCodec.decode(rows),BossState.Kind.NONE)
	sim.bullet_time_enabled = false
	sim.player.has_block = carried
	sim.player.carried_block_type = Tile.DIRT if carried else Tile.AIR
	sim.player.carried_block_eaten_count = 1 if carried else 0
	for i: int in 20:
		var run: SimInput = SimInput.new()
		run.right = true
		sim.step(run)
	var start: Vector2 = Vector2(sim.player.x,sim.player.y)
	var min_y: float = start.y
	var ticks: int = 0
	for i: int in 240:
		var inp: SimInput = SimInput.new()
		inp.right = true
		inp.jump = i < hold
		inp.jump_pressed = i == 0
		inp.shoot_released = i == shot
		var target: Vector2 = Vector2(sim.player.center_x(),sim.player.center_y()) + direction * 200.0
		inp.mouse_x = target.x - sim.camera.x
		inp.mouse_y = target.y - sim.camera.y
		# Isolate the movement impulse: a shot must not create a new floor
		# beneath the player and change the height of the landing surface.
		sim.input = inp
		PlayerSystem.update(sim)
		sim.projectiles.clear()
		min_y = minf(min_y,sim.player.y)
		ticks = i+1
		if sim.player.grounded:
			break
	print(JSON.stringify({"carried":carried,"hold":hold,"clearance":clearance,"shot":shot,"direction":str(direction),"height_px":snappedf(start.y-min_y,0.01),"distance_px":snappedf(sim.player.x-start.x,0.01),"ticks":ticks}))
