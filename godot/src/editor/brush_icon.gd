class_name BrushIcon
extends Control
## Picture of an editor brush: the tile it paints, or a symbol for the tools.

var brush: LevelEditor.Brush = LevelEditor.Brush.DIRT:
	set(value):
		brush = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func label_for(value: LevelEditor.Brush) -> String:
	match value:
		LevelEditor.Brush.SENSOR:
			return "感測器"
		LevelEditor.Brush.WIRE:
			return "拉線"
		LevelEditor.Brush.RAIL_RIGHT:
			return "右軌道"
		LevelEditor.Brush.RAIL_LEFT:
			return "左軌道"
		LevelEditor.Brush.RAIL_UP:
			return "上軌道"
		LevelEditor.Brush.RAIL_DOWN:
			return "下軌道"
		LevelEditor.Brush.SAND:
			return "沙子"
		LevelEditor.Brush.ICE:
			return "冰"
		LevelEditor.Brush.TNT:
			return "TNT"
		LevelEditor.Brush.DIRT:
			return "泥土"
		LevelEditor.Brush.BOUNCY:
			return "彈力"
		LevelEditor.Brush.STEEL:
			return "鋼鐵"
		LevelEditor.Brush.GLASS:
			return "玻璃"
		LevelEditor.Brush.VOID:
			return "虛空"
		LevelEditor.Brush.SPIKES:
			return "尖刺"
		LevelEditor.Brush.GOAL:
			return "終點"
		LevelEditor.Brush.PLAYER:
			return "起點"
		LevelEditor.Brush.COPY:
			return "複製"
		LevelEditor.Brush.PASTE:
			return "貼上"
	return "橡皮擦"


static func tile_label(type: int) -> String:
	match type:
		Tile.DIRT, Tile.DIRT_EATEN_1, Tile.DIRT_EATEN_2: return "泥土"
		Tile.BOUNCY, Tile.BOUNCY_EATEN_1, Tile.BOUNCY_EATEN_2: return "彈力"
		Tile.STEEL: return "鋼鐵"
		Tile.GLASS: return "玻璃"
		Tile.SAND: return "沙子"
		Tile.ICE: return "冰"
		Tile.TNT: return "TNT"
		Tile.GOAL: return "終點"
		Tile.VOID: return "虛空"
		Tile.SPIKE_UP, Tile.SPIKE_RIGHT, Tile.SPIKE_DOWN, Tile.SPIKE_LEFT: return "尖刺"
	return "空格"


func _draw() -> void:
	var s: float = minf(size.x, size.y) / 40.0
	var p: Painter = Painter.new(self, s)
	p.translate((size.x - 40.0 * s) / 2.0, (size.y - 40.0 * s) / 2.0)
	p.scale(s, s)
	match brush:
		LevelEditor.Brush.SENSOR:
			TilePainter.draw(p, Tile.SENSOR, 0.0, 0.0, 0.0)
		LevelEditor.Brush.RAIL_RIGHT:
			TilePainter.draw(p, Tile.RAIL_RIGHT, 0.0, 0.0, 0.0)
		LevelEditor.Brush.RAIL_LEFT:
			TilePainter.draw(p, Tile.RAIL_LEFT, 0.0, 0.0, 0.0)
		LevelEditor.Brush.RAIL_UP:
			TilePainter.draw(p, Tile.RAIL_UP, 0.0, 0.0, 0.0)
		LevelEditor.Brush.RAIL_DOWN:
			TilePainter.draw(p, Tile.RAIL_DOWN, 0.0, 0.0, 0.0)
		LevelEditor.Brush.SAND:
			TilePainter.draw(p, Tile.SAND, 0.0, 0.0, 0.0)
		LevelEditor.Brush.ICE:
			TilePainter.draw(p, Tile.ICE, 0.0, 0.0, 0.0)
		LevelEditor.Brush.TNT:
			TilePainter.draw(p, Tile.TNT, 0.0, 0.0, 0.0)
		LevelEditor.Brush.WIRE:
			var pts: PackedVector2Array = PackedVector2Array([Vector2(6, 32), Vector2(20, 32), Vector2(20, 8), Vector2(34, 8)])
			p.polyline(pts, Color("354957"), 7.0)
			p.polyline(pts, Palette.LIME_400, 3.5)
			for term: Vector2 in [Vector2(6, 32), Vector2(20, 20), Vector2(34, 8)]:
				p.fill_circle(term.x, term.y, 4.5, Color("050914", 0.95))
				p.stroke_circle(term.x, term.y, 4.5, Palette.LIME_400, 1.4)
				p.fill_circle(term.x, term.y, 2.2, Palette.WHITE)
		LevelEditor.Brush.DIRT:
			TilePainter.draw(p, Tile.DIRT, 0.0, 0.0, 0.0)
		LevelEditor.Brush.BOUNCY:
			TilePainter.draw(p, Tile.BOUNCY, 0.0, 0.0, 0.0)
		LevelEditor.Brush.STEEL:
			TilePainter.draw(p, Tile.STEEL, 0.0, 0.0, 0.0)
		LevelEditor.Brush.GLASS:
			TilePainter.draw(p, Tile.GLASS, 0.0, 0.0, 0.0)
		LevelEditor.Brush.VOID:
			TilePainter.draw(p, Tile.VOID, 0.0, 0.0, 0.0)
		LevelEditor.Brush.SPIKES:
			TilePainter.draw(p, Tile.SPIKE_UP, 0.0, -8.0, 0.0)
		LevelEditor.Brush.GOAL:
			TilePainter.draw(p, Tile.GOAL, 0.0, 0.0, 0.0)
		LevelEditor.Brush.PLAYER:
			p.fill_round_rect(3.0, 5.0, 34.0, 32.0, 11.0, Palette.GREEN_500)
			p.fill_rect(12.0, 13.0, 6.0, 10.0, Palette.WHITE)
			p.fill_rect(22.0, 13.0, 6.0, 10.0, Palette.WHITE)
			p.fill_rect(15.0, 16.0, 2.0, 4.0, Palette.SLATE_900)
			p.fill_rect(25.0, 16.0, 2.0, 4.0, Palette.SLATE_900)
		LevelEditor.Brush.COPY:
			# A dashed marquee.
			p.dashed_rect(5.0, 7.0, 30.0, 26.0, Palette.SKY_400, 2.5, 5.0)
			p.fill_rect(11.0, 13.0, 18.0, 14.0, Color(Palette.SKY_400, 0.3))
		LevelEditor.Brush.PASTE:
			# A block stamped down from a ghost of itself.
			p.stroke_rect(6.0, 5.0, 20.0, 20.0, Color(Palette.BLUE_500, 0.7), 2.0)
			p.fill_rect(14.0, 13.0, 20.0, 20.0, Palette.BLUE_500)
			p.stroke_rect(15.0, 14.0, 18.0, 18.0, Palette.SKY_400, 2.0)
		_:
			# The eraser: an empty cell struck through.
			p.dashed_rect(5.0, 5.0, 30.0, 30.0, Palette.SLATE_400, 2.0, 4.0)
			p.line(11.0, 11.0, 29.0, 29.0, Palette.RED_400, 3.0)
			p.line(29.0, 11.0, 11.0, 29.0, Palette.RED_400, 3.0)
