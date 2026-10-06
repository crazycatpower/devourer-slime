extends TestCase


func test_swapping_direction_keys_does_not_keep_opposite_aliases() -> void:
	InputBindings.apply_to_input_map(InputBindings.MOVE_LEFT, InputBindings.make_key(KEY_D))
	InputBindings.apply_to_input_map(InputBindings.MOVE_RIGHT, InputBindings.make_key(KEY_A))
	var left: InputEventKey = InputBindings.make_key(KEY_D)
	left.pressed = true
	var reader: PlayerInput = PlayerInput.new()
	reader.handle_event(left)
	var sampled: SimInput = reader.sample(Vector2.ZERO)
	check(sampled.left, "new left key works")
	check(not sampled.right, "old right alias cannot cancel movement")
	for action: StringName in [InputBindings.MOVE_LEFT, InputBindings.MOVE_RIGHT]:
		InputBindings.apply_to_input_map(action, InputBindings.default_event(action))
