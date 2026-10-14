class_name Tile
extends RefCounted
## Tile identifiers and their gameplay classification.
##
## Numeric IDs are persisted in save data and must never be renumbered.

const SIZE: float = GameConstants.TILE_SIZE

const AIR: int = 0
const DIRT: int = 1
const STEEL: int = 2
const GOAL: int = 3
const SPIKE_UP: int = 4
const BOUNCY: int = 5
const GLASS: int = 6
const VOID: int = 7
const SENSOR: int = 8
const RAIL_RIGHT: int = 9
const SAND: int = 10
const ICE: int = 13
const RAIL_LEFT: int = 14
const RAIL_UP: int = 17
const RAIL_DOWN: int = 18
const TNT: int = 16
## Dirt that has been swallowed and spat back once / twice.
const DIRT_EATEN_1: int = 11
const DIRT_EATEN_2: int = 12
## Bouncy block that has been swallowed and spat back once / twice.
const BOUNCY_EATEN_1: int = 15
const BOUNCY_EATEN_2: int = 25
const SPIKE_RIGHT: int = 41
const SPIKE_DOWN: int = 42
const SPIKE_LEFT: int = 43


static func is_solid(t: int) -> bool:
	return (
		t == DIRT or t == STEEL or t == BOUNCY
		or t == DIRT_EATEN_1 or t == DIRT_EATEN_2
		or t == BOUNCY_EATEN_1 or t == BOUNCY_EATEN_2
		or t == GLASS or t == SAND or t == ICE or t == TNT
	)


static func is_eatable(t: int) -> bool:
	return (
		t == DIRT or t == DIRT_EATEN_1 or t == DIRT_EATEN_2
		or t == BOUNCY or t == BOUNCY_EATEN_1 or t == BOUNCY_EATEN_2
		or t == SAND or t == ICE or t == TNT
	)


static func is_rail(t: int) -> bool:
	return t in [RAIL_RIGHT, RAIL_LEFT, RAIL_UP, RAIL_DOWN]


static func rail_direction(t: int) -> Vector2i:
	match t:
		RAIL_UP: return Vector2i.UP
		RAIL_DOWN: return Vector2i.DOWN
		RAIL_LEFT: return Vector2i.LEFT
	return Vector2i.RIGHT


static func is_movable(t: int) -> bool:
	return is_solid(t) and t != STEEL and t != SENSOR and not is_rail(t)


## Tiles that kill on contact with their hazard box (spikes and the void core).
static func is_spike(t: int) -> bool:
	return t == SPIKE_UP or (t >= SPIKE_RIGHT and t <= SPIKE_LEFT) or t == VOID


static func is_bouncy(t: int) -> bool:
	return t == BOUNCY or t == BOUNCY_EATEN_1 or t == BOUNCY_EATEN_2


## Column/row index containing world coordinate [param v].
static func cell_of(v: float) -> int:
	return floori(v / SIZE)


## Lethal sub-rectangle of a hazard tile at ([param r], [param c]).
static func hazard_rect(r: int, c: int, type: int) -> Rect2:
	var tile_x: float = float(c) * SIZE
	var tile_y: float = float(r) * SIZE
	match type:
		SPIKE_UP:
			return Rect2(tile_x + 3.0, tile_y + 24.0, SIZE - 6.0, 16.0)
		SPIKE_RIGHT:
			return Rect2(tile_x, tile_y + 3.0, 16.0, SIZE - 6.0)
		SPIKE_DOWN:
			return Rect2(tile_x + 3.0, tile_y, SIZE - 6.0, 16.0)
		SPIKE_LEFT:
			return Rect2(tile_x + 24.0, tile_y + 3.0, 16.0, SIZE - 6.0)
		VOID:
			# Only the small centre square of a void block is lethal.
			return Rect2(tile_x + 12.0, tile_y + 12.0, SIZE - 24.0, SIZE - 24.0)
	return Rect2(tile_x, tile_y, SIZE, SIZE)


## True when the box (px, py, pw, ph) overlaps the hazard box of the tile.
static func hazard_hits(
	px: float, py: float, pw: float, ph: float, r: int, c: int, type: int
) -> bool:
	var box: Rect2 = hazard_rect(r, c, type)
	var sx: float = box.position.x
	var sy: float = box.position.y
	return px < sx + box.size.x and px + pw > sx and py < sy + box.size.y and py + ph > sy
