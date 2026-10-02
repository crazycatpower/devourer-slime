class_name BulletTimeGauge
extends RefCounted
## Budget of slow motion while the player aims a spit.
##
## Bullet time is a property of how fast the simulation is stepped, not of the
## simulation itself, so its budget is kept by the game screen and measured in
## real seconds. Holding the shoot button drains the gauge; once it is empty
## the aim line stays but time runs at full speed until the button is let go,
## and the gauge refills whenever the player is not aiming.

## Real seconds of slow motion a full gauge buys.
const FULL_SECONDS: float = 3.0
## Real seconds an empty gauge takes to refill.
const REFILL_SECONDS: float = 4.0

## Bullet time left, 0..1.
var energy: float = 1.0

## The gauge ran dry during the current hold.
var _exhausted: bool = false


## Advances the gauge by [param delta] seconds. [param aiming] is whether the
## player is holding a spit. Returns true when time should run slow.
func spend(aiming: bool, delta: float) -> bool:
	if not aiming:
		_exhausted = false
		energy = minf(1.0, energy + delta / REFILL_SECONDS)
		return false
	if _exhausted:
		return false
	energy -= delta / FULL_SECONDS
	if energy <= 0.0:
		energy = 0.0
		_exhausted = true
		return false
	return true


func refill() -> void:
	energy = 1.0
	_exhausted = false
