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
var _screen_base: Transform2D
# While recording, filled shapes are collected as triangles instead of drawn.
var _recording: bool = false
var _record_base: Transform2D
var _record_points: PackedVector2Array
var _record_colors: PackedColorArray
var _record_indices: PackedInt32Array
var _has_screen_base: bool = false

## Unit directions along one corner's quarter turn, and triangle-fan indices by
## point count. Shared, so drawing a rounded rectangle does no trigonometry
## and no triangulation.
static var _arc: PackedVector2Array = PackedVector2Array()
static var _fans: Dictionary[int, PackedInt32Array] = {}


func _init(canvas_item: CanvasItem, p_pixel_scale: float = 1.0) -> void:
	ci = canvas_item
	pixel_scale = maxf(p_pixel_scale, 0.01)
	ci.draw_set_transform_matrix(xf)


## Starts collecting the shapes drawn from now on instead of drawing them, with
## the current transform as their origin. Lines, arcs and filled shapes are
## supported, including rounded outlines; text and dashed rectangles are not.
func begin_recording() -> void:
	_recording = true
	_record_base = xf.affine_inverse()
	_record_points = PackedVector2Array()
	_record_colors = PackedColorArray()
	_record_indices = PackedInt32Array()


## Ends [method begin_recording]. The result is drawn with [method draw_shape],
## as often as needed, at the cost of a single draw call.
func end_recording() -> Array:
	_recording = false
	return [_record_indices, _record_points, _record_colors]


func is_recording() -> bool:
	return _recording


func draw_shape(shape: Array) -> void:
	var indices: PackedInt32Array = shape[0]
	if indices.is_empty():
		return
	var points: PackedVector2Array = shape[1]
	var colors: PackedColorArray = shape[2]
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), indices, points, colors)


## Drawing units to screen pixels, for the current transform.
func to_screen() -> Transform2D:
	if not _has_screen_base:
		_screen_base = ci.get_screen_transform()
		_has_screen_base = true
	return _screen_base * xf


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


## A flat-footed jelly lean: the top shifts while the bottom stays horizontal.
func shear_x(amount: float) -> void:
	xf = xf * Transform2D(Vector2.RIGHT, Vector2(amount, 1.0), Vector2.ZERO)
	ci.draw_set_transform_matrix(xf)


func fill_rect(x: float, y: float, w: float, h: float, color: Color) -> void:
	if _recording:
		_fill_convex(PackedVector2Array([
			Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h),
		]), color)
		return
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


## [param corners] picks which corners are rounded: bit 0 top-right, 1
## bottom-right, 2 bottom-left, 3 top-left. The others stay square.
func fill_round_rect(
	x: float, y: float, w: float, h: float, radius: float, color: Color, corners: int = 15
) -> void:
	if w <= 0.0 or h <= 0.0:
		return
	if corners == 0:
		fill_rect(x, y, w, h, color)
		return
	_fill_convex(_round_rect_points(x, y, w, h, radius, corners), color)


func stroke_round_rect(
	x: float, y: float, w: float, h: float, radius: float, color: Color, width: float
) -> void:
	if w <= 0.0 or h <= 0.0:
		return
	var points: PackedVector2Array = _round_rect_points(x, y, w, h, radius)
	points.append(points[0])
	if _recording:
		polyline(points, color, width)
		return
	ci.draw_polyline(points, color, width, true)


func line(x1: float, y1: float, x2: float, y2: float, color: Color, width: float) -> void:
	if _recording:
		var from: Vector2 = Vector2(x1, y1)
		var to: Vector2 = Vector2(x2, y2)
		var side: Vector2 = (to - from).orthogonal().normalized() * width * 0.5
		_fill_convex(PackedVector2Array([from + side, to + side, to - side, from - side]), color)
		return
	ci.draw_line(Vector2(x1, y1), Vector2(x2, y2), color, width)


func polyline(points: PackedVector2Array, color: Color, width: float) -> void:
	if _recording:
		for i: int in range(1, points.size()):
			line(points[i - 1].x, points[i - 1].y, points[i].x, points[i].y, color, width)
		return
	if points.size() >= 2:
		ci.draw_polyline(points, color, width)


func dashed_polyline(points: PackedVector2Array, color: Color, width: float, dash: float) -> void:
	for i: int in range(1, points.size()):
		ci.draw_dashed_line(points[i - 1], points[i], color, width, dash)


func polygon(points: PackedVector2Array, color: Color) -> void:
	# While recording, the outline has to be convex: it is filled as a fan.
	if _recording:
		_fill_convex(points, color)
		return
	if points.size() >= 3:
		ci.draw_colored_polygon(points, color)


func triangle(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	if _recording:
		_fill_convex(PackedVector2Array([a, b, c]), color)
		return
	ci.draw_colored_polygon(PackedVector2Array([a, b, c]), color)


func fill_circle(x: float, y: float, radius: float, color: Color) -> void:
	if _recording:
		fill_round_rect(x - radius, y - radius, radius * 2.0, radius * 2.0, radius, color)
		return
	ci.draw_circle(Vector2(x, y), radius, color)


func stroke_circle(x: float, y: float, radius: float, color: Color, width: float) -> void:
	if _recording:
		arc(x, y, radius, 0.0, TAU, color, width)
		return
	ci.draw_arc(Vector2(x, y), radius, 0.0, TAU, 32, color, width, true)


## Arc from [param from] to [param to] radians, clockwise on screen.
func arc(
	x: float, y: float, radius: float, from: float, to: float, color: Color, width: float
) -> void:
	if _recording:
		var points: PackedVector2Array = PackedVector2Array()
		for i: int in 17:
			var angle: float = lerpf(from, to, float(i) / 16.0)
			points.append(Vector2(x + cos(angle) * radius, y + sin(angle) * radius))
		polyline(points, color, width)
		return
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


func _round_rect_points(
	x: float, y: float, w: float, h: float, radius: float, corners: int = 15
) -> PackedVector2Array:
	var r: float = minf(radius, minf(w, h) / 2.0)
	var points: PackedVector2Array = PackedVector2Array()
	var directions: PackedVector2Array = _unit_arc()
	var centers: Array[Vector2] = [
		Vector2(x + w - r, y + r), Vector2(x + w - r, y + h - r),
		Vector2(x + r, y + h - r), Vector2(x + r, y + r),
	]
	var square: Array[Vector2] = [
		Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h), Vector2(x, y),
	]
	for corner: int in 4:
		if corners & (1 << corner) == 0:
			points.append(square[corner])
			continue
		for i: int in _CORNER_SEGMENTS + 1:
			var point: Vector2 = centers[corner] + directions[corner * (_CORNER_SEGMENTS + 1) + i] * r
			# A fully rounded side ends where the next corner starts; a repeated
			# point would make the polygon invalid.
			if points.is_empty() or not points[points.size() - 1].is_equal_approx(point):
				points.append(point)
	if points.size() > 1 and points[0].is_equal_approx(points[points.size() - 1]):
		points.remove_at(points.size() - 1)
	return points


## Fills a convex outline: a fan from its first point covers it, so nothing has
## to be triangulated.
func _fill_convex(points: PackedVector2Array, color: Color) -> void:
	var count: int = points.size()
	if count < 3:
		return
	if not _recording:
		RenderingServer.canvas_item_add_triangle_array(
			ci.get_canvas_item(), _fan(count), points, PackedColorArray([color])
		)
		return
	var local: Transform2D = _record_base * xf
	var first: int = _record_points.size()
	for point: Vector2 in points:
		_record_points.append(local * point)
		_record_colors.append(color)
	for i: int in range(1, count - 1):
		_record_indices.append(first)
		_record_indices.append(first + i)
		_record_indices.append(first + i + 1)


## Directions for the four corners in drawing order, a quarter turn each.
static func _unit_arc() -> PackedVector2Array:
	if _arc.is_empty():
		for corner: int in 4:
			var start: float = -PI / 2.0 + float(corner) * PI / 2.0
			for i: int in _CORNER_SEGMENTS + 1:
				var angle: float = start + (PI / 2.0) * float(i) / float(_CORNER_SEGMENTS)
				_arc.append(Vector2(cos(angle), sin(angle)))
	return _arc


static func _fan(count: int) -> PackedInt32Array:
	if not _fans.has(count):
		var indices: PackedInt32Array = PackedInt32Array()
		for i: int in range(1, count - 1):
			indices.append(0)
			indices.append(i)
			indices.append(i + 1)
		_fans[count] = indices
	return _fans[count]
