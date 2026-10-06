extends TestCase
## The level editor's document model.

var editor: LevelEditor


func before_each() -> void:
	editor = LevelEditor.new()
	editor.open(LevelCodec.decode(LevelLibrary.default_rows()))  # The empty 40 x 15 room.


func test_open_starts_clean() -> void:
	check(not editor.is_dirty())
	check(not editor.can_undo())
	check(not editor.can_redo())
	check(editor.level.equals(LevelCodec.decode(LevelLibrary.default_rows())))


func test_undo_to_saved_state_is_clean_and_redo_is_dirty() -> void:
	_paint(Vector2i(4, 4))
	editor.mark_saved()
	_paint(Vector2i(5, 4))
	check(editor.is_dirty())
	editor.undo()
	check(not editor.is_dirty(), "undo to the saved document is clean")
	editor.redo()
	check(editor.is_dirty())


func test_erase_drag_keeps_brush_and_undo_restores_whole_drag() -> void:
	editor.set_brush(LevelEditor.Brush.STEEL)
	editor.begin_stroke()
	editor.stroke_to(Vector2i(4, 4), false)
	editor.stroke_to(Vector2i(8, 4), false)
	editor.end_stroke()
	var before: LevelData = editor.level.duplicate_level()
	editor.begin_stroke()
	editor.stroke_to(Vector2i(4, 4), true)
	editor.stroke_to(Vector2i(8, 4), true)
	editor.end_stroke()
	for col: int in range(4, 9):
		check_eq(editor.level.grid.get_cell(4, col), Tile.AIR)
	check_eq(editor.brush, LevelEditor.Brush.STEEL)
	editor.undo()
	check(editor.level.equals(before), "one undo restores all erased cells")


func test_pick_material_and_spike_direction_does_not_edit_level() -> void:
	editor.level.grid.set_cell(4, 4, Tile.SPIKE_LEFT)
	editor.mark_saved()
	editor.pick_brush(Vector2i(4, 4))
	check_eq(editor.brush, LevelEditor.Brush.SPIKES)
	check_eq(editor.spike_direction, LevelEditor.SpikeDirection.LEFT)
	check(not editor.is_dirty() and not editor.can_undo())
	editor.pick_brush(editor.level.start_cell)
	check_eq(editor.brush, LevelEditor.Brush.PLAYER)
	editor.pick_brush(Vector2i(5, 5))
	check_eq(editor.brush, LevelEditor.Brush.ERASER)


func test_save_during_stroke_preserves_undo() -> void:
	editor.begin_stroke()
	editor.stroke_to(Vector2i(4, 4), false)
	editor.mark_saved()
	check(not editor.is_dirty())
	check(editor.can_undo())
	editor.undo()
	check_eq(editor.level.grid.get_cell(4, 4), Tile.AIR)
	check(editor.is_dirty())


func test_open_works_on_a_copy() -> void:
	var source: LevelData = LevelCodec.decode(LevelLibrary.default_rows())
	editor.open(source)
	_paint(Vector2i(5, 5))
	check_eq(source.grid.get_cell(5, 5), Tile.AIR, "the caller's level is untouched")


func test_stroke_paints_a_gapless_line() -> void:
	editor.set_brush(LevelEditor.Brush.DIRT)
	editor.begin_stroke()
	editor.stroke_to(Vector2i(3, 3), false)
	editor.stroke_to(Vector2i(10, 6), false)  # A fast diagonal mouse move.
	editor.end_stroke()
	var painted: int = 0
	for r: int in range(3, 7):
		for c: int in range(3, 11):
			if editor.level.grid.get_cell(r, c) == Tile.DIRT:
				painted += 1
	check_eq(painted, 8, "one cell per column along the line")
	check_eq(editor.level.grid.get_cell(3, 3), Tile.DIRT)
	check_eq(editor.level.grid.get_cell(6, 10), Tile.DIRT)
	check(editor.is_dirty())


func test_a_stroke_is_one_undo_step() -> void:
	var before: LevelData = editor.level.duplicate_level()
	editor.begin_stroke()
	editor.stroke_to(Vector2i(3, 3), false)
	editor.stroke_to(Vector2i(8, 3), false)
	editor.stroke_to(Vector2i(8, 9), false)
	editor.end_stroke()
	var after: LevelData = editor.level.duplicate_level()
	check(editor.can_undo())
	editor.undo()
	check(editor.level.equals(before), "undo reverts the whole stroke")
	check(not editor.can_undo())
	check(editor.can_redo())
	editor.redo()
	check(editor.level.equals(after), "redo restores it")


func test_a_stroke_that_changes_nothing_leaves_no_history() -> void:
	editor.begin_stroke()
	editor.stroke_to(Vector2i(5, 5), true)  # Erasing air.
	editor.end_stroke()
	check(not editor.can_undo())
	check(not editor.is_dirty())


func test_new_edit_clears_redo() -> void:
	_paint(Vector2i(5, 5))
	editor.undo()
	check(editor.can_redo())
	_paint(Vector2i(6, 6))
	check(not editor.can_redo())


func test_erase_ignores_the_brush() -> void:
	editor.set_brush(LevelEditor.Brush.STEEL)
	_paint(Vector2i(5, 5))
	check_eq(editor.level.grid.get_cell(5, 5), Tile.STEEL)
	editor.begin_stroke()
	editor.stroke_to(Vector2i(5, 5), true)
	editor.end_stroke()
	check_eq(editor.level.grid.get_cell(5, 5), Tile.AIR)


func test_every_tile_brush() -> void:
	var expected: Dictionary[int, int] = {
		LevelEditor.Brush.DIRT: Tile.DIRT,
		LevelEditor.Brush.BOUNCY: Tile.BOUNCY,
		LevelEditor.Brush.STEEL: Tile.STEEL,
		LevelEditor.Brush.GLASS: Tile.GLASS,
		LevelEditor.Brush.VOID: Tile.VOID,
		LevelEditor.Brush.GOAL: Tile.GOAL,
	}
	for brush: int in expected:
		editor.set_brush(brush as LevelEditor.Brush)
		_paint(Vector2i(7, 7))
		check_eq(editor.level.grid.get_cell(7, 7), expected[brush], "brush %d" % brush)
	editor.set_brush(LevelEditor.Brush.ERASER)
	_paint(Vector2i(7, 7))
	check_eq(editor.level.grid.get_cell(7, 7), Tile.AIR)


func test_start_cell_can_never_be_built_over() -> void:
	var start: Vector2i = editor.level.start_cell
	editor.set_brush(LevelEditor.Brush.STEEL)
	_paint(start)
	check_eq(editor.level.grid.get_cell(start.y, start.x), Tile.AIR)
	check(not editor.is_dirty())


func test_player_brush_moves_the_start_and_frees_the_cell() -> void:
	editor.set_brush(LevelEditor.Brush.DIRT)
	_paint(Vector2i(9, 9))
	editor.set_brush(LevelEditor.Brush.PLAYER)
	_paint(Vector2i(9, 9))
	check_eq(editor.level.start_cell, Vector2i(9, 9))
	check_eq(editor.level.grid.get_cell(9, 9), Tile.AIR, "the tile under the new start is removed")


func test_spikes_turn_toward_their_only_solid_neighbour() -> void:
	editor.set_brush(LevelEditor.Brush.SPIKES)
	# Row 13 sits on the steel floor (row 14).
	_paint(Vector2i(10, 13))
	check_eq(editor.level.grid.get_cell(13, 10), Tile.SPIKE_UP)
	# Column 1 touches only the left wall.
	_paint(Vector2i(1, 6))
	check_eq(editor.level.grid.get_cell(6, 1), Tile.SPIKE_RIGHT)
	check_eq(editor.spike_direction, LevelEditor.SpikeDirection.RIGHT, "the brush follows")
	# Under the ceiling.
	_paint(Vector2i(20, 1))
	check_eq(editor.level.grid.get_cell(1, 20), Tile.SPIKE_DOWN)
	# Against the right wall.
	_paint(Vector2i(38, 6))
	check_eq(editor.level.grid.get_cell(6, 38), Tile.SPIKE_LEFT)
	# In open air the last direction is kept.
	_paint(Vector2i(20, 7))
	check_eq(editor.level.grid.get_cell(7, 20), Tile.SPIKE_LEFT)
	# The direction can also be chosen by hand.
	editor.set_spike_direction(LevelEditor.SpikeDirection.UP)
	_paint(Vector2i(22, 7))
	check_eq(editor.level.grid.get_cell(7, 22), Tile.SPIKE_UP)


func test_copy_and_paste() -> void:
	editor.set_brush(LevelEditor.Brush.BOUNCY)
	_paint(Vector2i(4, 4))
	editor.set_brush(LevelEditor.Brush.GLASS)
	_paint(Vector2i(5, 5))

	editor.set_brush(LevelEditor.Brush.COPY)
	editor.begin_selection(Vector2i(5, 5))  # Dragged up and to the left.
	editor.update_selection(Vector2i(4, 4))
	check_eq(editor.selection_rect(), Rect2i(4, 4, 2, 2))
	editor.finish_selection()
	check_eq(editor.brush, LevelEditor.Brush.PASTE, "copying switches to the paste brush")
	check(editor.clipboard != null)
	check_eq(editor.clipboard.cols, 2)
	check_eq(editor.clipboard.rows, 2)

	editor.paste_at(Vector2i(20, 8))
	check_eq(editor.level.grid.get_cell(8, 20), Tile.BOUNCY)
	check_eq(editor.level.grid.get_cell(9, 21), Tile.GLASS)
	editor.undo()
	check_eq(editor.level.grid.get_cell(8, 20), Tile.AIR, "a paste is one undo step")
	check_eq(editor.level.grid.get_cell(9, 21), Tile.AIR)


func test_paste_is_clipped_to_the_level() -> void:
	editor.set_brush(LevelEditor.Brush.DIRT)
	_paint(Vector2i(4, 4))
	editor.begin_selection(Vector2i(4, 4))
	editor.update_selection(Vector2i(6, 6))
	editor.finish_selection()
	editor.paste_at(Vector2i(39, 14))  # Mostly outside the grid.
	check_eq(editor.level.grid.cols, 40)
	check_eq(editor.level.grid.get_cell(14, 39), Tile.DIRT)


func test_resize_clamps_and_keeps_the_start_inside() -> void:
	editor.resize(1000, 1)
	check_eq(editor.level.grid.cols, GameConstants.MAX_LEVEL_COLS)
	check_eq(editor.level.grid.rows, GameConstants.MIN_LEVEL_ROWS)

	editor.set_brush(LevelEditor.Brush.PLAYER)
	_paint(Vector2i(150, 5))
	editor.resize(30, 20)
	check(editor.level.grid.is_interior(editor.level.start_cell.y, editor.level.start_cell.x), "start moved inside")
	check_eq(
		editor.level.grid.get_cell(editor.level.start_cell.y, editor.level.start_cell.x), Tile.AIR
	)
	check_eq(editor.level.grid.get_cell(0, 0), Tile.STEEL)
	check_eq(editor.level.grid.get_cell(19, 29), Tile.STEEL)


func test_resize_to_the_same_size_does_nothing() -> void:
	editor.resize(40, 15)
	check(not editor.is_dirty())
	check(not editor.can_undo())


func test_clear_keeps_only_the_border() -> void:
	editor.open(LevelLibrary.built_in_level(4))
	editor.clear()
	var grid: LevelGrid = editor.level.grid
	for r: int in grid.rows:
		for c: int in grid.cols:
			var expected: int = Tile.AIR if grid.is_interior(r, c) else Tile.STEEL
			check_eq(grid.get_cell(r, c), expected, "cell %d,%d" % [r, c])
	editor.undo()
	check(editor.level.equals(LevelLibrary.built_in_level(4)), "clearing can be undone")


func test_dirty_flag_follows_saves() -> void:
	_paint(Vector2i(5, 5))
	check(editor.is_dirty())
	editor.mark_saved()
	check(not editor.is_dirty())
	editor.undo()
	check(editor.is_dirty(), "undoing past a save is a change again")


func test_history_is_capped() -> void:
	editor.set_brush(LevelEditor.Brush.DIRT)
	for i: int in LevelEditor.MAX_HISTORY + 20:
		_paint(Vector2i(2 + i % 30, 2 + floori(float(i) / 30.0)))
	var undone: int = 0
	while editor.can_undo():
		editor.undo()
		undone += 1
	check_eq(undone, LevelEditor.MAX_HISTORY)


func test_signals() -> void:
	var counts: Dictionary[String, int] = {"changed": 0, "brush": 0, "history": 0}
	editor.changed.connect(func() -> void: counts["changed"] += 1)
	editor.brush_changed.connect(func() -> void: counts["brush"] += 1)
	editor.history_changed.connect(func() -> void: counts["history"] += 1)
	editor.set_brush(LevelEditor.Brush.STEEL)
	check_eq(counts["brush"], 1)
	editor.set_brush(LevelEditor.Brush.STEEL)
	check_eq(counts["brush"], 1, "choosing the same brush again is not a change")
	_paint(Vector2i(5, 5))
	check_eq(counts["changed"], 1)
	check_eq(counts["history"], 1)


func _paint(cell: Vector2i) -> void:
	editor.begin_stroke()
	editor.stroke_to(cell, false)
	editor.end_stroke()
