class_name InputBindings
extends RefCounted
## The game's rebindable input actions: names, defaults and (de)serialisation.
##
## Each action holds exactly one binding, a physical key or a mouse button.
## [Settings] owns the current bindings and persists them; this class is the
## stateless toolbox around them.

const MOVE_UP: StringName = &"move_up"
const MOVE_DOWN: StringName = &"move_down"
const MOVE_LEFT: StringName = &"move_left"
const MOVE_RIGHT: StringName = &"move_right"
const JUMP: StringName = &"jump"
const EAT: StringName = &"eat"
const SHOOT: StringName = &"shoot"
const RESTART: StringName = &"restart"

## Every rebindable action, in the order the settings screen lists them.
const ALL: Array[StringName] = [
	MOVE_UP, MOVE_DOWN, MOVE_LEFT, MOVE_RIGHT, JUMP, EAT, SHOOT, RESTART,
]
## Actions that are live at the same time during play. Two of them may not
## share a binding. (Up/down only pan the level editor, so Up may share W with
## Jump.)
const GAMEPLAY: Array[StringName] = [MOVE_LEFT, MOVE_RIGHT, JUMP, EAT, SHOOT, RESTART]

const _KEY_PREFIX: String = "key:"
const _MOUSE_PREFIX: String = "mouse:"


static func label(action: StringName) -> String:
	match action:
		MOVE_UP:
			return "上 (Up)"
		MOVE_DOWN:
			return "下 (Down)"
		MOVE_LEFT:
			return "左 (Left)"
		MOVE_RIGHT:
			return "右 (Right)"
		JUMP:
			return "跳躍 (Jump)"
		EAT:
			return "吞噬 (Eat)"
		SHOOT:
			return "吐出 (Shoot)"
		RESTART:
			return "重來 (Restart)"
	return String(action)


static func default_event(action: StringName) -> InputEvent:
	match action:
		MOVE_UP, JUMP:
			return make_key(KEY_W)
		MOVE_DOWN:
			return make_key(KEY_S)
		MOVE_LEFT:
			return make_key(KEY_A)
		MOVE_RIGHT:
			return make_key(KEY_D)
		EAT:
			return make_mouse(MOUSE_BUTTON_LEFT)
		SHOOT:
			return make_mouse(MOUSE_BUTTON_RIGHT)
		RESTART:
			return make_key(KEY_R)
	return null


static func make_key(physical_keycode: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = physical_keycode
	event.keycode = physical_keycode
	return event


static func make_mouse(button: MouseButton) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	return event


## True when [param event] is a fresh key or mouse-button press that may be
## used as a binding. Escape is reserved for pausing and cancelling, F11 for
## switching to and from fullscreen.
static func is_bindable(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key: InputEventKey = event
		return (
			key.pressed and not key.echo
			and key.physical_keycode != KEY_ESCAPE and key.physical_keycode != KEY_F11
		)
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		return mouse.pressed and mouse.button_index in [
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE,
			MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2,
		]
	return false


## Reduces a raw input event to the clean binding it represents.
static func normalized(event: InputEvent) -> InputEvent:
	if event is InputEventKey:
		var key: InputEventKey = event
		return make_key(key.physical_keycode)
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		return make_mouse(mouse.button_index)
	return null


static func same_binding(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		var key_a: InputEventKey = a
		var key_b: InputEventKey = b
		return key_a.physical_keycode == key_b.physical_keycode
	if a is InputEventMouseButton and b is InputEventMouseButton:
		var mouse_a: InputEventMouseButton = a
		var mouse_b: InputEventMouseButton = b
		return mouse_a.button_index == mouse_b.button_index
	return false


static func encode(event: InputEvent) -> String:
	if event is InputEventKey:
		var key: InputEventKey = event
		return _KEY_PREFIX + str(int(key.physical_keycode))
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		return _MOUSE_PREFIX + str(int(mouse.button_index))
	return ""


## Inverse of [method encode]; returns null for anything unrecognised.
static func decode(text: String) -> InputEvent:
	if text.begins_with(_KEY_PREFIX):
		var code: int = text.trim_prefix(_KEY_PREFIX).to_int()
		if code > 0:
			return make_key(code as Key)
	elif text.begins_with(_MOUSE_PREFIX):
		var button: int = text.trim_prefix(_MOUSE_PREFIX).to_int()
		if button > 0:
			return make_mouse(button as MouseButton)
	return null


## Short human-readable name of a binding, for buttons and prompts.
static func describe(event: InputEvent) -> String:
	if event is InputEventKey:
		var key: InputEventKey = event
		# Show the letter printed on the player's keyboard layout where the
		# platform can tell us; the headless server cannot.
		var label_code: Key = key.physical_keycode
		if DisplayServer.get_name() != "headless":
			var layout_code: Key = DisplayServer.keyboard_get_label_from_physical(key.physical_keycode)
			if layout_code != KEY_NONE:
				label_code = layout_code
		return OS.get_keycode_string(label_code)
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		match mouse.button_index:
			MOUSE_BUTTON_LEFT:
				return "滑鼠左鍵"
			MOUSE_BUTTON_RIGHT:
				return "滑鼠右鍵"
			MOUSE_BUTTON_MIDDLE:
				return "滑鼠中鍵"
			MOUSE_BUTTON_XBUTTON1:
				return "滑鼠側鍵 1"
			MOUSE_BUTTON_XBUTTON2:
				return "滑鼠側鍵 2"
	return "?"


## Short human-readable display of all active controls for this action.
static func describe_full(action: StringName, event: InputEvent) -> String:
	match action:
		MOVE_UP:
			return "W  /  ↑" if same_binding(event, default_event(MOVE_UP)) else "%s  (W/↑)" % describe(event)
		MOVE_DOWN:
			return "S  /  ↓" if same_binding(event, default_event(MOVE_DOWN)) else "%s  (S/↓)" % describe(event)
		MOVE_LEFT:
			return "A  /  ←" if same_binding(event, default_event(MOVE_LEFT)) else "%s  (A/←)" % describe(event)
		MOVE_RIGHT:
			return "D  /  →" if same_binding(event, default_event(MOVE_RIGHT)) else "%s  (D/→)" % describe(event)
		JUMP:
			return "空格  /  W  /  ↑" if same_binding(event, default_event(JUMP)) or (event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_SPACE) else "%s  (空格/W/↑)" % describe(event)
		_:
			return describe(event)


## Makes [param action] respond to [param event] and standard alternate keys (WASD, Arrows, Space).
static func apply_to_input_map(action: StringName, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	if event != null:
		InputMap.action_add_event(action, event)
	# Default convenience keys must not survive an explicit remap (e.g. A/D
	# swapped), or the same key can drive both directions at once.
	if not same_binding(event, default_event(action)):
		return
	match action:
		MOVE_LEFT:
			_add_alt_key(action, event, KEY_A)
			_add_alt_key(action, event, KEY_LEFT)
		MOVE_RIGHT:
			_add_alt_key(action, event, KEY_D)
			_add_alt_key(action, event, KEY_RIGHT)
		MOVE_UP:
			_add_alt_key(action, event, KEY_W)
			_add_alt_key(action, event, KEY_UP)
		MOVE_DOWN:
			_add_alt_key(action, event, KEY_S)
			_add_alt_key(action, event, KEY_DOWN)
		JUMP:
			_add_alt_key(action, event, KEY_W)
			_add_alt_key(action, event, KEY_UP)
			_add_alt_key(action, event, KEY_SPACE)


static func _add_alt_key(action: StringName, primary: InputEvent, key_code: Key) -> void:
	if primary is InputEventKey and (primary as InputEventKey).physical_keycode == key_code:
		return
	var alt: InputEventKey = make_key(key_code)
	InputMap.action_add_event(action, alt)
