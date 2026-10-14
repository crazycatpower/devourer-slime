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
	var visible: Rect2 = view.visible_world_rect().grow(Tile.SIZE)
	var first_col: int = maxi(0, Tile.cell_of(visible.position.x))
	var last_col: int = mini(level.cols, Tile.cell_of(visible.end.x) + 1)
	var first_row: int = maxi(0, Tile.cell_of(visible.position.y))
	var last_row: int = mini(level.rows, Tile.cell_of(visible.end.y) + 1)
	if view.editor_show_grid:
		for c: int in range(first_col, last_col + 1):
			p.line(float(c) * Tile.SIZE, maxf(0.0, visible.position.y), float(c) * Tile.SIZE, minf(height, visible.end.y), GRID_COLOR, 1.0)
		for r: int in range(first_row, last_row + 1):
			p.line(maxf(0.0, visible.position.x), float(r) * Tile.SIZE, minf(width, visible.end.x), float(r) * Tile.SIZE, GRID_COLOR, 1.0)

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
	if view.editor_erasing or editor.brush == LevelEditor.Brush.ERASER:
		p.fill_rect(hx, hy, Tile.SIZE, Tile.SIZE, Color(Palette.RED_500, 0.25))
		p.stroke_rect(hx, hy, Tile.SIZE, Tile.SIZE, Palette.RED_400, 2.0)
		var erase_label: String = "全部"
		if editor.brush == LevelEditor.Brush.WIRE:
			erase_label = "連線"
		elif editor.brush == LevelEditor.Brush.SENSOR:
			erase_label = "感測器"
		elif Tile.is_rail(editor.brush_tile()):
			erase_label = "軌道"
		p.line(hx + 10.0, hy + 10.0, hx + 30.0, hy + 30.0, Palette.RED_400, 2.0)
		p.line(hx + 30.0, hy + 10.0, hx + 10.0, hy + 30.0, Palette.RED_400, 2.0)
		p.text("擦除" + erase_label, hx + Tile.SIZE * 0.5, hy - 6.0, 12.0, Palette.RED_400)
		return

	if editor.brush == LevelEditor.Brush.PASTE and editor.clipboard != null:
		var clip: LevelGrid = editor.clipboard
		var clip_left: int = clampi(Tile.cell_of(visible.position.x - hx), 0, clip.cols)
		var clip_right: int = clampi(Tile.cell_of(visible.end.x - hx) + 1, 0, clip.cols)
		var clip_top: int = clampi(Tile.cell_of(visible.position.y - hy), 0, clip.rows)
		var clip_bottom: int = clampi(Tile.cell_of(visible.end.y - hy) + 1, 0, clip.rows)
		for r: int in range(clip_top, clip_bottom):
			for c: int in range(clip_left, clip_right):
				var t: int = clip.get_cell(r, c)
				if t != Tile.AIR:
					p.push()
					p.translate(hx + float(c) * Tile.SIZE, hy + float(r) * Tile.SIZE)
					TilePainter.draw(p, t, 0.0, 0.0, view.time_ms)
					p.fill_rect(0.0, 0.0, Tile.SIZE, Tile.SIZE, Color(Palette.SLATE_900, 0.45))
					p.pop()
		for cell: Vector2i in clip.sensors:
			if not visible.has_point(Vector2(hx, hy) + (Vector2(cell) + Vector2.ONE * 0.5) * Tile.SIZE):
				continue
			TilePainter.draw(p, Tile.SENSOR, hx + cell.x * Tile.SIZE, hy + cell.y * Tile.SIZE, view.time_ms)
		for cell: Vector2i in clip.wires:
			if not visible.has_point(Vector2(hx, hy) + (Vector2(cell) + Vector2.ONE * 0.5) * Tile.SIZE):
				continue
			MechanismLayer.draw_wire(p, clip, cell, false, Vector2(hx, hy), view.time_ms)
		for cell: Vector2i in clip.rails:
			if not visible.has_point(Vector2(hx, hy) + (Vector2(cell) + Vector2.ONE * 0.5) * Tile.SIZE):
				continue
			MechanismLayer.draw_rail(p, clip, cell, false, Vector2(hx, hy), view.time_ms)
		p.stroke_rect(
			hx, hy, float(clip.cols) * Tile.SIZE, float(clip.rows) * Tile.SIZE, Palette.BLUE_500, 2.0
		)
		return

	if level.in_bounds(hover_r, hover_c):
		p.fill_rect(hx, hy, Tile.SIZE, Tile.SIZE, Color(1.0, 1.0, 1.0, 0.3))
		p.stroke_rect(hx, hy, Tile.SIZE, Tile.SIZE, Palette.WHITE, 2.0)
