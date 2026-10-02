extends TestCase
## Level grid, codec, validator and the built-in level library.


func test_grid_reads_and_writes_are_bounds_safe() -> void:
	var grid: LevelGrid = LevelGrid.new(4, 3)
	check_eq(grid.cols, 4)
	check_eq(grid.rows, 3)
	grid.set_cell(1, 2, Tile.DIRT)
	check_eq(grid.get_cell(1, 2), Tile.DIRT)
	check_eq(grid.get_cell(-1, 0), Tile.AIR, "above the grid")
	check_eq(grid.get_cell(0, 4), Tile.AIR, "right of the grid")
	grid.set_cell(9, 9, Tile.STEEL)  # Must be ignored, not crash.
	check(grid.is_interior(1, 1))
	check(not grid.is_interior(0, 1))
	check(not grid.is_interior(1, 3))
	check_near(grid.pixel_width(), 160.0)
	check_near(grid.pixel_height(), 120.0)


func test_grid_duplicate_is_independent() -> void:
	var grid: LevelGrid = LevelGrid.new(3, 3)
	var copy: LevelGrid = grid.duplicate_grid()
	copy.set_cell(1, 1, Tile.GOAL)
	check_eq(grid.get_cell(1, 1), Tile.AIR)
	check(not grid.equals(copy))
	check(grid.equals(grid.duplicate_grid()))


func test_grid_resize_keeps_interior_and_reborders() -> void:
	var data: LevelData = LevelLibrary.built_in_level(2)
	var bigger: LevelGrid = data.grid.resized(30, 20)
	check_eq(bigger.cols, 30)
	check_eq(bigger.rows, 20)
	check_eq(bigger.get_cell(12, 22), Tile.DIRT, "interior tile kept")
	check_eq(bigger.get_cell(0, 15), Tile.STEEL, "new top border")
	check_eq(bigger.get_cell(19, 29), Tile.STEEL, "new corner")
	check_eq(bigger.get_cell(14, 5), Tile.AIR, "old bottom border is dropped")
	var smaller: LevelGrid = data.grid.resized(10, 10)
	check_eq(smaller.get_cell(9, 9), Tile.STEEL)
	check_eq(smaller.get_cell(5, 5), Tile.AIR)


func test_decode_maps_every_character() -> void:
	var data: LevelData = LevelLibrary.built_in_level(21)  # The tile showcase level.
	check_eq(data.start_cell, Vector2i(1, 13))
	check_eq(data.grid.get_cell(13, 1), Tile.AIR, "the start marker leaves air behind")
	check_eq(data.grid.get_cell(13, 3), Tile.DIRT)
	check_eq(data.grid.get_cell(13, 5), Tile.STEEL)
	check_eq(data.grid.get_cell(13, 7), Tile.SPIKE_UP)
	check_eq(data.grid.get_cell(13, 9), Tile.GOAL)
	check_eq(data.grid.get_cell(10, 3), Tile.BOUNCY)
	check_eq(data.grid.get_cell(10, 5), Tile.GLASS)
	check_eq(data.grid.get_cell(10, 7), Tile.VOID)
	var sideways: LevelData = LevelLibrary.built_in_level(14)
	check_eq(sideways.grid.get_cell(9, 8), Tile.SPIKE_LEFT)
	check_eq(sideways.grid.get_cell(9, 10), Tile.SPIKE_RIGHT)
	check_eq(sideways.grid.get_cell(10, 9), Tile.SPIKE_DOWN)


func test_start_position_is_centred_in_its_cell() -> void:
	var data: LevelData = LevelLibrary.built_in_level(1)
	check_eq(data.start_cell, Vector2i(1, 1))
	check_near(data.start_x(), 43.0)
	check_near(data.start_y(), 43.0)


func test_encode_round_trips_every_built_in_level() -> void:
	var sources: Array[PackedStringArray] = [LevelLibrary.default_rows(), LevelLibrary.boss_rows()]
	for slot: int in LevelLibrary.authored_slots():
		sources.append(LevelLibrary.built_in_rows(slot))
	for rows: PackedStringArray in sources:
		var data: LevelData = LevelCodec.decode(rows)
		var again: LevelData = LevelCodec.decode(LevelCodec.encode(data))
		check(data.equals(again), "decode(encode(level)) differs")
		check_eq(data.grid.rows, rows.size())
		check_eq(data.grid.cols, rows[0].length())


func test_short_rows_are_padded_with_air() -> void:
	# Slot 17's last row is one character short in the designer's data.
	var rows: PackedStringArray = LevelLibrary.built_in_rows(17)
	check_eq(rows[14].length(), 24)
	var data: LevelData = LevelCodec.decode(rows)
	check_eq(data.grid.cols, 25)
	check_eq(data.grid.get_cell(14, 24), Tile.AIR)


func test_missing_start_marker_falls_back_to_a_free_cell() -> void:
	var rows: PackedStringArray = LevelLibrary.default_rows().duplicate()
	rows[1] = rows[1].replace("P", ".")
	var data: LevelData = LevelCodec.decode(rows)
	check_eq(data.start_cell, Vector2i(1, 1))
	check_eq(data.grid.get_cell(data.start_cell.y, data.start_cell.x), Tile.AIR)


func test_library_slots() -> void:
	check_eq(LevelLibrary.authored_slots().size(), 22)
	check(LevelLibrary.has_authored_layout(1))
	check(not LevelLibrary.has_authored_layout(10))
	check(not LevelLibrary.has_authored_layout(23))
	check_eq(LevelLibrary.built_in_rows(10), LevelLibrary.boss_rows(), "slot 10 uses the boss arena")
	check_eq(LevelLibrary.built_in_rows(30), LevelLibrary.boss_rows(), "slot 30 uses the boss arena")
	check_eq(LevelLibrary.built_in_rows(23), LevelLibrary.default_rows(), "slot 23 is a placeholder")
	check_eq(LevelLibrary.built_in_rows(50), LevelLibrary.default_rows(), "slot 50 is a placeholder")
	check_eq(LevelLibrary.default_rows().size(), 15)
	check_eq(LevelLibrary.default_rows()[0].length(), 40)
	check_eq(LevelLibrary.boss_rows()[0].length(), 50)
	check_eq(LevelLibrary.big_world_rows().size(), 30)
	check_eq(LevelLibrary.big_world_rows()[0].length(), 128)


func test_library_boss_slots() -> void:
	check_eq(LevelLibrary.boss_kind_for_slot(10), BossState.Kind.WORLD_1)
	check_eq(LevelLibrary.boss_kind_for_slot(20), BossState.Kind.WORLD_2)
	check_eq(LevelLibrary.boss_kind_for_slot(30), BossState.Kind.WORLD_3)
	check_eq(LevelLibrary.boss_kind_for_slot(40), BossState.Kind.WORLD_4)
	check_eq(LevelLibrary.boss_kind_for_slot(50), BossState.Kind.NONE, "world 5 has no boss yet")
	check_eq(LevelLibrary.boss_kind_for_slot(9), BossState.Kind.NONE)
	check(LevelLibrary.is_placeholder(50))
	check(LevelLibrary.is_placeholder(23))
	check(not LevelLibrary.is_placeholder(30))
	check(not LevelLibrary.is_placeholder(1))


func test_world_and_level_numbering() -> void:
	check_eq(GameConstants.world_of_slot(1), 1)
	check_eq(GameConstants.world_of_slot(10), 1)
	check_eq(GameConstants.world_of_slot(11), 2)
	check_eq(GameConstants.world_of_slot(50), 5)
	check_eq(GameConstants.level_in_world(1), 1)
	check_eq(GameConstants.level_in_world(10), 10)
	check_eq(GameConstants.level_in_world(11), 1)
	check_eq(GameConstants.level_in_world(50), 10)


func test_validator_accepts_built_in_levels() -> void:
	for slot: int in LevelLibrary.authored_slots():
		check_eq(LevelValidator.problem_with(LevelLibrary.built_in_rows(slot)), "", "slot %d" % slot)
	check_eq(LevelValidator.problem_with(LevelLibrary.default_rows()), "")


func test_validator_rejects_malformed_levels() -> void:
	var too_small: PackedStringArray = ["@@@", "@P@", "@@@"]
	check(not LevelValidator.problem_with(too_small).is_empty(), "too few rows")

	var narrow: PackedStringArray = LevelLibrary.default_rows().duplicate()
	for r: int in narrow.size():
		narrow[r] = narrow[r].substr(0, 5)
	check(not LevelValidator.problem_with(narrow).is_empty(), "too narrow")

	var unknown: PackedStringArray = LevelLibrary.default_rows().duplicate()
	unknown[3] = unknown[3].substr(0, 5) + "?" + unknown[3].substr(6)
	check(LevelValidator.problem_with(unknown).contains("?"), "unknown character is named")

	var long_row: PackedStringArray = LevelLibrary.default_rows().duplicate()
	long_row[4] += "@@"
	check(not LevelValidator.problem_with(long_row).is_empty(), "row longer than the first")


func test_rows_from_json() -> void:
	check_eq(LevelValidator.rows_from_json(["ab", "cd"]), PackedStringArray(["ab", "cd"]))
	check(LevelValidator.rows_from_json(["ab", 3]).is_empty(), "non-string entry")
	check(LevelValidator.rows_from_json("ab").is_empty(), "not an array")
	check(LevelValidator.rows_from_json(null).is_empty(), "null")
