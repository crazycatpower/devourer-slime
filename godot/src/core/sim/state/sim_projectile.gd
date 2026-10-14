class_name SimProjectile
extends RefCounted
## A block in flight: spat by the player or fired by a boss.

var x: float = 0.0
var y: float = 0.0
var prev_x: float = 0.0
var prev_y: float = 0.0
var vx: float = 0.0
var vy: float = 0.0
var w: float = Tile.SIZE
var h: float = Tile.SIZE
## Consumed by a boss; removed at the start of the next projectile update.
var dead: bool = false
var type: int = Tile.DIRT
## How many times the block was swallowed before being spat (1 or 2).
var eaten_count: int = 0
var bounce_count: int = 0
## Boss projectiles kill the player on contact.
var is_enemy: bool = false
## Armed TNT keeps the same 0.4-second fuse through flight and impact.
var fuse_ticks: int = -1
var fuse_start_tick: int = -1

var returned_charge: bool = false
