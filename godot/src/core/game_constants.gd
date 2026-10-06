class_name GameConstants
extends RefCounted
## Gameplay tuning constants.
##
## Shared movement and timing constants.
## All velocities and accelerations are expressed per simulation tick, and the
## simulation runs at [constant TICKS_PER_SECOND].

const TICKS_PER_SECOND: int = 60

const TILE_SIZE: float = 40.0

## The reference canvas is 960x540 with world zoom 24/26.
const CANVAS_WIDTH: float = 960.0
const CANVAS_HEIGHT: float = 540.0
const CAMERA_ZOOM: float = 24.0 / 26.0
## Size of the visible world area, in world units.
const VIEW_WIDTH: float = CANVAS_WIDTH / CAMERA_ZOOM
const VIEW_HEIGHT: float = CANVAS_HEIGHT / CAMERA_ZOOM

const GRAVITY: float = 0.5
## The player's jump arc lasts this many times longer in the air, with the same
## height and horizontal reach: airborne movement is stepped at 1 / this speed.
const AIR_TIME_STRETCH: float = 1.25
const AIR_STEP: float = 1.0 / AIR_TIME_STRETCH
const JUMP_FORCE: float = 12.0
const MAX_SPEED: float = 4.2
const RECOIL_FORCE: float = 10.0
const BULLET_SPEED: float = 12.0

const WORLD_COUNT: int = 5
const LEVELS_PER_WORLD: int = 10
const SLOT_COUNT: int = WORLD_COUNT * LEVELS_PER_WORLD

## Level editor canvas limits.
const MIN_LEVEL_COLS: int = 10
const MAX_LEVEL_COLS: int = 200
const MIN_LEVEL_ROWS: int = 10
const MAX_LEVEL_ROWS: int = 120


## World index (1-based) that [param slot] (1-based) belongs to.
static func world_of_slot(slot: int) -> int:
	return floori(float(slot - 1) / float(LEVELS_PER_WORLD)) + 1


## Level index inside its world (1-based) for [param slot] (1-based).
static func level_in_world(slot: int) -> int:
	return posmod(slot - 1, LEVELS_PER_WORLD) + 1
