extends Node
## Walks the application through its screens and saves a screenshot of each
## to `res://tests/output/`. Started by `capture_screens.gd`.

const OUT_DIR: String = "res://tests/output"

var _app: App


func run() -> void:
	SavePaths.wipe_sandbox()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var app_scene: PackedScene = load("res://src/app/app.tscn")
	_app = app_scene.instantiate()
	get_tree().root.add_child(_app)
	await _wait(0.9)
	await _shot("01_menu_world1")

	var menu: MainMenu = _screen() as MainMenu
	menu.setup(3, true)
	menu.call(&"_refresh")
	await _wait(0.3)
	await _shot("02_menu_world3_custom")
	var dialog: SettingsDialog = menu.get_node("%SettingsDialog")
	dialog.open(SettingsDialog.Context.MAIN_MENU)
	await _wait(0.3)
	await _shot("03_settings_dialog")
	dialog.close()

	# A normal level, the player carrying a block and aiming.
	_app.play_official(19)
	await _wait(0.8)
	var sim: GameSim = _sim()
	sim.player.has_block = true
	sim.player.carried_block_type = Tile.BOUNCY
	sim.player.carried_block_eaten_count = 1
	sim.spawn_cosmetic_particles(sim.player.center_x(), sim.player.center_y(), Palette.PINK_500, 20, 5.0)
	await _wait(0.12)
	await _shot("04_level19_carrying")

	# Aiming: slow motion, its vignette and the gauge over the slime.
	var aim_at: Vector2 = get_viewport().get_visible_rect().size * Vector2(0.7, 0.35)
	_send_mouse_button(MOUSE_BUTTON_RIGHT, true, aim_at)
	await _wait(1.6)
	await _shot("04b_bullet_time")
	_send_mouse_button(MOUSE_BUTTON_RIGHT, false, aim_at)
	await _wait(0.2)

	_app.play_official(21)
	await _wait(1.0)
	await _shot("05_level21_tiles")

	_app.play_official(14)
	await _wait(0.6)
	sim = _sim()
	sim.kill_player()
	await _wait(0.5)
	await _shot("06_death_overlay")

	_app.play_official(1)
	await _wait(0.5)
	sim = _sim()
	sim.player.won = true
	await _wait(0.3)
	await _shot("07_win_overlay")
	sim.player.won = false
	_send_key(KEY_ESCAPE)
	await _wait(0.4)
	await _shot("08_pause_menu")
	_send_key(KEY_ESCAPE)
	await _wait(0.2)

	await _boss_shots(10, "09_boss1")
	await _boss_shots(20, "10_boss2")
	await _boss_shots(30, "11_boss3")
	await _boss_shots(40, "12_boss4")

	_app.edit_slot(4)
	await _wait(0.6)
	await _shot("13_editor")
	var screen: EditorScreen = _screen() as EditorScreen
	var editor: LevelEditor = screen.get("_editor")
	editor.set_brush(LevelEditor.Brush.SPIKES)
	editor.begin_stroke()
	editor.stroke_to(Vector2i(5, 12), false)
	editor.stroke_to(Vector2i(9, 12), false)
	editor.end_stroke()
	await _wait(0.3)
	await _shot("14_editor_spikes_dirty")
	var menu_button: Button = screen.get_node("%MenuButton")
	menu_button.pressed.emit()
	await _wait(0.3)
	await _shot("15_editor_unsaved_dialog")

	# Fullscreen and back, on the real window.
	_app.show_menu()
	await _wait(0.6)
	var windowed_size: Vector2i = get_window().size
	_send_key(KEY_F11)
	await _wait(1.0)
	print("capture: F11 -> window mode %d, size %s" % [get_window().mode, get_window().size])
	await _shot("16_menu_fullscreen")
	_send_key(KEY_F11)
	await _wait(1.0)
	print("capture: F11 -> window mode %d, size %s (was %s)" % [
		get_window().mode, get_window().size, windowed_size,
	])

	print("capture: screenshots written to ", ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit(0)


## Three stages of a boss fight: the entrance warning, the fight, and a
## telegraphed attack where the boss has one.
func _boss_shots(slot: int, name_prefix: String) -> void:
	_app.play_official(slot)
	await _wait(0.4)
	var sim: GameSim = _sim()
	# Put the player within the boss's trigger range.
	sim.player.place_at(sim.boss.x - 220.0, 13.0 * Tile.SIZE + 3.0)
	await _wait(0.7)
	await _shot(name_prefix + "_intro")
	# Skip ahead through the entrance.
	sim.boss.intro_timer = 2
	await _wait(2.2)
	await _shot(name_prefix + "_fight")
	match sim.boss_kind:
		BossState.Kind.WORLD_2:
			sim.boss.cooldown = 1
			await _wait(1.6)
			await _shot(name_prefix + "_charging")
		BossState.Kind.WORLD_4:
			for r: int in 3:
				for c: int in 3:
					if (r != 1 or c != 1) and (r + c) % 2 == 0:
						sim.boss.set_cell(r, c, Tile.DIRT_EATEN_2)
			sim.boss.action_count = 7
			sim.boss.cooldown = 1
			await _wait(1.8)
			await _shot(name_prefix + "_ultimate_charge")
		BossState.Kind.WORLD_3:
			sim.boss.cooldown = 1
			await _wait(0.5)
			await _shot(name_prefix + "_shield_detaching")
		BossState.Kind.WORLD_1:
			await _wait(1.5)
			await _shot(name_prefix + "_later")


func _screen() -> Control:
	var screens: Node = _app.get_node("%Screens")
	return screens.get_child(screens.get_child_count() - 1) as Control


func _sim() -> GameSim:
	return _screen().get("_sim")


## Waits [param seconds] of real time. Counted on the wall clock: the first
## frames after start-up are long, and a frame timer would run ahead of what
## was actually drawn.
func _wait(seconds: float) -> void:
	var until_msec: int = Time.get_ticks_msec() + roundi(seconds * 1000.0)
	while Time.get_ticks_msec() < until_msec:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(OUT_DIR.path_join(shot_name + ".png"))
	print("capture: ", shot_name)


func _send_mouse_button(button: MouseButton, pressed: bool, window_position: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = window_position
	motion.global_position = window_position
	Input.parse_input_event(motion)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = window_position
	event.global_position = window_position
	Input.parse_input_event(event)


func _send_key(physical_keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = physical_keycode
		event.keycode = physical_keycode
		event.pressed = pressed
		Input.parse_input_event(event)
