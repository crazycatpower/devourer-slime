class_name LevelCodec
extends RefCounted
## Converts between the text level format and [LevelData].
##
## The text format is the web version's: an array of strings with one
## character per tile. Keeping it lets level JSON move between both versions.

const CHAR_AIR: String = "."
const CHAR_PLAYER: String = "P"

const _CHAR_TO_TILE: Dictionary[String, int] = {
	".": Tile.AIR,
	"@": Tile.STEEL,
	"#": Tile.DIRT,
	"~": Tile.SPIKE_UP,
	"^": Tile.SPIKE_UP,
	">": Tile.SPIKE_RIGHT,
	"v": Tile.SPIKE_DOWN,
	"<": Tile.SPIKE_LEFT,
	"$": Tile.GOAL,
	"*": Tile.BOUNCY,
	"X": Tile.GLASS,
	"O": Tile.VOID,
}

## Partially eaten blocks are saved as their pristine tile.
const _TILE_TO_CHAR: Dictionary[int, String] = {
	Tile.AIR: ".",
	Tile.DIRT: "#",
	Tile.DIRT_EATEN_1: "#",
	Tile.DIRT_EATEN_2: "#",
	Tile.STEEL: "@",
	Tile.GOAL: "$",
	Tile.SPIKE_UP: "~",
	Tile.SPIKE_RIGHT: ">",
	Tile.SPIKE_DOWN: "v",
	Tile.SPIKE_LEFT: "<",
	Tile.BOUNCY: "*",
	Tile.BOUNCY_EATEN_1: "*",
	Tile.BOUNCY_EATEN_2: "*",
	Tile.GLASS: "X",
	Tile.VOID: "O",
}


## True when [param ch] is a character the format defines.
static func is_known_char(ch: String) -> bool:
	return ch == CHAR_PLAYER or _CHAR_TO_TILE.has(ch)


## Builds a level from text rows.
##
## The first row defines the width; shorter rows are padded with air and
## longer rows are cut. Unknown characters become air. When several start
## markers exist the last one wins, and when none exists the first free
## interior cell is used.
static func decode(text_rows: PackedStringArray) -> LevelData:
	var data: LevelData = LevelData.new()
	var row_count: int = text_rows.size()
	var col_count: int = text_rows[0].length() if row_count > 0 else 0
	var grid: LevelGrid = LevelGrid.new(col_count, row_count)
	var start: Vector2i = Vector2i(-1, -1)

	for r: int in row_count:
		var line: String = text_rows[r]
		var limit: int = mini(line.length(), col_count)
		for c: int in limit:
			var ch: String = line[c]
			if ch == CHAR_PLAYER:
				start = Vector2i(c, r)
			else:
				var tile: int = _CHAR_TO_TILE.get(ch, Tile.AIR)
				grid.set_cell(r, c, tile)

	data.grid = grid
	data.start_cell = start if start.x >= 0 else find_free_cell(grid)
	return data


static func encode(data: LevelData) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var grid: LevelGrid = data.grid
	for r: int in grid.rows:
		var line: String = ""
		for c: int in grid.cols:
			if c == data.start_cell.x and r == data.start_cell.y:
				line += CHAR_PLAYER
			else:
				var ch: String = _TILE_TO_CHAR.get(grid.get_cell(r, c), CHAR_AIR)
				line += ch
		out.append(line)
	return out


## First air cell inside the border, scanning rows then columns.
static func find_free_cell(grid: LevelGrid) -> Vector2i:
	for r: int in range(1, grid.rows - 1):
		for c: int in range(1, grid.cols - 1):
			if grid.get_cell(r, c) == Tile.AIR:
				return Vector2i(c, r)
	return Vector2i(1, 1)
