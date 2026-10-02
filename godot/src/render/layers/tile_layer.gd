class_name TileLayer
extends WorldLayer
## The level's tiles. Only the visible ones are drawn.


func _paint(p: Painter, sim: GameSim) -> void:
	var level: LevelGrid = sim.level
	var visible_rect: Rect2 = view.visible_world_rect()
	var first_row: int = maxi(0, floori(visible_rect.position.y / Tile.SIZE) - 1)
	var last_row: int = mini(level.rows - 1, ceili(visible_rect.end.y / Tile.SIZE) + 1)
	var first_col: int = maxi(0, floori(visible_rect.position.x / Tile.SIZE) - 1)
	var last_col: int = mini(level.cols - 1, ceili(visible_rect.end.x / Tile.SIZE) + 1)
	for r: int in range(first_row, last_row + 1):
		for c: int in range(first_col, last_col + 1):
			var t: int = level.get_cell(r, c)
			if t != Tile.AIR:
				TilePainter.draw(p, t, float(c) * Tile.SIZE, float(r) * Tile.SIZE, view.time_ms)
