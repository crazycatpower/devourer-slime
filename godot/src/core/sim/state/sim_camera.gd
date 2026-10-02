class_name SimCamera
extends RefCounted
## Camera state: top-left corner of the visible area in world units.
##
## The camera belongs to the simulation because gameplay reads it (the aim
## point is the mouse position offset by the camera, and boss attacks target
## the visible columns). It advances once per 60 Hz frame via [method follow].

const FOLLOW_RATE: float = 0.1
const SHAKE_DECAY: float = 0.9
const SHAKE_CUTOFF: float = 0.5

var x: float = 0.0
var y: float = 0.0
var prev_x: float = 0.0
var prev_y: float = 0.0
## Current shake amplitude in world units.
var shake: float = 0.0


## Clamps a camera coordinate; levels smaller than the view are centred.
static func limit(value: float, level_extent: float, view_extent: float) -> float:
	if level_extent <= view_extent:
		return (level_extent - view_extent) / 2.0
	return maxf(0.0, minf(value, level_extent - view_extent))


## Centres the camera on a point immediately.
func snap_to(target_x: float, target_y: float, level: LevelGrid) -> void:
	x = limit(target_x - GameConstants.VIEW_WIDTH / 2.0, level.pixel_width(), GameConstants.VIEW_WIDTH)
	y = limit(target_y - GameConstants.VIEW_HEIGHT / 2.0, level.pixel_height(), GameConstants.VIEW_HEIGHT)
	prev_x = x
	prev_y = y


## Eases toward a point and decays the shake. Call once per 60 Hz frame.
func follow(target_x: float, target_y: float, level: LevelGrid) -> void:
	prev_x = x
	prev_y = y
	x += (target_x - GameConstants.VIEW_WIDTH / 2.0 - x) * FOLLOW_RATE
	y += (target_y - GameConstants.VIEW_HEIGHT / 2.0 - y) * FOLLOW_RATE
	apply_limits(level)
	decay_shake()


func apply_limits(level: LevelGrid) -> void:
	x = limit(x, level.pixel_width(), GameConstants.VIEW_WIDTH)
	y = limit(y, level.pixel_height(), GameConstants.VIEW_HEIGHT)


func decay_shake() -> void:
	if shake > SHAKE_CUTOFF:
		shake *= SHAKE_DECAY
	else:
		shake = 0.0
