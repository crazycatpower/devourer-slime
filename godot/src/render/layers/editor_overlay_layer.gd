class_name EditorOverlayLayer
extends WorldLayer
## The level editor's aids: cell grid, hovered cell, copy selection and paste
## preview. Draws nothing outside the editor.

const GRID_COLOR: Color = Color(1.0, 1.0, 1.0, 0.1)


func _paint(p: Painter, sim: GameSim) -> void:
	var editor: LevelEditor = view.editor
	if editor == null:
		return
	var level: LevelGrid = sim.level
	var width: float = level.pixel_width()
	var height: float = level.pixel_height()
	for c: int in level.cols + 1:
		p.line(float(c) * Tile.SIZE, 0.0, float(c) * Tile.SIZE, height, GRID_COLOR, 1.0)
	for r: int in level.rows + 1:
		p.line(0.0, float(r) * Tile.SIZE, width, float(r) * Tile.SIZE, GRID_COLOR, 1.0)

	# Mark the start cell so it stays findable under the slime.
	var start: Vector2i = editor.level.start_cell
	p.dashed_rect(
		float(start.x) * Tile.SIZE + 1.0, float(start.y) * Tile.SIZE + 1.0,
		Tile.SIZE - 2.0, Tile.SIZE - 2.0, Color(Palette.EMERALD_400, 0.8), 2.0, 5.0
	)

	if editor.selection_start != LevelEditor.NO_CELL:
		var area: Rect2i = editor.selection_rect()
		var x: float = float(area.position.x) * Tile.SIZE
		var y: float = float(area.position.y) * Tile.SIZE
		var w: float = float(area.size.x) * Tile.SIZE
		var h: float = float(area.size.y) * Tile.SIZE
		p.fill_rect(x, y, w, h, Color(Palette.SKY_400, 0.2))
		p.stroke_rect(x, y, w, h, Palette.SKY_400, 2.0)
		return

	if not Rect2(Vector2.ZERO, view.size).has_point(view.get_local_mouse_position()):
		return
	var mouse: Vector2 = view.mouse_in_world()
	var hover_c: int = floori(mouse.x / Tile.SIZE)
	var hover_r: int = floori(mouse.y / Tile.SIZE)
	var hx: float = float(hover_c) * Tile.SIZE
	var hy: float = float(hover_r) * Tile.SIZE

	if editor.brush == LevelEditor.Brush.PASTE and editor.clipboard != null:
		var clip: LevelGrid = editor.clipboard
		for r: int in clip.rows:
			for c: int in clip.cols:
				var t: int = clip.get_cell(r, c)
				if t != Tile.AIR:
					p.push()
					p.translate(hx + float(c) * Tile.SIZE, hy + float(r) * Tile.SIZE)
					TilePainter.draw(p, t, 0.0, 0.0, view.time_ms)
					p.fill_rect(0.0, 0.0, Tile.SIZE, Tile.SIZE, Color(Palette.SLATE_900, 0.45))
					p.pop()
		p.stroke_rect(
			hx, hy, float(clip.cols) * Tile.SIZE, float(clip.rows) * Tile.SIZE, Palette.BLUE_500, 2.0
		)
		return

	if level.in_bounds(hover_r, hover_c):
		p.fill_rect(hx, hy, Tile.SIZE, Tile.SIZE, Color(1.0, 1.0, 1.0, 0.3))
		p.stroke_rect(hx, hy, Tile.SIZE, Tile.SIZE, Palette.WHITE, 2.0)
