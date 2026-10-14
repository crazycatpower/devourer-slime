class_name GlassBomb
extends RefCounted
## A shield thrown as glass. First contact stops it; only contacted glass breaks.

## Centre of the bomb.
var x: float = 0.0
var y: float = 0.0
var prev_x: float = 0.0
var prev_y: float = 0.0
var vx: float = 0.0
var vy: float = 0.0
## True on floor impact; the bomb is removed in that same simulation tick.
var landed: bool = false

## Solid cells touched by the leading edge on the impact step.
var hit_cells: Array[Vector2i] = []
