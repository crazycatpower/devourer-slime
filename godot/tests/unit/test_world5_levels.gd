extends TestCase
## End-to-end routes: inputs only, no teleports or terrain edits.


func test_world5_stages_are_authored_valid_and_distinct() -> void:
	var hashes: Array[int] = []
	for slot: int in range(41, 50):
		check(LevelLibrary.has_authored_layout(slot))
		var rows: PackedStringArray = LevelLibrary.built_in_rows(slot)
		check_eq(LevelValidator.problem_with(rows), "")
		var data: LevelData = LevelCodec.decode(rows)
		check(not hashes.has(data.grid.checksum()), "unique stage %d" % slot)
		hashes.append(data.grid.checksum())


func test_world5_routes_win_with_and_without_bullet_time() -> void:
	var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/world5_solutions.json"))
	for enabled: bool in [true, false]:
		for slot: int in range(41, 50):
			var sim: GameSim = GameSim.new()
			sim.rng.set_seed(7)
			sim.load_level(slot, LevelLibrary.built_in_level(slot), BossState.Kind.NONE)
			sim.bullet_time_enabled = enabled
			for _i: int in 15:
				sim.step(SimInput.new())
			for action: Dictionary in routes[str(slot)]:
				if sim.player.dead or sim.player.won:
					break
				_execute(sim, action)
				if sim.player.dead:
					print("world5 route death slot=", slot, " action=", action, " x=", sim.player.x, " y=", sim.player.y)
			check(not sim.player.dead, "slot %d bullet=%s route survives" % [slot, enabled])
			check(sim.player.won, "slot %d bullet=%s route reaches goal (x=%.1f y=%.1f)" % [slot, enabled, sim.player.x, sim.player.y])


func _aim(sim: GameSim, target: Vector2) -> SimInput:
	var inp: SimInput = SimInput.new()
	inp.mouse_x = target.x - sim.camera.x
	inp.mouse_y = target.y - sim.camera.y
	return inp


func _execute(sim: GameSim, action: Dictionary) -> void:
	var op: String = action.op
	if op == "eat":
		var col: float = action.c
		var row: float = action.r
		var target: Vector2 = (Vector2(col, row) + Vector2(0.5, 0.5)) * Tile.SIZE
		for _i: int in 24:
			var inp: SimInput = _aim(sim, target)
			inp.eat = true
			sim.step(inp)
	elif op == "shoot":
		var col: float = action.c
		var row: float = action.r
		var target: Vector2 = (Vector2(col, row) + Vector2(0.5, 0.5)) * Tile.SIZE
		var hold: SimInput = _aim(sim, target)
		hold.shoot = true
		sim.step(hold)
		var release: SimInput = _aim(sim, target)
		release.shoot_released = true
		sim.step(release)
		for _i: int in 45:
			if not sim.player.dead:
				sim.step(SimInput.new())
	else:
		var jump_frames: int = 0
		if op == "recoil_jump":
			var launch: SimInput = SimInput.new()
			launch.jump = true
			launch.jump_pressed = true
			sim.step(launch)
			launch.jump_pressed = false
			for _wait: int in 27:
				sim.step(launch)
			var down: SimInput = _aim(sim, Vector2(sim.player.center_x(), sim.player.center_y() + 200.0))
			down.jump = true
			down.shoot = true
			sim.step(down)
			down.shoot = false
			down.shoot_released = true
			sim.step(down)
			jump_frames = 60
		for i: int in 700:
			if sim.player.dead or sim.player.won:
				break
			var destination: float = action.x
			var dx: float = destination - sim.player.x
			if absf(dx) < 5.0 and sim.player.grounded:
				break
			var inp: SimInput = SimInput.new()
			inp.right = dx > 3.0
			inp.left = dx < -3.0
			var ahead: float = sim.player.x + sim.player.w + 3.0 if dx > 0.0 else sim.player.x - 3.0
			var obstacle: int = sim.level.get_cell(floori((sim.player.y + sim.player.h - 2.0) / Tile.SIZE), floori(ahead / Tile.SIZE))
			var feet_row: int = floori((sim.player.y + sim.player.h + 2.0) / Tile.SIZE)
			var feet_col: int = floori((sim.player.x + 1.0) / Tile.SIZE)
			var edge_void: bool = sim.level.get_cell(feet_row, feet_col + 1) == Tile.VOID and fposmod(sim.player.x, Tile.SIZE) > 29.0
			if (sim.player.grounded and (Tile.is_solid(obstacle) or edge_void)) or (op == "jump" and i == 0):
				inp.jump_pressed = true
				jump_frames = 40 if op == "jump" else 8
			inp.jump = jump_frames > 0
			jump_frames = maxi(0, jump_frames - 1)
			sim.step(inp)
		# Let residual walking inertia settle without resetting velocity.
		for _i: int in 6:
			if not sim.player.dead and not sim.player.won:
				sim.step(SimInput.new())
