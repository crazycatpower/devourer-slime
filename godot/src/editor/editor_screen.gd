class_name EditorScreen
extends Control
## The level editor: a paintable view of one slot's level with brushes, map
## size, import/export, undo and saving.
##
## The document lives in a [LevelEditor]; this screen turns mouse and key
## input into edits and keeps the widgets in step with it. All modifications
## are automatically saved to disk without requiring confirmation prompts.

signal menu_requested
signal test_requested(slot: int, level: LevelData)
signal toast_requested(text: String)

const PAN_SPEED: float = 900.0
const SIZE_PRESETS: Array[Vector2i] = [
	Vector2i(25, 15), Vector2i(40, 15), Vector2i(40, 24),
	Vector2i(65, 18), Vector2i(90, 25), Vector2i(160, 32),
]
const BRUSH_ORDER: Array[LevelEditor.Brush] = [
	LevelEditor.Brush.DIRT, LevelEditor.Brush.BOUNCY, LevelEditor.Brush.STEEL,
	LevelEditor.Brush.GLASS, LevelEditor.Brush.VOID, LevelEditor.Brush.SPIKES,
	LevelEditor.Brush.GOAL, LevelEditor.Brush.PLAYER, LevelEditor.Brush.ERASER,
	LevelEditor.Brush.COPY, LevelEditor.Brush.PASTE,
	LevelEditor.Brush.SENSOR, LevelEditor.Brush.WIRE,
	LevelEditor.Brush.RAIL_RIGHT, LevelEditor.Brush.RAIL_LEFT, LevelEditor.Brush.RAIL_UP, LevelEditor.Brush.RAIL_DOWN,
	LevelEditor.Brush.SAND, LevelEditor.Brush.ICE, LevelEditor.Brush.TNT,
]
const SPIKE_LABELS: PackedStringArray = ["朝上", "朝右", "朝下", "朝左"]

var _slot: int = 1
var _editor: LevelEditor = LevelEditor.new()
## Never stepped: it only gives the [WorldView] something to draw.
var _sim: GameSim = GameSim.new()
var _painting: bool = false
var _erasing: bool = false
var _panning: bool = false
var _brush_buttons: Dictionary[int, Button] = {}
var _spike_buttons: Array[Button] = []
var _preset_buttons: Array[Button] = []
var _zoom_label: Button
var _space_panning: bool = false
var _saving: bool = false
var _save_error: Error = OK
var _rail_panel: VBoxContainer
var _rail_auto_toggle: CheckButton
var _cell_info: Label
var _grid_toggle: Button
var _devices_toggle: Button

@onready var _backdrop: MenuBackdrop = %Backdrop
@onready var _view: WorldView = %WorldView
@onready var _menu_button: Button = %MenuButton
@onready var _slot_caption: Label = %SlotCaption
@onready var _play_button: Button = %PlayButton
@onready var _prev_button: Button = %PrevButton
@onready var _next_button: Button = %NextButton
@onready var _slot_label: Label = %SlotLabel
@onready var _slot_info: Label = %SlotInfo
@onready var _dirty_label: Label = %DirtyLabel
@onready var _size_info: Label = %SizeInfo
@onready var _brush_grid: GridContainer = %BrushGrid
@onready var _spike_panel: PanelContainer = %SpikePanel
@onready var _spike_row: HBoxContainer = %SpikeRow
@onready var _undo_button: Button = %UndoButton
@onready var _redo_button: Button = %RedoButton
@onready var _width_value: LineEdit = %WidthValue
@onready var _height_value: LineEdit = %HeightValue
@onready var _width_minus: Button = %WidthMinus
@onready var _width_plus: Button = %WidthPlus
@onready var _height_minus: Button = %HeightMinus
@onready var _height_plus: Button = %HeightPlus
@onready var _preset_grid: GridContainer = %PresetGrid
@onready var _export_slot_button: Button = %ExportSlotButton
@onready var _export_all_button: Button = %ExportAllButton
@onready var _import_text: TextEdit = %ImportText
@onready var _import_error: Label = %ImportError
@onready var _import_button: Button = %ImportButton
@onready var _save_button: Button = %SaveButton
@onready var _clear_button: Button = %ClearButton
@onready var _confirm: ConfirmDialog = %ConfirmDialog


## Call before the screen enters the tree.
func setup(slot: int) -> void:
	_slot = slot


func _ready() -> void:
	_build_brush_buttons()
	_build_spike_buttons()
	_build_preset_buttons()
	_build_view_controls()
	_build_rail_controls()

	_view.sim = _sim
	_view.editor = _editor
	_view.gui_input.connect(_on_view_gui_input)
	_view.resized.connect(func() -> void: _move_camera(Vector2.ZERO))

	_editor.changed.connect(_on_level_changed)
	_editor.brush_changed.connect(_refresh_brushes)
	_editor.history_changed.connect(_on_history_changed)

	_menu_button.pressed.connect(_on_menu_pressed)
	_play_button.pressed.connect(_on_play_pressed)
	_prev_button.pressed.connect(_change_slot.bind(-1))
	_next_button.pressed.connect(_change_slot.bind(1))
	_undo_button.pressed.connect(_undo_action)
	_redo_button.pressed.connect(_redo_action)
	_width_minus.pressed.connect(_on_step_width.bind(-1))
	_width_plus.pressed.connect(_on_step_width.bind(1))
	_height_minus.pressed.connect(_on_step_height.bind(-1))
	_height_plus.pressed.connect(_on_step_height.bind(1))
	_width_value.text_submitted.connect(_on_width_submitted)
	_width_value.focus_exited.connect(_on_width_focus_exited)
	_height_value.text_submitted.connect(_on_height_submitted)
	_height_value.focus_exited.connect(_on_height_focus_exited)
	_width_minus.tooltip_text = "減 1 格 (Shift 減 5 格)"
	_width_plus.tooltip_text = "加 1 格 (Shift 加 5 格)"
	_height_minus.tooltip_text = "減 1 格 (Shift 減 5 格)"
	_height_plus.tooltip_text = "加 1 格 (Shift 加 5 格)"
	_width_value.tooltip_text = "直接輸入地圖寬度 (10~200)"
	_height_value.tooltip_text = "直接輸入地圖高度 (10~120)"
	_export_slot_button.pressed.connect(_on_export_slot_pressed)
	_export_all_button.pressed.connect(_on_export_all_pressed)
	_import_button.pressed.connect(_on_import_pressed)
	_import_text.text_changed.connect(func() -> void: _import_error.visible = false)
	_save_button.pressed.connect(_save)
	_clear_button.pressed.connect(_on_clear_pressed)
	LevelStore.custom_levels_changed.connect(_refresh_status)

	_open_slot(_slot)


func _process(delta: float) -> void:
	_view.editor_erasing = _erasing
	_refresh_cell_info()
	# A release outside the canvas or a lost focus must still finish the gesture.
	if _painting and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT if not _erasing else MOUSE_BUTTON_RIGHT):
		_end_stroke()
	if _panning and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT if _space_panning else MOUSE_BUTTON_MIDDLE):
		_panning = false
	# Typing in a text box must not scroll the level.
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is TextEdit or focus is LineEdit or _confirm.visible:
		return
	var direction: Vector2 = Vector2(
		Input.get_axis(InputBindings.MOVE_LEFT, InputBindings.MOVE_RIGHT),
		Input.get_axis(InputBindings.MOVE_UP, InputBindings.MOVE_DOWN)
	)
	if direction != Vector2.ZERO and not Input.is_key_pressed(KEY_CTRL) and not Input.is_key_pressed(KEY_META):
		_move_camera(direction * PAN_SPEED * delta)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or _confirm.visible:
		return
	var key: InputEventKey = event
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is TextEdit or focus is LineEdit:
		return
	if not key.pressed or key.echo:
		return
	if not key.is_command_or_control_pressed():
		if key.keycode >= KEY_1 and key.keycode <= KEY_9:
			_end_stroke()
			_editor.set_brush(BRUSH_ORDER[int(key.keycode - KEY_1)])
		elif key.keycode == KEY_E:
			_select_brush(LevelEditor.Brush.ERASER)
		elif key.keycode == KEY_R:
			_end_stroke()
			if Tile.is_rail(_editor.brush_tile()):
				_editor.rotate_rail()
			else:
				_editor.set_spike_direction(posmod(_editor.spike_direction + 1, 4) as LevelEditor.SpikeDirection)
		elif key.keycode == KEY_HOME:
			_focus_start()
		elif key.keycode == KEY_F:
			_fit_map()
		elif key.keycode == KEY_LEFT or key.keycode == KEY_A:
			_move_camera(Vector2(-60.0, 0.0) / maxf(_view.world_scale, 0.001))
		elif key.keycode == KEY_RIGHT or key.keycode == KEY_D:
			_move_camera(Vector2(60.0, 0.0) / maxf(_view.world_scale, 0.001))
		elif key.keycode == KEY_UP or key.keycode == KEY_W:
			_move_camera(Vector2(0.0, -60.0) / maxf(_view.world_scale, 0.001))
		elif key.keycode == KEY_DOWN or key.keycode == KEY_S:
			_move_camera(Vector2(0.0, 60.0) / maxf(_view.world_scale, 0.001))
		else:
			return
		get_viewport().set_input_as_handled()
		return
	_end_stroke()
	match key.keycode:
		KEY_Z:
			if key.shift_pressed:
				_editor.redo()
			else:
				_editor.undo()
		KEY_Y:
			_editor.redo()
		KEY_S:
			_save()
		KEY_C:
			_editor.set_brush(LevelEditor.Brush.COPY)
		KEY_V:
			if _editor.clipboard != null:
				_editor.set_brush(LevelEditor.Brush.PASTE)
		_:
			return
	get_viewport().set_input_as_handled()


# --- Painting ---------------------------------------------------------------------

func _on_view_gui_input(event: InputEvent) -> void:
	if _confirm.visible:
		return
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.pressed:
			var focus: Control = get_viewport().gui_get_focus_owner()
			if focus != null:
				focus.release_focus()
		match button.button_index:
			MOUSE_BUTTON_LEFT:
				if button.pressed:
					_end_stroke()
					if Input.is_key_pressed(KEY_SPACE):
						_end_stroke()
						_panning = true
						_space_panning = true
					elif button.alt_pressed:
						_end_stroke()
						_editor.pick_brush(_hover_cell())
					else:
						_begin_left_stroke()
				else:
					_end_stroke()
					if _space_panning:
						_panning = false
			MOUSE_BUTTON_RIGHT:
				if button.pressed:
					_end_stroke()
					_panning = false
					_painting = true
					_erasing = true
					_editor.begin_stroke()
					_editor.stroke_to(_hover_cell(), true)
				else:
					_end_stroke()
			MOUSE_BUTTON_MIDDLE:
				_end_stroke()
				_panning = button.pressed
				_space_panning = false
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed:
					_set_zoom(_view.editor_zoom * (1.2 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2), button.position)
		_view.accept_event()
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		if _panning:
			_move_camera(-motion.relative / maxf(_view.world_scale, 0.001))
		elif _painting:
			if not Rect2(Vector2.ZERO, _view.size).has_point(_view.get_local_mouse_position()):
				return
			if _editor.brush == LevelEditor.Brush.COPY and not _erasing:
				_editor.update_selection(_hover_cell())
			else:
				_editor.stroke_to(_hover_cell(), _erasing)


func _begin_left_stroke() -> void:
	var cell: Vector2i = _hover_cell()
	_erasing = false
	match _editor.brush:
		LevelEditor.Brush.COPY:
			_painting = true
			_editor.begin_selection(cell)
		LevelEditor.Brush.PASTE:
			_editor.paste_at(cell)
		_:
			_painting = true
			_editor.begin_stroke()
			_editor.stroke_to(cell, false)


func _end_stroke() -> bool:
	if not _painting:
		return true
	var copying: bool = _editor.brush == LevelEditor.Brush.COPY and not _erasing
	_erasing = false
	if copying:
		_editor.finish_selection()
		toast_requested.emit("已複製選取範圍，點一下即可貼上")
	else:
		# Commit while the gesture is active; history callbacks must not save twice.
		_editor.end_stroke()
	_painting = false
	return _auto_save() if _editor.is_dirty() else true


func _hover_cell() -> Vector2i:
	var mouse: Vector2 = _view.mouse_in_world()
	return Vector2i(floori(mouse.x / Tile.SIZE), floori(mouse.y / Tile.SIZE))


func _move_camera(offset: Vector2) -> void:
	var camera: SimCamera = _sim.camera
	camera.x += offset.x
	camera.y += offset.y
	_limit_camera()
	camera.prev_x = camera.x
	camera.prev_y = camera.y


# --- Slots, saving and leaving --------------------------------------------------------

func _open_slot(slot: int) -> void:
	_save_error = OK
	_slot = slot
	if LevelStore.is_custom_damaged(slot):
		toast_requested.emit("SLOT %d 的存檔已損毀，改為載入內建關卡" % slot)
	_editor.open(LevelStore.get_level(slot))
	var start: Vector2i = _editor.level.start_cell
	_sim.camera.snap_to(
		(float(start.x) + 0.5) * Tile.SIZE, (float(start.y) + 0.5) * Tile.SIZE, _editor.level.grid
	)
	_import_error.visible = false
	_focus_start()
	_refresh_brushes()
	_refresh_status()


func _auto_save() -> bool:
	if not _editor.is_dirty():
		return true
	if _saving:
		return false
	_saving = true
	var error: Error = LevelStore.save_custom(_slot, _editor.level)
	if error != OK:
		_save_error = error
		toast_requested.emit("自動儲存失敗（%s），修改仍保留，請重試儲存。" % error_string(error))
		_saving = false
		_refresh_status()
		return false
	_save_error = OK
	_editor.mark_saved()
	_saving = false
	return true


func _save() -> void:
	if not _end_stroke():
		return
	var error: Error = LevelStore.save_custom(_slot, _editor.level)
	if error != OK:
		_save_error = error
		toast_requested.emit("儲存失敗（%s），修改仍保留。" % error_string(error))
		_refresh_status()
		return
	_save_error = OK
	_editor.mark_saved()
	toast_requested.emit("關卡已儲存")


## Runs [param action] after settling in-progress edits and auto-saving.
## Confirmation is not required since edits are saved automatically.
func run_when_changes_settled(action: Callable) -> void:
	# Finish text editing while the controls still belong to this viewport.
	# Removing a focused editor first can leave native IME input active and
	# also commits the size too late for the test-play snapshot.
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus != null and is_ancestor_of(focus):
		focus.release_focus()
	if not _end_stroke():
		return
	if _editor.is_dirty() and not _auto_save():
		return
	action.call()


func _on_menu_pressed() -> void:
	run_when_changes_settled(func() -> void: menu_requested.emit())


func _on_play_pressed() -> void:
	run_when_changes_settled(func() -> void:
		test_requested.emit(_slot, _editor.level.duplicate_level())
	)


func _change_slot(step: int) -> void:
	var position: int = _display_slot() + step
	if position < 1 or position > GameConstants.SLOT_COUNT:
		return
	var world_index: int = floori(float(position - 1) / GameConstants.LEVELS_PER_WORLD)
	var target: int = (WorldCatalog.ORDER[world_index] - 1) * GameConstants.LEVELS_PER_WORLD + GameConstants.level_in_world(position)
	run_when_changes_settled(_open_slot.bind(target))


func _on_clear_pressed() -> void:
	_confirm.ask("確定要清空整張地圖嗎？\n（可以用復原救回來）", ["清空", "取消"], 0)
	if await _confirm.chosen == 0:
		_editor.clear()
		toast_requested.emit("畫布已清空")


func _on_step_width(dir: int) -> void:
	var step: int = 5 if Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL) else 1
	_resize_by(dir * step, 0)


func _on_step_height(dir: int) -> void:
	var step: int = 5 if Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL) else 1
	_resize_by(0, dir * step)


func _on_width_submitted(new_text: String) -> void:
	_end_stroke()
	if new_text.is_valid_int():
		var cols: int = clampi(new_text.to_int(), GameConstants.MIN_LEVEL_COLS, GameConstants.MAX_LEVEL_COLS)
		_editor.resize(cols, _editor.level.grid.rows)
	else:
		_width_value.text = str(_editor.level.grid.cols)
	_width_value.release_focus()


func _on_width_focus_exited() -> void:
	_on_width_submitted(_width_value.text)


func _on_height_submitted(new_text: String) -> void:
	_end_stroke()
	if new_text.is_valid_int():
		var rows: int = clampi(new_text.to_int(), GameConstants.MIN_LEVEL_ROWS, GameConstants.MAX_LEVEL_ROWS)
		_editor.resize(_editor.level.grid.cols, rows)
	else:
		_height_value.text = str(_editor.level.grid.rows)
	_height_value.release_focus()


func _on_height_focus_exited() -> void:
	_on_height_submitted(_height_value.text)


func _resize_by(cols: int, rows: int) -> void:
	_end_stroke()
	_editor.resize(_editor.level.grid.cols + cols, _editor.level.grid.rows + rows)


func _display_slot() -> int:
	return (WorldCatalog.display_world(GameConstants.world_of_slot(_slot)) - 1) * GameConstants.LEVELS_PER_WORLD + GameConstants.level_in_world(_slot)


func _limit_camera() -> void:
	var scale_value: float = maxf(_view.size.x / GameConstants.VIEW_WIDTH * _view.editor_zoom, 0.001)
	var extent: Vector2 = _view.size / scale_value
	_sim.camera.x = SimCamera.limit(_sim.camera.x, _sim.level.pixel_width(), extent.x)
	_sim.camera.y = SimCamera.limit(_sim.camera.y, _sim.level.pixel_height(), extent.y)


func _set_zoom(value: float, anchor: Vector2) -> void:
	_end_stroke()
	var old_scale: float = maxf(_view.size.x / GameConstants.VIEW_WIDTH * _view.editor_zoom, 0.001)
	var point: Vector2 = Vector2(_sim.camera.x, _sim.camera.y) + anchor / old_scale
	_view.editor_zoom = clampf(value, 0.1, 4.0)
	_view.world_scale = maxf(_view.size.x / GameConstants.VIEW_WIDTH * _view.editor_zoom, 0.001)
	var target: Vector2 = point - anchor / _view.world_scale
	_move_camera(target - Vector2(_sim.camera.x, _sim.camera.y))
	_zoom_label.text = "%d%%" % roundi(_view.editor_zoom * 100.0)


func _fit_map() -> void:
	var scale_value: float = minf(_view.size.x / _sim.level.pixel_width(), _view.size.y / _sim.level.pixel_height())
	_set_zoom(scale_value * GameConstants.VIEW_WIDTH / maxf(_view.size.x, 1.0), _view.size / 2.0)
	_move_camera(Vector2.ZERO)


func _focus_start() -> void:
	var scale_value: float = maxf(_view.size.x / GameConstants.VIEW_WIDTH * _view.editor_zoom, 0.001)
	var target: Vector2 = (Vector2(_editor.level.start_cell) + Vector2(0.5, 0.5)) * Tile.SIZE
	_move_camera(target - _view.size / scale_value / 2.0 - Vector2(_sim.camera.x, _sim.camera.y))


func _build_view_controls() -> void:
	var bar: HBoxContainer = HBoxContainer.new()
	bar.add_theme_constant_override(&"separation", 8)
	var area: Node = _view.get_parent().get_parent()
	area.add_child(bar)
	area.move_child(bar, 1)
	for caption: String in ["−", "100%", "+", "全圖", "起點"]:
		var button: Button = Button.new()
		button.text = caption
		button.focus_mode = Control.FOCUS_NONE
		button.theme_type_variation = &"ChipButton"
		bar.add_child(button)
		match caption:
			"−":
				button.pressed.connect(func() -> void: _set_zoom(_view.editor_zoom / 1.2, _view.size / 2.0))
			"+":
				button.pressed.connect(func() -> void: _set_zoom(_view.editor_zoom * 1.2, _view.size / 2.0))
			"100%":
				_zoom_label = button
				button.tooltip_text = "重設縮放；滾輪以游標為中心縮放"
				button.pressed.connect(func() -> void: _set_zoom(1.0, _view.size / 2.0))
			"全圖":
				button.tooltip_text = "顯示整張地圖 (F)"
				button.pressed.connect(_fit_map)
			"起點":
				button.tooltip_text = "回到玩家起點 (Home)"
				button.pressed.connect(_focus_start)
	for label: String in ["格線", "機關"]:
		var toggle: Button = Button.new()
		toggle.text = label
		toggle.toggle_mode = true
		toggle.button_pressed = true
		toggle.focus_mode = Control.FOCUS_NONE
		toggle.theme_type_variation = &"ChipButton"
		bar.add_child(toggle)
		if label == "格線":
			_grid_toggle = toggle
			toggle.tooltip_text = "顯示／隱藏編輯格線，不修改地圖"
			toggle.toggled.connect(func(enabled: bool) -> void: _view.editor_show_grid = enabled)
		else:
			_devices_toggle = toggle
			toggle.tooltip_text = "顯示／隱藏連線、感測器與軌道，不修改地圖"
			toggle.toggled.connect(func(enabled: bool) -> void: _view.editor_show_devices = enabled)


# --- Import and export -------------------------------------------------------------------

func _on_export_slot_pressed() -> void:
	DisplayServer.clipboard_set(JSON.stringify(LevelCodec.encode_document(_editor.level)))
	toast_requested.emit("已將目前關卡複製到剪貼簿")


func _on_export_all_pressed() -> void:
	var text: String = LevelStore.export_all()
	if text.is_empty():
		toast_requested.emit("目前沒有已儲存的自訂關卡可匯出")
		return
	DisplayServer.clipboard_set(text)
	toast_requested.emit("已將所有自訂關卡複製到剪貼簿")


func _on_import_pressed() -> void:
	if not _end_stroke():
		return
	if _editor.is_dirty() and not _auto_save():
		return
	var result: LevelRepository.ImportResult = LevelStore.import_text(_import_text.text, _slot)
	if not result.ok:
		_import_error.text = result.message
		_import_error.visible = true
		return
	_import_text.text = ""
	_import_error.visible = false
	if result.slots.has(_slot):
		_open_slot(_slot)
	toast_requested.emit(result.message)


# --- Keeping the widgets in step -----------------------------------------------------------

func _on_level_changed() -> void:
	# The editor replaces its level on undo and resize, so re-attach each time.
	var level: LevelData = _editor.level
	_sim.level = level.grid
	_sim.player = PlayerState.new()
	_sim.player.place_at(level.start_x(), level.start_y())
	_limit_camera()
	_sim.camera.prev_x = _sim.camera.x
	_sim.camera.prev_y = _sim.camera.y
	_refresh_status()


func _on_history_changed() -> void:
	if not _painting and _editor.is_dirty():
		_auto_save()
	_refresh_status()


func _refresh_status() -> void:
	var world: int = WorldCatalog.display_world(GameConstants.world_of_slot(_slot))
	var source_world: int = GameConstants.world_of_slot(_slot)
	var accent: Color = WorldCatalog.accent(source_world)
	var grid: LevelGrid = _editor.level.grid
	_backdrop.glow_color = WorldCatalog.fill(source_world)
	_slot_caption.text = "WORLD %d  //  LEVEL %d" % [world, GameConstants.level_in_world(_slot)]
	_slot_caption.add_theme_color_override(&"font_color", accent)
	_slot_label.text = "SLOT %02d" % _slot
	_slot_label.add_theme_color_override(&"font_color", accent)
	_prev_button.disabled = _display_slot() <= 1
	_next_button.disabled = _display_slot() >= GameConstants.SLOT_COUNT

	_slot_info.text = "SLOT %02d（WORLD %d）" % [_slot, world]
	_size_info.text = "%d × %d" % [grid.cols, grid.rows]
	_dirty_label.visible = true
	if _editor.is_dirty():
		_dirty_label.text = "儲存失敗 · 修改仍保留" if _save_error != OK else "● 編輯中..."
		_dirty_label.add_theme_color_override(&"font_color", Palette.RED_400 if _save_error != OK else Palette.AMBER_400)
		_save_button.text = "重試儲存" if _save_error != OK else "儲存中..."
		_save_button.tooltip_text = error_string(_save_error) if _save_error != OK else "編輯完成後會自動儲存"
	else:
		_dirty_label.text = "✓ 已自動儲存"
		_dirty_label.add_theme_color_override(&"font_color", Palette.EMERALD_400)
		_save_button.text = "已自動儲存 AUTO SAVED"
		_save_button.tooltip_text = "關卡修改已寫入存檔"
	if not _width_value.has_focus():
		_width_value.text = str(grid.cols)
	if not _height_value.has_focus():
		_height_value.text = str(grid.rows)
	_width_minus.disabled = grid.cols <= GameConstants.MIN_LEVEL_COLS
	_width_plus.disabled = grid.cols >= GameConstants.MAX_LEVEL_COLS
	_height_minus.disabled = grid.rows <= GameConstants.MIN_LEVEL_ROWS
	_height_plus.disabled = grid.rows >= GameConstants.MAX_LEVEL_ROWS
	for i: int in _preset_buttons.size():
		_preset_buttons[i].set_pressed_no_signal(
			SIZE_PRESETS[i] == Vector2i(grid.cols, grid.rows)
		)

	_undo_button.disabled = not _editor.can_undo()
	_redo_button.disabled = not _editor.can_redo()


func _refresh_brushes() -> void:
	_refresh_context_hint()
	for brush: int in _brush_buttons:
		_brush_buttons[brush].set_pressed_no_signal(brush == _editor.brush)
	_brush_buttons[LevelEditor.Brush.PASTE].disabled = _editor.clipboard == null
	_rail_panel.visible = Tile.is_rail(_editor.brush_tile())
	_spike_panel.visible = _editor.brush == LevelEditor.Brush.SPIKES
	for i: int in _spike_buttons.size():
		_spike_buttons[i].set_pressed_no_signal(i == _editor.spike_direction)


func _refresh_context_hint() -> void:
	var hint: Label = $VBox/Body/HBox/CanvasArea/Hint
	var text: String = "左鍵畫 · 右鍵清除整格 · 滾輪縮放 · 空白＋拖曳 · Alt 取材"
	if Tile.is_rail(_editor.brush_tile()):
		text = "拖曳自動轉彎" if _editor.rail_auto_turn else "固定方向繪製"
		text += " · R 旋轉單格方向 · 右鍵只擦軌道 · Alt 取軌道"
	elif _editor.brush == LevelEditor.Brush.WIRE:
		text = "拖曳連接感測器與機關 · 右鍵只擦線 · 相交處共用信號"
	elif _editor.brush == LevelEditor.Brush.SENSOR:
		text = "可與方塊重疊 · 被方塊覆蓋時輸出信號 · 右鍵只擦感測器"
	elif _editor.brush == LevelEditor.Brush.ERASER:
		text = "拖曳清除方塊與全部機關 · 玩家起點保留 · Ctrl+Z 復原 · E 橡皮擦"
	elif _editor.brush == LevelEditor.Brush.COPY:
		text = "拖曳框選，放開後切換貼上 · 方塊與機關圖層一起複製"
	elif _editor.brush == LevelEditor.Brush.PASTE:
		text = "左鍵貼上預覽區域 · Ctrl+Z 復原 · 藍框外的格子不受影響"
	hint.text = text


func _build_brush_buttons() -> void:
	for brush: LevelEditor.Brush in BRUSH_ORDER:
		var button: Button = Button.new()
		button.theme_type_variation = &"ChipButton"
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0.0, 96.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var shortcut_index: int = BRUSH_ORDER.find(brush)
		button.tooltip_text = "%s (%d)" % [BrushIcon.label_for(brush), shortcut_index + 1] if shortcut_index < 9 else BrushIcon.label_for(brush)
		if brush == LevelEditor.Brush.ERASER:
			button.tooltip_text = "橡皮擦 (E)：清除同格方塊與全部機關；玩家起點保留"
		button.pressed.connect(_select_brush.bind(brush))

		# Icon above caption, laid out inside the button.
		var content: VBoxContainer = VBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override(&"separation", 4)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var icon: BrushIcon = BrushIcon.new()
		icon.brush = brush
		icon.custom_minimum_size = Vector2(40.0, 40.0)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		content.add_child(icon)
		var caption: Label = Label.new()
		caption.text = BrushIcon.label_for(brush)
		caption.theme_type_variation = &"CaptionLabel"
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(caption)
		button.add_child(content)

		_brush_grid.add_child(button)
		_brush_buttons[brush] = button


func _build_rail_controls() -> void:
	_rail_panel = VBoxContainer.new()
	_brush_grid.get_parent().add_child(_rail_panel)
	_brush_grid.get_parent().move_child(_rail_panel, _brush_grid.get_index() + 1)
	_rail_auto_toggle = CheckButton.new()
	_rail_auto_toggle.text = "拖曳軌道自動轉彎"
	_rail_auto_toggle.button_pressed = _editor.rail_auto_turn
	_rail_auto_toggle.focus_mode = Control.FOCUS_NONE
	_rail_auto_toggle.toggled.connect(func(enabled: bool) -> void:
		_end_stroke()
		_editor.rail_auto_turn = enabled
		_refresh_brushes()
	)
	_rail_panel.add_child(_rail_auto_toggle)
	var help: Label = Label.new()
	help.text = "沿拖曳方向前進 · R 旋轉單格方向\n右鍵只擦軌道，保留覆蓋的方塊"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override(&"font_size", 15)
	_rail_panel.add_child(help)
	_cell_info = Label.new()
	_cell_info.text = "將滑鼠移到地圖，查看格子與機關"
	_cell_info.add_theme_font_size_override(&"font_size", 15)
	_cell_info.add_theme_color_override(&"font_color", Palette.SKY_400)
	var hint: Label = $VBox/Body/HBox/CanvasArea/Hint
	hint.get_parent().add_child(_cell_info)
	hint.get_parent().move_child(_cell_info, hint.get_index())


func _refresh_cell_info() -> void:
	if _cell_info == null:
		return
	var cell: Vector2i = _hover_cell()
	var grid: LevelGrid = _editor.level.grid
	if not Rect2(Vector2.ZERO, _view.size).has_point(_view.get_local_mouse_position()) or not grid.in_bounds(cell.y, cell.x):
		_cell_info.text = "筆刷：" + BrushIcon.label_for(_editor.brush)
		return
	var layers: PackedStringArray = []
	if grid.get_cell(cell.y, cell.x) != Tile.AIR:
		layers.append(BrushIcon.tile_label(grid.get_cell(cell.y, cell.x)))
	if grid.sensors.has(cell):
		layers.append("感測器")
	if grid.wires.has(cell):
		layers.append("連線")
	if grid.rails.has(cell):
		var labels: Dictionary[int, String] = {Tile.RAIL_RIGHT: "→", Tile.RAIL_LEFT: "←", Tile.RAIL_UP: "↑", Tile.RAIL_DOWN: "↓"}
		layers.append("軌道 " + labels[grid.rails[cell]])
	_cell_info.text = "格子 (%d, %d) · %s" % [cell.x + 1, cell.y + 1, " + ".join(layers) if not layers.is_empty() else "空格"]


func _build_spike_buttons() -> void:
	for i: int in SPIKE_LABELS.size():
		var button: Button = Button.new()
		button.theme_type_variation = &"ChipButton"
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.text = SPIKE_LABELS[i]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_editor.set_spike_direction.bind(i as LevelEditor.SpikeDirection))
		_spike_row.add_child(button)
		_spike_buttons.append(button)


func _build_preset_buttons() -> void:
	for preset: Vector2i in SIZE_PRESETS:
		var button: Button = Button.new()
		button.theme_type_variation = &"ChipButton"
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.text = "%d×%d" % [preset.x, preset.y]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_editor.resize.bind(preset.x, preset.y))
		_preset_grid.add_child(button)
		_preset_buttons.append(button)


func _select_brush(brush: LevelEditor.Brush) -> void:
	_end_stroke()
	_editor.set_brush(brush)
	# Clicking an already selected toggle must keep its active highlight.
	_refresh_brushes()


func _undo_action() -> void:
	_end_stroke()
	_editor.undo()


func _redo_action() -> void:
	_end_stroke()
	_editor.redo()
