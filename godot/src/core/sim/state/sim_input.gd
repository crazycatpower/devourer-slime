class_name SimInput
extends RefCounted
## Input sampled for one simulation tick.

var left: bool = false
var right: bool = false
## Jump button held (releasing early shortens the jump).
var jump: bool = false
var eat: bool = false
var shoot: bool = false
## Edges: true only on the tick the button changed.
var jump_pressed: bool = false
var shoot_released: bool = false
## Mouse position relative to the top-left of the view, in world units.
var mouse_x: float = 0.0
var mouse_y: float = 0.0
