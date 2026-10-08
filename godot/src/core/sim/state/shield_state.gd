class_name ShieldState
extends RefCounted
## One glass shield orbiting the glass slime.

## Ticks a shield flashes and draws back before it is thrown as a bomb.
const WINDUP_TICKS: int = 45

var active: bool = true
var angle_offset: float = 0.0
var radius: float = BossState.SHIELD_ORBIT_RADIUS
## World position of the shield centre.
var cx: float = 0.0
var cy: float = 0.0
## Set once the shield has been picked to be thrown: it leaves the orbit,
## holds [member hold_offset] from the boss centre and counts down.
var winding_up: bool = false
var windup_timer: int = 0
var hold_offset: Vector2 = Vector2.ZERO
