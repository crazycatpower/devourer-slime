class_name SolidBox
extends RefCounted
## Axis-aligned box of one solid tile, used by the player's collision solver.

var x: float = 0.0
var y: float = 0.0
var w: float = Tile.SIZE
var h: float = Tile.SIZE
var type: int = Tile.AIR


static func make(p_x: float, p_y: float, p_type: int) -> SolidBox:
	var box: SolidBox = SolidBox.new()
	box.x = p_x
	box.y = p_y
	box.type = p_type
	return box
