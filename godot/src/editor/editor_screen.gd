class_name EditorScreen
extends Control
## The level editor: a paintable view of one slot's level with brushes, map
## size, import/export, undo and saving.
##
## The document lives in a [LevelEditor]; this screen turns mouse and key
## input into edits and keeps the widgets in step with it. Unsaved work is
## never dropped silently: leaving or switching slots asks first, and test
## play runs the working copy as it is.

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
@onready var _width_value: Label = %WidthValue
@onready var _height_value: Label = %HeightValue
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
@onready var _revert_button: Button = %RevertButton
@onready var _clear_button: Button = %ClearButton
@onready var _confirm: ConfirmDialog = %ConfirmDialog


## Call before the screen enters the tree.
func setup(slot: int) -> void:
	_slot = slot


func _ready() -> void:
	_build_brush_buttons()
	_build_spike_buttons()
	_build_preset_buttons()

	_view.sim = _sim
	_view.editor = _editor
	_view.gui_input.connect(_on_view_gui_input)

	_editor.changed.connect(_on_level_changed)
	_editor.brush_changed.connect(_refresh_brushes)
	_editor.history_changed.connect(_refresh_status)

	_menu_button.pressed.connect(_on_menu_pressed)
	_play_button.pressed.connect(_on_play_pressed)
	_prev_button.pressed.connect(_change_slot.bind(-1))
	_next_button.pressed.connect(_change_slot.bind(1))
	_undo_button.pressed.connect(_editor.undo)
	_redo_button.pressed.connect(_editor.redo)
	_width_minus.pressed.connect(_resize_by.bind(-10, 0))
	_width_plus.pressed.connect(_resize_by.bind(10, 0))
	_height_minus.pressed.connect(_resize_by.bind(0, -5))
	_height_plus.pressed.connect(_resize_by.bind(0, 5))
	_export_slot_button.pressed.connect(_on_export_slot_pressed)
	_export_all_button.pressed.connect(_on_export_all_pressed)
	_import_button.pressed.connect(_on_import_pressed)
	_import_text.text_changed.connect(func() -> void: _import_error.visible = false)
	_save_button.pressed.connect(_save)
	_revert_button.pressed.connect(_on_revert_pressed)
	_clear_button.pressed.connect(_on_clear_pressed)
	LevelStore.custom_levels_changed.connect(_refresh_status)

	_open_slot(_slot)


func _process(delta: float) -> void:
	# Typing in a text box must not scroll the level.
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is TextEdit or focus is LineEdit or _confirm.visible:
		return
	var direction: Vector2 = Vector2(
		Input.get_axis(InputBindings.MOVE_LEFT, InputBindings.MOVE_RIGHT),
		Input.get_axis(InputBindings.MOVE_UP, InputBindings.MOVE_DOWN)
	)
	if direction != Vector2.ZERO:
		_move_camera(direction * PAN_SPEED * delta)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or _confirm.visible:
		return
	var key: InputEventKey = event
	if not key.pressed or not key.is_command_or_control_pressed():
		return
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
		_:
			return
	get_viewport().set_input_as_handled()


# --- Painting ---------------------------------------------------------------------

func _on_view_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		match button.button_index:
			MOUSE_BUTTON_LEFT:
				if button.pressed:
					_begin_left_stroke()
				else:
					_end_stroke()
			MOUSE_BUTTON_RIGHT:
				if button.pressed:
					_painting = true
					_erasing = true
					_editor.begin_stroke()
					_editor.stroke_to(_hover_cell(), true)
				else:
					_end_stroke()
			MOUSE_BUTTON_MIDDLE:
				_panning = button.pressed
		_view.accept_event()
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		if _panning:
			_move_camera(-motion.relative / maxf(_view.world_scale, 0.001))
		elif _painting:
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


func _end_stroke() -> void:
	if not _painting:
		return
	if _editor.brush == LevelEditor.Brush.COPY and not _erasing:
		_editor.finish_selection()
		toast_requested.emit("已複製選取範圍，點一下即可貼上")
	else:
		_editor.end_stroke()
	_painting = false
	_erasing = false


func _hover_cell() -> Vector2i:
	var mouse: Vector2 = _view.mouse_in_world()
	return Vector2i(floori(mouse.x / Tile.SIZE), floori(mouse.y / Tile.SIZE))


func _move_camera(offset: Vector2) -> void:
	var camera: SimCamera = _sim.camera
	camera.x += offset.x
	camera.y += offset.y
	camera.apply_limits(_sim.level)
	camera.prev_x = camera.x
	camera.prev_y = camera.y


# --- Slots, saving and leaving --------------------------------------------------------

func _open_slot(slot: int) -> void:
	_slot = slot
	if LevelStore.is_custom_damaged(slot):
		toast_requested.emit("SLOT %d 的存檔已損毀，改為載入內建關卡" % slot)
	_editor.open(LevelStore.get_level(slot))
	var start: Vector2i = _editor.level.start_cell
	_sim.camera.snap_to(
		(float(start.x) + 0.5) * Tile.SIZE, (float(start.y) + 0.5) * Tile.SIZE, _editor.level.grid
	)
	_import_error.visible = false
	_refresh_brushes()
	_refresh_status()


func _save() -> void:
	var error: Error = LevelStore.save_custom(_slot, _editor.level)
	if error != OK:
		toast_requested.emit("儲存失敗（%s）" % error_string(error))
		return
	_editor.mark_saved()
	toast_requested.emit("關卡已儲存")


## Runs [param action] once any unsaved changes have been dealt with: saved,
## knowingly discarded, or (when the player cancels) not at all.
func run_when_changes_settled(action: Callable) -> void:
	if not _editor.is_dirty():
		action.call()
		return
	_confirm.ask("這個關卡有尚未儲存的變更。", ["儲存後繼續", "不儲存", "取消"], 1)
	var choice: int = await _confirm.chosen
	if choice == 0:
		_save()
		if _editor.is_dirty():
			return  # Saving failed; stay here.
		action.call()
	elif choice == 1:
		action.call()


func _on_menu_pressed() -> void:
	run_when_changes_settled(func() -> void: menu_requested.emit())


func _on_play_pressed() -> void:
	# Test play runs the working copy, saved or not.
	test_requested.emit(_slot, _editor.level.duplicate_level())


func _change_slot(step: int) -> void:
	var target: int = _slot + step
	if target < 1 or target > GameConstants.SLOT_COUNT:
		return
	run_when_changes_settled(_open_slot.bind(target))


func _on_revert_pressed() -> void:
	_confirm.ask("要刪除 SLOT %d 的自訂存檔，還原成內建關卡嗎？\n這個動作無法復原。" % _slot, ["還原", "取消"], 0)
	if await _confirm.chosen != 0:
		return
	var error: Error = LevelStore.delete_custom(_slot)
	if error != OK:
		toast_requested.emit("還原失敗（%s）" % error_string(error))
		return
	_open_slot(_slot)
	toast_requested.emit("已還原為內建關卡")


func _on_clear_pressed() -> void:
	_confirm.ask("確定要清空整張地圖嗎？\n（可以用復原救回來）", ["清空", "取消"], 0)
	if await _confirm.chosen == 0:
		_editor.clear()
		toast_requested.emit("畫布已清空")


func _resize_by(cols: int, rows: int) -> void:
	_editor.resize(_editor.level.grid.cols + cols, _editor.level.grid.rows + rows)


# --- Import and export -------------------------------------------------------------------

func _on_export_slot_pressed() -> void:
	DisplayServer.clipboard_set(JSON.stringify(Array(LevelCodec.encode(_editor.level))))
	toast_requested.emit("已將目前關卡複製到剪貼簿")


func _on_export_all_pressed() -> void:
	var text: String = LevelStore.export_all()
	if text.is_empty():
		toast_requested.emit("目前沒有已儲存的自訂關卡可匯出")
		return
	DisplayServer.clipboard_set(text)
	toast_requested.emit("已將所有自訂關卡複製到剪貼簿")


func _on_import_pressed() -> void:
	if _editor.is_dirty():
		_confirm.ask("匯入可能會覆蓋這個關卡尚未儲存的變更。", ["繼續匯入", "取消"], 0)
		if await _confirm.chosen != 0:
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
	_sim.camera.apply_limits(level.grid)
	_sim.camera.prev_x = _sim.camera.x
	_sim.camera.prev_y = _sim.camera.y
	_refresh_status()


func _refresh_status() -> void:
	var world: int = GameConstants.world_of_slot(_slot)
	var accent: Color = WorldCatalog.accent(world)
	var grid: LevelGrid = _editor.level.grid
	_backdrop.glow_color = WorldCatalog.fill(world)
	_slot_caption.text = "WORLD %d  //  LEVEL %d" % [world, GameConstants.level_in_world(_slot)]
	_slot_caption.add_theme_color_override(&"font_color", accent)
	_slot_label.text = "SLOT %02d" % _slot
	_slot_label.add_theme_color_override(&"font_color", accent)
	_prev_button.disabled = _slot <= 1
	_next_button.disabled = _slot >= GameConstants.SLOT_COUNT

	var source: String = "自訂存檔" if LevelStore.has_custom(_slot) else "內建關卡"
	_slot_info.text = "SLOT %02d（WORLD %d）· %s" % [_slot, world, source]
	_dirty_label.visible = _editor.is_dirty()
	_size_info.text = "%d × %d" % [grid.cols, grid.rows]
	_width_value.text = str(grid.cols)
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
	_revert_button.disabled = not LevelStore.has_custom(_slot)
	_save_button.text = "儲存關卡 SAVE ●" if _editor.is_dirty() else "儲存關卡 SAVE"


func _refresh_brushes() -> void:
	for brush: int in _brush_buttons:
		_brush_buttons[brush].set_pressed_no_signal(brush == _editor.brush)
	_brush_buttons[LevelEditor.Brush.PASTE].disabled = _editor.clipboard == null
	_spike_panel.visible = _editor.brush == LevelEditor.Brush.SPIKES
	for i: int in _spike_buttons.size():
		_spike_buttons[i].set_pressed_no_signal(i == _editor.spike_direction)


func _build_brush_buttons() -> void:
	for brush: LevelEditor.Brush in BRUSH_ORDER:
		var button: Button = Button.new()
		button.theme_type_variation = &"ChipButton"
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0.0, 96.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = BrushIcon.label_for(brush)
		button.pressed.connect(_editor.set_brush.bind(brush))

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
