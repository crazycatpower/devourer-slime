extends Node
## Walks the application through its screens and saves a screenshot of each
## to `res://tests/output/`. Started by `capture_screens.gd`.

const OUT_DIR: String = "res://tests/output/devour-v3"

var _app: App


func run() -> void:
	SavePaths.wipe_sandbox()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var app_scene: PackedScene = load("res://src/app/app.tscn")
	_app = app_scene.instantiate()
	get_tree().root.add_child(_app)
	if "--tile-style" in OS.get_cmdline_user_args():
		await _wait(0.3)
		get_window().size = Vector2i(1280, 720)
		_app.hide()
		var sheet: Node2D = Node2D.new()
		sheet.set_script(load("res://tools/capture/tile_style_sheet.gd"))
		get_tree().root.add_child(sheet)
		await _wait(0.3)
		await _shot("tile_style_before" if "--before" in OS.get_cmdline_user_args() else "tile_style_after")
		get_tree().quit(0)
		return
	if "--project-qa" in OS.get_cmdline_user_args():
		await _project_qa()
		get_tree().quit(0)
		return
	if "--boss-backgrounds" in OS.get_cmdline_user_args():
		for stage: int in [10, 20, 30, 40, 50]:
			_app.play_official(stage)
			await _wait(0.8)
			(_screen() as GameScreen).set_physics_process(false)
			await _wait(2.1)
			await _shot("boss_hall_%d" % stage)
			_sim().camera.x += 160.0
			_sim().camera.prev_x = _sim().camera.x
			await _wait(0.2)
			await _shot("boss_hall_%d_shift" % stage)
		get_tree().quit(0)
		return
	if "--world-backgrounds" in OS.get_cmdline_user_args():
		for stage: int in [10, 11, 23, 31, 41]:
			_app.play_official(stage)
			await _wait(0.8)
			(_screen() as GameScreen).set_physics_process(false)
			await _wait(2.1)
			await _shot("wall_world_%d" % GameConstants.world_of_slot(stage))
		get_tree().quit(0)
		return
	if "--biofactory-pilot" in OS.get_cmdline_user_args():
		_app.play_official(10)
		await _wait(2.8)
		await _shot("biofactory_world1_level10_start")
		(_screen() as GameScreen).set_physics_process(false)
		# Capture-only camera offset to inspect parallax and aperture masking.
		_sim().camera.x += 160.0
		_sim().camera.prev_x = _sim().camera.x
		await _wait(0.2)
		await _shot("biofactory_world1_level10_parallax")
		get_tree().quit(0)
		return
	if "--art-review" in OS.get_cmdline_user_args():
		# Existing official layouts only; freeze gameplay for material review.
		get_window().size = Vector2i(1280, 720)
		for stage: int in [21, 19, 31, 50, 61, 71, 81, 91]:
			_app.play_official(stage)
			await _wait(0.15)
			var art_screen: GameScreen = _screen() as GameScreen
			art_screen.set_physics_process(false)
			_sim().particles.clear()
			await _wait(2.5)
			await _shot("art_review_%02d" % stage)
		get_tree().quit(0)
		return
	if "--editor-tools" in OS.get_cmdline_user_args():
		await _wait(0.5)
		_app.edit_slot(50)
		await _wait(0.5)
		var tools_screen: EditorScreen = _screen() as EditorScreen
		tools_screen.call(&"_fit_map")
		await _wait(0.3)
		await _shot("editor_tools_overview")
		tools_screen.call(&"_set_zoom", 1.6, Vector2(200.0, 200.0))
		tools_screen.call(&"_focus_start")
		await _wait(0.3)
		await _shot("editor_tools_zoom")
		get_tree().quit(0)
		return
	if "--steel-chase" in OS.get_cmdline_user_args():
		await _wait(0.5)
		await _shot("steel_chase_menu")
		_app.play_official(50)
		await _wait(0.2)
		var chase_game: GameScreen = _screen() as GameScreen
		chase_game.set_physics_process(false)
		var chase_sim: GameSim = _sim()
		for i: int in 140:
			var run_input: SimInput = SimInput.new()
			run_input.right = i < 65
			chase_sim.step(run_input)
			chase_sim.update_camera()
			if i == 75:
				await _wait(0.15)
				await _shot("steel_chase_warning")
		await _wait(2.5)
		await _shot("steel_chase_pursuit")
		get_tree().quit(0)
		return
	if "--campaign" in OS.get_cmdline_user_args():
		await _wait(0.9)
		var campaign_menu: MainMenu = _screen() as MainMenu
		campaign_menu.setup(5, false)
		campaign_menu.call(&"_refresh")
		await _wait(0.3)
		await _shot("campaign_world5_menu")
		var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/campaign_solutions.json"))
		var controller_script: GDScript = load("res://tests/unit/test_world5_levels.gd") as GDScript
		var controller: RefCounted = controller_script.new()
		for stage: int in [31, 33, 36, 38, 39, 41, 45, 49]:
			_app.play_official(stage)
			await _wait(2.3)
			await _shot("campaign_%02d_start" % stage)
			var game: GameScreen = _screen() as GameScreen
			game.set_physics_process(false)
			var stage_route: Array = routes[str(stage)]
			for i: int in floori(stage_route.size() * 0.65):
				controller.call(&"_execute", _sim(), stage_route[i])
			_sim().camera.snap_to(_sim().player.center_x(), _sim().player.center_y(), _sim().level)
			await _wait(0.2)
			await _shot("campaign_%02d_mid" % stage)
		get_tree().quit(0)
		return
	if "--world4" in OS.get_cmdline_user_args():
		await _wait(0.9)
		var world_menu: MainMenu = _screen() as MainMenu
		world_menu.setup(4, false)
		world_menu.call(&"_refresh")
		await _wait(0.3)
		await _shot("world4_menu")
		for stage: int in range(31, 40):
			_app.play_official(stage)
			await _wait(2.3)
			await _shot("world4_%d" % stage)
		get_tree().quit(0)
		return
	if "--slime-contact" in OS.get_cmdline_user_args():
		await _slime_contact_shots()
		get_tree().quit(0)
		return
	if "--slime-reactions" in OS.get_cmdline_user_args():
		await _slime_reaction_shots()
		get_tree().quit(0)
		return
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
	await _wait(0.07)
	await _shot("04c_spit_burst")

	_app.play_official(21)
	await _wait(1.0)
	await _shot("05_level21_tiles")
	await _wait(1.4)
	await _shot("05b_level21_clear")
	await _wait(1.3)
	await _shot("05c_slime_happy")
	await _wait(3.5)
	await _shot("05d_slime_curious")
	await _wait(4.0)
	await _shot("05e_slime_sleepy")
	# Freeze only the capture fixture to review the short intake pose.
	var intake_screen: GameScreen = _screen() as GameScreen
	intake_screen.set_physics_process(false)
	sim = _sim()
	var captured_intake: bool = false
	for row: int in sim.level.rows:
		for col: int in sim.level.cols:
			if sim.level.get_cell(row, col) == Tile.DIRT and not captured_intake:
				sim.player.place_at(float(col) * Tile.SIZE - 55.0, float(row) * Tile.SIZE + 3.0)
				sim.player.has_block = false
				sim.player.set_eating_target(row, col, false)
				sim.player.eating_progress = 0.65
				captured_intake = true
	if captured_intake:
		await _wait(0.1)
		await _shot("05f_eat_intake")
	intake_screen.set_physics_process(true)
	await _slime_contact_shots()
	await _slime_reaction_shots()

	_app.play_official(14)
	await _wait(0.6)
	sim = _sim()
	sim.kill_player()
	await _wait(0.5)
	await _shot("06_death_overlay")

	_app.play_official(1)
	await _wait(0.5)
	sim = _sim()
	for row: int in sim.level.rows:
		for col: int in sim.level.cols:
			if sim.level.get_cell(row, col) == Tile.GOAL:
				sim.player.place_at(float(col) * Tile.SIZE - 40.0, float(row) * Tile.SIZE)
	sim.player.won = true
	await _wait(0.3)
	await _shot("07_vortex_start")
	await _wait(0.45)
	await _shot("07b_vortex_absorb")
	await _wait(0.8)
	await _shot("07c_next_level")
	sim = _sim()
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


## Presentation fixtures use the official flat arena without changing tiles.
func _slime_contact_shots() -> void:
	_app.play_official(23)
	await _wait(0.6)
	var screen: GameScreen = _screen() as GameScreen
	screen.set_physics_process(false)
	var sim: GameSim = _sim()
	var view: WorldView = screen.get_node("%WorldView")
	var player_layer: PlayerLayer = view.get_node("World/Player")
	sim.player.scale_x = 1.0
	sim.player.scale_y = 1.0
	sim.player.vx = 0.0
	sim.player.vy = 0.0
	sim.particles.clear()
	sim.player.place_at(400.0, 560.0 - sim.player.h)
	sim.player.grounded = true
	sim.camera.snap_to(sim.player.center_x(), sim.player.center_y(), sim.level)
	for direction: Vector2 in [Vector2(0.0, -120.0), Vector2(120.0, 0.0), Vector2(0.0, 80.0)]:
		var event: InputEventMouseMotion = InputEventMouseMotion.new()
		event.position = view.global_position + (Vector2(sim.player.center_x(), sim.player.center_y()) + direction - Vector2(sim.camera.x, sim.camera.y)) * view.world_scale
		event.global_position = event.position
		Input.parse_input_event(event)
		await _wait(0.3)
		# Freeze the fixture gaze, so the user's real pointer cannot replace it.
		player_layer.set_process(false)
		player_layer.set("_look", direction.normalized())
		await _shot("05g_look_up" if direction.y < 0.0 else ("05h_look_side" if direction.x > 0.0 else "05i_look_down"))
	player_layer.set_process(true)
	sim.player.place_at(40.0, 560.0 - sim.player.h)
	sim.camera.snap_to(sim.player.center_x(), sim.player.center_y(), sim.level)
	await _wait(0.4)
	await _shot("05j_wall_squeeze")
	sim.player.place_at(400.0, 560.0 - sim.player.h)
	sim.camera.snap_to(sim.player.center_x(), sim.player.center_y(), sim.level)
	sim.player.vx = 4.2
	await _wait(0.4)
	sim.player.vx = 0.0
	await _wait(0.065)
	await _shot("05k_stop_rebound")
	screen.set_physics_process(true)


## Reactions staged on official levels without changing tiles: a head bump on
## the flat arena's ceiling, a fall from it, and the lone block of level 21.
func _slime_reaction_shots() -> void:
	_app.play_official(23)
	# Let the level's title card clear first.
	await _wait(2.1)
	var sim: GameSim = _sim()
	sim.particles.clear()
	# Rising fast just under the ceiling: the bump comes on the second tick.
	sim.player.place_at(400.0, 50.0)
	sim.player.grounded = false
	sim.player.vx = 0.0
	sim.player.vy = -11.0
	sim.camera.snap_to(sim.player.center_x(), sim.player.center_y(), sim.level)
	await _wait(0.09)
	await _shot("05l_head_bump")
	await _wait(0.3)
	await _shot("05m_dizzy")
	await _wait(1.8)
	# A fall from the ceiling to the floor, well beyond a jump's height.
	sim.player.place_at(400.0, 42.0)
	sim.player.grounded = false
	sim.player.vy = 0.0
	sim.camera.snap_to(sim.player.center_x(), sim.player.center_y(), sim.level)
	await _wait(0.8)
	await _shot("05n_long_fall")
	await _wait(0.15)
	await _shot("05o_hard_landing")

	_app.play_official(21)
	await _wait(2.1)
	sim = _sim()
	var block_top: float = 13.0 * Tile.SIZE
	var block_right: float = 4.0 * Tile.SIZE
	if sim.level.get_cell(13, 3) == Tile.DIRT and sim.level.get_cell(13, 4) == Tile.AIR:
		# The middle of the slime hangs past the right edge of the block.
		sim.player.place_at(block_right + 8.0 - sim.player.w * 0.5, block_top - sim.player.h - 0.001)
		sim.player.grounded = true
		sim.player.vx = 0.0
		sim.player.vy = 0.0
		sim.camera.snap_to(sim.player.center_x(), sim.player.center_y(), sim.level)
		await _wait(0.8)
		# Wait for a sweat drop to be on show.
		var view: WorldView = (_screen() as GameScreen).get_node("%WorldView")
		var motion: SlimeMotion = view.get_node("World/Player").get("_motion")
		var until_msec: int = Time.get_ticks_msec() + 1500
		while Time.get_ticks_msec() < until_msec:
			var cycle: float = fmod(motion.time, PlayerLayer.SWEAT_PERIOD) / PlayerLayer.SWEAT_PERIOD
			if cycle > 0.3 and cycle < 0.6:
				break
			await get_tree().process_frame
		await _shot("05p_teeter")


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
		BossState.Kind.BOUNCY_SLIME:
			sim.boss.cooldown = 1
			await _wait(1.6)
			await _shot(name_prefix + "_charging")
		BossState.Kind.VOID_SLIME:
			for r: int in 3:
				for c: int in 3:
					if (r != 1 or c != 1) and (r + c) % 2 == 0:
						sim.boss.set_cell(r, c, Tile.DIRT_EATEN_2)
			sim.boss.action_count = 7
			sim.boss.cooldown = 1
			await _wait(1.8)
			await _shot(name_prefix + "_ultimate_charge")
		BossState.Kind.GLASS_SLIME:
			sim.boss.cooldown = 1
			await _wait(0.5)
			await _shot(name_prefix + "_shield_detaching")
		BossState.Kind.MUD_GOLEM:
			await _wait(1.5)
			await _shot(name_prefix + "_later")


## Repeatable rendered review of existing official layouts, not a playthrough.
func _project_qa() -> void:
	await _wait(0.2)
	get_window().size = Vector2i(1280, 720)
	await _wait(0.2)
	var results: Array[Dictionary] = []
	for slot: int in [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]:
		_app.play_official(slot)
		await _wait(0.15)
		var game: GameScreen = _screen() as GameScreen
		game.set_physics_process(false)
		var sim: GameSim = _sim()
		sim.rng.set_seed(1206)
		sim.fx_rng.set_seed(1206)
		await _wait(2.0)
		await _shot("qa_%d_entrance" % slot)
		# Move only actors; keep official terrain intact.
		if sim.boss_kind == BossState.Kind.STEEL_CHASE:
			sim.player.place_at(sim.boss.target_vx + 40.0, sim.player.y)
		else:
			# Glass extends its arena underground. Preserve the actual entrance
			# height instead of placing the player inside the bottom of the map.
			sim.player.place_at(sim.boss.x - 220.0, sim.player.y)
		for tick: int in 260:
			sim.step(SimInput.new())
			sim.update_camera()
			if sim.boss.state == BossState.State.ACTIVE:
				break
			if sim.player.dead:
				break
		sim.camera.snap_to(sim.player.center_x(), sim.player.center_y(), sim.level)
		await _wait(0.15)
		await _shot("qa_%d_combat" % slot)
		var backdrop: BackdropLayer = game.get_node("%WorldView/World/Backdrop") as BackdropLayer
		for cached: bool in [false, true]:
			backdrop.cache_enabled = cached
			await _wait(0.2)
			backdrop.redraw_count = 0
			backdrop.paint_usec = 0
			var samples: Array[float] = []
			var last: int = Time.get_ticks_usec()
			for frame: int in 120:
				await RenderingServer.frame_post_draw
				var now: int = Time.get_ticks_usec()
				samples.append(float(now - last) / 1000.0)
				last = now
			samples.sort()
			var total: float = 0.0
			for value: float in samples:
				total += value
			results.append({"slot": slot, "cached": cached, "frames": samples.size(),
				"mean_frame_ms": total / samples.size(), "p95_frame_ms": samples[113],
				"backdrop_redraws": backdrop.redraw_count, "backdrop_paint_ms": float(backdrop.paint_usec) / 1000.0,
				"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				"static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
				"boss_state": sim.boss.state, "player_dead": sim.player.dead})
			await _shot("qa_%d_cache_%s" % [slot, str(cached)])
		sim.camera.x += 160.0
		sim.camera.prev_x = sim.camera.x
		await _wait(0.2)
		await _shot("qa_%d_shift" % slot)
		game.set_process(false)
		var review_view: WorldView = game.get_node("%WorldView") as WorldView
		review_view.tick_alpha = 1.0
		review_view.camera_alpha = 1.0
		sim.player.has_block = true
		sim.player.in_bullet_time = true
		review_view.shoot_held = true
		await _wait(0.15)
		await _shot("qa_%d_aim" % slot)
		review_view.shoot_held = false
		sim.player.in_bullet_time = false
		sim.boss.cooldown = 1
		var active_samples: Array[float] = []
		var active_last: int = Time.get_ticks_usec()
		for frame: int in 120:
			sim.step(SimInput.new())
			sim.update_camera()
			await RenderingServer.frame_post_draw
			var now: int = Time.get_ticks_usec()
			active_samples.append(float(now - active_last) / 1000.0)
			active_last = now
		active_samples.sort()
		var active_total: float = 0.0
		for value: float in active_samples:
			active_total += value
		results.append({"slot": slot, "scenario": "120 live simulation ticks; no player movement; may include death/retry",
			"mean_frame_ms": active_total / 120.0, "p95_frame_ms": active_samples[113],
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC)})
		await _shot("qa_%d_attack" % slot)
	var output: FileAccess = FileAccess.open(OUT_DIR.path_join("performance.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"resolution": str(get_viewport().get_texture().get_size()), "renderer": RenderingServer.get_video_adapter_name(),
		"scenario": "frozen combat pose; rendered frames; 120 samples after warmup; vsync unchanged", "results": results}, "  "))
	output.close()
	_app.show_menu()
	await _wait(0.4)
	for window_size: Vector2i in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1600, 900)]:
		get_window().size = window_size
		await _wait(0.3)
		await _shot("qa_menu_%d" % window_size.x)
	get_window().size = Vector2i(960, 540)
	var menu: MainMenu = _screen() as MainMenu
	var dialog: SettingsDialog = menu.get_node("%SettingsDialog") as SettingsDialog
	dialog.open(SettingsDialog.Context.MAIN_MENU)
	await _wait(0.3)
	await _shot("qa_settings_960")


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
	var save_error: Error = image.save_png(OUT_DIR.path_join(shot_name + ".png"))
	if save_error != OK:
		push_error("capture: save failed: %s" % error_string(save_error))
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
