class_name LevelGrid
extends RefCounted
## Rectangular grid of [Tile] ids, addressed as (row, column).
##
## Reads outside the grid return [constant Tile.AIR] and writes outside the
## grid are ignored, so callers never index out of range.

var cols: int = 0
var rows: int = 0

var _cells: PackedInt32Array = PackedInt32Array()


func _init(p_cols: int = 0, p_rows: int = 0, fill: int = Tile.AIR) -> void:
	cols = maxi(p_cols, 0)
	rows = maxi(p_rows, 0)
	_cells.resize(cols * rows)
	_cells.fill(fill)


func in_bounds(r: int, c: int) -> bool:
	return r >= 0 and r < rows and c >= 0 and c < cols


## True for cells inside the grid that are not part of its outer ring.
func is_interior(r: int, c: int) -> bool:
	return r >= 1 and r < rows - 1 and c >= 1 and c < cols - 1


func get_cell(r: int, c: int) -> int:
	if r < 0 or r >= rows or c < 0 or c >= cols:
		return Tile.AIR
	return _cells[r * cols + c]


func set_cell(r: int, c: int, tile: int) -> void:
	if r < 0 or r >= rows or c < 0 or c >= cols:
		return
	_cells[r * cols + c] = tile


func pixel_width() -> float:
	return float(cols) * Tile.SIZE


func pixel_height() -> float:
	return float(rows) * Tile.SIZE


func duplicate_grid() -> LevelGrid:
	var copy: LevelGrid = LevelGrid.new()
	copy.cols = cols
	copy.rows = rows
	copy._cells = _cells.duplicate()
	return copy


## Adds [param count] rows of [param fill] below the last one.
func append_rows(count: int, fill: int = Tile.AIR) -> void:
	if count <= 0:
		return
	var old_size: int = _cells.size()
	rows += count
	_cells.resize(cols * rows)
	for i: int in range(old_size, _cells.size()):
		_cells[i] = fill


## Changes whenever a cell does; cheap enough to ask for every frame.
func content_hash() -> int:
	return hash(_cells)


## Hash of the cells in rows [param first_row] up to [param end_row] and
## columns [param first_col] up to [param end_col] (ends excluded). The part
## outside the grid is ignored.
func region_hash(first_row: int, first_col: int, end_row: int, end_col: int) -> int:
	var from_col: int = clampi(first_col, 0, cols)
	var to_col: int = clampi(end_col, 0, cols)
	var result: int = 17
	for r: int in range(clampi(first_row, 0, rows), clampi(end_row, 0, rows)):
		result = hash([result, _cells.slice(r * cols + from_col, r * cols + to_col)])
	return result


func equals(other: LevelGrid) -> bool:
	return other != null and cols == other.cols and rows == other.rows and _cells == other._cells


## Overwrites the outer ring of the grid with [param tile].
func fill_border(tile: int) -> void:
	for c: int in cols:
		set_cell(0, c, tile)
		set_cell(rows - 1, c, tile)
	for r: int in rows:
		set_cell(r, 0, tile)
		set_cell(r, cols - 1, tile)


## Returns a copy with new dimensions. Interior tiles are kept where they
## still fit, and the result always gets a fresh steel border.
func resized(new_cols: int, new_rows: int) -> LevelGrid:
	var result: LevelGrid = LevelGrid.new(new_cols, new_rows)
	for r: int in range(1, new_rows - 1):
		for c: int in range(1, new_cols - 1):
			if r < rows - 1 and c < cols - 1:
				result.set_cell(r, c, get_cell(r, c))
	result.fill_border(Tile.STEEL)
	return result


## Order-sensitive checksum of the grid contents, used by tests.
func checksum() -> int:
	var h: int = 7
	for value: int in _cells:
		h = (h * 31 + value) % 1000000007
	return h
