class_name PlayerState
extends RefCounted
## Mutable state of the player slime inside a [GameSim].

const WIDTH: float = 34.0
const HEIGHT: float = 34.0

var x: float = 0.0
var y: float = 0.0
## Position at the start of the current tick, for render interpolation.
var prev_x: float = 0.0
var prev_y: float = 0.0
var vx: float = 0.0
var vy: float = 0.0
var w: float = WIDTH
var h: float = HEIGHT
## Horizontal facing: 1 (right) or -1 (left).
var facing: int = 1

var has_block: bool = false
var carried_block_type: int = Tile.AIR
## How many times the carried block has been swallowed (1 or 2).
var carried_block_eaten_count: int = 0

## 0..1 progress of the swallow in flight.
var eating_progress: float = 0.0
var has_eating_target: bool = false
var eating_target_r: int = 0
var eating_target_c: int = 0
var eating_target_is_boss_cell: bool = false

var in_bullet_time: bool = false
## Set right after swallowing so a still-held shoot button does not fire.
var waiting_for_shoot_release: bool = false

var dead: bool = false
var won: bool = false
var grounded: bool = false
var jump_buffer: int = 0
var coyote_timer: int = 0
var is_jumping: bool = false
## Height the current fall started from; drives bounce strength.
var fall_start_y: float = 0.0
## Ticks left during which horizontal input is ignored after a wall bounce.
var wall_bounce_timer: int = 0
## What is left of the sideways kick from the last spit, in units per tick.
var recoil_vx: float = 0.0

## Squash and stretch factors, purely visual.
var scale_x: float = 1.0
var scale_y: float = 1.0


func center_x() -> float:
	return x + w / 2.0


func center_y() -> float:
	return y + h / 2.0


func place_at(px: float, py: float) -> void:
	x = px
	y = py
	prev_x = px
	prev_y = py
	fall_start_y = py


func set_eating_target(r: int, c: int, is_boss_cell: bool) -> void:
	has_eating_target = true
	eating_target_r = r
	eating_target_c = c
	eating_target_is_boss_cell = is_boss_cell


func clear_eating() -> void:
	eating_progress = 0.0
	has_eating_target = false
