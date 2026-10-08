class_name GlassBomb
extends RefCounted
## A bomb lobbed by the glass slime. It bursts on first contact,
## killing nearby and shattering the glass around it.

## Centre of the bomb.
var x: float = 0.0
var y: float = 0.0
var prev_x: float = 0.0
var prev_y: float = 0.0
var vx: float = 0.0
var vy: float = 0.0
## True on floor impact; the bomb is removed in that same simulation tick.
var landed: bool = false
