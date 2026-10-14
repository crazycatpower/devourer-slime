class_name LevelValidator
extends RefCounted
## Checks level text before it is accepted from outside the game (imports and
## save files). Returns problems as messages for the player instead of letting
## malformed data reach the simulation.


## Returns an empty string when [param rows] is a usable level, otherwise a
## message describing the first problem found.
static func problem_with(rows: PackedStringArray) -> String:
	var row_count: int = rows.size()
	if row_count < GameConstants.MIN_LEVEL_ROWS or row_count > GameConstants.MAX_LEVEL_ROWS:
		return "關卡高度必須在 %d 到 %d 列之間（目前 %d 列）。" % [
			GameConstants.MIN_LEVEL_ROWS, GameConstants.MAX_LEVEL_ROWS, row_count,
		]
	var col_count: int = rows[0].length()
	if col_count < GameConstants.MIN_LEVEL_COLS or col_count > GameConstants.MAX_LEVEL_COLS:
		return "關卡寬度必須在 %d 到 %d 格之間（目前 %d 格）。" % [
			GameConstants.MIN_LEVEL_COLS, GameConstants.MAX_LEVEL_COLS, col_count,
		]
	for r: int in row_count:
		var line: String = rows[r]
		# Shorter rows are tolerated (the missing cells are air), because the
		# saved files may contain them; longer rows would lose tiles.
		if line.length() > col_count:
			return "第 %d 列比第一列長（%d > %d）。" % [r + 1, line.length(), col_count]
		for c: int in line.length():
			if not LevelCodec.is_known_char(line[c]):
				return "第 %d 列第 %d 格有無法辨識的字元「%s」。" % [r + 1, c + 1, line[c]]
	return ""


## Converts a parsed JSON value into level rows. Returns an empty array when
## it is not an array made only of strings.
static func rows_from_json(value: Variant) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if value is Dictionary:
		var document: Dictionary = value
		return rows_from_json(document.get("rows", null))
	if not value is Array:
		return out
	var list: Array = value
	for item: Variant in list:
		if not item is String:
			return PackedStringArray()
		out.append(item as String)
	return out


static func problem_with_document(value: Variant) -> String:
	var rows: PackedStringArray = rows_from_json(value)
	var problem: String = problem_with(rows)
	if not problem.is_empty():
		return problem
	if value is Dictionary:
		var document: Dictionary = value
		for layer: String in ["wires", "sensors", "rails"]:
			var label: String = "連線" if layer == "wires" else ("軌道" if layer == "rails" else "感測器")
			var wire_value: Variant = document.get(layer, [])
			if not wire_value is Array:
				return "%s資料格式錯誤。" % label
			var wires: Array = wire_value
			if wires.size() > rows.size() * rows[0].length():
				return "%s資料格式錯誤。" % label
			for pair: Variant in wires:
				if not pair is Array:
					return "%s座標格式錯誤。" % label
				var coordinates: Array = pair
				if coordinates.size() != (3 if layer == "rails" else 2):
					return "%s座標格式錯誤。" % label
				for coordinate: Variant in coordinates:
					if not (coordinate is int or coordinate is float):
						return "%s座標必須是整數。" % label
					var number: float = coordinate as float
					if not is_finite(number) or number != floorf(number):
						return "%s座標必須是整數。" % label
				if layer == "rails" and not Tile.is_rail(coordinates[2] as int):
					return "軌道方向格式錯誤。"
				if coordinates[0] < 0 or coordinates[0] >= rows[0].length() or coordinates[1] < 0 or coordinates[1] >= rows.size():
					return "%s座標超出關卡範圍。" % label
	return ""
