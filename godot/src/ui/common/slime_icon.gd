class_name SlimeIcon
extends Control
## The player slime's face, as a logo or an icon.

const BREATH_PERIOD_SEC: float = 2.4
## How much the body squashes and stretches while breathing.
const BREATH_AMOUNT: float = 0.045
const BLINK_PERIOD_SEC: float = 4.0
const BLINK_LENGTH_SEC: float = 0.15
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


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var s: float = minf(size.x, size.y) / 40.0
	var p: Painter = Painter.new(self, s)
	p.translate((size.x - 40.0 * s) / 2.0, (size.y - 40.0 * s) / 2.0)
	p.scale(s, s)

	var blinking: bool = false
	if animated:
		var breath: float = sin(_time / BREATH_PERIOD_SEC * TAU) * BREATH_AMOUNT
		p.translate(20.0, FEET_Y)
		p.scale(1.0 + breath, 1.0 - breath)
		p.translate(-20.0, -FEET_Y)
		blinking = fmod(_time, BLINK_PERIOD_SEC) > BLINK_PERIOD_SEC - BLINK_LENGTH_SEC

	p.fill_round_rect(3.0, 5.0, 34.0, 32.0, 11.0, body_color)
	p.stroke_round_rect(3.0, 5.0, 34.0, 32.0, 11.0, body_color.darkened(0.3), 2.0)
	if blinking:
		p.fill_rect(12.0, 17.0, 6.0, 2.0, Palette.SLATE_900)
		p.fill_rect(22.0, 17.0, 6.0, 2.0, Palette.SLATE_900)
	else:
		p.fill_rect(12.0, 13.0, 6.0, 10.0, Palette.WHITE)
		p.fill_rect(22.0, 13.0, 6.0, 10.0, Palette.WHITE)
		p.fill_rect(15.0, 16.0, 2.0, 4.0, Palette.SLATE_900)
		p.fill_rect(25.0, 16.0, 2.0, 4.0, Palette.SLATE_900)
	p.fill_round_rect(14.0, 27.0, 12.0, 3.0, 1.5, Color(0.0, 0.0, 0.0, 0.35))
