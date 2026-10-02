class_name UiMotion
extends RefCounted
## Small, shared interface animations, so that every dialog opens the same
## way and every card reacts to the pointer the same way.
##
## They only touch a control's scale and transparency, never its layout, and a
## control is fully usable from the first frame: nothing waits for an
## animation to finish.

const POP_SEC: float = 0.18
const POP_FROM_SCALE: float = 0.92
const RISE_SEC: float = 0.22
const RISE_FROM_SCALE: float = 0.96
const HOVER_SEC: float = 0.1
const HOVER_SCALE: float = 1.025

const _TWEEN_META: StringName = &"ui_motion_tween"


## Opens a modal: [param panel] pops in while [param dim], the darkening
## behind it, fades in.
static func pop_in(panel: Control, dim: CanvasItem = null) -> void:
	panel.pivot_offset_ratio = Vector2(0.5, 0.5)
	panel.scale = Vector2(POP_FROM_SCALE, POP_FROM_SCALE)
	panel.modulate.a = 0.0
	var tween: Tween = _restart_tween(panel)
	tween.set_parallel(true)
	tween.tween_property(panel, "scale", Vector2.ONE, POP_SEC).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, POP_SEC * 0.6)
	if dim != null:
		dim.modulate.a = 0.0
		tween.tween_property(dim, "modulate:a", 1.0, POP_SEC)


## Lets [param control] settle into place after [param delay] seconds; give
## the items of a list growing delays to have them arrive one after another.
static func rise_in(control: Control, delay: float = 0.0) -> void:
	control.pivot_offset_ratio = Vector2(0.5, 0.5)
	control.scale = Vector2(RISE_FROM_SCALE, RISE_FROM_SCALE)
	control.modulate.a = 0.0
	var tween: Tween = _restart_tween(control)
	tween.set_parallel(true)
	tween.tween_property(control, "scale", Vector2.ONE, RISE_SEC).set_delay(delay).set_trans(
		Tween.TRANS_CUBIC
	).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, RISE_SEC).set_delay(delay)


## Makes [param control] grow slightly while the pointer is over it.
static func add_hover_lift(control: Control) -> void:
	control.pivot_offset_ratio = Vector2(0.5, 0.5)
	control.mouse_entered.connect(_scale_to.bind(control, HOVER_SCALE))
	control.mouse_exited.connect(_scale_to.bind(control, 1.0))


static func _scale_to(control: Control, target: float) -> void:
	var tween: Tween = _restart_tween(control)
	tween.tween_property(control, "scale", Vector2(target, target), HOVER_SEC).set_trans(
		Tween.TRANS_CUBIC
	).set_ease(Tween.EASE_OUT)
	# A hover can interrupt the arrival animation; never leave it half faded.
	tween.parallel().tween_property(control, "modulate:a", 1.0, HOVER_SEC)


## One animation per control at a time: a new one replaces the old one.
static func _restart_tween(control: Control) -> Tween:
	if control.has_meta(_TWEEN_META):
		var running: Tween = control.get_meta(_TWEEN_META)
		if running != null and running.is_valid():
			running.kill()
	var tween: Tween = control.create_tween()
	control.set_meta(_TWEEN_META, tween)
	return tween
