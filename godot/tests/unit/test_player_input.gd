extends TestCase


func _event(reader: PlayerInput, action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	reader.handle_event(event)


func test_pause_cancels_aim_without_firing() -> void:
	var reader := PlayerInput.new()
	_event(reader, InputBindings.SHOOT, true)
	check(reader.sample(Vector2.ZERO).shoot, "aim starts")
	reader.end_tick()
	reader.release_all()
	var resumed := reader.sample(Vector2.ZERO)
	check(not resumed.shoot, "aim is cleared")
	check(not resumed.shoot_released, "resume must not synthesize a shot")


func test_quick_shot_release_is_consumed_once() -> void:
	var reader := PlayerInput.new()
	_event(reader, InputBindings.SHOOT, true)
	_event(reader, InputBindings.SHOOT, false)
	check(reader.sample(Vector2.ZERO).shoot_released, "tap survives until tick")
	reader.end_tick()
	check(not reader.sample(Vector2.ZERO).shoot_released, "no repeated shot")


func test_cancel_discards_pending_jump_and_shot_edges() -> void:
	var reader := PlayerInput.new()
	_event(reader, InputBindings.JUMP, true)
	_event(reader, InputBindings.SHOOT, true)
	_event(reader, InputBindings.SHOOT, false)
	reader.release_all()
	var cleared := reader.sample(Vector2.ZERO)
	check(not cleared.jump_pressed, "pending jump cleared")
	check(not cleared.shoot_released, "pending shot cleared")
