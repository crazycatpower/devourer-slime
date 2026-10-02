class_name PlayerInput
extends RefCounted
## Turns input events into the per-tick [SimInput] the simulation consumes.
##
## Button edges (a press, a release) are remembered until a tick has consumed
## them. That way a tap is never lost when the simulation runs slower than
## the display (bullet time), and is never applied twice when it runs faster.

const ACTIONS: Array[StringName] = [
	InputBindings.MOVE_LEFT, InputBindings.MOVE_RIGHT, InputBindings.JUMP,
	InputBindings.EAT, InputBindings.SHOOT,
]

var _held: Dictionary[StringName, bool] = {}
var _pressed: Dictionary[StringName, bool] = {}
var _released: Dictionary[StringName, bool] = {}


func _init() -> void:
	release_all()


## Feeds one input event. Returns true when it belonged to a gameplay action.
func handle_event(event: InputEvent) -> bool:
	var used: bool = false
	for action: StringName in ACTIONS:
		if event.is_action_pressed(action):
			if not _held[action]:
				_pressed[action] = true
			_held[action] = true
			used = true
		elif event.is_action_released(action):
			if _held[action]:
				_released[action] = true
			_held[action] = false
			used = true
	return used


func is_held(action: StringName) -> bool:
	return _held.get(action, false)


## Input for the next tick. [param mouse] is the pointer position relative to
## the view's top-left corner, in world units.
func sample(mouse: Vector2) -> SimInput:
	var inp: SimInput = SimInput.new()
	inp.left = _held[InputBindings.MOVE_LEFT]
	inp.right = _held[InputBindings.MOVE_RIGHT]
	inp.jump = _held[InputBindings.JUMP]
	inp.eat = _held[InputBindings.EAT]
	inp.shoot = _held[InputBindings.SHOOT]
	inp.jump_pressed = _pressed[InputBindings.JUMP]
	inp.shoot_released = _released[InputBindings.SHOOT]
	inp.mouse_x = mouse.x
	inp.mouse_y = mouse.y
	return inp


## Call after each simulated tick: its edges have been consumed.
func end_tick() -> void:
	for action: StringName in ACTIONS:
		_pressed[action] = false
		_released[action] = false


## Forgets every held button without producing release edges. Used when the
## game pauses or loses focus, where the real releases may never arrive.
func release_all() -> void:
	for action: StringName in ACTIONS:
		_held[action] = false
		_pressed[action] = false
		_released[action] = false
