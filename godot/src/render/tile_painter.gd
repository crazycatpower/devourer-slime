class_name TilePainter
extends RefCounted
## Draws tiles. Every tile is vector art drawn inside its 40x40 cell; the
## shapes and colours are shared by the terrain and bosses.

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
			# Embedded strata are fixed to the material, never animated noise.
			p.polyline(_points(x, y, [7, 17, 16, 17, 20, 21, 32, 21]), Color("97551f"), 2.0)
			p.line(x + 9.0, y + 28.0, x + 18.0, y + 28.0, Color("efb153"), 2.0)
			p.fill_rect(x + 26.0, y + 11.0, 4.0, 3.0, Color("f4bd64"))
		Tile.DIRT_EATEN_1:
			_block(p, x, y, Palette.AMBER_700, Palette.AMBER_800, 3.0)
			p.fill_rect(x + 4.0, y + 4.0, _T - 8.0, _T - 8.0, _SLIME_LIGHT)
			p.polyline(_points(x, y, [6, 12, 12, 22, 20, 26, 28, 22, 34, 12]), Palette.GREEN_500, 2.0)
		Tile.DIRT_EATEN_2:
			_block(p, x, y, Palette.AMBER_900, Palette.GREEN_500, 2.5)
			p.fill_rect(x + 6.0, y + 6.0, _T - 12.0, _T - 12.0, _SLIME_HEAVY)
			p.polyline(_points(x, y, [6, 6, 16, 18, 8, 32]), Palette.LIME_400, 1.8)
			p.polyline(_points(x, y, [34, 6, 24, 18, 32, 32]), Palette.LIME_400, 1.8)
		Tile.BOUNCY:
			_block(p, x, y, Palette.PINK_500, Palette.PINK_600, 3.0)
			var bounce_pulse: float = sin(time_ms * 0.005 + (x + y) * 0.02) * 0.75
			p.stroke_circle(x + _T / 2.0, y + _T / 2.0, 8.0 + bounce_pulse, Palette.PINK_200, 2.5)
			p.fill_circle(x + _T / 2.0, y + _T / 2.0, 2.5, Color(Palette.PINK_200, 0.45))
		Tile.BOUNCY_EATEN_1:
			_block(p, x, y, Palette.PINK_700, Palette.PINK_800, 3.0)
			p.fill_rect(x + 4.0, y + 4.0, _T - 8.0, _T - 8.0, _SLIME_LIGHT)
			p.arc(x + _T / 2.0, y + _T / 2.0, 8.0, 0.2, PI * 1.5, Palette.PINK_200, 2.0)
			p.line(x + 5.0, y + 8.0, x + 15.0, y + 15.0, Palette.GREEN_500, 1.5)
			p.line(x + 35.0, y + 8.0, x + 25.0, y + 15.0, Palette.GREEN_500, 1.5)
		Tile.BOUNCY_EATEN_2:
			_block(p, x, y, Palette.PINK_900, Palette.GREEN_500, 2.5)
			p.fill_rect(x + 6.0, y + 6.0, _T - 12.0, _T - 12.0, _SLIME_HEAVY)
			p.arc(x + _T / 2.0, y + _T / 2.0, 8.0, 1.0, 3.0, Palette.LIME_400, 1.5)
			p.polyline(_points(x, y, [4, 36, 16, 18, 4, 4, 20, 12, 36, 4, 24, 18, 36, 36]), Palette.LIME_400, 2.0)
		Tile.STEEL:
			_block(p, x, y, Color("435c6c"), Color("243646"), 2.0)
			p.fill_rect(x + 8.0, y + 8.0, _T - 16.0, _T - 16.0, Color("304452"))
			p.line(x + 9.0, y + 9.0, x + 30.0, y + 9.0, Color("617783"), 1.0)
			p.line(x + 9.0, y + 30.0, x + 30.0, y + 30.0, Color("20303c"), 2.0)
			p.line(x + 13.0, y + 15.0, x + 24.0, y + 15.0, Color("3c5361"), 1.0)
			p.line(x + 17.0, y + 18.0, x + 27.0, y + 18.0, Color("3c5361"), 1.0)
			for corner: Vector2 in [Vector2(5, 5), Vector2(32, 5), Vector2(5, 32), Vector2(32, 32)]:
				p.fill_rect(x + corner.x, y + corner.y + 1.0, 4.0, 4.0, Color("1e303c"))
				p.fill_rect(x + corner.x, y + corner.y, 3.0, 3.0, Color("8aa2aa"))
		Tile.SPIKE_UP, Tile.SPIKE_RIGHT, Tile.SPIKE_DOWN, Tile.SPIKE_LEFT:
			draw_spikes(p, t, x, y, _SPIKE_LENGTH)
		Tile.GLASS:
			var line_color: Color = Color(Palette.CYAN_500, 0.6)
			p.fill_rect(x, y, _T, _T, Color(Palette.CYAN_500, 0.15))
			p.stroke_rect(x + 1.0, y + 1.0, _T - 2.0, _T - 2.0, line_color, 1.0)
			p.stroke_rect(x + 4.0, y + 4.0, _T - 8.0, _T - 8.0, Color(Palette.CYAN_200, 0.22), 1.0)
			for gx: float in [7.0, 27.0]:
				p.fill_rect(x + gx, y + 7.0, 6.0, 2.0, Color(Palette.WHITE, 0.6))
			p.line(x + 4.0, y + 4.0, x + _T - 4.0, y + _T - 4.0, line_color, 1.0)
			p.line(x + _T - 4.0, y + 4.0, x + 4.0, y + _T - 4.0, line_color, 1.0)
			var sheen_phase: float = fposmod(time_ms * 0.0006 + (x + y * 1.3) * 0.004, 1.0)
			if sheen_phase < 0.2:
				var sheen_a: float = sin(sheen_phase / 0.2 * PI) * 0.35
				p.line(x + 2.0, y + 14.0, x + 14.0, y + 2.0, Color(Palette.WHITE, sheen_a), 2.0)
		Tile.VOID:
			p.fill_rect(x, y, _T, _T, Palette.VOID_BACKGROUND)
			p.dashed_rect(x + 3.0, y + 3.0, _T - 6.0, _T - 6.0, Palette.PURPLE_500, 2.0, 4.0)
			var pulse: float = sin(time_ms / 150.0) * 0.15 + 0.35
			p.fill_rect(x + 9.0, y + 9.0, _T - 18.0, _T - 18.0, Color(Palette.PURPLE_500, pulse))
			var void_rot: float = time_ms * 0.002 + (x * 0.03 + y * 0.02)
			for i: int in 4:
				var a: float = void_rot + float(i) * (PI * 0.5)
				var ox: float = x + _T * 0.5 + cos(a) * 13.0
				var oy: float = y + _T * 0.5 + sin(a) * 13.0
				p.fill_rect(ox - 1.0, oy - 1.0, 2.0, 2.0, Color(Palette.PURPLE_400, 0.45))
			# The bright core is exactly the lethal part of the tile.
			p.fill_rect(x + 12.0, y + 12.0, _T - 24.0, _T - 24.0, Palette.PURPLE_400)
			var core_shimmer: float = 0.8 + sin(time_ms * 0.009 + x + y) * 0.2
			p.fill_rect(x + 16.0, y + 16.0, _T - 32.0, _T - 32.0, Color(Palette.PURPLE_100, core_shimmer))
		Tile.GOAL:
			var glow: float = 0.16 + sin(time_ms * 0.004) * 0.07
			p.fill_rect(x, y, _T, _T, Color(Palette.AMBER_400, glow))
			p.stroke_rect(x + 5.0, y + 5.0, _T - 10.0, _T - 10.0, Palette.AMBER_400, 3.0)
			p.fill_rect(x + 12.0, y + 12.0, _T - 24.0, _T - 24.0, Palette.AMBER_100)
			var goal_rot: float = time_ms * 0.0025
			for i: int in 4:
				var a: float = goal_rot + float(i) * (PI * 0.5)
				p.fill_rect(x + _T * 0.5 + cos(a) * 10.0 - 1.0, y + _T * 0.5 + sin(a) * 10.0 - 1.0, 2.0, 2.0, Palette.YELLOW_200)


## Three red teeth along one side of a cell. [param spike_type] is one of the
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
		var root: Vector2 = Vector2(a + third * 0.5, _T)
		p.triangle(Vector2(a, _T), tip, root, Color("ff7c83"))
		p.triangle(root, tip, Vector2(a + third, _T), Color("b92f4e"))
		p.line(tip.x, tip.y + 2.0, root.x, root.y - 3.0, Color("ffb0a7"), 1.0)
	p.fill_rect(0.0, _T - 3.0, _T, 3.0, Color("712c42"))
	p.fill_rect(1.0, _T - 3.0, _T - 2.0, 1.0, Color("e85b6b"))
	p.pop()

## Flying or carried block of [param type], drawn with distinct surface and worn patterns.
static func draw_projectile(p: Painter, type: int, x: float, y: float, w: float, h: float) -> void:
	if type == Tile.GLASS:
		p.fill_rect(x, y, w, h, Color(Palette.CYAN_200, 0.75))
		p.stroke_rect(x + 1.0, y + 1.0, w - 2.0, h - 2.0, Palette.CYAN_500, 2.0)
		var shine: Color = Color(Palette.WHITE, 0.85)
		p.line(x + 4.0, y + 4.0, x + w - 4.0, y + h - 4.0, shine, 1.2)
		p.line(x + w - 4.0, y + 4.0, x + 4.0, y + h - 4.0, shine, 1.2)
	elif type == Tile.BOUNCY or type == Tile.BOUNCY_EATEN_1 or type == Tile.BOUNCY_EATEN_2:
		var fill: Color = Palette.PINK_500
		var stroke: Color = Palette.PINK_600
		if type == Tile.BOUNCY_EATEN_1:
			fill = Palette.PINK_700
			stroke = Palette.PINK_800
		elif type == Tile.BOUNCY_EATEN_2:
			fill = Palette.PINK_900
			stroke = Palette.GREEN_500
		p.fill_rect(x, y, w, h, fill)
		p.stroke_rect(x + 1.5, y + 1.5, w - 3.0, h - 3.0, stroke, 3.0)
		p.stroke_circle(x + w * 0.5, y + h * 0.5, minf(w, h) * 0.25, Palette.PINK_200, 1.8)
		if type == Tile.BOUNCY_EATEN_1 or type == Tile.BOUNCY_EATEN_2:
			p.fill_rect(x + 3.0, y + 3.0, w - 6.0, h - 6.0, _SLIME_LIGHT)
	else:
		var fill: Color = Palette.AMBER_600
		var stroke: Color = Palette.AMBER_700
		if type == Tile.DIRT_EATEN_1:
			fill = Palette.AMBER_700
			stroke = Palette.AMBER_800
		elif type == Tile.DIRT_EATEN_2:
			fill = Palette.AMBER_900
			stroke = Palette.GREEN_500
		p.fill_rect(x, y, w, h, fill)
		p.stroke_rect(x + 1.5, y + 1.5, w - 3.0, h - 3.0, stroke, 3.0)
		if type == Tile.DIRT_EATEN_1 or type == Tile.DIRT_EATEN_2:
			p.fill_rect(x + 3.0, y + 3.0, w - 6.0, h - 6.0, _SLIME_LIGHT)


static func _block(p: Painter, x: float, y: float, fill: Color, border: Color, width: float) -> void:
	# A consistent upper-left light gives the material a bevel inside its cell.
	p.fill_rect(x, y, _T, _T, border.darkened(0.35))
	p.fill_rect(x + 2.0, y + 2.0, _T - 4.0, _T - 4.0, fill)
	p.stroke_rect(x + 1.5, y + 1.5, _T - 3.0, _T - 3.0, border, width)
	p.fill_rect(x + 4.0, y + 4.0, _T - 8.0, 3.0, fill.lightened(0.28))
	p.fill_rect(x + 4.0, y + 7.0, 2.0, _T - 13.0, fill.lightened(0.12))
	p.fill_rect(x + 6.0, y + _T - 7.0, _T - 10.0, 3.0, fill.darkened(0.27))
	p.fill_rect(x + _T - 6.0, y + 7.0, 2.0, _T - 14.0, fill.darkened(0.18))

## Point list from flat (x, y, x, y, ...) offsets inside the cell.
static func _points(x: float, y: float, offsets: Array[int]) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(0, offsets.size(), 2):
		points.append(Vector2(x + float(offsets[i]), y + float(offsets[i + 1])))
	return points
