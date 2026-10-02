extends TestCase
## Window sizing and the fullscreen shortcuts.


func test_windowed_size_fits_the_desktop_at_16_by_9() -> void:
	check_eq(WindowController.fitted_size(Vector2i(1920, 1040), 0.8), Vector2i(1479, 832))
	# An ultrawide desktop is limited by its height, a tall one by its width.
	check_eq(WindowController.fitted_size(Vector2i(3440, 1400), 0.8), Vector2i(1991, 1120))
	check_eq(WindowController.fitted_size(Vector2i(1200, 1920), 0.8), Vector2i(960, 540))


func test_windowed_size_never_drops_below_the_minimum() -> void:
	check_eq(WindowController.fitted_size(Vector2i(800, 600), 0.8), WindowController.MIN_WINDOW_SIZE)


func test_fullscreen_shortcuts() -> void:
	check(WindowController.is_fullscreen_shortcut(_key(KEY_F11)))
	check(WindowController.is_fullscreen_shortcut(_key(KEY_ENTER, true)), "Alt+Enter")
	check(WindowController.is_fullscreen_shortcut(_key(KEY_KP_ENTER, true)), "Alt+keypad Enter")
	check(not WindowController.is_fullscreen_shortcut(_key(KEY_ENTER)), "Enter alone is not one")
	check(not WindowController.is_fullscreen_shortcut(_key(KEY_F10)))

	var held: InputEventKey = _key(KEY_F11)
	held.echo = true
	check(not WindowController.is_fullscreen_shortcut(held), "key repeat does not toggle again")
	var released: InputEventKey = _key(KEY_F11)
	released.pressed = false
	check(not WindowController.is_fullscreen_shortcut(released))
	check(not WindowController.is_fullscreen_shortcut(InputEventMouseButton.new()))


func test_f11_cannot_be_bound_to_an_action() -> void:
	check(not InputBindings.is_bindable(_key(KEY_F11)))
	check(InputBindings.is_bindable(_key(KEY_F10)))


func _key(physical_keycode: Key, alt: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = physical_keycode
	event.pressed = true
	event.alt_pressed = alt
	return event
