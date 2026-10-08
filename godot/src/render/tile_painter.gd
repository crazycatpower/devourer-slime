class_name TilePainter
extends RefCounted
## Draws tiles. Every tile is vector art drawn inside its 40x40 cell; the
## shapes and colours are shared by the terrain and bosses.

const _T: float = Tile.SIZE
const _SPIKE_LENGTH: float = 16.0
## Corner radius of a block's outline; its face is rounded a little less.
const _RADIUS: float = 9.0
const _FACE_RADIUS: float = 5.0
const _SLIME_LIGHT: Color = Color(Palette.GREEN_600, 0.25)
const _SLIME_HEAVY: Color = Color(Palette.GREEN_500, 0.45)
## Bound on the recorded shapes kept; zooming creates one set per zoom level.
const _MAX_SHAPES: int = 800

## Recorded unmoving part of each tile, by tile, free corners and zoom.
static var _shapes: Dictionary[int, Array] = {}


## Draws tile [param t] with its top-left corner at ([param x], [param y]).
## [param time_ms] animates the pulses. [param corners] says which outer
## corners are free to be rounded (see [method Painter.fill_round_rect]); a
## corner that touches a neighbouring tile stays square so the two join flush.
##
## The unmoving part of a tile is recorded once and then replayed with a single
## draw call, which is what keeps a screen full of tiles cheap.
static func draw(p: Painter, t: int, x: float, y: float, time_ms: float, corners: int = 15) -> void:
	draw_static(p, t, x, y, corners)
	draw_live(p, t, x, y, time_ms)


## True for tiles that have a part drawn by [method draw_live].
static func is_animated(t: int) -> bool:
	return t == Tile.BOUNCY or t == Tile.VOID or t == Tile.GOAL


## The part of tile [param t] that never changes. A drawing of it can be kept
## on screen for as long as the tile and the zoom stay the same.
static func draw_static(p: Painter, t: int, x: float, y: float, corners: int = 15) -> void:
	if t == Tile.GOAL:
		return
	var to_screen: Transform2D = p.to_screen()
	if absf(to_screen.x.y) > 0.0001 or absf(to_screen.y.x) > 0.0001:
		# A turning tile is drawn directly: its shape would never be reused.
		p.push()
		p.translate(x, y)
		_draw_static(p, t, corners)
		p.pop()
		return
	var key: int = t | (corners << 8) | (roundi(to_screen.x.x * 2000.0) << 12)
	if not _shapes.has(key):
		if _shapes.size() >= _MAX_SHAPES:
			_shapes.clear()
		p.begin_recording()
		_draw_static(p, t, corners)
		_shapes[key] = p.end_recording()
	var cell: Rect2 = _cell(p, x, y)
	p.push()
	p.translate(cell.position.x, cell.position.y)
	p.scale(cell.size.x / _T, cell.size.y / _T)
	p.draw_shape(_shapes[key])
	p.pop()


## The part of tile [param t] that never changes, drawn at the origin.
static func _draw_static(p: Painter, t: int, corners: int) -> void:
	var x: float = 0.0
	var y: float = 0.0
	match t:
		Tile.DIRT:
			_block(p, x, y, Palette.AMBER_600, Palette.AMBER_700, 3.0, corners)
			# A darker clod in the middle; no lines or dots.
			_inset(p, x, y, 11.0, 6.0, Color("c56a07"))
		Tile.DIRT_EATEN_1:
			_block(p, x, y, Palette.AMBER_700, Palette.AMBER_800, 3.0, corners)
			p.fill_round_rect(x + 4.0, y + 4.0, _T - 8.0, _T - 8.0, _FACE_RADIUS, _SLIME_LIGHT)
			p.polyline(_points(x, y, [8, 13, 13, 22, 20, 26, 27, 22, 32, 13]), Palette.GREEN_500, 2.0)
		Tile.DIRT_EATEN_2:
			_block(p, x, y, Palette.AMBER_900, Palette.GREEN_500, 2.5, corners)
			p.fill_round_rect(x + 6.0, y + 6.0, _T - 12.0, _T - 12.0, _FACE_RADIUS, _SLIME_HEAVY)
			p.polyline(_points(x, y, [9, 9, 16, 19, 10, 30]), Palette.LIME_400, 1.8)
			p.polyline(_points(x, y, [31, 9, 24, 19, 30, 30]), Palette.LIME_400, 1.8)
		Tile.BOUNCY:
			_block(p, x, y, Palette.PINK_500, Palette.PINK_600, 3.0, corners)
		Tile.BOUNCY_EATEN_1:
			_block(p, x, y, Palette.PINK_700, Palette.PINK_800, 3.0, corners)
			p.fill_round_rect(x + 4.0, y + 4.0, _T - 8.0, _T - 8.0, _FACE_RADIUS, _SLIME_LIGHT)
			p.arc(x + _T / 2.0, y + _T / 2.0, 8.0, -PI * 0.25, PI * 1.25, Palette.PINK_200, 2.0)
			p.line(x + 8.0, y + 9.0, x + 15.0, y + 15.0, Palette.GREEN_500, 1.5)
			p.line(x + 32.0, y + 9.0, x + 25.0, y + 15.0, Palette.GREEN_500, 1.5)
		Tile.BOUNCY_EATEN_2:
			_block(p, x, y, Palette.PINK_900, Palette.GREEN_500, 2.5, corners)
			p.fill_round_rect(x + 6.0, y + 6.0, _T - 12.0, _T - 12.0, _FACE_RADIUS, _SLIME_HEAVY)
			p.arc(x + _T / 2.0, y + _T / 2.0, 8.0, PI * 0.2, PI * 0.8, Palette.LIME_400, 1.5)
			p.polyline(_points(x, y, [8, 32, 16, 19, 8, 8, 20, 13, 32, 8, 24, 19, 32, 32]), Palette.LIME_400, 2.0)
		Tile.STEEL:
			_block(p, x, y, Color("435c6c"), Color("243646"), 3.0, corners)
			_inset(p, x, y, 10.0, 4.0, Color("304452"))
			for rivet: Vector2 in [Vector2(7, 7), Vector2(33, 7), Vector2(7, 33), Vector2(33, 33)]:
				p.fill_circle(x + rivet.x, y + rivet.y, 1.5, Color("243646"))
		Tile.SPIKE_UP, Tile.SPIKE_RIGHT, Tile.SPIKE_DOWN, Tile.SPIKE_LEFT:
			draw_spikes(p, t, x, y, _SPIKE_LENGTH)
		Tile.GLASS:
			# Solid tones that read as a clear pane against the dark walls.
			_block(p, x, y, Color("0f3a47"), Color("1a8298"), 2.0, corners)
			p.line(x + 11.0, y + 11.0, x + 29.0, y + 29.0, Color("1a8298"), 1.5)
			p.line(x + 29.0, y + 11.0, x + 11.0, y + 29.0, Color("1a8298"), 1.5)
		Tile.VOID:
			_block(p, x, y, Palette.VOID_BACKGROUND, Palette.PURPLE_600, 2.0, corners)


## The animated part of tile [param t]. Only [method is_animated] tiles have one.
static func draw_live(p: Painter, t: int, x: float, y: float, time_ms: float) -> void:
	match t:
		Tile.BOUNCY:
			var bounce_pulse: float = sin(time_ms * 0.005 + (x + y) * 0.02) * 0.75
			p.stroke_circle(x + _T / 2.0, y + _T / 2.0, 8.0 + bounce_pulse, Palette.PINK_200, 2.5)
			p.fill_circle(x + _T / 2.0, y + _T / 2.0, 2.5, Color(Palette.PINK_200, 0.45))
		Tile.VOID:
			# The bright core is exactly the lethal part of the tile.
			var pulse: float = 0.8 + sin(time_ms / 150.0) * 0.2
			_inset(p, x, y, 12.0, 5.0, Color(Palette.PURPLE_400, pulse))
			var void_rot: float = time_ms * 0.002 + (x * 0.03 + y * 0.02)
			for i: int in 4:
				var a: float = void_rot + float(i) * (PI * 0.5)
				p.fill_circle(x + _T * 0.5 + cos(a) * 12.0, y + _T * 0.5 + sin(a) * 12.0, 1.4, Palette.PURPLE_500)
		Tile.GOAL:
			var glow: float = 0.16 + sin(time_ms * 0.004) * 0.07
			p.fill_round_rect(x, y, _T, _T, _RADIUS, Color(Palette.AMBER_400, glow))
			p.stroke_round_rect(x + 5.0, y + 5.0, _T - 10.0, _T - 10.0, 7.0, Palette.AMBER_400, 3.5)
			p.fill_round_rect(x + 12.0, y + 12.0, _T - 24.0, _T - 24.0, 5.0, Palette.AMBER_100)
			var goal_rot: float = time_ms * 0.0025
			for i: int in 4:
				var a: float = goal_rot + float(i) * (PI * 0.5)
				p.fill_circle(x + _T * 0.5 + cos(a) * 10.0, y + _T * 0.5 + sin(a) * 10.0, 1.3, Palette.YELLOW_200)

## Three flat red teeth along one side of a cell. [param spike_type] is one of the
## four spike tiles and decides which way they point; teeth of
## [param length] grow from the opposite edge.
static func draw_spikes(p: Painter, spike_type: int, x: float, y: float, length: float) -> void:
	p.push()
	p.translate(x + _T * 0.5, y + _T * 0.5)
	var angle: float = 0.0
	match spike_type:
		Tile.SPIKE_RIGHT: angle = PI * 0.5
		Tile.SPIKE_DOWN: angle = PI
		Tile.SPIKE_LEFT: angle = -PI * 0.5
	p.rotate(angle)
	p.translate(-_T * 0.5, -_T * 0.5)
	var third: float = _T / 3.0
	for s: int in 3:
		var a: float = float(s) * third
		var tip: Vector2 = Vector2(a + third * 0.5, _T - length)
		p.triangle(Vector2(a, _T), tip, Vector2(a + third, _T), Color("e85b6b"))
	p.fill_rect(0.0, _T - 3.0, _T, 3.0, Color("712c42"))
	p.pop()

## Flying or carried block of [param type], drawn with distinct surface and worn patterns.
static func draw_projectile(p: Painter, type: int, x: float, y: float, w: float, h: float) -> void:
	var radius: float = minf(w, h) * 0.24
	if type == Tile.GLASS:
		p.fill_round_rect(x, y, w, h, radius, Palette.CYAN_500)
		p.fill_round_rect(x + 3.0, y + 3.0, w - 6.0, h - 6.0, maxf(radius - 3.0, 1.0), Palette.CYAN_200)
	elif type == Tile.BOUNCY or type == Tile.BOUNCY_EATEN_1 or type == Tile.BOUNCY_EATEN_2:
		var fill: Color = Palette.PINK_500
		var stroke: Color = Palette.PINK_600
		if type == Tile.BOUNCY_EATEN_1:
			fill = Palette.PINK_700
			stroke = Palette.PINK_800
		elif type == Tile.BOUNCY_EATEN_2:
			fill = Palette.PINK_900
			stroke = Palette.GREEN_500
		p.fill_round_rect(x, y, w, h, radius, stroke)
		p.fill_round_rect(x + 3.0, y + 3.0, w - 6.0, h - 6.0, maxf(radius - 3.0, 1.0), fill)
		p.stroke_circle(x + w * 0.5, y + h * 0.5, minf(w, h) * 0.25, Palette.PINK_200, 1.8)
		if type == Tile.BOUNCY_EATEN_1 or type == Tile.BOUNCY_EATEN_2:
			p.fill_round_rect(x + 3.0, y + 3.0, w - 6.0, h - 6.0, maxf(radius - 3.0, 1.0), _SLIME_LIGHT)
	else:
		var fill: Color = Palette.AMBER_600
		var stroke: Color = Palette.AMBER_700
		if type == Tile.DIRT_EATEN_1:
			fill = Palette.AMBER_700
			stroke = Palette.AMBER_800
		elif type == Tile.DIRT_EATEN_2:
			fill = Palette.AMBER_900
			stroke = Palette.GREEN_500
		p.fill_round_rect(x, y, w, h, radius, stroke)
		p.fill_round_rect(x + 3.0, y + 3.0, w - 6.0, h - 6.0, maxf(radius - 3.0, 1.0), fill)
		if type == Tile.DIRT_EATEN_1 or type == Tile.DIRT_EATEN_2:
			p.fill_round_rect(x + 3.0, y + 3.0, w - 6.0, h - 6.0, maxf(radius - 3.0, 1.0), _SLIME_LIGHT)


static func _block(
	p: Painter, x: float, y: float, fill: Color, border: Color, width: float, corners: int = 15
) -> void:
	# A rounded flat face inside a thick, even, rounded border: chunky and soft,
	# with no light direction, so every side matches.
	var cell: Rect2 = _cell(p, x, y)
	p.fill_round_rect(cell.position.x, cell.position.y, cell.size.x, cell.size.y, _RADIUS, border, corners)
	_inset(p, x, y, width + 1.0, _FACE_RADIUS, fill)


## Rounded patch [param margin] units inside the cell on every side.
static func _inset(p: Painter, x: float, y: float, margin: float, radius: float, color: Color) -> void:
	var cell: Rect2 = _cell(p, x, y).grow(-_px(p, margin))
	p.fill_round_rect(cell.position.x, cell.position.y, cell.size.x, cell.size.y, radius, color)


## The cell at ([param x], [param y]) with its edges on whole screen pixels
## from the drawing origin. Margins measured in whole pixels from it are then
## equally thick on every side. Only the zoom matters, not the camera position,
## so a drawing that is kept stays aligned as long as the world itself moves
## by whole pixels. A turned drawing is left as it is.
static func _cell(p: Painter, x: float, y: float) -> Rect2:
	var to_screen: Transform2D = p.to_screen()
	# A recorded shape is aligned as a whole when it is drawn.
	if p.is_recording() or absf(to_screen.x.y) > 0.0001 or absf(to_screen.y.x) > 0.0001:
		return Rect2(x, y, _T, _T)
	var zoom: Vector2 = Vector2(to_screen.x.x, to_screen.y.y)
	if zoom.x <= 0.0 or zoom.y <= 0.0:
		return Rect2(x, y, _T, _T)
	var top_left: Vector2 = (Vector2(x, y) * zoom).round() / zoom
	var bottom_right: Vector2 = (Vector2(x + _T, y + _T) * zoom).round() / zoom
	return Rect2(top_left, bottom_right - top_left)


## [param units] rounded to a whole number of screen pixels, in drawing units.
static func _px(p: Painter, units: float) -> float:
	var pixels_per_unit: float = p.to_screen().get_scale().x
	if pixels_per_unit <= 0.0:
		return units
	return maxf(1.0, roundf(units * pixels_per_unit)) / pixels_per_unit


## Point list from flat (x, y, x, y, ...) offsets inside the cell.
static func _points(x: float, y: float, offsets: Array[int]) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(0, offsets.size(), 2):
		points.append(Vector2(x + float(offsets[i]), y + float(offsets[i + 1])))
	return points
