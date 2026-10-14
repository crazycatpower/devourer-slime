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
		Tile.SENSOR:
			# An open frame reads as a pass-through region, even over a block.
			p.stroke_round_rect(3.0, 3.0, 34.0, 34.0, 6.0, Palette.SKY_400, 2.0)
			for corner: Vector2 in [Vector2(8, 8), Vector2(32, 8), Vector2(8, 32), Vector2(32, 32)]:
				p.fill_circle(corner.x, corner.y, 2.0, Palette.SKY_100)
			p.stroke_circle(20.0, 20.0, 5.0, Palette.SKY_400, 1.5)
		Tile.RAIL_RIGHT, Tile.RAIL_LEFT, Tile.RAIL_UP, Tile.RAIL_DOWN:
			var outgoing: Vector2i = Tile.rail_direction(t)
			draw_track(p, Vector2(20, 20), outgoing, [outgoing, -outgoing])
		Tile.SAND:
			_block(p, x, y, Color("c9a25a"), Color("826639"), 3.0, corners)
			# A paler drift across the middle sets it apart from dirt's dark clod.
			p.fill_round_rect(9.0, 16.0, 22.0, 8.0, 4.0, Color("dbb873"))
		Tile.ICE:
			# Calmer than glass and with no glint: a pale crystal in the middle.
			_block(p, x, y, Color("6fbdd6"), Color("3a86ac"), 3.0, corners)
			p.polygon(PackedVector2Array([Vector2(20, 11), Vector2(29, 20), Vector2(20, 29), Vector2(11, 20)]), Color("a3dcec"))
		Tile.TNT:
			_block(p, x, y, Palette.RED_600, Color("7f1d1d"), 3.0, corners)
			p.fill_round_rect(5.0, 13.5, 30.0, 13.0, 4.0, Color("f3d9bd"))
			# Geometric TNT lettering works in the recorded tile shape.
			for start: float in [7.0, 25.0]:
				p.line(start, 17.0, start + 7.0, 17.0, Color("7f1d1d"), 2.0)
				p.line(start + 3.5, 17.0, start + 3.5, 24.0, Color("7f1d1d"), 2.0)
			p.polyline(PackedVector2Array([Vector2(17, 24), Vector2(17, 17), Vector2(22, 24), Vector2(22, 17)]), Color("7f1d1d"), 1.8)
			# The fuse stands straight up in the middle.
			p.fill_round_rect(18.5, 5.0, 3.0, 6.0, 1.5, Palette.AMBER_400)
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
			_block(p, x, y, Color("526777"), Color("354957"), 3.0, corners)
			# One soft inset, like dirt's clod: no rivets, bevels or specular lines.
			_inset(p, x, y, 11.0, 6.0, Color("435867"))
		Tile.SPIKE_UP, Tile.SPIKE_RIGHT, Tile.SPIKE_DOWN, Tile.SPIKE_LEFT:
			draw_spikes(p, t, x, y, _SPIKE_LENGTH)
		Tile.GLASS:
			_block(p, x, y, Color("378596"), Color("255e72"), 3.0, corners)
			# A single soft reflection distinguishes glass from ice's crystal.
			p.line(13.0, 27.0, 27.0, 13.0, Color("8ac6cd"), 3.0)
			p.fill_circle(13.0, 27.0, 1.5, Color("8ac6cd"))
			p.fill_circle(27.0, 13.0, 1.5, Color("8ac6cd"))
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
		Tile.GOAL:
			var pulse: float = sin(time_ms * 0.004)
			var glow: float = 0.2 + pulse * 0.08
			p.fill_round_rect(x, y, _T, _T, _RADIUS, Color(Palette.AMBER_400, glow))
			p.stroke_round_rect(x + 4.0, y + 4.0, _T - 8.0, _T - 8.0, 7.0, Palette.AMBER_400, 2.5)
			p.fill_round_rect(x + 10.0, y + 10.0, _T - 20.0, _T - 20.0, 5.0, Color("451a03"))
			p.fill_circle(x + _T * 0.5, y + _T * 0.5, 8.5 + pulse * 1.2, Color(Palette.AMBER_400, 0.4))
			p.fill_circle(x + _T * 0.5, y + _T * 0.5, 5.0 + pulse * 0.8, Palette.AMBER_100)

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
	# Three chunky coral teeth. Tips stay at the same lethal height, while
	# the outline has soft shoulders instead of a metallic razor highlight.
	p.fill_round_rect(1.0, _T - 5.0, _T - 2.0, 5.0, 2.0, Color("913e51"))
	var third: float = _T / 3.0
	for tooth: int in 3:
		var left: float = float(tooth) * third
		var mid: float = left + third * 0.5
		var top: float = _T - length
		p.polygon(PackedVector2Array([
			Vector2(left + 0.5, _T - 3.0), Vector2(left + 1.0, _T - 6.0),
			Vector2(mid - 0.9, top + 0.5), Vector2(mid + 0.9, top + 0.5),
			Vector2(left + third - 1.0, _T - 6.0), Vector2(left + third - 0.5, _T - 3.0)
		]), Color("913e51"))
		p.triangle(Vector2(left + 3.0, _T - 4.0), Vector2(mid, top + 3.0), Vector2(left + third - 3.0, _T - 4.0), Color("ee8491"))
	p.pop()

## Flying or carried block of [param type], drawn with distinct surface and worn patterns.
static func draw_projectile(p: Painter, type: int, x: float, y: float, w: float, h: float) -> void:
	# The inventory, projectile, editor and terrain all use the same artwork.
	p.push()
	p.translate(x, y)
	p.scale(w / _T, h / _T)
	draw(p, type, 0.0, 0.0, 0.0)
	p.pop()

## Chunky two-rail silhouette, shared by isolated icons and connected devices.
static func draw_track(p: Painter, center: Vector2, outgoing: Vector2i, connected: Array[Vector2i], powered: bool = false) -> void:
	var rail_color: Color = Color("7893a1")
	for branch: Vector2i in connected:
		var direction: Vector2 = Vector2(branch)
		var normal: Vector2 = Vector2(-direction.y, direction.x)
		var tie: Vector2 = center + direction * 11.0
		p.line(tie.x - normal.x * 13.0, tie.y - normal.y * 13.0, tie.x + normal.x * 13.0, tie.y + normal.y * 13.0, Color("354957"), 5.0)
		for side: float in [-1.0, 1.0]:
			var a: Vector2 = center + normal * side * 8.5
			var b: Vector2 = a + direction * 20.0
			p.line(a.x, a.y, b.x, b.y, rail_color, 3.5)
		if powered:
			var end: Vector2 = center + direction * 20.0
			p.line(center.x, center.y, end.x, end.y, Color(Palette.LIME_400, 0.65), 2.0)
	var forward: Vector2 = Vector2(outgoing)
	var normal: Vector2 = Vector2(-forward.y, forward.x)
	var tip: Vector2 = center + forward * 7.0
	var a: Vector2 = center - forward * 3.0 + normal * 5.5
	var b: Vector2 = center - forward * 3.0 - normal * 5.5
	p.triangle(a, tip, b, Palette.LIME_400 if powered else Color("b9cad0"))
	if not connected.has(-outgoing):
		var stop: Vector2 = center - forward * 13.0
		p.line(stop.x - normal.x * 9.5, stop.y - normal.y * 9.5, stop.x + normal.x * 9.5, stop.y + normal.y * 9.5, Color("526777"), 4.0)


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
