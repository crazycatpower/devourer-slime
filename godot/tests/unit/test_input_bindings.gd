extends TestCase
## Input binding helpers.


func test_defaults_match_the_web_version() -> void:
	_check_key(InputBindings.default_event(InputBindings.MOVE_UP), KEY_W)
	_check_key(InputBindings.default_event(InputBindings.MOVE_DOWN), KEY_S)
	_check_key(InputBindings.default_event(InputBindings.MOVE_LEFT), KEY_A)
	_check_key(InputBindings.default_event(InputBindings.MOVE_RIGHT), KEY_D)
	_check_key(InputBindings.default_event(InputBindings.JUMP), KEY_W)
	_check_key(InputBindings.default_event(InputBindings.RESTART), KEY_R)
	_check_mouse(InputBindings.default_event(InputBindings.EAT), MOUSE_BUTTON_LEFT)
	_check_mouse(InputBindings.default_event(InputBindings.SHOOT), MOUSE_BUTTON_RIGHT)


func test_every_action_has_a_default_and_a_label() -> void:
	check_eq(InputBindings.ALL.size(), 8)
	for action: StringName in InputBindings.ALL:
		check(InputBindings.default_event(action) != null, "default for %s" % action)
		check(InputBindings.label(action) != String(action), "label for %s" % action)


func test_gameplay_defaults_do_not_collide() -> void:
	for a: StringName in InputBindings.GAMEPLAY:
		for b: StringName in InputBindings.GAMEPLAY:
			if a != b:
				check(
					not InputBindings.same_binding(
						InputBindings.default_event(a), InputBindings.default_event(b)
					),
					"%s and %s share a default" % [a, b],
				)


func test_encode_decode_round_trip() -> void:
	for event: InputEvent in [
		InputBindings.make_key(KEY_SPACE),
		InputBindings.make_key(KEY_LEFT),
		InputBindings.make_mouse(MOUSE_BUTTON_MIDDLE),
		InputBindings.make_mouse(MOUSE_BUTTON_XBUTTON2),
	]:
		var decoded: InputEvent = InputBindings.decode(InputBindings.encode(event))
		check(InputBindings.same_binding(event, decoded), InputBindings.encode(event))


func test_decode_rejects_garbage() -> void:
	for text: String in ["", "key:", "key:abc", "mouse:0", "pad:3", "KeyW"]:
		check(InputBindings.decode(text) == null, "'%s' should not decode" % text)


func test_same_binding() -> void:
	check(InputBindings.same_binding(InputBindings.make_key(KEY_A), InputBindings.make_key(KEY_A)))
	check(not InputBindings.same_binding(InputBindings.make_key(KEY_A), InputBindings.make_key(KEY_D)))
	check(not InputBindings.same_binding(
		InputBindings.make_key(KEY_A), InputBindings.make_mouse(MOUSE_BUTTON_LEFT)
	))
	check(not InputBindings.same_binding(null, InputBindings.make_key(KEY_A)))


func test_is_bindable() -> void:
	var press: InputEventKey = InputBindings.make_key(KEY_Q)
	press.pressed = true
	check(InputBindings.is_bindable(press), "key press")

	var release: InputEventKey = InputBindings.make_key(KEY_Q)
	check(not InputBindings.is_bindable(release), "key release")

	var echo: InputEventKey = InputBindings.make_key(KEY_Q)
	echo.pressed = true
	echo.echo = true
	check(not InputBindings.is_bindable(echo), "key repeat")

	var escape: InputEventKey = InputBindings.make_key(KEY_ESCAPE)
	escape.pressed = true
	check(not InputBindings.is_bindable(escape), "escape is reserved")

	var click: InputEventMouseButton = InputBindings.make_mouse(MOUSE_BUTTON_MIDDLE)
	click.pressed = true
	check(InputBindings.is_bindable(click), "middle mouse button")

	var wheel: InputEventMouseButton = InputBindings.make_mouse(MOUSE_BUTTON_WHEEL_UP)
	wheel.pressed = true
	check(not InputBindings.is_bindable(wheel), "mouse wheel")
	check(not InputBindings.is_bindable(InputEventMouseMotion.new()), "mouse motion")


func test_normalized_strips_event_state() -> void:
	var press: InputEventKey = InputBindings.make_key(KEY_Q)
	press.pressed = true
	press.shift_pressed = true
	var clean: InputEvent = InputBindings.normalized(press)
	check(clean is InputEventKey)
	var key: InputEventKey = clean
	check(not key.pressed)
	check(not key.shift_pressed)
	check_eq(key.physical_keycode, KEY_Q)


func test_apply_to_input_map_includes_wasd_arrows_and_space() -> void:
	InputBindings.apply_to_input_map(InputBindings.JUMP, InputBindings.make_key(KEY_W))
	var events: Array[InputEvent] = InputMap.action_get_events(InputBindings.JUMP)
	var keycodes: Array[Key] = []
	for e: InputEvent in events:
		if e is InputEventKey:
			keycodes.append((e as InputEventKey).physical_keycode)
	check(keycodes.has(KEY_W), "jump has W")
	check(keycodes.has(KEY_UP), "jump has Up Arrow")
	check(keycodes.has(KEY_SPACE), "jump has Space")

	InputBindings.apply_to_input_map(InputBindings.MOVE_LEFT, InputBindings.make_key(KEY_A))
	events = InputMap.action_get_events(InputBindings.MOVE_LEFT)
	keycodes.clear()
	for e: InputEvent in events:
		if e is InputEventKey:
			keycodes.append((e as InputEventKey).physical_keycode)
	check(keycodes.has(KEY_A), "left has A")
	check(keycodes.has(KEY_LEFT), "left has Left Arrow")


func _check_key(event: InputEvent, expected: Key) -> void:
	check(event is InputEventKey, "expected a key")
	if event is InputEventKey:
		var key: InputEventKey = event
		check_eq(key.physical_keycode, expected)


func _check_mouse(event: InputEvent, expected: MouseButton) -> void:
	check(event is InputEventMouseButton, "expected a mouse button")
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		check_eq(mouse.button_index, expected)
