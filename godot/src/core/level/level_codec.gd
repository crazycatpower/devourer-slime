class_name LevelCodec
extends RefCounted
## Converts between the text level format and [LevelData].
##
## The text format is an array of strings with one
## character per tile, shared by built-in and custom levels.

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
	"S": Tile.SENSOR,
	"R": Tile.RAIL_RIGHT,
	"L": Tile.RAIL_LEFT,
	"U": Tile.RAIL_UP,
	"D": Tile.RAIL_DOWN,
	"A": Tile.SAND,
	"I": Tile.ICE,
	"T": Tile.TNT,
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
	Tile.SENSOR: "S",
	Tile.RAIL_RIGHT: "R",
	Tile.RAIL_LEFT: "L",
	Tile.RAIL_UP: "U",
	Tile.RAIL_DOWN: "D",
	Tile.SAND: "A",
	Tile.ICE: "I",
	Tile.TNT: "T",
}


## Legacy levels remain row arrays. Only wired levels need the extended format.
static func encode_document(data: LevelData) -> Variant:
	var rows: Array = Array(encode(data))
	if data.grid.wires.is_empty() and data.grid.sensors.is_empty() and data.grid.rails.is_empty():
		return rows
	var wires: Array = []
	for cell: Vector2i in data.grid.wires:
		wires.append([cell.x, cell.y])
	var sensors: Array = []
	for cell: Vector2i in data.grid.sensors:
		sensors.append([cell.x, cell.y])
	var rails: Array = []
	for cell: Vector2i in data.grid.rails:
		rails.append([cell.x, cell.y, data.grid.rails[cell]])
	return {"rows": rows, "wires": wires, "sensors": sensors, "rails": rails}


static func decode_document(value: Variant) -> LevelData:
	var data: LevelData = decode(LevelValidator.rows_from_json(value))
	if value is Dictionary:
		var document: Dictionary = value
		for layer: String in ["wires", "sensors", "rails"]:
			var cell_list: Variant = document.get(layer, [])
			if cell_list is Array:
				for pair: Variant in cell_list:
					if not pair is Array:
						continue
					var coordinates: Array = pair
					if coordinates.size() == (3 if layer == "rails" else 2) and (coordinates[0] is int or coordinates[0] is float) and (coordinates[1] is int or coordinates[1] is float):
						var cell: Vector2i = Vector2i(coordinates[0] as int, coordinates[1] as int)
						if layer == "wires":
							data.grid.set_wire(cell, true)
						elif layer == "rails":
							if coordinates[2] is int or coordinates[2] is float:
								data.grid.set_rail(cell, coordinates[2] as int)
						else:
							data.grid.set_sensor(cell, true)
	return data


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
				if grid.get_cell(r, c) == Tile.AIR and grid.sensors.has(Vector2i(c, r)):
					ch = "S"
				elif grid.get_cell(r, c) == Tile.AIR and grid.rails.has(Vector2i(c, r)):
					ch = _TILE_TO_CHAR[grid.rails[Vector2i(c, r)]]
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
