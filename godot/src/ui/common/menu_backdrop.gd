class_name MenuBackdrop
extends Control
## The dark dotted background behind every screen, with two soft glows in the
## current world's colour.

const DOT_SPACING: float = 44.0
const DOT_COLOR: Color = Color(Palette.SLATE_800, 0.55)

## How far the glows wander from their resting place, as a share of the size.
const DRIFT_REACH: float = 0.06
## Seconds for one slow lap of a glow.
const DRIFT_PERIOD_SEC: float = 26.0
const COLOR_EASING: float = 4.0

## Colour the glows move toward; they blend rather than switch.
var glow_color: Color = Palette.AMBER_600:
	set(value):
		glow_color = value
		if not is_inside_tree():
			_shown_color = value
		set_process(true)
		queue_redraw()

## When set, the glows drift slowly. Used by the menu; behind the game the
## backdrop stays still.
var drifting: bool = false:
	set(value):
		drifting = value
		set_process(true)

var _shown_color: Color = Palette.AMBER_600
var _time: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	resized.connect(queue_redraw)
	_shown_color = glow_color


func _process(delta: float) -> void:
	var settled: bool = _shown_color.is_equal_approx(glow_color)
	if not settled:
		_shown_color = _shown_color.lerp(glow_color, minf(1.0, delta * COLOR_EASING))
	if drifting:
		_time += delta
	elif settled:
		# Nothing left to animate: stop redrawing every frame.
		_shown_color = glow_color
		set_process(false)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.APP_BACKGROUND)
	var phase: float = _time / DRIFT_PERIOD_SEC * TAU
	var reach: Vector2 = size * DRIFT_REACH
	_glow(Vector2(size.x * 0.25, size.y * 0.05) + Vector2(cos(phase), sin(phase)) * reach)
	_glow(Vector2(size.x * 0.75, size.y * 0.9) + Vector2(cos(phase * 0.7 + 2.0), sin(phase * 0.7 + 2.0)) * reach)
	var y: float = DOT_SPACING / 2.0
	while y < size.y:
		var x: float = DOT_SPACING / 2.0
		while x < size.x:
			draw_rect(Rect2(x - 1.5, y - 1.5, 3.0, 3.0), DOT_COLOR)
			x += DOT_SPACING
		y += DOT_SPACING


## A blurred blob, approximated by stacked translucent discs.
func _glow(center: Vector2) -> void:
	for i: int in 14:
		var radius: float = 420.0 - float(i) * 26.0
		draw_circle(center, radius, Color(_shown_color, 0.008 + float(i) * 0.0012))
