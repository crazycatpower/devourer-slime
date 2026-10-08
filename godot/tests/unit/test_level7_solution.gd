extends TestCase
## Original World 2-7: four materials, ceiling storage and one-cell jumps.

func test_original_level7_four_block_route_reaches_goal() -> void:
	check_eq(LevelLibrary.built_in_rows(17),Fixtures.legacy_rows(17),"original map retained")
	var frames: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/level7_attempt.json"))
	var sim: GameSim = GameSim.new()
	sim.load_level(17,LevelLibrary.built_in_level(17),BossState.Kind.NONE)
	sim.bullet_time_enabled = false
	var shoot_held: bool = false
	for frame: Dictionary in frames:
		var inp: SimInput = SimInput.new()
		inp.left = frame.left
		inp.right = frame.right
		inp.jump = frame.jump
		inp.jump_pressed = frame.jp
		inp.eat = frame.eat
		inp.shoot = frame.shoot
		inp.shoot_released = shoot_held and not inp.shoot
		shoot_held = inp.shoot
		var mx: float = frame.mx
		var my: float = frame.my
		inp.mouse_x = mx-sim.camera.x
		inp.mouse_y = my-sim.camera.y
		sim.step(inp)
		if sim.player.dead or sim.player.won:
			break
	check(not sim.player.dead,"route survives")
	check(sim.player.won,"route wins through ordinary inputs")
	for col: int in range(17,21):
		check_eq(sim.level.get_cell(11,col),Tile.AIR,"all four source blocks used")
	for col: int in [9,15,16]:
		check_eq(sim.level.get_cell(2,col),Tile.DIRT_EATEN_2,"stored block reused as bridge")
