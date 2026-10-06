extends Node
## Persistent user settings (autoload `Settings`).
##
## Stored in the file named by [method SavePaths.settings_file]. Every setter validates its value, notifies
## listeners and schedules a save, so callers never write the file themselves.

signal audio_changed
signal gameplay_changed
signal display_changed
signal bindings_changed

const GAME_SPEEDS: Array[float] = [0.5, 1.0, 1.5, 2.0]
const DEFAULT_VOLUME: float = 0.8

var volume: float = DEFAULT_VOLUME
var muted: bool = false
var game_speed: float = 1.0
var bullet_time_enabled: bool = true
var fullscreen: bool = false

var _bindings: Dictionary[StringName, InputEvent] = {}
var _save_queued: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	_apply_bindings()
	_apply_fullscreen()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_flush()


func set_volume(value: float) -> void:
	if not is_finite(value):
		return
	var clamped: float = clampf(value, 0.0, 1.0)
	if is_equal_approx(clamped, volume):
		return
	volume = clamped
	audio_changed.emit()
	_queue_save()


func set_muted(value: bool) -> void:
	if value == muted:
		return
	muted = value
	audio_changed.emit()
	_queue_save()


func set_game_speed(value: float) -> void:
	if not is_finite(value):
		return
	var clamped: float = clampf(value, GAME_SPEEDS[0], GAME_SPEEDS[-1])
	if is_equal_approx(clamped, game_speed):
		return
	game_speed = clamped
	gameplay_changed.emit()
	_queue_save()


func set_bullet_time_enabled(value: bool) -> void:
	if value == bullet_time_enabled:
		return
	bullet_time_enabled = value
	gameplay_changed.emit()
	_queue_save()


func set_fullscreen(value: bool) -> void:
	if value == fullscreen:
		return
	fullscreen = value
	_apply_fullscreen()
	display_changed.emit()
	_queue_save()


func binding(action: StringName) -> InputEvent:
	return _bindings.get(action)


## Binds [param action] to [param event]. When another action that is live at
## the same time already uses that binding, the two swap, so no action is ever
## left unreachable.
func rebind(action: StringName, event: InputEvent) -> void:
	var new_event: InputEvent = InputBindings.normalized(event)
	if new_event == null or not _bindings.has(action):
		return
	var old_event: InputEvent = _bindings[action]
	if InputBindings.same_binding(old_event, new_event):
		return
	for other: StringName in _conflict_group(action):
		if other != action and InputBindings.same_binding(_bindings[other], new_event):
			_set_binding(other, old_event)
	_set_binding(action, new_event)
	_apply_bindings()
	bindings_changed.emit()
	_queue_save()


func reset_bindings() -> void:
	for action: StringName in InputBindings.ALL:
		_set_binding(action, InputBindings.default_event(action))
	_apply_bindings()
	bindings_changed.emit()
	_queue_save()


## Actions whose bindings must stay distinct from [param action]'s.
func _conflict_group(action: StringName) -> Array[StringName]:
	if action in InputBindings.GAMEPLAY:
		return InputBindings.GAMEPLAY
	return [InputBindings.MOVE_UP, InputBindings.MOVE_DOWN, InputBindings.MOVE_LEFT, InputBindings.MOVE_RIGHT]


func _apply_bindings() -> void:
	for action: StringName in InputBindings.ALL:
		InputBindings.apply_to_input_map(action, _bindings[action])
	# A deliberately chosen gameplay key takes priority over another action's
	# optional alias, such as Space assigned to shooting instead of jumping.
	for action: StringName in InputBindings.GAMEPLAY:
		for other: StringName in InputBindings.GAMEPLAY:
			if action == other:
				continue
			for event: InputEvent in InputMap.action_get_events(action):
				if not InputBindings.same_binding(event, _bindings[action]) and InputBindings.same_binding(event, _bindings[other]):
					InputMap.action_erase_event(action, event)


func _set_binding(action: StringName, event: InputEvent) -> void:
	_bindings[action] = event
	InputBindings.apply_to_input_map(action, event)


func _apply_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode: DisplayServer.WindowMode = (
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


func _load() -> void:
	for action: StringName in InputBindings.ALL:
		_bindings[action] = InputBindings.default_event(action)

	var config: ConfigFile = ConfigFile.new()
	if SafeConfig.load_file(config, SavePaths.settings_file()) != OK:
		return  # First run, or an unreadable file: keep the defaults.
	volume = clampf(_read_float(config, "audio", "volume", volume), 0.0, 1.0)
	muted = _read_bool(config, "audio", "muted", muted)
	game_speed = clampf(
		_read_float(config, "gameplay", "game_speed", game_speed), GAME_SPEEDS[0], GAME_SPEEDS[-1]
	)
	bullet_time_enabled = _read_bool(config, "gameplay", "bullet_time", bullet_time_enabled)
	fullscreen = _read_bool(config, "display", "fullscreen", fullscreen)
	for action: StringName in InputBindings.ALL:
		var stored: Variant = config.get_value("input", action, "")
		if stored is String:
			var event: InputEvent = InputBindings.decode(stored as String)
			if event != null:
				_bindings[action] = event


func _queue_save() -> void:
	if _save_queued:
		return
	_save_queued = true
	_flush.call_deferred()


func _flush() -> void:
	if not _save_queued:
		return
	_save_queued = false
	var config: ConfigFile = ConfigFile.new()
	config.set_value("audio", "volume", volume)
	config.set_value("audio", "muted", muted)
	config.set_value("gameplay", "game_speed", game_speed)
	config.set_value("gameplay", "bullet_time", bullet_time_enabled)
	config.set_value("display", "fullscreen", fullscreen)
	for action: StringName in InputBindings.ALL:
		config.set_value("input", action, InputBindings.encode(_bindings[action]))
	DirAccess.make_dir_recursive_absolute(SavePaths.root())
	var error: Error = SafeConfig.save_file(config, SavePaths.settings_file())
	if error != OK:
		push_warning("Settings: could not save (%s)" % error_string(error))


static func _read_float(config: ConfigFile, section: String, key: String, fallback: float) -> float:
	var value: Variant = config.get_value(section, key, fallback)
	if value is float:
		var number: float = value as float
		return number if is_finite(number) else fallback
	if value is int:
		return float(value as int)
	return fallback


static func _read_bool(config: ConfigFile, section: String, key: String, fallback: bool) -> bool:
	var value: Variant = config.get_value(section, key, fallback)
	if value is bool:
		return value
	return fallback
