extends Node
## Drives the real application through its main flows with synthetic input and
## checks the result of each step. Started by `smoke_test.gd`, which explains
## how to run it.

var _failures: PackedStringArray = PackedStringArray()
var _checks: int = 0
var _app: App


func run() -> void:
	SavePaths.wipe_sandbox()
	# Run the clock fast: the game logic counts ticks, not seconds.
	Engine.time_scale = 12.0
	var app_scene: PackedScene = load("res://src/app/app.tscn")
	_app = app_scene.instantiate()
	get_tree().root.add_child(_app)
	await _frames(5)

	await _test_menu()
	await _test_play_and_win()
	await _test_pause()
	await _test_death_and_restart()
	await _test_mouse_eat_and_shoot()
	await _test_boss_level()
	await _test_editor()
	await _test_editor_mouse_painting()
	await _test_editor_test_play()
	await _test_settings()

	Engine.time_scale = 1.0
	print("")
	for failure: String in _failures:
		print("FAIL  " + failure)
	print("smoke: %d checks, %d failures" % [_checks, _failures.size()])
	get_tree().quit(1 if not _failures.is_empty() else 0)


# --- Scenarios ------------------------------------------------------------------------

func _test_menu() -> void:
	var menu: MainMenu = _screen() as MainMenu
	_check(menu != null, "the app starts on the main menu")
	if menu == null:
		return
	_check(menu.find_children("*", "LevelCard", true, false).size() == 10, "ten level cards are shown")
	_check(menu.selected_world() == 1, "world 1 is selected")


func _test_play_and_win() -> void:
	_app.play_official(1)
	await _frames(3)
	var game: GameScreen = _screen() as GameScreen
	_check(game != null, "choosing a level opens the game")
	if game == null:
		return
	var sim: GameSim = game.get("_sim")
	await _physics_frames(20)
	_check(sim.tick_count >= 15, "the simulation is ticking (%d ticks)" % sim.tick_count)

	# Walk right to the goal of level 1.
	_key(KEY_D, true)
	var frames: int = 0
	while not sim.player.won and frames < 600:
		await get_tree().physics_frame
		frames += 1
	_key(KEY_D, false)
	_check(sim.player.won, "holding right reaches the goal of level 1")
	_check(Progress.is_cleared(1), "clearing a level is recorded")

	# The jump key continues to the next level.
	_key(KEY_W, true)
	await _frames(4)
	_key(KEY_W, false)
	await _frames(4)
	var next_game: GameScreen = _screen() as GameScreen
	_check(next_game != null and next_game != game, "continuing loads the next level")
	if next_game != null:
		var next_sim: GameSim = next_game.get("_sim")
		_check(next_sim.slot == 2, "the next level is slot 2")


func _test_pause() -> void:
	var game: GameScreen = _screen() as GameScreen
	if game == null:
		return
	var sim: GameSim = game.get("_sim")
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await _frames(3)
	_check(get_tree().paused, "Escape pauses the game")
	var ticks: int = sim.tick_count
	await _physics_frames(15)
	_check(sim.tick_count == ticks, "the simulation is frozen while paused")
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await _frames(3)
	_check(not get_tree().paused, "Escape resumes the game")
	await _physics_frames(10)
	_check(sim.tick_count > ticks, "the simulation runs again")


func _test_death_and_restart() -> void:
	_app.play_official(14)  # Floor spikes two tiles right of the start.
	await _frames(3)
	var game: GameScreen = _screen() as GameScreen
	if game == null:
		return
	var sim: GameSim = game.get("_sim")
	_key(KEY_D, true)
	var frames: int = 0
	while not sim.player.dead and frames < 300:
		await get_tree().physics_frame
		frames += 1
	_key(KEY_D, false)
	_check(sim.player.dead, "walking into spikes kills the player")
	# R restarts at once instead of waiting for the death screen.
	_key(KEY_R, true)
	_key(KEY_R, false)
	await _physics_frames(3)
	_check(not sim.player.dead, "the restart key restarts the level")


## Swallows a block and spits it out again using real mouse events.
func _test_mouse_eat_and_shoot() -> void:
	_app.play_official(21)  # Start at column 1, dirt at column 3, steel at column 5.
	await _frames(3)
	var game: GameScreen = _screen() as GameScreen
	if game == null:
		return
	var sim: GameSim = game.get("_sim")
	var view: WorldView = game.get_node("%WorldView")
	await _physics_frames(40)  # Let the player land.

	var dirt: Vector2 = _world_to_window(view, Vector2(3.5, 13.5) * Tile.SIZE)
	_mouse_move(dirt)
	await _frames(2)
	_check(view.mouse_in_world().distance_to(Vector2(3.5, 13.5) * Tile.SIZE) < 2.0, "the pointer maps to world coordinates")
	_mouse_button(MOUSE_BUTTON_LEFT, true, dirt)
	await _physics_frames(14)
	_mouse_button(MOUSE_BUTTON_LEFT, false, dirt)
	_check(sim.player.has_block, "holding the left button on a block swallows it")
	_check(sim.level.get_cell(13, 3) == Tile.AIR, "and removes it from the level")

	var wall: Vector2 = _world_to_window(view, Vector2(5.5, 13.5) * Tile.SIZE)
	_mouse_move(wall)
	_mouse_button(MOUSE_BUTTON_RIGHT, true, wall)
	await _physics_frames(6)
	_check(sim.player.in_bullet_time, "holding the right button enters bullet time")
	_mouse_button(MOUSE_BUTTON_RIGHT, false, wall)
	await _physics_frames(60)
	_check(not sim.player.has_block, "releasing it spits the block out")
	_check(sim.level.get_cell(13, 4) == Tile.DIRT_EATEN_1, "and the block lands, one stage worn")


func _test_boss_level() -> void:
	_app.play_official(40)
	await _frames(3)
	var game: GameScreen = _screen() as GameScreen
	if game == null:
		return
	var sim: GameSim = game.get("_sim")
	_check(sim.boss.active, "slot 40 has a boss")
	_key(KEY_D, true)
	var frames: int = 0
	while sim.boss.state == BossState.State.SUSPENDED and frames < 600:
		await get_tree().physics_frame
		frames += 1
	_key(KEY_D, false)
	_check(sim.boss.state == BossState.State.INTRO, "approaching wakes the boss")
	# Let the entrance, the drop and a few attacks play out and get drawn.
	await _physics_frames(700)
	_check(sim.boss.state != BossState.State.INTRO, "the boss fight is under way")


func _test_editor() -> void:
	_app.edit_slot(23)
	await _frames(4)
	var screen: EditorScreen = _screen() as EditorScreen
	_check(screen != null, "opening a slot for editing shows the editor")
	if screen == null:
		return
	var editor: LevelEditor = screen.get("_editor")
	_check(not editor.is_dirty(), "a freshly opened level has no unsaved changes")
	_check(editor.level.equals(LevelLibrary.built_in_level(23)), "the slot's level is loaded")

	editor.set_brush(LevelEditor.Brush.BOUNCY)
	editor.begin_stroke()
	editor.stroke_to(Vector2i(5, 5), false)
	editor.stroke_to(Vector2i(9, 5), false)
	editor.end_stroke()
	await _frames(2)
	_check(editor.level.grid.get_cell(5, 7) == Tile.BOUNCY, "a stroke paints every cell on its way")
	_check(editor.is_dirty(), "painting marks the level unsaved")
	var view_sim: GameSim = screen.get("_sim")
	_check(view_sim.level.get_cell(5, 7) == Tile.BOUNCY, "the view shows the edited level")

	editor.undo()
	_check(editor.level.grid.get_cell(5, 7) == Tile.AIR, "undo reverts the whole stroke")
	editor.redo()
	_check(editor.level.grid.get_cell(5, 7) == Tile.BOUNCY, "redo restores it")
	editor.resize(50, 20)
	await _frames(2)
	_check(view_sim.level.cols == 50 and view_sim.level.rows == 20, "resizing reaches the view")
	_check(not LevelStore.has_custom(23), "nothing is written until the level is saved")


## Paints, erases and pans with real mouse events on the editor's view.
func _test_editor_mouse_painting() -> void:
	var screen: EditorScreen = _screen() as EditorScreen
	if screen == null:
		return
	var editor: LevelEditor = screen.get("_editor")
	var view: WorldView = screen.get_node("%WorldView")
	editor.set_brush(LevelEditor.Brush.STEEL)
	await _frames(2)

	var from: Vector2 = _world_to_window(view, Vector2(12.5, 8.5) * Tile.SIZE)
	var to: Vector2 = _world_to_window(view, Vector2(16.5, 8.5) * Tile.SIZE)
	_mouse_move(from)
	_mouse_button(MOUSE_BUTTON_LEFT, true, from)
	await _frames(2)
	_mouse_move(to)
	await _frames(2)
	_mouse_button(MOUSE_BUTTON_LEFT, false, to)
	await _frames(2)
	var painted: int = 0
	for c: int in range(12, 17):
		if editor.level.grid.get_cell(8, c) == Tile.STEEL:
			painted += 1
	_check(painted == 5, "dragging the left button paints a line (%d of 5 cells)" % painted)

	_mouse_button(MOUSE_BUTTON_RIGHT, true, to)
	await _frames(2)
	_mouse_button(MOUSE_BUTTON_RIGHT, false, to)
	await _frames(2)
	_check(editor.level.grid.get_cell(8, 16) == Tile.AIR, "the right button erases")
	_check(editor.brush == LevelEditor.Brush.STEEL, "without changing the brush")


func _test_editor_test_play() -> void:
	var screen: EditorScreen = _screen() as EditorScreen
	if screen == null:
		return
	var editor: LevelEditor = screen.get("_editor")
	var play_button: Button = screen.get_node("%PlayButton")
	play_button.pressed.emit()
	await _frames(4)
	var game: GameScreen = _screen() as GameScreen
	_check(game != null, "the play button test-plays the level")
	if game == null:
		return
	var sim: GameSim = game.get("_sim")
	_check(sim.level.cols == 50, "test play uses the unsaved working copy")
	_check(sim.level.get_cell(5, 7) == Tile.BOUNCY, "including its unsaved tiles")
	await _physics_frames(30)

	game.editor_requested.emit()
	await _frames(4)
	_check(_screen() == screen, "leaving test play returns to the same editor")
	_check(editor.is_dirty(), "the unsaved work survived the round trip")
	_check(editor.can_undo(), "and so did the undo history")

	# Closing the window with unsaved work must ask instead of quitting.
	var confirm: ConfirmDialog = screen.get_node("%ConfirmDialog")
	get_tree().root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await _frames(3)
	_check(confirm.visible, "closing the window with unsaved work asks first")
	var answers: Array[Node] = confirm.get_node("%Buttons").get_children()
	_check(answers.size() == 3, "the question offers save, discard and cancel")
	if answers.size() == 3:
		var cancel: Button = answers[2]
		cancel.pressed.emit()
	await _frames(3)
	_check(not confirm.visible and _screen() == screen, "cancelling keeps the editor open")
	_check(editor.is_dirty(), "and keeps the unsaved work")

	# Saving, then reverting to the built-in level.
	var save_button: Button = screen.get_node("%SaveButton")
	save_button.pressed.emit()
	await _frames(2)
	_check(LevelStore.has_custom(23), "saving writes the custom level")
	_check(not editor.is_dirty(), "and clears the unsaved flag")
	_check(LevelStore.get_level(23).grid.get_cell(5, 7) == Tile.BOUNCY, "the saved level is what the slot plays")
	_check(LevelStore.delete_custom(23) == OK, "the custom level can be deleted")
	_check(LevelStore.get_level(23).equals(LevelLibrary.built_in_level(23)), "the slot falls back to its built-in level")


func _test_settings() -> void:
	_app.show_menu()
	await _frames(4)
	var menu: MainMenu = _screen() as MainMenu
	_check(menu != null, "the menu can be reached from the editor")
	if menu == null:
		return
	var dialog: SettingsDialog = menu.get_node("%SettingsDialog")
	dialog.open(SettingsDialog.Context.MAIN_MENU)
	await _frames(3)
	_check(dialog.visible, "the settings dialog opens")

	Settings.set_game_speed(2.0)
	Settings.set_volume(0.35)
	Settings.rebind(InputBindings.JUMP, InputBindings.make_key(KEY_SPACE))
	await _frames(3)
	_check(InputMap.action_has_event(InputBindings.JUMP, InputBindings.make_key(KEY_SPACE)), "rebinding reaches the input map")
	# Binding eat to the shoot button swaps the two instead of leaving shoot dead.
	Settings.rebind(InputBindings.EAT, InputBindings.make_mouse(MOUSE_BUTTON_RIGHT))
	_check(
		InputBindings.same_binding(Settings.binding(InputBindings.SHOOT), InputBindings.make_mouse(MOUSE_BUTTON_LEFT)),
		"a conflicting binding swaps with the other action"
	)
	await _frames(3)
	_check(FileAccess.file_exists(SavePaths.settings_file()), "settings are saved")
	var saved: ConfigFile = ConfigFile.new()
	saved.load(SavePaths.settings_file())
	var saved_speed: float = saved.get_value("gameplay", "game_speed", 0.0)
	var saved_volume: float = saved.get_value("audio", "volume", 0.0)
	_check(is_equal_approx(saved_speed, 2.0), "game speed is persisted")
	_check(is_equal_approx(saved_volume, 0.35), "volume is persisted")
	Settings.reset_bindings()
	Settings.set_game_speed(1.0)

	# The fullscreen shortcut works everywhere, a dialog included, and goes
	# through the setting so the settings screen stays in step.
	var was_fullscreen: bool = Settings.fullscreen
	_key(KEY_F11, true)
	_key(KEY_F11, false)
	await _frames(2)
	_check(Settings.fullscreen != was_fullscreen, "F11 switches fullscreen")
	var fullscreen_button: Button = dialog.get_node("%SettingsPanel").get_node("%FullscreenButton")
	_check(fullscreen_button.button_pressed == Settings.fullscreen, "the settings screen follows")
	_key(KEY_F11, true)
	_key(KEY_F11, false)
	await _frames(2)
	_check(Settings.fullscreen == was_fullscreen, "and F11 switches it back")
	dialog.close()
	await _frames(2)
	_check(not dialog.visible, "the settings dialog closes")


# --- Helpers -----------------------------------------------------------------------------

func _screen() -> Control:
	var screens: Node = _app.get_node("%Screens")
	return screens.get_child(screens.get_child_count() - 1) as Control if screens.get_child_count() > 0 else null


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("  ok    " + description)
	else:
		print("  FAIL  " + description)
		_failures.append(description)


func _frames(count: int) -> void:
	for _i: int in count:
		await get_tree().process_frame


func _physics_frames(count: int) -> void:
	for _i: int in count:
		await get_tree().physics_frame


## Window position of a world coordinate shown in [param view].
func _world_to_window(view: WorldView, world: Vector2) -> Vector2:
	var camera: Vector2 = Vector2(view.sim.camera.x, view.sim.camera.y)
	var in_view: Vector2 = (world - camera) * view.world_scale
	var on_canvas: Vector2 = view.get_global_transform_with_canvas() * in_view
	return get_tree().root.get_final_transform() * on_canvas


func _mouse_move(window_position: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = window_position
	event.global_position = window_position
	Input.parse_input_event(event)


func _mouse_button(button: MouseButton, pressed: bool, window_position: Vector2) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = window_position
	event.global_position = window_position
	Input.parse_input_event(event)


## Sends a physical key press or release through the real input pipeline.
func _key(physical_keycode: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = physical_keycode
	event.keycode = physical_keycode
	event.pressed = pressed
	Input.parse_input_event(event)
