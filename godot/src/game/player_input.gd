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
var _prev_jump: bool = false
var _prev_shoot: bool = false


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
			if not Input.is_action_pressed(action):
				if _held[action]:
					_released[action] = true
				_held[action] = false
			used = true
	return used


func is_held(action: StringName) -> bool:
	return _held.get(action, false) or Input.is_action_pressed(action)


## Input for the next tick. [param mouse] is the pointer position relative to
## the view's top-left corner, in world units.
func sample(mouse: Vector2) -> SimInput:
	var inp: SimInput = SimInput.new()
	var left_held: bool = _held[InputBindings.MOVE_LEFT] or Input.is_action_pressed(InputBindings.MOVE_LEFT)
	var right_held: bool = _held[InputBindings.MOVE_RIGHT] or Input.is_action_pressed(InputBindings.MOVE_RIGHT)
	var jump_held: bool = _held[InputBindings.JUMP] or Input.is_action_pressed(InputBindings.JUMP)
	var eat_held: bool = _held[InputBindings.EAT] or Input.is_action_pressed(InputBindings.EAT)
	var shoot_held: bool = _held[InputBindings.SHOOT] or Input.is_action_pressed(InputBindings.SHOOT)

	inp.left = left_held
	inp.right = right_held
	inp.jump = jump_held
	inp.eat = eat_held
	inp.shoot = shoot_held
	inp.jump_pressed = _pressed[InputBindings.JUMP] or (jump_held and not _prev_jump)
	inp.shoot_released = _released[InputBindings.SHOOT] or (not shoot_held and _prev_shoot)
	_prev_jump = jump_held
	_prev_shoot = shoot_held
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
	_prev_jump = false
	_prev_shoot = false
	for action: StringName in ACTIONS:
		_held[action] = false
		_pressed[action] = false
		_released[action] = false
