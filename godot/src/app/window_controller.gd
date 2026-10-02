class_name WindowController
extends Node
## Looks after the game window: the fullscreen shortcuts (F11 and Alt+Enter),
## a windowed size that suits the monitor, and a minimum size below which the
## interface would not fit.
##
## Whether the game is fullscreen is a setting, so the shortcuts go through
## [code]Settings[/code] and the settings screen stays in step.

const MIN_WINDOW_SIZE: Vector2i = Vector2i(960, 540)
## Share of the usable desktop the window takes when it is not fullscreen.
const DESKTOP_SHARE: float = 0.8
const ASPECT: float = 16.0 / 9.0

## The windowed size is chosen once; after that the player's own resizing
## is left alone.
var _window_fitted: bool = false


func _ready() -> void:
	# The shortcuts must work in the pause menu and in dialogs too.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _has_real_window():
		return
	get_window().min_size = MIN_WINDOW_SIZE
	Settings.display_changed.connect(_fit_window_once)
	_fit_window_once()


func _input(event: InputEvent) -> void:
	if is_fullscreen_shortcut(event):
		get_viewport().set_input_as_handled()
		Settings.set_fullscreen(not Settings.fullscreen)


## True for a fresh press of F11 or Alt+Enter.
static func is_fullscreen_shortcut(event: InputEvent) -> bool:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return false
	if key.physical_keycode == KEY_F11:
		return true
	return key.alt_pressed and (
		key.physical_keycode == KEY_ENTER or key.physical_keycode == KEY_KP_ENTER
	)


## Largest 16:9 size that fits inside [param share] of [param available].
static func fitted_size(available: Vector2i, share: float) -> Vector2i:
	var width: float = float(available.x) * share
	var height: float = float(available.y) * share
	if width / height > ASPECT:
		width = height * ASPECT
	else:
		height = width / ASPECT
	return Vector2i(roundi(width), roundi(height)).max(MIN_WINDOW_SIZE)


func _fit_window_once() -> void:
	if _window_fitted or Settings.fullscreen:
		return
	_window_fitted = true
	# Leaving fullscreen is applied by the window system a moment later.
	_fit_window.call_deferred()


func _fit_window() -> void:
	var window: Window = get_window()
	if window.mode != Window.MODE_WINDOWED:
		return
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(window.current_screen)
	window.size = fitted_size(usable.size, DESKTOP_SHARE)
	var margin: Vector2 = Vector2(usable.size - window.size) / 2.0
	window.position = usable.position + Vector2i(margin.round())


## False when there is no window of our own to manage: headless runs, and
## the game embedded in the editor's own window.
func _has_real_window() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	return not Engine.is_embedded_in_editor()
