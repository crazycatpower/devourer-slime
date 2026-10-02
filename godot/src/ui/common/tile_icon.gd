class_name TileIcon
extends Control
## Shows one tile, scaled to fit the control.

var tile: int = Tile.DIRT:
	set(value):
		tile = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s: float = minf(size.x, size.y) / Tile.SIZE
	var p: Painter = Painter.new(self, s)
	p.translate((size.x - Tile.SIZE * s) / 2.0, (size.y - Tile.SIZE * s) / 2.0)
	p.scale(s, s)
	TilePainter.draw(p, tile, 0.0, 0.0, 0.0)
