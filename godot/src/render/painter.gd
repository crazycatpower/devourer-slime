class_name Painter
extends RefCounted
## Immediate-mode drawing helper around a [CanvasItem]'s `draw_*` calls.
##
## It keeps a transform stack (push / pop / translate / rotate / scale) and
## offers the handful of shapes the game is drawn with, so the renderers read
## like the 2D-canvas code they were ported from. Only valid inside the
## `_draw()` of the canvas item it was created for.

enum Align { LEFT, CENTER, RIGHT }

const _CORNER_SEGMENTS: int = 6

var ci: CanvasItem
var xf: Transform2D = Transform2D.IDENTITY
## Screen pixels per drawing unit, used to rasterise text at its on-screen size.
var pixel_scale: float = 1.0

var _stack: Array[Transform2D] = []


func _init(canvas_item: CanvasItem, p_pixel_scale: float = 1.0) -> void:
	ci = canvas_item
	pixel_scale = maxf(p_pixel_scale, 0.01)
	ci.draw_set_transform_matrix(xf)


func push() -> void:
	_stack.append(xf)


func pop() -> void:
	if not _stack.is_empty():
		xf = _stack.pop_back()
		ci.draw_set_transform_matrix(xf)


func translate(dx: float, dy: float) -> void:
	xf = xf * Transform2D(0.0, Vector2(dx, dy))
	ci.draw_set_transform_matrix(xf)


func rotate(angle: float) -> void:
	xf = xf * Transform2D(angle, Vector2.ZERO)
	ci.draw_set_transform_matrix(xf)


func scale(sx: float, sy: float) -> void:
	xf = xf * Transform2D(0.0, Vector2(sx, sy), 0.0, Vector2.ZERO)
	ci.draw_set_transform_matrix(xf)


func fill_rect(x: float, y: float, w: float, h: float, color: Color) -> void:
	ci.draw_rect(Rect2(x, y, w, h), color)


## Outline centred on the rectangle's edges, like a canvas stroke.
func stroke_rect(x: float, y: float, w: float, h: float, color: Color, width: float) -> void:
	ci.draw_rect(Rect2(x, y, w, h), color, false, width)


func dashed_rect(
	x: float, y: float, w: float, h: float, color: Color, width: float, dash: float
) -> void:
	var a: Vector2 = Vector2(x, y)
	var b: Vector2 = Vector2(x + w, y)
	var c: Vector2 = Vector2(x + w, y + h)
	var d: Vector2 = Vector2(x, y + h)
	ci.draw_dashed_line(a, b, color, width, dash)
	ci.draw_dashed_line(b, c, color, width, dash)
	ci.draw_dashed_line(c, d, color, width, dash)
	ci.draw_dashed_line(d, a, color, width, dash)


func fill_round_rect(x: float, y: float, w: float, h: float, radius: float, color: Color) -> void:
	if w <= 0.0 or h <= 0.0:
		return
	ci.draw_colored_polygon(_round_rect_points(x, y, w, h, radius), color)


func stroke_round_rect(
	x: float, y: float, w: float, h: float, radius: float, color: Color, width: float
) -> void:
	if w <= 0.0 or h <= 0.0:
		return
	var points: PackedVector2Array = _round_rect_points(x, y, w, h, radius)
	points.append(points[0])
	ci.draw_polyline(points, color, width, true)


func line(x1: float, y1: float, x2: float, y2: float, color: Color, width: float) -> void:
	ci.draw_line(Vector2(x1, y1), Vector2(x2, y2), color, width)


func polyline(points: PackedVector2Array, color: Color, width: float) -> void:
	if points.size() >= 2:
		ci.draw_polyline(points, color, width)


func dashed_polyline(points: PackedVector2Array, color: Color, width: float, dash: float) -> void:
	for i: int in range(1, points.size()):
		ci.draw_dashed_line(points[i - 1], points[i], color, width, dash)


func polygon(points: PackedVector2Array, color: Color) -> void:
	if points.size() >= 3:
		ci.draw_colored_polygon(points, color)


func triangle(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([a, b, c]), color)


func fill_circle(x: float, y: float, radius: float, color: Color) -> void:
	ci.draw_circle(Vector2(x, y), radius, color)


func stroke_circle(x: float, y: float, radius: float, color: Color, width: float) -> void:
	ci.draw_arc(Vector2(x, y), radius, 0.0, TAU, 32, color, width, true)


## Arc from [param from] to [param to] radians, clockwise on screen.
func arc(
	x: float, y: float, radius: float, from: float, to: float, color: Color, width: float
) -> void:
	ci.draw_arc(Vector2(x, y), radius, from, to, 16, color, width, true)


## Horizontal bar whose colour runs from [param left] to [param right].
func gradient_rect(x: float, y: float, w: float, h: float, left: Color, right: Color) -> void:
	if w <= 0.0 or h <= 0.0:
		return
	ci.draw_polygon(
		PackedVector2Array([
			Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h),
		]),
		PackedColorArray([left, right, right, left])
	)


## Vertical bar whose colour runs from [param top] to [param bottom].
func vertical_gradient_rect(x: float, y: float, w: float, h: float, top: Color, bottom: Color) -> void:
	if w <= 0.0 or h <= 0.0:
		return
	ci.draw_polygon(
		PackedVector2Array([
			Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h),
		]),
		PackedColorArray([top, top, bottom, bottom])
	)


## Draws [param content] with its baseline at ([param x], [param y]). With
## [param middle] set, the text is vertically centred on y instead.
func text(
	content: String, x: float, y: float, size: float, color: Color,
	bold: bool = false, align: Align = Align.CENTER, middle: bool = false
) -> void:
	if content.is_empty():
		return
	var font: Font = UiFonts.bold() if bold else UiFonts.regular()
	# Rasterise at the size the text has on screen, then scale down to the
	# requested size, so text stays sharp however the drawing is scaled.
	var on_screen: float = size * pixel_scale * xf.get_scale().y
	var font_px: int = clampi(roundi(on_screen), 8, 256)
	var k: float = size / float(font_px)
	var width: float = font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_px).x
	var offset_x: float = 0.0
	if align == Align.CENTER:
		offset_x = -width / 2.0
	elif align == Align.RIGHT:
		offset_x = -width
	var offset_y: float = 0.0
	if middle:
		offset_y = (font.get_ascent(font_px) - font.get_descent(font_px)) / 2.0
	ci.draw_set_transform_matrix(xf * Transform2D(0.0, Vector2(k, k), 0.0, Vector2(x, y)))
	ci.draw_string(
		font, Vector2(offset_x, offset_y), content, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_px, color
	)
	ci.draw_set_transform_matrix(xf)


## Width [param content] takes up when drawn with [method text].
func text_width(content: String, size: float, bold: bool = false) -> float:
	var font: Font = UiFonts.bold() if bold else UiFonts.regular()
	var on_screen: float = size * pixel_scale * xf.get_scale().y
	var font_px: int = clampi(roundi(on_screen), 8, 256)
	var width: float = font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_px).x
	return width * size / float(font_px)


## Warning triangle with an exclamation mark, centred on (x, y).
func icon_warning(x: float, y: float, size: float, color: Color) -> void:
	var half: float = size / 2.0
	triangle(
		Vector2(x, y - half), Vector2(x + half * 1.1, y + half), Vector2(x - half * 1.1, y + half),
		color
	)
	fill_rect(x - size * 0.06, y - half * 0.35, size * 0.12, size * 0.42, Palette.SLATE_950)
	fill_rect(x - size * 0.06, y + half * 0.6, size * 0.12, size * 0.12, Palette.SLATE_950)


## Small skull, centred on (x, y).
func icon_skull(x: float, y: float, size: float, color: Color) -> void:
	var r: float = size * 0.42
	fill_circle(x, y - size * 0.08, r, color)
	fill_rect(x - r * 0.55, y + size * 0.12, r * 1.1, size * 0.3, color)
	fill_circle(x - r * 0.42, y - size * 0.08, r * 0.27, Palette.BLACK)
	fill_circle(x + r * 0.42, y - size * 0.08, r * 0.27, Palette.BLACK)
	fill_rect(x - size * 0.03, y + size * 0.2, size * 0.06, size * 0.22, Palette.BLACK)


## Heart, centred on (x, y).
func icon_heart(x: float, y: float, size: float, color: Color) -> void:
	var r: float = size * 0.27
	fill_circle(x - r * 0.95, y - r * 0.5, r, color)
	fill_circle(x + r * 0.95, y - r * 0.5, r, color)
	triangle(
		Vector2(x - r * 1.9, y - r * 0.15), Vector2(x + r * 1.9, y - r * 0.15),
		Vector2(x, y + size * 0.48), color
	)


## Diamond gem, centred on (x, y).
func icon_gem(x: float, y: float, size: float, color: Color) -> void:
	var half: float = size / 2.0
	polygon(
		PackedVector2Array([
			Vector2(x, y - half), Vector2(x + half * 0.85, y - half * 0.15),
			Vector2(x, y + half), Vector2(x - half * 0.85, y - half * 0.15),
		]),
		color
	)


func _round_rect_points(x: float, y: float, w: float, h: float, radius: float) -> PackedVector2Array:
	var r: float = minf(radius, minf(w, h) / 2.0)
	var points: PackedVector2Array = PackedVector2Array()
	var centers: Array[Vector2] = [
		Vector2(x + w - r, y + r), Vector2(x + w - r, y + h - r),
		Vector2(x + r, y + h - r), Vector2(x + r, y + r),
	]
	for corner: int in 4:
		var start: float = -PI / 2.0 + float(corner) * PI / 2.0
		for i: int in _CORNER_SEGMENTS + 1:
			var angle: float = start + (PI / 2.0) * float(i) / float(_CORNER_SEGMENTS)
			points.append(centers[corner] + Vector2(cos(angle), sin(angle)) * r)
	return points
