class_name ShieldState
extends RefCounted
## One glass shield orbiting the World 3 boss.

enum Mode { ORBIT, DETACHING }

## Ticks a shield glows outside the ring before it launches at the player.
const DETACH_TICKS: int = 35

var active: bool = true
var mode: Mode = Mode.ORBIT
var angle_offset: float = 0.0
var radius: float = BossState.SHIELD_ORBIT_RADIUS
var detaching_timer: int = 0
## World position of the shield centre.
var cx: float = 0.0
var cy: float = 0.0
