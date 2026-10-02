class_name LevelData
extends RefCounted
## A level layout: the tile grid plus the cell the player starts in.

## The player box is smaller than a tile and starts centred inside its cell.
const START_INSET: float = (Tile.SIZE - PlayerState.WIDTH) / 2.0

var grid: LevelGrid = LevelGrid.new()
## Start cell as (column, row).
var start_cell: Vector2i = Vector2i(1, 1)


func duplicate_level() -> LevelData:
	var copy: LevelData = LevelData.new()
	copy.grid = grid.duplicate_grid()
	copy.start_cell = start_cell
	return copy


func equals(other: LevelData) -> bool:
	return other != null and start_cell == other.start_cell and grid.equals(other.grid)


func start_x() -> float:
	return float(start_cell.x) * Tile.SIZE + START_INSET


func start_y() -> float:
	return float(start_cell.y) * Tile.SIZE + START_INSET
