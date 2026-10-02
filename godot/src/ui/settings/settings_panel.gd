class_name SettingsPanel
extends VBoxContainer
## Volume, game speed, bullet time, fullscreen and key bindings. Used by the
## pause menu and the main menu's settings dialog; it edits [Settings]
## directly.

const _LISTENING_TEXT: String = "…"

## The action whose binding button is waiting for a key, or empty.
var _capturing: StringName = &""
var _binding_buttons: Dictionary[StringName, Button] = {}
var _speed_buttons: Dictionary[float, Button] = {}

@onready var _volume_value: Label = %VolumeValue
@onready var _mute_button: Button = %MuteButton
@onready var _volume_slider: HSlider = %VolumeSlider
@onready var _speed_value: Label = %SpeedValue
@onready var _speed_row: HBoxContainer = %SpeedRow
@onready var _bullet_time_button: Button = %BulletTimeButton
@onready var _fullscreen_button: Button = %FullscreenButton
@onready var _binding_grid: GridContainer = %BindingGrid
@onready var _binding_hint: Label = %BindingHint
@onready var _reset_bindings_button: Button = %ResetBindingsButton


func _ready() -> void:
	for speed: float in Settings.GAME_SPEEDS:
		var button: Button = Button.new()
		button.theme_type_variation = &"ChipButton"
		button.toggle_mode = true
		button.text = "x%.1f" % speed
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(Settings.set_game_speed.bind(speed))
		_speed_row.add_child(button)
		_speed_buttons[speed] = button

	for action: StringName in InputBindings.ALL:
		var label: Label = Label.new()
		label.text = InputBindings.label(action)
		label.theme_type_variation = &"CaptionLabel"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_binding_grid.add_child(label)
		var button: Button = Button.new()
		button.theme_type_variation = &"ChipButton"
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(150.0, 0.0)
		button.pressed.connect(_on_binding_button_pressed.bind(action))
		_binding_grid.add_child(button)
		_binding_buttons[action] = button

	_volume_slider.value_changed.connect(_on_volume_slider_changed)
	_mute_button.pressed.connect(_on_mute_pressed)
	_bullet_time_button.pressed.connect(_on_bullet_time_pressed)
	_fullscreen_button.pressed.connect(_on_fullscreen_pressed)
	_reset_bindings_button.pressed.connect(_on_reset_bindings_pressed)
	visibility_changed.connect(_stop_capturing)

	Settings.audio_changed.connect(_refresh)
	Settings.gameplay_changed.connect(_refresh)
	Settings.display_changed.connect(_refresh)
	Settings.bindings_changed.connect(_refresh)
	_refresh()


func _input(event: InputEvent) -> void:
	if _capturing.is_empty() or not is_visible_in_tree():
		return
	# While a binding button is listening, the next key or mouse button
	# belongs to it and must not reach anything else.
	if event is InputEventKey:
		var key: InputEventKey = event
		if key.pressed and key.physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_stop_capturing()
			return
	if InputBindings.is_bindable(event):
		get_viewport().set_input_as_handled()
		var action: StringName = _capturing
		_capturing = &""
		Settings.rebind(action, event)
		_refresh()
	elif event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


## True while a binding button is waiting for input, so that owners can
## leave Escape to this panel.
func is_capturing() -> bool:
	return not _capturing.is_empty()


func _refresh() -> void:
	var percent: int = 0 if Settings.muted else roundi(Settings.volume * 100.0)
	_volume_value.text = "%d%%" % percent
	_volume_slider.set_value_no_signal(float(percent))
	_mute_button.set_pressed_no_signal(Settings.muted)
	_mute_button.text = "已靜音" if Settings.muted else "靜音"

	_speed_value.text = "x%.1f" % Settings.game_speed
	for speed: float in _speed_buttons:
		_speed_buttons[speed].set_pressed_no_signal(is_equal_approx(speed, Settings.game_speed))

	_bullet_time_button.set_pressed_no_signal(Settings.bullet_time_enabled)
	_bullet_time_button.text = "已啟用 (Enabled)" if Settings.bullet_time_enabled else "已停用 (Disabled)"
	_fullscreen_button.set_pressed_no_signal(Settings.fullscreen)
	_fullscreen_button.text = "全螢幕：開 (F11)" if Settings.fullscreen else "全螢幕：關 (F11)"

	for action: StringName in _binding_buttons:
		var button: Button = _binding_buttons[action]
		var listening: bool = action == _capturing
		button.set_pressed_no_signal(listening)
		button.text = _LISTENING_TEXT if listening else InputBindings.describe(Settings.binding(action))
	_binding_hint.text = (
		"請按下要使用的按鍵或滑鼠鍵（Esc 取消）" if is_capturing()
		else "點選按鍵後按下新的按鍵；與其他動作重複時會自動互換。"
	)


func _stop_capturing() -> void:
	if not _capturing.is_empty():
		_capturing = &""
		_refresh()


func _on_binding_button_pressed(action: StringName) -> void:
	_capturing = action
	_refresh()


func _on_volume_slider_changed(value: float) -> void:
	var volume: float = value / 100.0
	if volume > 0.0:
		Settings.set_volume(volume)
		Settings.set_muted(false)
	else:
		Settings.set_muted(true)
	_refresh()


func _on_mute_pressed() -> void:
	Settings.set_muted(not Settings.muted)
	_refresh()


func _on_bullet_time_pressed() -> void:
	Settings.set_bullet_time_enabled(not Settings.bullet_time_enabled)
	_refresh()


func _on_fullscreen_pressed() -> void:
	Settings.set_fullscreen(not Settings.fullscreen)
	_refresh()


func _on_reset_bindings_pressed() -> void:
	_stop_capturing()
	Settings.reset_bindings()
