class_name TilePainter
extends RefCounted
## Draws tiles. Every tile is vector art drawn inside its 40x40 cell; the
## shapes and colours are those of the web version.

const _T: float = Tile.SIZE
const _SPIKE_LENGTH: float = 16.0
const _SLIME_LIGHT: Color = Color(Palette.GREEN_600, 0.25)
const _SLIME_HEAVY: Color = Color(Palette.GREEN_500, 0.45)


## Draws tile [param t] with its top-left corner at ([param x], [param y]).
## [param time_ms] animates the void's pulse.
static func draw(p: Painter, t: int, x: float, y: float, time_ms: float) -> void:
	match t:
		Tile.DIRT:
			_block(p, x, y, Palette.AMBER_600, Palette.AMBER_700, 3.0)
		Tile.DIRT_EATEN_1:
			_block(p, x, y, Palette.AMBER_700, Palette.AMBER_800, 3.0)
			p.fill_rect(x + 4.0, y + 4.0, _T - 8.0, _T - 8.0, _SLIME_LIGHT)
			p.polyline(_points(x, y, [5, 10, 15, 25, 35, 30]), Palette.GREEN_500, 2.0)
		Tile.DIRT_EATEN_2:
			_block(p, x, y, Palette.AMBER_900, Palette.GREEN_500, 2.5)
			p.fill_rect(x + 6.0, y + 6.0, _T - 12.0, _T - 12.0, _SLIME_HEAVY)
			p.polyline(_points(x, y, [5, 5, 20, 18, 8, 32]), Palette.LIME_400, 1.8)
			p.polyline(_points(x, y, [35, 5, 22, 22, 30, 35]), Palette.LIME_400, 1.8)
		Tile.BOUNCY:
			_block(p, x, y, Palette.PINK_500, Palette.PINK_600, 3.0)
			p.stroke_circle(x + _T / 2.0, y + _T / 2.0, 8.0, Palette.PINK_200, 2.5)
		Tile.BOUNCY_EATEN_1:
			_block(p, x, y, Palette.PINK_700, Palette.PINK_800, 3.0)
			p.fill_rect(x + 4.0, y + 4.0, _T - 8.0, _T - 8.0, _SLIME_LIGHT)
			p.arc(x + _T / 2.0, y + _T / 2.0, 8.0, 0.2, PI * 1.5, Palette.PINK_200, 2.0)
			p.line(x + 5.0, y + 8.0, x + 20.0, y + 15.0, Palette.GREEN_500, 1.5)
		Tile.BOUNCY_EATEN_2:
			_block(p, x, y, Palette.PINK_900, Palette.GREEN_500, 2.5)
			p.fill_rect(x + 6.0, y + 6.0, _T - 12.0, _T - 12.0, _SLIME_HEAVY)
			p.arc(x + _T / 2.0, y + _T / 2.0, 8.0, 1.0, 3.0, Palette.LIME_400, 1.5)
			p.polyline(_points(x, y, [4, 36, 20, 18, 36, 2]), Palette.LIME_400, 2.0)
		Tile.STEEL:
			p.fill_rect(x, y, _T, _T, Palette.SLATE_600)
			p.fill_rect(x + 6.0, y + 6.0, _T - 12.0, _T - 12.0, Palette.SLATE_700)
		Tile.SPIKE_UP, Tile.SPIKE_RIGHT, Tile.SPIKE_DOWN, Tile.SPIKE_LEFT:
			draw_spikes(p, t, x, y, _SPIKE_LENGTH)
		Tile.GLASS:
			var line_color: Color = Color(Palette.CYAN_500, 0.6)
			p.fill_rect(x, y, _T, _T, Color(Palette.CYAN_500, 0.15))
			p.stroke_rect(x + 1.0, y + 1.0, _T - 2.0, _T - 2.0, line_color, 1.0)
			p.line(x + 4.0, y + 4.0, x + _T - 4.0, y + _T - 4.0, line_color, 1.0)
			p.line(x + _T - 4.0, y + 4.0, x + 4.0, y + _T - 4.0, line_color, 1.0)
		Tile.VOID:
			p.fill_rect(x, y, _T, _T, Palette.VOID_BACKGROUND)
			p.dashed_rect(x + 3.0, y + 3.0, _T - 6.0, _T - 6.0, Palette.PURPLE_500, 2.0, 4.0)
			var pulse: float = sin(time_ms / 150.0) * 0.15 + 0.35
			p.fill_rect(x + 9.0, y + 9.0, _T - 18.0, _T - 18.0, Color(Palette.PURPLE_500, pulse))
			# The bright core is exactly the lethal part of the tile.
			p.fill_rect(x + 12.0, y + 12.0, _T - 24.0, _T - 24.0, Palette.PURPLE_400)
			p.fill_rect(x + 16.0, y + 16.0, _T - 32.0, _T - 32.0, Palette.PURPLE_100)
		Tile.GOAL:
			p.fill_rect(x + 4.0, y + 4.0, _T - 8.0, _T - 8.0, Palette.AMBER_400)
			p.fill_rect(x + 12.0, y + 12.0, _T - 24.0, _T - 24.0, Palette.AMBER_100)


## Three red teeth along one side of a cell. [param spike_type] is one of the
## four spike tiles and decides which way they point; teeth of
## [param length] grow from the opposite edge.
static func draw_spikes(p: Painter, spike_type: int, x: float, y: float, length: float) -> void:
	var third: float = _T / 3.0
	for s: int in 3:
		var a: float = float(s) * third
		match spike_type:
			Tile.SPIKE_UP:
				p.triangle(
					Vector2(x + a, y + _T), Vector2(x + a + third / 2.0, y + _T - length),
					Vector2(x + a + third, y + _T), Palette.RED_500
				)
			Tile.SPIKE_RIGHT:
				p.triangle(
					Vector2(x, y + a), Vector2(x + length, y + a + third / 2.0),
					Vector2(x, y + a + third), Palette.RED_500
				)
			Tile.SPIKE_DOWN:
				p.triangle(
					Vector2(x + a, y), Vector2(x + a + third / 2.0, y + length),
					Vector2(x + a + third, y), Palette.RED_500
				)
			Tile.SPIKE_LEFT:
				p.triangle(
					Vector2(x + _T, y + a), Vector2(x + _T - length, y + a + third / 2.0),
					Vector2(x + _T, y + a + third), Palette.RED_500
				)


## Flying or carried block of [param type], drawn as a plain coloured square.
static func draw_projectile(p: Painter, type: int, x: float, y: float, w: float, h: float) -> void:
	if type == Tile.GLASS:
		p.fill_rect(x, y, w, h, Color(Palette.CYAN_200, 0.75))
		p.stroke_rect(x + 1.0, y + 1.0, w - 2.0, h - 2.0, Palette.CYAN_500, 2.0)
		var shine: Color = Color(Palette.WHITE, 0.85)
		p.line(x + 4.0, y + 4.0, x + w - 4.0, y + h - 4.0, shine, 1.2)
		p.line(x + w - 4.0, y + 4.0, x + 4.0, y + h - 4.0, shine, 1.2)
	elif type == Tile.BOUNCY:
		p.fill_rect(x, y, w, h, Palette.PINK_500)
		p.stroke_rect(x + 1.5, y + 1.5, w - 3.0, h - 3.0, Palette.PINK_600, 3.0)
	else:
		p.fill_rect(x, y, w, h, Palette.AMBER_600)
		p.stroke_rect(x + 1.5, y + 1.5, w - 3.0, h - 3.0, Palette.AMBER_700, 3.0)


static func _block(p: Painter, x: float, y: float, fill: Color, border: Color, width: float) -> void:
	p.fill_rect(x, y, _T, _T, fill)
	p.stroke_rect(x + 1.5, y + 1.5, _T - 3.0, _T - 3.0, border, width)


## Point list from flat (x, y, x, y, ...) offsets inside the cell.
static func _points(x: float, y: float, offsets: Array[int]) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(0, offsets.size(), 2):
		points.append(Vector2(x + float(offsets[i]), y + float(offsets[i + 1])))
	return points
