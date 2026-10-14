extends "res://tests/smoke/smoke_driver.gd"
## Runs the standard smoke suite with the new editor-to-game mechanism flow.


func _test_editor() -> void:
	_app.edit_slot(61)
	await _frames(4)
	var screen: EditorScreen = _screen() as EditorScreen
	_check(screen != null, "mechanism editor opens")
	if screen == null:
		return
	var editor: LevelEditor = screen._editor
	_check(screen._size_info.text == "%d × %d" % [editor.level.grid.cols, editor.level.grid.rows], "editor caption shows the loaded campaign dimensions")
	var original_view_document: LevelData = editor.level.duplicate_level()
	screen._grid_toggle.toggled.emit(false)
	screen._devices_toggle.toggled.emit(false)
	_check(not screen._view.editor_show_grid and not screen._view.editor_show_devices, "editor display layers can be hidden")
	_check(editor.level.equals(original_view_document), "display toggles never modify level data")
	screen._grid_toggle.toggled.emit(true)
	screen._devices_toggle.toggled.emit(true)
	var brushes: Array[LevelEditor.Brush] = [LevelEditor.Brush.SENSOR, LevelEditor.Brush.WIRE, LevelEditor.Brush.RAIL_RIGHT, LevelEditor.Brush.RAIL_LEFT, LevelEditor.Brush.RAIL_UP, LevelEditor.Brush.RAIL_DOWN, LevelEditor.Brush.SAND, LevelEditor.Brush.ICE, LevelEditor.Brush.TNT]
	for brush: LevelEditor.Brush in brushes:
		var button: Button = screen._brush_buttons[brush]
		button.pressed.emit()
		_check(editor.brush == brush, "new brush selectable: " + BrushIcon.label_for(brush))
	_paint_material(editor, LevelEditor.Brush.SENSOR, Vector2i(4, 6))
	_paint_material(editor, LevelEditor.Brush.DIRT, Vector2i(4, 6))
	_paint_material(editor, LevelEditor.Brush.DIRT, Vector2i(8, 6))
	editor.set_brush(LevelEditor.Brush.RAIL_RIGHT)
	_check(screen._rail_panel.visible, "rail options appear for track brush")
	screen._rail_auto_toggle.toggled.emit(false)
	_check(not editor.rail_auto_turn, "manual rail direction mode is available")
	screen._rail_auto_toggle.set_pressed_no_signal(true)
	screen._rail_auto_toggle.toggled.emit(true)
	editor.begin_stroke()
	for cell: Vector2i in [Vector2i(8, 6), Vector2i(9, 6), Vector2i(9, 7), Vector2i(8, 7), Vector2i(8, 6)]:
		editor.stroke_to(cell, false)
	editor.end_stroke()
	_check(editor.level.grid.rails[Vector2i(9, 6)] == Tile.RAIL_DOWN, "dragging automatically orients the corner")
	_paint_material(editor, LevelEditor.Brush.RAIL_LEFT, Vector2i(12, 6))
	_paint_material(editor, LevelEditor.Brush.SAND, Vector2i(14, 5))
	_paint_material(editor, LevelEditor.Brush.ICE, Vector2i(16, 6))
	_paint_material(editor, LevelEditor.Brush.TNT, Vector2i(20, 6))
	editor.set_brush(LevelEditor.Brush.WIRE)
	editor.begin_stroke()
	editor.stroke_to(Vector2i(4, 6), false)
	editor.stroke_to(Vector2i(8, 6), false)
	editor.end_stroke()
	await _frames(3)
	_check(LevelStore.get_level(61).grid.wires.size() == 5, "wire stroke is automatically saved")
	_check(LevelStore.get_level(61).grid.sensors.has(Vector2i(4, 6)), "wire stroke preserves sensor")
	var serialized: Variant = JSON.parse_string(LevelStore.export_slot(61))
	_check(LevelCodec.decode_document(serialized).equals(editor.level), "export retains all new tiles and wires")
	editor.set_brush(LevelEditor.Brush.RAIL_RIGHT)
	await _capture_mechanisms("mechanism_editor")
	screen._on_play_pressed()
	var game: GameScreen = _screen() as GameScreen
	_check(game != null, "mechanism room test-plays from the real editor")
	if game != null:
		game.set_physics_process(false)
		await _frames(3)
		game._pause_menu.hide()
		get_tree().paused = false
		var sim: GameSim = game._sim
		_check(sim.mechanisms_enabled, "new mechanism simulation is enabled")
		_check(sim.level.wires.size() == 5, "test play receives the separate wire layer")
		sim.tick_count = 12
		MechanismSystem.update(sim)
		_check(sim.powered_cells.has(Vector2i(8, 6)), "sensor powers rail through the wire")
		_check(sim.level.get_cell(6, 9) == Tile.DIRT, "powered rail transports its block")
		_check(sim.level.get_cell(6, 14) == Tile.SAND, "sand drops in test play")
		sim.tick_count = 24
		MechanismSystem.update(sim)
		_check(sim.level.get_cell(7, 9) == Tile.DIRT, "rail bends downward in actual test play")
		sim.tick_count = 36
		MechanismSystem.update(sim)
		_check(sim.level.get_cell(7, 8) == Tile.DIRT, "rail bends left in actual test play")
		game._view.tick_alpha = 1.0
		await _capture_mechanisms("mechanism_play")
		var player_layer: PlayerLayer = game._view.get_node("World/Player") as PlayerLayer
		sim.player.has_block = true
		sim.player.carried_block_type = Tile.TNT
		player_layer._process(0.2)
		_check(player_layer._current_tint_strength > 0.0, "held material colors the rendered player")
		sim.reset()
		player_layer._process(0.0)
		_check(player_layer._current_tint_strength == 0.0 and player_layer._current_tint_color == Palette.GREEN_500, "restart immediately clears stale tint and movement reactions")
		game.editor_requested.emit()
		await _frames(3)
		_check(_screen() == screen, "returning from test preserves the mechanism editor")
		_check(editor.level.grid.get_cell(6, 8) == Tile.DIRT, "test play does not mutate editor source")
	_test_failed_save_preserves_editor(screen)
	var before_erase: LevelData = editor.level.duplicate_level()
	var eraser_button: Button = screen._brush_buttons[LevelEditor.Brush.ERASER]
	eraser_button.pressed.emit()
	eraser_button.set_pressed_no_signal(false)
	eraser_button.pressed.emit()
	_check(eraser_button.button_pressed, "reselecting eraser keeps its active highlight")
	editor.begin_stroke()
	editor.stroke_to(Vector2i(8, 6), false)
	editor.end_stroke()
	_check(editor.level.grid.get_cell(6, 8) == Tile.AIR and not editor.level.grid.rails.has(Vector2i(8, 6)) and not editor.level.grid.wires.has(Vector2i(8, 6)), "eraser clears a covered rail and wire with its block")
	editor.undo()
	_check(editor.level.equals(before_erase), "eraser undo restores every layer")
	screen._select_brush(LevelEditor.Brush.COPY)
	screen._painting = true
	screen._erasing = true
	editor.begin_stroke()
	editor.stroke_to(Vector2i(8, 6), true)
	screen._end_stroke()
	_check(editor._stroke_snapshot == null, "right erase in copy mode commits its stroke")
	screen._undo_action()
	_check(editor.level.equals(before_erase), "right erase in copy mode has one complete undo")
	LevelStore.delete_custom(61)
	await super._test_editor()


func _paint_material(editor: LevelEditor, brush: LevelEditor.Brush, cell: Vector2i) -> void:
	editor.set_brush(brush)
	editor.begin_stroke()
	editor.stroke_to(cell, false)
	editor.end_stroke()


func _capture_mechanisms(label: String) -> void:
	if DisplayServer.get_name() == "headless" or not "--qa-capture" in OS.get_cmdline_user_args():
		return
	await _frames(4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/output/" + label + ".png")


class FailingRepository extends LevelRepository:
	var attempts: int = 0
	func save_custom(_slot: int, _data: LevelData) -> Error:
		attempts += 1
		return ERR_CANT_CREATE


func _test_failed_save_preserves_editor(screen: EditorScreen) -> void:
	var original: LevelRepository = LevelStore._repository
	LevelStore._repository = FailingRepository.new(original._dir)
	_paint_material(screen._editor, LevelEditor.Brush.ICE, Vector2i(24, 5))
	var progress: Dictionary[String, bool] = {"left": false}
	screen.run_when_changes_settled(func() -> void: progress["left"] = true)
	_check(not progress["left"], "failed save prevents leaving editor")
	_check(screen._editor.is_dirty(), "failed save keeps unsaved work and undo history")
	_check(screen._editor.level.grid.get_cell(5, 24) == Tile.ICE, "failed save preserves in-memory changes")
	_check(screen._save_button.text == "重試儲存", "failed save exposes an explicit retry button")
	var failing: FailingRepository = LevelStore._repository as FailingRepository
	var attempts_before: int = failing.attempts
	screen._painting = true
	screen._editor.set_brush(LevelEditor.Brush.DIRT)
	screen._editor.begin_stroke()
	screen._editor.stroke_to(Vector2i(24, 6), false)
	screen._end_stroke()
	_check(failing.attempts == attempts_before + 1, "gesture completion attempts one save on failure")
	LevelStore._repository = original
	screen.run_when_changes_settled(func() -> void: progress["left"] = true)
	_check(progress["left"] and not screen._editor.is_dirty(), "saving again succeeds before leaving")


func _test_menu() -> void:
	await super._test_menu()
	var menu: MainMenu = _screen() as MainMenu
	for world: int in range(6, 11):
		menu._select_world(world)
		await _frames(2)
		_check(menu.selected_world() == world, "mechanism world %d selectable" % world)
		_check(menu._world_buttons[world - 1].visible, "world %d visible in campaign" % world)
		var first: int = (world - 1) * 10 + 1
		_check(LevelStore.has_level(first), "authored stage available in world %d" % world)
		_check(menu._cards[0]._title.text == LevelLibrary.stage_name(first), "world %d displays its authored stage name" % world)
		_check(not menu._cards[0].tooltip_text.is_empty(), "world %d exposes its lesson in the menu" % world)
		_check(LevelLibrary.is_boss_slot(first + 9), "world %d boss card is assigned" % world)
	menu._select_world(1)
