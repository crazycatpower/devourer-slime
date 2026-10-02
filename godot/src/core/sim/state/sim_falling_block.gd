class_name SimFallingBlock
extends RefCounted
## A block shaken loose from the ceiling during a boss fight. Lethal on touch.

## Centre of the block.
var x: float = 0.0
var y: float = 0.0
var prev_x: float = 0.0
var prev_y: float = 0.0
var vy: float = 2.0
var type: int = Tile.DIRT
## Ticks the warning column is shown before the block starts to fall.
var delay: int = 0
var warning_color: Color = Palette.AMBER_600
