class_name SimRandom
extends RefCounted
## Small deterministic random generator (Lehmer / MINSTD).
##
## The simulation uses its own generator instead of the engine's so that a
## seed reproduces a run exactly on every platform and in simulation tests.

const _MODULUS: int = 2147483647
const _MULTIPLIER: int = 48271

## Number of values drawn so far; lets tests pinpoint where two runs diverge.
var draw_count: int = 0

var _state: int = 1


func _init(p_seed: int = 0) -> void:
	if p_seed == 0:
		randomize_seed()
	else:
		set_seed(p_seed)


func set_seed(p_seed: int) -> void:
	_state = posmod(p_seed, _MODULUS)
	if _state == 0:
		_state = 1


func randomize_seed() -> void:
	set_seed(int(Time.get_unix_time_from_system() * 1000.0) ^ Time.get_ticks_usec())


## Uniform value in the open interval (0, 1).
##
## Deliberately not named `randf`: inside this class a bare `randf()` call
## resolves to the engine's global function, which silently breaks determinism.
func next_float() -> float:
	_state = (_state * _MULTIPLIER) % _MODULUS
	draw_count += 1
	return float(_state) / float(_MODULUS)


## Uniform integer in [0, n).
func next_below(n: int) -> int:
	return floori(next_float() * float(n))
