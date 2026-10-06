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
				var player: PlayerState = sim.player
				var x: float = float(c) * Tile.SIZE
				var y: float = float(r) * Tile.SIZE
				if view.editor == null and not player.eating_target_is_boss_cell and player.has_eating_target and player.eating_target_r == r and player.eating_target_c == c:
					var progress: float = clampf(player.eating_progress, 0.0, 1.0)
					var center: Vector2 = Vector2(x, y) + Vector2.ONE * Tile.SIZE * 0.5
					var body: Vector2 = view.tween_position(player.prev_x, player.prev_y, player.x, player.y) + Vector2(player.w, player.h) * 0.5
					var pull: float = progress * progress * (3.0 - 2.0 * progress)
					var visual: Vector2 = center.lerp(body, pull)
					p.push()
					p.translate(visual.x, visual.y)
					p.rotate(sin(progress * PI) * 0.08)
					var shrink: float = lerpf(1.0, 0.5, pull)
					p.scale(shrink, shrink)
					TilePainter.draw(p, t, -Tile.SIZE * 0.5, -Tile.SIZE * 0.5, view.time_ms)
					p.pop()
				else:
					TilePainter.draw(p, t, x, y, view.time_ms)
					if Tile.is_solid(t) and t != Tile.GLASS:
						_draw_exposed_edges(p, level, r, c, x, y)


## Thin, static rim lighting stays inside collision boundaries. Interior
## seams remain quieter so long platforms read as a continuous surface.
func _draw_exposed_edges(p: Painter, level: LevelGrid, r: int, c: int, x: float, y: float) -> void:
	var light: Color = Color(0.77, 0.89, 0.92, 0.42)
	var shade: Color = Color(0.015, 0.025, 0.045, 0.55)
	if not Tile.is_solid(level.get_cell(r - 1, c)):
		p.fill_rect(x + 1.0, y, Tile.SIZE - 2.0, 1.5, light)
	if not Tile.is_solid(level.get_cell(r, c - 1)):
		p.fill_rect(x, y + 1.0, 1.0, Tile.SIZE - 2.0, Color(light, 0.24))
	if not Tile.is_solid(level.get_cell(r + 1, c)):
		p.fill_rect(x + 1.0, y + Tile.SIZE - 2.0, Tile.SIZE - 2.0, 2.0, shade)
	if not Tile.is_solid(level.get_cell(r, c + 1)):
		p.fill_rect(x + Tile.SIZE - 1.0, y + 1.0, 1.0, Tile.SIZE - 2.0, shade)
