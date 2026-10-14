extends TestCase
## Isolated interactions inside the existing official default room.


func _sim() -> GameSim:
	var sim: GameSim = GameSim.new()
	sim.load_level(61, LevelCodec.decode(LevelLibrary.default_rows()), BossState.Kind.NONE)
	sim.mechanisms_enabled = true
	return sim


func _update(sim: GameSim, tick: int) -> void:
	sim.tick_count = tick
	MechanismSystem.update(sim)


func _advance_tnt(sim: GameSim, ticks: int = MechanismSystem.TNT_FUSE_TICKS) -> void:
	for tick: int in ticks:
		sim.tick_count += 1
		MechanismSystem.update_tnt(sim)


func _shot(sim: GameSim, type: int, x: float, y: float, vx: float, vy: float = 0.0) -> SimProjectile:
	var shot: SimProjectile = SimProjectile.new()
	shot.type = type
	shot.x = x
	shot.y = y
	shot.vx = vx
	shot.vy = vy
	sim.projectiles.append(shot)
	return shot


func test_sensor_requires_a_block_and_wire_disconnect_clears_signal() -> void:
	var sim: GameSim = _sim()
	sim.level.set_cell(5, 4, Tile.SENSOR)
	sim.level.set_cell(5, 8, Tile.RAIL_RIGHT)
	for col: int in range(4, 9):
		sim.level.set_wire(Vector2i(col, 5), true)
	sim.player.place_at(163.0, 166.0)
	_update(sim, 1)
	check(sim.powered_cells.is_empty(), "the player alone does not activate a block sensor")
	sim.player.place_at(43.0, 43.0)
	sim.level.set_cell(5, 4, Tile.DIRT)
	_update(sim, 2)
	check(sim.powered_cells.has(Vector2i(8, 5)), "signal reaches the rail")
	sim.level.set_wire(Vector2i(6, 5), false)
	_update(sim, 3)
	check(not sim.powered_cells.has(Vector2i(8, 5)), "cut wire removes power without latching")
	sim.level.set_cell(5, 4, Tile.AIR)
	_update(sim, 4)
	check(sim.powered_cells.is_empty())


func test_sensor_is_passable_and_covering_block_does_not_replace_it() -> void:
	var sim: GameSim = _sim()
	var cell: Vector2i = Vector2i(4, 5)
	sim.level.set_sensor(cell, true)
	sim.player.place_at(163.0, 203.0)
	sim.player.grounded = true
	sim.player.vx = 5.0
	Collision.solve_x(sim)
	check_near(sim.player.x, 168.0, 0.01, "player passes through sensor")
	check(sim.solid_boxes(160.0, 200.0, 40.0, 40.0).is_empty())
	sim.level.set_cell(4, 4, Tile.DIRT)
	_update(sim, 1)
	check(sim.powered_cells.is_empty(), "a block above does not cover the sensor")
	sim.level.set_cell(5, 4, Tile.DIRT)
	_update(sim, 2)
	check(sim.level.sensors.has(cell), "block and sensor share a cell")
	check(sim.powered_cells.has(cell), "covering block activates sensor")
	sim.level.set_cell(5, 4, Tile.AIR)
	_update(sim, 3)
	check(sim.level.sensors.has(cell), "uncovering leaves sensor intact")
	check(sim.powered_cells.is_empty(), "uncovering turns signal off")


func test_projectile_passes_through_and_activates_sensor_region() -> void:
	var sim: GameSim = _sim()
	sim.level.set_sensor(Vector2i(4, 5), true)
	var block: SimProjectile = _shot(sim, Tile.DIRT, 150.0, 200.0, 25.0)
	ProjectileSystem.update(sim)
	check_eq(sim.projectiles.size(), 1, "sensor never stops a projectile")
	check_near(block.x, 175.0, 0.01)
	_update(sim, 1)
	check(sim.powered_cells.has(Vector2i(4, 5)), "flying block overlaps the detector")
	block.x = 300.0
	_update(sim, 2)
	check(sim.powered_cells.is_empty())


func test_sensor_editor_overlay_survives_paint_copy_save_and_layer_erasure() -> void:
	var editor: LevelEditor = LevelEditor.new()
	editor.open(LevelCodec.decode(LevelLibrary.default_rows()))
	var cell: Vector2i = Vector2i(4, 5)
	editor.set_brush(LevelEditor.Brush.DIRT)
	editor.stroke_to(cell, false)
	editor.end_stroke()
	editor.set_brush(LevelEditor.Brush.SENSOR)
	editor.stroke_to(cell, false)
	editor.end_stroke()
	check_eq(editor.level.grid.get_cell(5, 4), Tile.DIRT, "painting sensor preserves existing block")
	check(editor.level.grid.sensors.has(cell))
	var saved: Variant = JSON.parse_string(JSON.stringify(LevelCodec.encode_document(editor.level)))
	check(LevelCodec.decode_document(saved).equals(editor.level), "covered sensor survives serialization")
	editor.begin_selection(cell)
	editor.update_selection(cell)
	editor.finish_selection()
	editor.paste_at(Vector2i(10, 5))
	check_eq(editor.level.grid.get_cell(5, 10), Tile.DIRT)
	check(editor.level.grid.sensors.has(Vector2i(10, 5)))
	editor.set_brush(LevelEditor.Brush.SENSOR)
	editor.stroke_to(cell, true)
	editor.end_stroke()
	check_eq(editor.level.grid.get_cell(5, 4), Tile.DIRT, "sensor eraser preserves covering block")
	check(not editor.level.grid.sensors.has(cell))
	editor.undo()
	check(editor.level.grid.sensors.has(cell))
	editor.set_brush(LevelEditor.Brush.ICE)
	editor.stroke_to(cell, false)
	editor.end_stroke()
	check(editor.level.grid.sensors.has(cell), "painting material over sensor preserves it")
	editor.set_brush(LevelEditor.Brush.ERASER)
	editor.stroke_to(cell, false)
	editor.end_stroke()
	check(not editor.level.grid.sensors.has(cell))
	check_eq(editor.level.grid.get_cell(5, 4), Tile.AIR)


func test_wire_loops_and_branches_propagate_once() -> void:
	var sim: GameSim = _sim()
	sim.level.set_cell(5, 4, Tile.SENSOR)
	sim.level.set_cell(5, 4, Tile.ICE)
	for cell: Vector2i in [Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(6, 6), Vector2i(5, 6), Vector2i(4, 6), Vector2i(7, 5)]:
		sim.level.set_wire(cell, true)
	_update(sim, 1)
	check_eq(sim.powered_cells.size(), 7, "loop terminates and branch is powered")


func test_powered_rail_moves_once_and_stops_without_signal() -> void:
	for rail_type: int in [Tile.RAIL_RIGHT, Tile.RAIL_LEFT]:
		var sim: GameSim = _sim()
		sim.level.set_cell(6, 4, Tile.SENSOR)
		sim.level.set_cell(6, 4, Tile.DIRT)
		for col: int in range(4, 12):
			sim.level.set_wire(Vector2i(col, 6), true)
			if col >= 7:
				sim.level.set_cell(6, col, rail_type)
		sim.level.set_cell(6, 9, Tile.DIRT_EATEN_1)
		_update(sim, 12)
		var target: int = 10 if rail_type == Tile.RAIL_RIGHT else 8
		check_eq(sim.level.get_cell(6, 9), Tile.AIR)
		check_eq(sim.level.get_cell(6, target), Tile.DIRT_EATEN_1, "transport preserves wear and moves once per update")
		sim.level.set_cell(6, 4, Tile.AIR)
		_update(sim, 24)
		check_eq(sim.level.get_cell(6, target), Tile.DIRT_EATEN_1, "rail stops without signal")


func test_rail_obstacles_and_rider_clearance() -> void:
	var sim: GameSim = _sim()
	sim.level.set_cell(6, 4, Tile.SENSOR)
	sim.level.set_cell(6, 4, Tile.DIRT)
	for col: int in range(4, 11):
		sim.level.set_wire(Vector2i(col, 6), true)
	sim.level.set_cell(5, 8, Tile.RAIL_RIGHT)
	sim.level.set_cell(5, 9, Tile.RAIL_RIGHT)
	sim.level.set_cell(5, 8, Tile.DIRT)
	sim.level.set_cell(5, 9, Tile.STEEL)
	_update(sim, 12)
	check_eq(sim.level.get_cell(5, 8), Tile.DIRT, "wall blocks transport")
	sim.level.set_cell(5, 9, Tile.AIR)
	sim.player.place_at(323.0, 166.0)
	sim.player.grounded = true
	# The trip to the next cell takes a rail step; the rider goes along tick by tick.
	sim.tick_count = 35
	sim.step(SimInput.new())
	check_eq(sim.level.get_cell(5, 9), Tile.DIRT)
	check(sim.player.x > 323.0 and sim.player.x < 333.0, "the rider has only just set off")
	for _tick: int in MechanismSystem.RAIL_TICKS - 1:
		sim.step(SimInput.new())
	check_near(sim.player.x, 363.0, 1.5, "rider follows the transported block")
	check(sim.player.grounded, "and is still standing on it")
	check(not sim.player.dead)


func test_rider_with_no_room_is_left_behind_not_a_brake() -> void:
	var sim: GameSim = _sim()
	_powered_rail_row(sim, 7, 10)
	sim.level.set_cell(6, 8, Tile.DIRT)
	sim.player.place_at(323.0, 240.0 - sim.player.h - 0.001)
	sim.player.grounded = true
	# A wall right beside the rider, in the way of going along.
	sim.level.set_cell(5, 9, Tile.STEEL)
	sim.tick_count = 11
	sim.step(SimInput.new())
	check_eq(sim.level.get_cell(6, 9), Tile.DIRT, "the block sets off all the same")
	for _tick: int in MechanismSystem.RAIL_TICKS:
		sim.step(SimInput.new())
	check(sim.player.x < 330.0, "the rider stayed behind the wall (x %d)" % roundi(sim.player.x))
	check(not sim.player.dead, "unharmed")


func test_sand_falls_stacks_and_resumes_after_support_is_removed() -> void:
	var sim: GameSim = _sim()
	sim.level.set_cell(4, 8, Tile.SAND)
	sim.level.set_cell(5, 8, Tile.SAND)
	sim.level.set_cell(8, 8, Tile.STEEL)
	for tick: int in [6, 12, 18, 24]:
		_update(sim, tick)
	check_eq(sim.level.get_cell(6, 8), Tile.SAND)
	check_eq(sim.level.get_cell(7, 8), Tile.SAND)
	check_eq(sim.level.get_cell(8, 8), Tile.STEEL)
	sim.level.set_cell(8, 8, Tile.AIR)
	_update(sim, 30)
	check_eq(sim.level.get_cell(7, 8), Tile.SAND)
	check_eq(sim.level.get_cell(8, 8), Tile.SAND)


func test_sand_does_not_overwrite_player_or_goal() -> void:
	var sim: GameSim = _sim()
	sim.level.set_cell(4, 8, Tile.SAND)
	sim.player.place_at(323.0, 203.0)
	sim.tick_count = 5
	sim.step(SimInput.new())
	check_eq(sim.level.get_cell(5, 8), Tile.SAND, "a player underneath does not hold the grain up")
	for _tick: int in MechanismSystem.FALL_TICKS - 1:
		sim.step(SimInput.new())
		var grain: Vector2 = sim.tile_position_now(sim.tile_motions[Vector2i(8, 5)]) if sim.tile_motions.has(Vector2i(8, 5)) else Vector2(320.0, 200.0)
		check(sim.player.y >= grain.y + Tile.SIZE - 0.01, "the player is pushed down ahead of it")
	check(not sim.player.dead, "and with room below comes to no harm")
	sim.level.set_cell(5, 8, Tile.AIR)
	sim.level.set_cell(6, 8, Tile.AIR)
	sim.level.set_cell(7, 8, Tile.AIR)
	sim.tile_motions.clear()
	sim.level.set_cell(4, 8, Tile.SAND)
	sim.tick_count = 6
	sim.player.place_at(43.0, 43.0)
	sim.level.set_cell(5, 8, Tile.GOAL)
	_update(sim, 12)
	check_eq(sim.level.get_cell(5, 8), Tile.GOAL)


func test_rider_follows_sand_when_support_is_removed() -> void:
	var sim: GameSim = _sim()
	sim.level.set_cell(5, 8, Tile.SAND)
	sim.player.place_at(323.0, 166.0 - 0.001)
	sim.player.grounded = true
	sim.tick_count = 5
	for _tick: int in MechanismSystem.FALL_TICKS:
		sim.step(SimInput.new())
	check_eq(sim.level.get_cell(6, 8), Tile.SAND)
	check_near(sim.player.y, 206.0 - 0.001, 0.5, "falling support carries the rider down too")
	check(not sim.player.dead)


func test_regular_blocks_slide_on_ice_and_stop_at_its_end() -> void:
	var sim: GameSim = _sim()
	for col: int in range(5, 9):
		sim.level.set_cell(6, col, Tile.ICE)
	sim.level.set_cell(6, 9, Tile.STEEL)
	var shot: SimProjectile = _shot(sim, Tile.DIRT, 200.0, 215.0, 12.0, 8.0)
	ProjectileSystem.update(sim)
	check(sim.projectiles.is_empty(), "shot lands on the ice")
	check_eq(sim.level.get_cell(5, 5), Tile.DIRT)
	for tick: int in [4, 8, 12, 16, 20, 24]:
		_update(sim, tick)
	check_eq(sim.level.get_cell(5, 9), Tile.DIRT, "block stops on the first non-ice floor")
	check(sim.sliding_cells.is_empty())
	check_eq(shot.type, Tile.DIRT)


func test_ice_keeps_sliding_on_normal_floor_until_wall() -> void:
	var sim: GameSim = _sim()
	for col: int in range(5, 11):
		sim.level.set_cell(6, col, Tile.STEEL)
	sim.level.set_cell(5, 10, Tile.STEEL)
	_shot(sim, Tile.ICE, 200.0, 215.0, 12.0, 8.0)
	ProjectileSystem.update(sim)
	for tick: int in [4, 8, 12, 16, 20, 24]:
		_update(sim, tick)
	check_eq(sim.level.get_cell(5, 9), Tile.ICE, "ice itself keeps sliding on a normal floor")
	check_eq(sim.level.get_cell(5, 10), Tile.STEEL)
	check(sim.sliding_cells.is_empty(), "wall stops momentum")


func test_projectile_knocks_ice_into_motion() -> void:
	var sim: GameSim = _sim()
	for col: int in range(5, 11):
		sim.level.set_cell(6, col, Tile.STEEL)
	sim.level.set_cell(5, 7, Tile.ICE)
	_shot(sim, Tile.DIRT, 235.0, 200.0, 25.0)
	ProjectileSystem.update(sim)
	check(sim.projectiles.is_empty())
	_update(sim, 4)
	check_eq(sim.level.get_cell(5, 7), Tile.AIR)
	check_eq(sim.level.get_cell(5, 8), Tile.ICE)


func test_player_has_low_friction_only_on_ice() -> void:
	var sim: GameSim = _sim()
	sim.level.set_cell(6, 8, Tile.ICE)
	sim.player.place_at(323.0, 206.0 - 0.001)
	sim.player.grounded = true
	sim.player.vx = 5.0
	PlayerSystem.update(sim)
	check(sim.player.vx > 4.9, "release barely slows a player on ice")
	sim.level.set_cell(6, 8, Tile.STEEL)
	PlayerSystem.update(sim)
	check(sim.player.vx < 4.0, "ordinary floor restores friction")
	sim.level.set_cell(5, 9, Tile.STEEL)
	sim.player.x = 359.0 - sim.player.w
	sim.player.vx = 10.0
	Collision.solve_x(sim)
	check_eq(sim.player.vx, 0.0, "wall stops the player")


func test_new_materials_keep_their_type_when_swallowed() -> void:
	for type: int in [Tile.SAND, Tile.ICE, Tile.TNT]:
		var sim: GameSim = _sim()
		sim.player.place_at(203.0, 203.0)
		sim.player.grounded = true
		sim.level.set_cell(5, 6, type)
		sim.input.eat = true
		sim.input.mouse_x = 300.0 - sim.camera.x
		sim.input.mouse_y = 220.0 - sim.camera.y
		var aim: PlayerSystem.Aim = PlayerSystem.aim_of(sim, sim.input.mouse_x, sim.input.mouse_y)
		for tick: int in 26:
			PlayerSystem._update_eating(sim, aim)
		check(sim.player.has_block)
		check_eq(sim.player.carried_block_type, type)
		check_eq(sim.level.get_cell(5, 6), Tile.AIR)


func test_tnt_spitting_arms_a_fuse_and_explodes_in_flight() -> void:
	var sim: GameSim = _sim()
	sim.player.place_at(203.0, 203.0)
	sim.player.has_block = true
	sim.player.carried_block_type = Tile.TNT
	var aim: PlayerSystem.Aim = PlayerSystem.Aim.new()
	PlayerSystem._fire(sim, aim)
	check_eq(sim.projectiles.size(), 1)
	check_eq(sim.projectiles[0].fuse_ticks, MechanismSystem.TNT_FUSE_TICKS)
	check(not sim.player.dead, "spitting is not immediate self-destruction")
	sim.projectiles[0].x = 700.0
	sim.projectiles[0].y = 200.0
	sim.projectiles[0].vx = 0.0
	sim.projectiles[0].vy = 0.0
	for tick: int in MechanismSystem.TNT_FUSE_TICKS:
		sim.tick_count += 1
		ProjectileSystem.update(sim)
	check(sim.projectiles.is_empty(), "armed TNT expires without needing a target")


func test_tnt_projectile_impact_and_chain_preserve_fixed_tiles() -> void:
	var sim: GameSim = _sim()
	sim.level.set_cell(5, 7, Tile.TNT)
	sim.level.set_cell(5, 9, Tile.TNT)
	sim.level.set_cell(5, 10, Tile.GLASS)
	sim.level.set_cell(6, 9, Tile.STEEL)
	sim.level.set_cell(4, 9, Tile.GOAL)
	sim.level.set_wire(Vector2i(5, 5), true)
	_shot(sim, Tile.DIRT, 235.0, 200.0, 25.0)
	ProjectileSystem.update(sim)
	check_eq(sim.level.get_cell(5, 7), Tile.AIR)
	check_eq(sim.level.get_cell(5, 9), Tile.TNT, "impact only primes the first charge")
	_advance_tnt(sim, MechanismSystem.TNT_FUSE_TICKS - 1)
	check_eq(sim.level.get_cell(5, 9), Tile.TNT, "no blast before 0.4 seconds")
	_advance_tnt(sim, 1)
	check_eq(sim.level.get_cell(5, 9), Tile.AIR, "blast primes another TNT")
	check_eq(sim.level.get_cell(5, 10), Tile.GLASS, "chain has its own fuse")
	_advance_tnt(sim)
	check_eq(sim.level.get_cell(5, 10), Tile.AIR, "second blast breaks nearby glass")
	check_eq(sim.level.get_cell(6, 9), Tile.STEEL)
	check_eq(sim.level.get_cell(4, 9), Tile.GOAL)
	check(not sim.level.wires.has(Vector2i(5, 5)), "blast breaks nearby wire")


func test_tnt_signal_explodes_and_reset_restores_source() -> void:
	var data: LevelData = LevelCodec.decode(LevelLibrary.default_rows())
	data.grid.set_cell(5, 4, Tile.SENSOR)
	data.grid.set_cell(5, 4, Tile.DIRT)
	data.grid.set_cell(5, 8, Tile.TNT)
	for col: int in range(4, 9):
		data.grid.set_wire(Vector2i(col, 5), true)
	var sim: GameSim = GameSim.new()
	sim.load_level(61, data, BossState.Kind.NONE)
	_update(sim, 1)
	check_eq(sim.level.get_cell(5, 8), Tile.AIR, "wired signal primes TNT")
	check_eq(sim.tnt_charges.size(), 1)
	_update(sim, 2)
	check_eq(sim.tnt_charges.size(), 1, "continuous signal cannot duplicate the charge")
	check_eq(sim.tnt_charges[0].explode_tick, 1 + MechanismSystem.TNT_FUSE_TICKS, "continuous signal cannot restart the fuse")
	sim.reset()
	check(sim.level.equals(data.grid), "reset restores TNT and wires")
	check(sim.powered_cells.is_empty())
	check(sim.sliding_cells.is_empty())
	check(sim.tnt_charges.is_empty(), "reset cancels pending explosions")


func test_armed_tnt_also_explodes_when_it_hits_a_boss() -> void:
	var sim: GameSim = GameSim.new()
	sim.load_level(40, LevelLibrary.built_in_level(40), BossState.Kind.GLASS_SLIME)
	sim.boss.state = BossState.State.ACTIVE
	sim.boss.x = 800.0
	sim.boss.y = 300.0
	for shield: ShieldState in sim.boss.shields:
		shield.active = false
	var target: Vector2i = Vector2i(Tile.cell_of(sim.boss.center_x()) + 2, Tile.cell_of(sim.boss.center_y()))
	sim.level.set_cell(target.y, target.x, Tile.TNT)
	var shot: SimProjectile = _shot(sim, Tile.TNT, sim.boss.center_x() - 20.0, sim.boss.center_y() - 20.0, 0.0)
	shot.fuse_ticks = MechanismSystem.TNT_FUSE_TICKS
	ProjectileSystem.update(sim)
	check(shot.dead, "boss impact detonates the armed shot")
	check(sim.projectiles.is_empty())
	check_eq(sim.level.get_cell(target.y, target.x), Tile.TNT, "boss impact waits for the fuse")
	_advance_tnt(sim, MechanismSystem.TNT_FUSE_TICKS - 2)
	check_eq(sim.level.get_cell(target.y, target.x), Tile.TNT)
	_advance_tnt(sim, 1)
	check_eq(sim.level.get_cell(target.y, target.x), Tile.AIR, "boss impact explosion primes nearby TNT")


func test_tnt_blast_kills_near_player_but_not_far_player() -> void:
	var sim: GameSim = _sim()
	sim.player.place_at(323.0, 203.0)
	MechanismSystem.explode(sim, Vector2(340.0, 220.0))
	check(sim.player.dead)
	sim.reset()
	MechanismSystem.explode(sim, Vector2(700.0, 220.0))
	check(not sim.player.dead)


func test_wire_editor_drag_undo_copy_paste_and_resize() -> void:
	var editor: LevelEditor = LevelEditor.new()
	editor.open(LevelCodec.decode(LevelLibrary.default_rows()))
	editor.level.grid.set_cell(4, 4, Tile.SENSOR)
	editor.set_brush(LevelEditor.Brush.WIRE)
	editor.stroke_to(Vector2i(4, 4), false)
	editor.stroke_to(Vector2i(7, 7), false)
	editor.end_stroke()
	check(editor.level.grid.sensors.has(Vector2i(4, 4)), "wire preserves the sensor overlay")
	check(editor.level.grid.wires.has(Vector2i(5, 4)), "diagonal drag inserts an orthogonal connection")
	var wired: LevelData = editor.level.duplicate_level()
	editor.undo()
	check(editor.level.grid.wires.is_empty())
	editor.redo()
	check(editor.level.equals(wired))
	editor.begin_selection(Vector2i(4, 4))
	editor.update_selection(Vector2i(7, 7))
	editor.finish_selection()
	editor.paste_at(Vector2i(10, 4))
	check(editor.level.grid.wires.has(Vector2i(10, 4)))
	check(editor.level.grid.sensors.has(Vector2i(10, 4)))
	editor.set_brush(LevelEditor.Brush.WIRE)
	editor.stroke_to(Vector2i(4, 4), true)
	editor.end_stroke()
	check(not editor.level.grid.wires.has(Vector2i(4, 4)))
	check(editor.level.grid.sensors.has(Vector2i(4, 4)), "wire eraser preserves the sensor overlay")
	editor.resize(25, 15)
	check(editor.level.grid.wires.has(Vector2i(10, 4)))


func test_wired_document_roundtrip_and_malformed_wire_validation() -> void:
	var data: LevelData = LevelCodec.decode(LevelLibrary.default_rows())
	var types: Array[int] = [Tile.SENSOR, Tile.RAIL_RIGHT, Tile.RAIL_LEFT, Tile.SAND, Tile.ICE, Tile.TNT]
	for i: int in types.size():
		data.grid.set_cell(4, 4 + i, types[i])
		data.grid.set_wire(Vector2i(4 + i, 4), true)
	var document: Variant = JSON.parse_string(JSON.stringify(LevelCodec.encode_document(data)))
	check_eq(LevelValidator.problem_with_document(document), "")
	check(LevelCodec.decode_document(document).equals(data), "tiles and wires survive JSON")
	var bad: Dictionary = {"rows": Array(LevelCodec.encode(data)), "wires": []}
	for wire_value: Variant in [[[4.5, 4]], [[-1, 4]], [[4, 999]], [["x", 4]], [[4]], "broken"]:
		bad["wires"] = wire_value
		check(not LevelValidator.problem_with_document(bad).is_empty(), "invalid wire data is rejected")


func test_rail_overlay_copy_erasure_and_round_trip() -> void:
	var editor: LevelEditor = LevelEditor.new()
	editor.open(LevelCodec.decode(LevelLibrary.default_rows()))
	var cell: Vector2i = Vector2i(8, 5)
	editor.level.grid.set_cell(5, 8, Tile.DIRT)
	editor.set_brush(LevelEditor.Brush.RAIL_UP)
	editor.stroke_to(cell, false)
	editor.end_stroke()
	check_eq(editor.level.grid.get_cell(5, 8), Tile.DIRT)
	check_eq(editor.level.grid.rails[cell], Tile.RAIL_UP)
	var document: Variant = JSON.parse_string(JSON.stringify(LevelCodec.encode_document(editor.level)))
	check_eq(LevelValidator.problem_with_document(document), "")
	check(LevelCodec.decode_document(document).equals(editor.level), "overlapping rail and block survive save")
	editor.begin_selection(cell)
	editor.finish_selection()
	editor.paste_at(Vector2i(10, 5))
	check_eq(editor.level.grid.rails[Vector2i(10, 5)], Tile.RAIL_UP)
	check_eq(editor.level.grid.get_cell(5, 10), Tile.DIRT)
	editor.set_brush(LevelEditor.Brush.RAIL_UP)
	editor.stroke_to(cell, true)
	editor.end_stroke()
	check(not editor.level.grid.rails.has(cell))
	check_eq(editor.level.grid.get_cell(5, 8), Tile.DIRT)
	editor.undo()
	check_eq(editor.level.grid.rails[cell], Tile.RAIL_UP)
	editor.rotate_rail()
	check_eq(editor.brush, LevelEditor.Brush.RAIL_RIGHT)
	check_eq(editor.level.grid.resized(32, 18).rails[cell], Tile.RAIL_UP)
	(document as Dictionary)["rails"] = [[8, 5, 999]]
	check(not LevelValidator.problem_with_document(document).is_empty())


func test_rail_turns_all_directions_and_stops_at_end() -> void:
	var sim: GameSim = _sim()
	var cells: Array[Vector2i] = [Vector2i(8, 6), Vector2i(9, 6), Vector2i(9, 7), Vector2i(8, 7)]
	var types: Array[int] = [Tile.RAIL_RIGHT, Tile.RAIL_DOWN, Tile.RAIL_LEFT, Tile.RAIL_UP]
	for i: int in cells.size():
		sim.level.set_rail(cells[i], types[i])
	check(sim.solid_boxes(320.0, 240.0, 40.0, 40.0).is_empty(), "uncovered rail is passable")
	sim.level.set_sensor(Vector2i(7, 6), true)
	sim.level.set_cell(6, 7, Tile.DIRT)
	sim.level.set_cell(6, 8, Tile.GLASS)
	for i: int in range(1, 5):
		_update(sim, i * 12)
		var target: Vector2i = cells[i % 4]
		check_eq(sim.level.get_cell(target.y, target.x), Tile.GLASS, "block follows bends once per tick")
		check_eq(sim.level.rails.size(), 4, "movement preserves tracks")
	sim.level.set_rail(cells[1], Tile.AIR)
	_update(sim, 60)
	check_eq(sim.level.get_cell(6, 8), Tile.GLASS, "block stops at missing next segment")


func test_vertical_rail_carries_rider_and_captures_sand_and_ice() -> void:
	for type: int in [Tile.DIRT, Tile.SAND, Tile.ICE]:
		var sim: GameSim = _sim()
		sim.level.set_rail(Vector2i(8, 6), Tile.RAIL_UP)
		sim.level.set_rail(Vector2i(8, 5), Tile.RAIL_LEFT)
		sim.level.set_sensor(Vector2i(7, 6), true)
		sim.level.set_cell(6, 7, Tile.DIRT)
		sim.level.set_cell(6, 8, type)
		sim.player.place_at(323.0, 206.0)
		sim.player.grounded = true
		MechanismSystem.start_slide(sim, Vector2i(8, 6), 5.0)
		_update(sim, 6)
		check_eq(sim.level.get_cell(6, 8), type, "track captures sand before transport")
		sim.tick_count = 11
		for _tick: int in MechanismSystem.RAIL_TICKS:
			sim.step(SimInput.new())
		check_eq(sim.level.get_cell(5, 8), type, "rail overrides ice momentum")
		check_near(sim.player.y, 166.0, 0.5, "rider moves upward safely")
		check(not sim.player.dead)


func test_swallowing_grants_material_ability_and_spitting_clears_it() -> void:
	var colors: Array[Color] = []
	for type: int in [Tile.DIRT, Tile.BOUNCY, Tile.SAND, Tile.ICE, Tile.TNT]:
		var sim: GameSim = _sim()
		sim.player.place_at(203.0, 203.0)
		sim.level.set_cell(5, 6, type)
		sim.input.eat = true
		var aim: PlayerSystem.Aim = PlayerSystem.aim_of(sim, 300.0 - sim.camera.x, 220.0 - sim.camera.y)
		for tick: int in 26:
			PlayerSystem._update_eating(sim, aim)
		check_eq(sim.player.ability_type(), type, "completed swallow activates material")
		check(not sim.player.ability_label().is_empty())
		check(not sim.player.ability_color() in colors, "each material has a distinct body color")
		colors.append(sim.player.ability_color())
		PlayerSystem._fire(sim, aim)
		check_eq(sim.player.ability_type(), Tile.AIR)
		check_eq(sim.player.ability_color(), Palette.GREEN_500)
		check_eq(sim.player.ability_label(), "")
		sim.player.has_block = true
		sim.player.carried_block_type = type
		sim.reset()
		check_eq(sim.player.ability_type(), Tile.AIR, "reset clears ability")


func test_bouncy_power_keeps_original_jump_and_worn_blocks_share_power() -> void:
	for type: int in [Tile.BOUNCY, Tile.BOUNCY_EATEN_1, Tile.BOUNCY_EATEN_2]:
		var sim: GameSim = _sim()
		sim.player.has_block = true
		sim.player.carried_block_type = type
		sim.player.grounded = true
		sim.input.jump_pressed = true
		sim.input.jump = true
		PlayerSystem._update_jump(sim)
		check_near(sim.player.vy, -GameConstants.JUMP_FORCE, 0.001)
		check_eq(sim.player.ability_type(), Tile.BOUNCY)


func test_ice_power_slides_on_ordinary_floor_and_ends_after_spit() -> void:
	var sim: GameSim = _sim()
	sim.level.set_cell(6, 8, Tile.STEEL)
	sim.player.place_at(323.0, 206.0 - 0.001)
	sim.player.grounded = true
	sim.player.has_block = true
	sim.player.carried_block_type = Tile.ICE
	sim.player.vx = 5.0
	PlayerSystem.update(sim)
	check(sim.player.vx > 4.9, "ice ability lowers friction on steel")
	sim.player.has_block = false
	PlayerSystem.update(sim)
	check(sim.player.vx < 4.0, "friction returns when ice is gone")


func test_sand_power_accelerates_fall_without_reducing_rising_jump() -> void:
	var regular: GameSim = _sim()
	var sand: GameSim = _sim()
	for sim: GameSim in [regular, sand]:
		sim.player.place_at(323.0, 203.0)
		sim.player.vy = 2.0
	sand.player.has_block = true
	sand.player.carried_block_type = Tile.SAND
	PlayerSystem.update(regular)
	PlayerSystem.update(sand)
	check(sand.player.vy > regular.player.vy, "sand falls faster")
	for sim: GameSim in [regular, sand]:
		sim.player.place_at(323.0, 203.0)
		sim.player.vy = -5.0
	PlayerSystem.update(regular)
	PlayerSystem.update(sand)
	check_near(sand.player.vy, regular.player.vy, 0.001, "sand does not weaken upward jumps")


func test_carried_tnt_no_longer_grants_blast_resistance() -> void:
	var sim: GameSim = _sim()
	sim.player.place_at(323.0, 203.0)
	sim.player.has_block = true
	sim.player.carried_block_type = Tile.TNT
	MechanismSystem.explode(sim, Vector2(400.0, 220.0))
	check(sim.player.dead, "carried TNT does not reduce blast range")
	var boss_blast: GameSim = _sim()
	boss_blast.player.has_block = true
	boss_blast.player.carried_block_type = Tile.TNT
	boss_blast.player.place_at(323.0, 203.0)
	var bomb: GlassBomb = GlassBomb.new()
	bomb.x = boss_blast.player.x + boss_blast.player.w + 40.0
	bomb.y = boss_blast.player.center_y()
	BossGlassSlime._shatter_throw(boss_blast, bomb)
	check(not boss_blast.player.dead, "thrown glass has no blast range")


func _impact_sim(direction: Vector2i, speed: float, type: int = Tile.TNT) -> GameSim:
	var sim: GameSim = _sim()
	sim.player.place_at(323.0, 203.0)
	sim.player.has_block = true
	sim.player.carried_block_type = type
	sim.player.grounded = true
	sim.player.vx = float(direction.x) * speed
	sim.player.vy = float(direction.y) * speed
	sim.level.set_cell(5 + direction.y, 8 + direction.x, Tile.STEEL)
	return sim


func test_tnt_hard_impacts_detonate_in_every_direction_only_once() -> void:
	for direction: Vector2i in MechanismSystem.DIRECTIONS:
		var sim: GameSim = _impact_sim(direction, Collision.TNT_IMPACT_SPEED)
		sim.player.in_bullet_time = true
		sim.player.waiting_for_shoot_release = true
		if direction.x != 0:
			Collision.solve_x(sim)
		else:
			Collision.solve_y(sim)
		check(not sim.player.dead, "hard impact gives the player time to escape")
		check_eq(sim.tnt_charges.size(), 1)
		_advance_tnt(sim, MechanismSystem.TNT_FUSE_TICKS - 1)
		check(not sim.player.dead, "no damage before 0.4 seconds")
		_advance_tnt(sim, 1)
		check(sim.player.dead, "remaining in the blast still causes normal self damage")
		check(not sim.player.has_block, "impact consumes held TNT")
		check_eq(sim.player.carried_block_type, Tile.AIR)
		check(not sim.player.in_bullet_time)
		check(not sim.player.waiting_for_shoot_release)
		check_eq(sim.level.get_cell(5 + direction.y, 8 + direction.x), Tile.STEEL)
		var particle_count: int = sim.particles.size()
		check(not MechanismSystem.detonate_carried_tnt(sim))
		check_eq(sim.particles.size(), particle_count, "charge cannot detonate twice")


func test_tnt_gentle_impacts_and_fast_free_flight_do_not_explode() -> void:
	for direction: Vector2i in MechanismSystem.DIRECTIONS:
		var sim: GameSim = _impact_sim(direction, Collision.TNT_IMPACT_SPEED - 0.01)
		if direction.x != 0:
			Collision.solve_x(sim)
		else:
			Collision.solve_y(sim)
		check(not sim.player.dead)
		check(sim.player.has_block, "ordinary impacts preserve TNT")
	var flight: GameSim = _sim()
	flight.player.place_at(323.0, 203.0)
	flight.player.has_block = true
	flight.player.carried_block_type = Tile.TNT
	flight.player.vx = 100.0
	Collision.solve_x(flight)
	check(flight.player.has_block, "speed without impact never detonates")
	check(not flight.player.dead)
	var grazing: GameSim = _impact_sim(Vector2i.DOWN, 0.5)
	grazing.player.y = 240.0 - grazing.player.h - 0.1
	grazing.player.vx = 100.0
	Collision.solve_y(grazing)
	check(grazing.player.has_block, "parallel speed does not turn a gentle landing into an impact")


func test_tnt_fast_wall_impact_cannot_tunnel_and_chains_nearby_tnt() -> void:
	var sim: GameSim = _impact_sim(Vector2i.RIGHT, 100.0)
	sim.level.set_cell(5, 10, Tile.TNT)
	sim.level.set_cell(5, 12, Tile.DIRT)
	Collision.solve_x(sim)
	check(not sim.player.dead)
	_advance_tnt(sim)
	check(sim.player.dead)
	check(sim.player.x + sim.player.w < 360.0, "swept impact catches a one-cell steel wall")
	check_eq(sim.level.get_cell(5, 10), Tile.AIR, "held explosion starts TNT chain")
	check_eq(sim.level.get_cell(5, 12), Tile.DIRT, "chain waits for its own fuse")
	_advance_tnt(sim)
	check_eq(sim.level.get_cell(5, 12), Tile.AIR, "chain reaches blocks beyond initial blast")
	check_eq(sim.level.get_cell(5, 9), Tile.STEEL)


func test_other_materials_and_spat_tnt_do_not_trigger_body_explosion() -> void:
	for type: int in [Tile.DIRT, Tile.BOUNCY, Tile.SAND, Tile.ICE]:
		var sim: GameSim = _impact_sim(Vector2i.RIGHT, 20.0, type)
		Collision.solve_x(sim)
		check(not sim.player.dead)
		check(sim.player.has_block)
	var spat: GameSim = _impact_sim(Vector2i.RIGHT, 20.0)
	PlayerSystem._fire(spat, PlayerSystem.Aim.new())
	spat.player.vx = 20.0
	Collision.solve_x(spat)
	check(not spat.player.dead, "spitting removes body detonation ability")
	check_eq(spat.projectiles.size(), 1, "spat TNT retains its own projectile fuse")


func test_dragged_rail_loop_turns_and_transports_without_replacing_layers() -> void:
	var editor: LevelEditor = LevelEditor.new()
	editor.open(LevelCodec.decode(LevelLibrary.default_rows()))
	var start: Vector2i = Vector2i(8, 6)
	editor.level.grid.set_sensor(start, true)
	editor.level.grid.set_wire(start, true)
	editor.level.grid.set_cell(6, 8, Tile.DIRT)
	var before: LevelData = editor.level.duplicate_level()
	editor.set_brush(LevelEditor.Brush.RAIL_RIGHT)
	editor.begin_stroke()
	for cell: Vector2i in [start, Vector2i(9, 6), Vector2i(9, 7), Vector2i(8, 7), start]:
		editor.stroke_to(cell, false)
	editor.end_stroke()
	var grid: LevelGrid = editor.level.grid
	check_eq(grid.rails[start], Tile.RAIL_RIGHT)
	check_eq(grid.rails[Vector2i(9, 6)], Tile.RAIL_DOWN)
	check_eq(grid.rails[Vector2i(9, 7)], Tile.RAIL_LEFT)
	check_eq(grid.rails[Vector2i(8, 7)], Tile.RAIL_UP)
	check_eq(grid.get_cell(6, 8), Tile.DIRT)
	check(grid.sensors.has(start) and grid.wires.has(start))
	var saved: LevelData = editor.level.duplicate_level()
	editor.undo()
	check(editor.level.equals(before), "one undo removes the entire loop gesture")
	editor.redo()
	check(editor.level.equals(saved))
	var sim: GameSim = _sim()
	sim.load_level(61, editor.level, BossState.Kind.NONE)
	# A separate covered detector keeps the loop powered after its payload moves.
	sim.level.set_sensor(Vector2i(7, 6), true)
	sim.level.set_cell(6, 7, Tile.DIRT)
	var expected: Array[Vector2i] = [Vector2i(9, 6), Vector2i(9, 7), Vector2i(8, 7), start]
	for i: int in expected.size():
		_update(sim, (i + 1) * 12)
		check_eq(sim.level.get_cell(expected[i].y, expected[i].x), Tile.DIRT, "dragged route turns during simulation")


func test_diagonal_track_drag_bridges_gaps_and_erases_only_rail_layer() -> void:
	var editor: LevelEditor = LevelEditor.new()
	editor.open(LevelCodec.decode(LevelLibrary.default_rows()))
	editor.set_brush(LevelEditor.Brush.RAIL_RIGHT)
	editor.stroke_to(Vector2i(8, 5), false)
	editor.stroke_to(Vector2i(11, 8), false)
	editor.end_stroke()
	check_eq(editor.level.grid.rails.size(), 7, "diagonal drag inserts cardinal bridge cells")
	var cursor: Vector2i = Vector2i(8, 5)
	for step: int in 6:
		cursor += Tile.rail_direction(editor.level.grid.rails[cursor])
		check(editor.level.grid.rails.has(cursor), "every arrow reaches a connected segment")
	check_eq(cursor, Vector2i(11, 8))
	editor.level.grid.set_cell(5, 8, Tile.ICE)
	editor.level.grid.set_sensor(Vector2i(8, 5), true)
	editor.stroke_to(Vector2i(8, 5), true)
	editor.stroke_to(Vector2i(11, 8), true)
	editor.end_stroke()
	check(editor.level.grid.rails.is_empty())
	check_eq(editor.level.grid.get_cell(5, 8), Tile.ICE)
	check(editor.level.grid.sensors.has(Vector2i(8, 5)))


func test_manual_rail_mode_preserves_selected_direction_and_picks_covered_track() -> void:
	var editor: LevelEditor = LevelEditor.new()
	editor.open(LevelCodec.decode(LevelLibrary.default_rows()))
	editor.rail_auto_turn = false
	editor.set_brush(LevelEditor.Brush.RAIL_UP)
	editor.stroke_to(Vector2i(8, 5), false)
	editor.stroke_to(Vector2i(10, 5), false)
	editor.end_stroke()
	for col: int in range(8, 11):
		check_eq(editor.level.grid.rails[Vector2i(col, 5)], Tile.RAIL_UP)
	editor.level.grid.set_cell(5, 8, Tile.DIRT)
	editor.set_brush(LevelEditor.Brush.RAIL_RIGHT)
	editor.pick_brush(Vector2i(8, 5))
	check_eq(editor.brush, LevelEditor.Brush.RAIL_UP, "rail brush samples track under its covering block")


func test_sand_index_survives_copy_resize_append_and_material_changes() -> void:
	var grid: LevelGrid = LevelGrid.new(4, 4, Tile.SAND)
	check_eq(grid.sand_cells.size(), 16)
	grid.set_cell(1, 1, Tile.ICE)
	grid.set_cell(1, 2, Tile.AIR)
	check_eq(grid.sand_cells.size(), 14)
	var copy: LevelGrid = grid.duplicate_grid()
	copy.set_cell(2, 2, Tile.AIR)
	check_eq(grid.sand_cells.size(), 14, "copy mutations do not change original sand index")
	check_eq(copy.sand_cells.size(), 13)
	grid.append_rows(2, Tile.SAND)
	check_eq(grid.sand_cells.size(), 22)
	check(grid.sand_cells.has(Vector2i(3, 5)))
	var resized: LevelGrid = grid.resized(6, 8)
	for cell: Vector2i in resized.sand_cells:
		check_eq(resized.get_cell(cell.y, cell.x), Tile.SAND)
		check(resized.is_interior(cell.y, cell.x))
	grid.set_cell(2, 2, Tile.SENSOR)
	check(grid.sand_cells.has(Vector2i(2, 2)), "overlay writes preserve sand index")


func test_sand_covering_sensor_detonates_tnt_in_same_update() -> void:
	var sim: GameSim = _sim()
	sim.level.set_cell(5, 8, Tile.SAND)
	sim.level.set_sensor(Vector2i(8, 6), true)
	for col: int in range(8, 13):
		sim.level.set_wire(Vector2i(col, 6), true)
	sim.level.set_cell(6, 12, Tile.TNT)
	_update(sim, 6)
	check_eq(sim.level.get_cell(6, 8), Tile.SAND)
	check_eq(sim.level.get_cell(6, 12), Tile.AIR, "new sensor coverage activates TNT in the same tick")
	check(sim.powered_cells.has(Vector2i(12, 6)), "wires remain intact while fuse burns")
	_advance_tnt(sim)
	_update(sim, sim.tick_count)
	check(not sim.powered_cells.has(Vector2i(12, 6)), "blast wire damage clears downstream power")


func test_sensors_import_order_does_not_change_signal_or_transport() -> void:
	var first: GameSim = _sim()
	var second: GameSim = _sim()
	var cells: Array[Vector2i] = [Vector2i(4, 5), Vector2i(4, 7)]
	for sim: GameSim in [first, second]:
		for row: int in [5, 7]:
			sim.level.set_cell(row, 4, Tile.DIRT)
		for col: int in range(4, 11):
			sim.level.set_wire(Vector2i(col, 5), true)
			sim.level.set_wire(Vector2i(col, 7), true)
			sim.level.set_rail(Vector2i(col, 6), Tile.RAIL_RIGHT)
		sim.level.set_cell(6, 8, Tile.GLASS)
	for cell: Vector2i in cells:
		first.level.set_sensor(cell, true)
	cells.reverse()
	for cell: Vector2i in cells:
		second.level.set_sensor(cell, true)
	_update(first, 12)
	_update(second, 12)
	check_eq(first.powered_cells.keys(), second.powered_cells.keys(), "sensor ordering stays deterministic")
	check(first.level.equals(second.level))


func test_signal_cache_reacts_to_wire_device_and_tnt_changes() -> void:
	var sim: GameSim = _sim()
	var source: Vector2i = Vector2i(4, 5)
	sim.level.set_sensor(source, true)
	sim.level.set_cell(source.y, source.x, Tile.DIRT)
	for col: int in range(4, 9):
		sim.level.set_wire(Vector2i(col, 5), true)
	_update(sim, 1)
	check(sim.powered_cells.has(Vector2i(8, 5)))
	var cached_revision: int = sim.signal_revision
	_update(sim, 2)
	check_eq(sim.signal_revision, cached_revision)
	sim.level.set_wire(Vector2i(6, 5), false)
	_update(sim, 3)
	check(not sim.powered_cells.has(Vector2i(8, 5)), "cut wire invalidates cached power")
	sim.level.set_rail(Vector2i(6, 5), Tile.RAIL_DOWN)
	_update(sim, 4)
	check(sim.powered_cells.has(Vector2i(8, 5)), "new rail reconnects signal")
	sim.level.set_rail(Vector2i(6, 5), Tile.AIR)
	sim.level.set_cell(5, 6, Tile.TNT)
	_update(sim, 5)
	check_eq(sim.level.get_cell(5, 6), Tile.AIR, "newly connected TNT is detected immediately")
	check(not sim.powered_cells.has(Vector2i(8, 5)))
	sim.reset()
	check(sim.signal_grid == null)
	check(sim.signal_sources.is_empty())


func test_signal_cache_tracks_flying_block_coverage_without_terrain_change() -> void:
	var sim: GameSim = _sim()
	sim.level.set_sensor(Vector2i(4, 5), true)
	sim.level.set_wire(Vector2i(5, 5), true)
	var shot: SimProjectile = _shot(sim, Tile.DIRT, 160.0, 200.0, 0.0)
	_update(sim, 1)
	check(sim.powered_cells.has(Vector2i(5, 5)))
	shot.x = 400.0
	_update(sim, 2)
	check(sim.powered_cells.is_empty(), "flying coverage changes invalidate power without tile changes")
	shot.x = 160.0
	_update(sim, 3)
	check(sim.powered_cells.has(Vector2i(5, 5)))
	var replacement: LevelGrid = sim.level.duplicate_grid()
	replacement.set_wire(Vector2i(5, 5), false)
	sim.level = replacement
	_update(sim, 4)
	check(not sim.powered_cells.has(Vector2i(5, 5)), "replacement grid rebuilds signal cache")


func test_tnt_index_is_updated_after_copy_append_and_detonation() -> void:
	var grid: LevelGrid = LevelGrid.new(4, 4, Tile.TNT)
	check_eq(grid.tnt_cells.size(), 16)
	grid.set_cell(1, 1, Tile.AIR)
	check_eq(grid.tnt_cells.size(), 15)
	var copy: LevelGrid = grid.duplicate_grid()
	copy.set_cell(2, 2, Tile.DIRT)
	check_eq(grid.tnt_cells.size(), 15)
	check_eq(copy.tnt_cells.size(), 14)
	grid.append_rows(1, Tile.TNT)
	check_eq(grid.tnt_cells.size(), 19)
	var sim: GameSim = _sim()
	sim.level.set_cell(5, 8, Tile.TNT)
	check(sim.level.tnt_cells.has(Vector2i(8, 5)))
	MechanismSystem.detonate_cell(sim, Vector2i(8, 5))
	check(sim.level.tnt_cells.is_empty(), "chain removal cannot leave ghost TNT receivers")


func test_rail_motion_interpolates_every_material_and_follows_corners() -> void:
	for type: int in [Tile.DIRT, Tile.BOUNCY, Tile.GLASS, Tile.SAND, Tile.ICE, Tile.TNT]:
		var sim: GameSim = _sim()
		var from: Vector2i = Vector2i(8, 5)
		var corner: Vector2i = Vector2i(9, 5)
		sim.level.set_cell(from.y, from.x, type)
		sim.tick_count = 12
		check(MechanismSystem._move(sim, from, Vector2i.RIGHT))
		var motion: GameSim.TileMotion = sim.tile_motions[corner]
		check_eq(motion.position_at(11.0), Vector2(from) * Tile.SIZE, "motion begins at source")
		check_eq(motion.position_at(17.0), (Vector2(from) + Vector2(0.5, 0.0)) * Tile.SIZE, "half tick interval is halfway")
		check_eq(motion.position_at(23.0), Vector2(corner) * Tile.SIZE)
		sim.tick_count = 24
		check(MechanismSystem._move(sim, corner, Vector2i.DOWN))
		var next: GameSim.TileMotion = sim.tile_motions[corner + Vector2i.DOWN]
		check_eq(next.position_at(23.0), motion.position_at(23.0), "corner begins exactly where previous motion ends")
		check_eq(next.position_at(29.0), (Vector2(corner) + Vector2(0.0, 0.5)) * Tile.SIZE)


func test_sand_and_ice_motion_use_their_transport_interval() -> void:
	var sim: GameSim = _sim()
	sim.level.set_cell(5, 8, Tile.SAND)
	_update(sim, 6)
	check_eq(sim.tile_motions[Vector2i(8, 6)].duration, MechanismSystem.FALL_TICKS)
	check_eq(sim.tile_motions[Vector2i(8, 6)].position_at(8.0), Vector2(320.0, 220.0))
	sim.level.set_cell(6, 12, Tile.ICE)
	sim.level.set_cell(7, 12, Tile.STEEL)
	sim.level.set_cell(7, 13, Tile.STEEL)
	MechanismSystem.start_slide(sim, Vector2i(12, 6), 10.0)
	_update(sim, 8)
	check_eq(sim.tile_motions[Vector2i(13, 6)].duration, MechanismSystem.SLIDE_TICKS)


func test_rider_moves_with_the_block_tick_by_tick() -> void:
	var sim: GameSim = _sim()
	sim.level.set_cell(6, 8, Tile.DIRT)
	sim.player.place_at(324.0, 240.0 - sim.player.h - 0.001)
	sim.player.grounded = true
	sim.tick_count = 12
	var before: float = sim.player.x
	check(MechanismSystem._move(sim, Vector2i(8, 6), Vector2i.RIGHT))
	var motion: GameSim.TileMotion = sim.tile_motions[Vector2i(9, 6)]
	var step: float = Tile.SIZE / float(MechanismSystem.RAIL_TICKS)
	check_near(sim.tile_position_now(motion).x, 320.0 + step, 0.001, "the block has made its first step")
	check_near(sim.player.x, before + step, 0.001, "and so has the rider: no jump to the destination")
	for tick: int in range(13, 19):
		sim.tick_count = tick
		MechanismSystem.carry_player(sim)
	check_near(sim.player.x - before, sim.tile_position_now(motion).x - 320.0, 0.001, "half way, they are still together")
	check_near(sim.player.x, before + 20.0 + step, 0.001)
	# Jumping off leaves the block to finish the trip alone.
	sim.player.grounded = false
	sim.player.y -= 30.0
	var left_at: float = sim.player.x
	for tick: int in range(19, 24):
		sim.tick_count = tick
		MechanismSystem.carry_player(sim)
	check_near(sim.player.x, left_at, 0.001, "a rider who jumped off is not dragged along")
	check_near(sim.tile_position_now(motion).x, 360.0, 0.001, "the block arrives")


func test_block_in_transit_is_solid_where_it_is_not_where_it_is_going() -> void:
	var sim: GameSim = _sim()
	sim.level.set_cell(6, 8, Tile.DIRT)
	sim.player.place_at(43.0, 43.0)
	sim.tick_count = 12
	check(MechanismSystem._move(sim, Vector2i(8, 6), Vector2i.RIGHT))
	check_eq(sim.level.get_cell(6, 9), Tile.DIRT, "the grid already has it in the next cell")
	check(sim.is_tile_in_transit(Vector2i(9, 6)), "but it has not arrived")
	# Just after setting off it still fills the cell it came from...
	var origin_side: Array[SolidBox] = sim.solid_boxes(322.0, 242.0, 4.0, 4.0)
	check_eq(origin_side.size(), 1, "it is still solid at the near side of its old cell")
	check_near(origin_side[0].x, 320.0 + Tile.SIZE / float(MechanismSystem.RAIL_TICKS), 0.001, "at the place it has reached")
	# ...and has not filled the far side of the cell it is headed for.
	check(sim.solid_boxes(394.0, 242.0, 4.0, 4.0).is_empty(), "the far side of the next cell is still free")

	sim.tick_count = 18
	var half_way: Array[SolidBox] = sim.solid_boxes(300.0, 242.0, 140.0, 4.0)
	check_eq(half_way.size(), 1)
	check_near(half_way[0].x, 320.0 + Tile.SIZE * 7.0 / float(MechanismSystem.RAIL_TICKS), 0.001, "half way it is between the two cells")
	check(sim.solid_boxes(322.0, 242.0, 4.0, 4.0).is_empty(), "the cell it left has opened up behind it")

	sim.tick_count = 23
	check(not sim.is_tile_in_transit(Vector2i(9, 6)), "once there, it is an ordinary block again")
	var arrived: Array[SolidBox] = sim.solid_boxes(394.0, 242.0, 4.0, 4.0)
	check_eq(arrived.size(), 1)
	check_near(arrived[0].x, 360.0, 0.001)


func test_spat_block_easing_into_its_cell_is_solid_there_at_once() -> void:
	var sim: GameSim = _sim()
	sim.player.place_at(43.0, 43.0)
	sim.level.set_cell(6, 8, Tile.DIRT)
	sim.tick_count = 12
	sim.animate_tile_from(Vector2(290.0, 225.0), Vector2i(8, 6), MechanismSystem.SLIDE_TICKS)
	check(not sim.is_tile_in_transit(Vector2i(8, 6)), "a landing block is not a block in transit")
	var boxes: Array[SolidBox] = sim.solid_boxes(322.0, 242.0, 4.0, 4.0)
	check_eq(boxes.size(), 1)
	check_near(boxes[0].x, 320.0, 0.001, "it is solid in its cell straight away")
	var before: Vector2 = Vector2(sim.player.x, sim.player.y)
	sim.player.place_at(300.0, 240.0)
	MechanismSystem.carry_player(sim)
	check_near(sim.player.x, 300.0, 0.001, "and pushes nobody on the way in")
	sim.player.place_at(before.x, before.y)


func test_player_standing_where_a_block_is_going_is_pushed_along() -> void:
	var sim: GameSim = _sim()
	_powered_rail_row(sim, 7, 10)
	sim.level.set_cell(6, 8, Tile.DIRT)
	for col: int in range(7, 14):
		sim.level.set_cell(7, col, Tile.STEEL)
	# Standing on the floor in the very cell the block will move into.
	sim.player.place_at(363.0, 280.0 - sim.player.h - 0.001)
	sim.player.grounded = true
	sim.tick_count = 11
	sim.step(SimInput.new())
	check_eq(sim.level.get_cell(6, 9), Tile.DIRT, "the block moves although the player is in its way")
	for _tick: int in MechanismSystem.RAIL_TICKS:
		sim.step(SimInput.new())
		if sim.player.dead:
			break
	check(not sim.player.dead, "with room ahead the player is only moved")
	check(sim.player.x >= 400.0 - 0.01, "pushed out past the cell the block now fills (x %d)" % roundi(sim.player.x))


func test_player_pushed_into_a_wall_is_crushed() -> void:
	var sim: GameSim = _sim()
	_powered_rail_row(sim, 7, 9)
	sim.level.set_cell(6, 8, Tile.DIRT)
	for col: int in range(7, 12):
		sim.level.set_cell(7, col, Tile.STEEL)
		sim.level.set_cell(5, col, Tile.STEEL)
	# Boxed in: the block comes from the left, a wall stands right behind.
	sim.level.set_cell(6, 10, Tile.STEEL)
	sim.player.place_at(363.0, 280.0 - sim.player.h - 0.001)
	sim.player.grounded = true
	sim.tick_count = 11
	for _tick: int in MechanismSystem.RAIL_TICKS + 2:
		sim.step(SimInput.new())
		if sim.player.dead:
			break
	check(sim.player.dead, "with nowhere to go, being pushed is fatal")


func test_block_in_transit_pushes_a_player_in_its_way() -> void:
	var sim: GameSim = _sim()
	sim.level.set_cell(6, 8, Tile.DIRT)
	sim.player.place_at(43.0, 43.0)
	sim.tick_count = 12
	check(MechanismSystem._move(sim, Vector2i(8, 6), Vector2i.RIGHT))
	# The player steps into the path after the block has set off.
	sim.player.place_at(375.0, 240.0 + 3.0)
	sim.player.grounded = false
	for tick: int in range(13, 24):
		sim.tick_count = tick
		MechanismSystem.carry_player(sim)
		var block: Vector2 = sim.tile_position_now(sim.tile_motions[Vector2i(9, 6)])
		check(sim.player.x >= block.x + Tile.SIZE, "the player is kept ahead of the block (tick %d)" % tick)
	check_near(sim.player.x, 400.0, 0.01, "and ends up just past where it stops")
	check(not sim.player.dead, "with room to be pushed into, nothing worse happens")

func test_tile_motion_cleanup_after_destruction_completion_and_reset() -> void:
	var sim: GameSim = _sim()
	sim.level.set_cell(5, 8, Tile.ICE)
	sim.tick_count = 12
	check(MechanismSystem._move(sim, Vector2i(8, 5), Vector2i.RIGHT))
	sim.level.set_cell(5, 9, Tile.AIR)
	sim._prune_tile_motions()
	check(sim.tile_motions.is_empty(), "destroyed moving block leaves no visual ghost")
	sim.level.set_cell(5, 8, Tile.DIRT)
	check(MechanismSystem._move(sim, Vector2i(8, 5), Vector2i.RIGHT))
	sim.tick_count += 12
	sim._prune_tile_motions()
	check(sim.tile_motions.is_empty(), "completed block returns to the static tile layer")
	sim.level.set_cell(5, 8, Tile.ICE)
	check(MechanismSystem._move(sim, Vector2i(8, 5), Vector2i.DOWN))
	sim.reset()
	check(sim.tile_motions.is_empty())


func test_eraser_removes_all_overlapping_layers_in_one_undo() -> void:
	var editor: LevelEditor = LevelEditor.new()
	editor.open(LevelCodec.decode(LevelLibrary.default_rows()))
	var cell: Vector2i = Vector2i(8, 5)
	editor.level.grid.set_cell(cell.y, cell.x, Tile.ICE)
	editor.level.grid.set_sensor(cell, true)
	editor.level.grid.set_wire(cell, true)
	editor.level.grid.set_rail(cell, Tile.RAIL_DOWN)
	var before: LevelData = editor.level.duplicate_level()
	editor.set_brush(LevelEditor.Brush.ERASER)
	editor.begin_stroke()
	editor.stroke_to(cell, false)
	editor.end_stroke()
	check_eq(editor.level.grid.get_cell(cell.y, cell.x), Tile.AIR)
	check(not editor.level.grid.sensors.has(cell))
	check(not editor.level.grid.wires.has(cell))
	check(not editor.level.grid.rails.has(cell))
	editor.undo()
	check(editor.level.equals(before), "whole overlapping cell is restored together")


func test_spat_block_settles_smoothly_into_its_grid_cell() -> void:
	var sim: GameSim = _sim()
	sim.level.set_cell(6, 9, Tile.STEEL)
	var shot: SimProjectile = _shot(sim, Tile.DIRT, 325.0, 240.0, 10.0)
	shot.eaten_count = 1
	sim.tick_count = 10
	ProjectileSystem._settle(sim, shot, 6, 8, 345.0, 260.0)
	var motion: GameSim.TileMotion = sim.tile_motions[Vector2i(8, 6)]
	check_eq(motion.position_at(9.0), Vector2(325.0, 240.0))
	check_eq(motion.position_at(13.0), Vector2(320.0, 240.0))
	check_eq(motion.type, Tile.DIRT_EATEN_1, "settling preserves swallowed block wear")


## A powered rail along row 6 from column [param first] to [param last].
func _powered_rail_row(sim: GameSim, first: int, last: int, rail: int = Tile.RAIL_RIGHT) -> void:
	for col: int in range(first, last + 1):
		sim.level.set_rail(Vector2i(col, 6), rail)
	# A covered sensor beside the row keeps the whole rail powered.
	sim.level.set_sensor(Vector2i(first, 7), true)
	sim.level.set_cell(7, first, Tile.STEEL)
	sim.player.place_at(43.0, 43.0)


func test_block_on_a_rail_can_be_swallowed_whole_while_it_moves() -> void:
	var sim: GameSim = _sim()
	_powered_rail_row(sim, 5, 16)
	sim.level.set_cell(6, 7, Tile.DIRT)
	for col: int in range(1, 18):
		sim.level.set_cell(8, col, Tile.STEEL)
	# Standing on the floor just under the rail, mouth open at the block.
	sim.player.place_at(6.0 * Tile.SIZE + 3.0, 8.0 * Tile.SIZE - sim.player.h - 0.001)
	sim.player.grounded = true
	var eat: SimInput = SimInput.new()
	eat.eat = true
	eat.mouse_x = 7.5 * Tile.SIZE - sim.camera.x
	eat.mouse_y = 6.5 * Tile.SIZE - sim.camera.y
	sim.tick_count = 8
	var started: bool = false
	var moved_while_eating: int = 0
	var target_col: int = -1
	for _tick: int in 90:
		sim.step(eat)
		if sim.player.has_eating_target and sim.player.eating_progress > 0.0:
			started = true
			if target_col >= 0 and sim.player.eating_target_c != target_col:
				moved_while_eating += 1
			target_col = sim.player.eating_target_c
		if sim.player.has_block:
			break
	check(started, "the player gets a bite on the block")
	check(moved_while_eating >= 1, "the block moved on during the bite (%d steps)" % moved_while_eating)
	check(sim.player.has_block, "and was swallowed all the same")
	check_eq(sim.player.carried_block_type, Tile.DIRT)
	var left: int = 0
	for col: int in sim.level.cols:
		if sim.level.get_cell(6, col) == Tile.DIRT:
			left += 1
	check_eq(left, 0, "nothing of it is left on the rail")


func test_blocks_in_an_unbroken_row_ride_the_rail_together() -> void:
	var sim: GameSim = _sim()
	_powered_rail_row(sim, 5, 12)
	for col: int in [6, 7, 8]:
		sim.level.set_cell(6, col, Tile.DIRT)
	_update(sim, 12)
	check_eq(sim.level.get_cell(6, 6), Tile.AIR, "the last block of the row has moved on")
	for col: int in [7, 8, 9]:
		check_eq(sim.level.get_cell(6, col), Tile.DIRT, "the whole row moved one cell, with no gap needed (%d)" % col)
		check(sim.is_tile_in_transit(Vector2i(col, 6)), "each of them is on its way")
	_update(sim, 24)
	for col: int in [8, 9, 10]:
		check_eq(sim.level.get_cell(6, col), Tile.DIRT, "and keeps moving as one (%d)" % col)
	check_eq(sim.level.get_cell(6, 7), Tile.AIR)


func test_row_on_a_rail_stops_together_at_the_end_of_the_line() -> void:
	var sim: GameSim = _sim()
	_powered_rail_row(sim, 5, 9)
	for col: int in [7, 8, 9]:
		sim.level.set_cell(6, col, Tile.DIRT)
	_update(sim, 12)
	for col: int in [7, 8, 9]:
		check_eq(sim.level.get_cell(6, col), Tile.DIRT, "nobody moves when the front has nowhere to go (%d)" % col)
		check(not sim.is_tile_in_transit(Vector2i(col, 6)))

	# A wall ahead of the front block holds the whole row back the same way.
	var walled: GameSim = _sim()
	_powered_rail_row(walled, 5, 12)
	for col: int in [6, 7]:
		walled.level.set_cell(6, col, Tile.DIRT)
	walled.level.set_cell(6, 8, Tile.STEEL)
	_update(walled, 12)
	check_eq(walled.level.get_cell(6, 6), Tile.DIRT, "a wall in front stops the block behind as well")
	check_eq(walled.level.get_cell(6, 7), Tile.DIRT)


func test_each_block_moves_one_cell_per_rail_step() -> void:
	var sim: GameSim = _sim()
	_powered_rail_row(sim, 5, 12)
	sim.level.set_cell(6, 6, Tile.DIRT)
	sim.level.set_cell(6, 8, Tile.DIRT)
	_update(sim, 12)
	check_eq(sim.level.get_cell(6, 7), Tile.DIRT, "the rear block moved one cell")
	check_eq(sim.level.get_cell(6, 9), Tile.DIRT, "the front block moved one cell")
	check_eq(sim.level.get_cell(6, 8), Tile.AIR, "and the gap between them is still there")
	check_eq(sim.level.get_cell(6, 10), Tile.AIR, "nothing was carried twice")


func test_tnt_delayed_body_charge_allows_escape_and_survives_without_mechanisms() -> void:
	var sim: GameSim = _impact_sim(Vector2i.RIGHT, Collision.TNT_IMPACT_SPEED)
	Collision.solve_x(sim)
	sim.player.place_at(43.0, 43.0)
	sim.mechanisms_enabled = false
	for tick: int in MechanismSystem.TNT_FUSE_TICKS - 1:
		sim.step(SimInput.new())
	check_eq(sim.tnt_charges.size(), 1)
	check(not sim.player.dead, "no blast damage before the fuse ends")
	sim.step(SimInput.new())
	check(sim.tnt_charges.is_empty())
	check(not sim.player.dead, "player can leave the stationary primed charge")


func test_tnt_impact_preserves_remaining_projectile_fuse() -> void:
	var sim: GameSim = _sim()
	sim.level.set_cell(5, 7, Tile.STEEL)
	var shot: SimProjectile = _shot(sim, Tile.TNT, 235.0, 200.0, 25.0)
	shot.fuse_ticks = 11
	ProjectileSystem.update(sim)
	check_eq(sim.tnt_charges.size(), 1)
	check_eq(sim.tnt_charges[0].explode_tick, 10)
	_advance_tnt(sim, 9)
	check_eq(sim.tnt_charges.size(), 1)
	_advance_tnt(sim, 1)
	check(sim.tnt_charges.is_empty(), "wall contact does not extend an already burning fuse")


func test_tnt_firing_tick_does_not_shorten_point_four_second_delay() -> void:
	var sim: GameSim = _sim()
	sim.player.place_at(203.0, 203.0)
	sim.player.has_block = true
	sim.player.carried_block_type = Tile.TNT
	PlayerSystem._fire(sim, PlayerSystem.Aim.new())
	var shot: SimProjectile = sim.projectiles[0]
	shot.x = 700.0
	shot.y = 200.0
	shot.vx = 0.0
	shot.vy = 0.0
	ProjectileSystem.update(sim)
	check_eq(shot.fuse_ticks, 24, "creation tick is not part of the 0.4-second interval")
	for tick: int in MechanismSystem.TNT_FUSE_TICKS - 1:
		sim.tick_count += 1
		ProjectileSystem.update(sim)
	check(not shot.dead)
	sim.tick_count += 1
	ProjectileSystem.update(sim)
	check(shot.dead)
