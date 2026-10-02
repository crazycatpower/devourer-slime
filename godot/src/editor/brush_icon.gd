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


func _draw() -> void:
	var s: float = minf(size.x, size.y) / 40.0
	var p: Painter = Painter.new(self, s)
	p.translate((size.x - 40.0 * s) / 2.0, (size.y - 40.0 * s) / 2.0)
	p.scale(s, s)
	match brush:
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
