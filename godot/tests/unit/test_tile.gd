extends TestCase
## Tile classification and stable save IDs.

const SOLID: Array[int] = [1, 2, 5, 6, 11, 12, 15, 25]
const EATABLE: Array[int] = [1, 5, 11, 12, 15, 25]
const SPIKES: Array[int] = [4, 7, 41, 42, 43]
const BOUNCY: Array[int] = [5, 15, 25]


func test_classification_of_every_id() -> void:
	for t: int in range(-1, 60):
		check_eq(Tile.is_solid(t), t in SOLID, "is_solid(%d)" % t)
		check_eq(Tile.is_eatable(t), t in EATABLE, "is_eatable(%d)" % t)
		check_eq(Tile.is_spike(t), t in SPIKES, "is_spike(%d)" % t)
		check_eq(Tile.is_bouncy(t), t in BOUNCY, "is_bouncy(%d)" % t)


func test_ids_are_the_save_format_values() -> void:
	check_eq(Tile.AIR, 0)
	check_eq(Tile.DIRT, 1)
	check_eq(Tile.STEEL, 2)
	check_eq(Tile.GOAL, 3)
	check_eq(Tile.SPIKE_UP, 4)
	check_eq(Tile.BOUNCY, 5)
	check_eq(Tile.GLASS, 6)
	check_eq(Tile.VOID, 7)
	check_eq(Tile.DIRT_EATEN_1, 11)
	check_eq(Tile.DIRT_EATEN_2, 12)
	check_eq(Tile.BOUNCY_EATEN_1, 15)
	check_eq(Tile.BOUNCY_EATEN_2, 25)
	check_eq(Tile.SPIKE_RIGHT, 41)
	check_eq(Tile.SPIKE_DOWN, 42)
	check_eq(Tile.SPIKE_LEFT, 43)


func test_hazard_boxes() -> void:
	# Tile at row 2, column 3 starts at (120, 80).
	check_eq(Tile.hazard_rect(2, 3, Tile.SPIKE_UP), Rect2(123, 104, 34, 16))
	check_eq(Tile.hazard_rect(2, 3, Tile.SPIKE_RIGHT), Rect2(120, 83, 16, 34))
	check_eq(Tile.hazard_rect(2, 3, Tile.SPIKE_DOWN), Rect2(123, 80, 34, 16))
	check_eq(Tile.hazard_rect(2, 3, Tile.SPIKE_LEFT), Rect2(144, 83, 16, 34))
	check_eq(Tile.hazard_rect(2, 3, Tile.VOID), Rect2(132, 92, 16, 16))


func test_hazard_hits_only_the_lethal_part() -> void:
	# A floor spike's top 24 units are safe.
	check(not Tile.hazard_hits(120.0, 60.0, 34.0, 34.0, 2, 3, Tile.SPIKE_UP), "above the spikes")
	check(Tile.hazard_hits(120.0, 75.0, 34.0, 34.0, 2, 3, Tile.SPIKE_UP), "into the spikes")
	# Touching a void's edge is safe; reaching its core is not.
	check(not Tile.hazard_hits(100.0, 80.0, 30.0, 34.0, 2, 3, Tile.VOID), "void edge")
	check(Tile.hazard_hits(110.0, 80.0, 30.0, 34.0, 2, 3, Tile.VOID), "void core")


func test_cell_of() -> void:
	check_eq(Tile.cell_of(0.0), 0)
	check_eq(Tile.cell_of(39.999), 0)
	check_eq(Tile.cell_of(40.0), 1)
	check_eq(Tile.cell_of(-0.001), -1)
