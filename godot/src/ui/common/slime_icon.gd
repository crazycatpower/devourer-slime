class_name SlimeIcon
extends Control
## The player slime's face, as a logo or an icon.

## Bottom of the body in the icon's 40-unit drawing space; breathing pivots here.
const FEET_Y: float = 37.0

var body_color: Color = Palette.GREEN_500:
	set(value):
		body_color = value
		queue_redraw()

## When set, the slime breathes and blinks. Off for small static icons.
var animated: bool = false:
	set(value):
		animated = value
		set_process(value)
		queue_redraw()

var _time: float = 0.0
var _motion: SlimeMotion = SlimeMotion.new()
var _mascot: PlayerState = PlayerState.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func _process(delta: float) -> void:
	_time += delta
	_mascot.grounded = true
	_motion.advance(delta, _mascot)
	queue_redraw()


func _draw() -> void:
	var s: float = minf(size.x, size.y) / 40.0
	var p: Painter = Painter.new(self, s)
	p.translate((size.x - 40.0 * s) / 2.0, (size.y - 40.0 * s) / 2.0)
	p.scale(s, s)

	if animated:
		p.translate(20.0, FEET_Y)
		p.rotate(_motion.lean)
		p.scale(_motion.body_scale.x, _motion.body_scale.y)
		p.translate(-20.0, -FEET_Y)
	p.push()
	p.translate(1.0, 1.0)
	p.scale(0.95, 0.95)
	SlimeFace.paint_body(p)
	p.pop()
	SlimeFace.paint(p, _motion, Vector2(_motion.look_offset, 0.0))