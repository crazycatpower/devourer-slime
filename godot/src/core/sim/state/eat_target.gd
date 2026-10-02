class_name EatTarget
extends RefCounted
## The block the player's mouth is pointing at.

var r: int = 0
var c: int = 0
var type: int = Tile.AIR
## True when (r, c) indexes the boss grid instead of the level grid.
var is_boss_cell: bool = false


static func make(p_r: int, p_c: int, p_type: int, p_is_boss_cell: bool) -> EatTarget:
	var target: EatTarget = EatTarget.new()
	target.r = p_r
	target.c = p_c
	target.type = p_type
	target.is_boss_cell = p_is_boss_cell
	return target
