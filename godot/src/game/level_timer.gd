class_name LevelTimer
extends RefCounted
## Real play time, deliberately outside GameSim so rewind cannot undo it.

var seconds: float = 0.0
var started: bool = false
var finished: bool = false
var ranked: bool = true


func reset(eligible: bool = true) -> void:
	seconds = 0.0
	started = false
	finished = false
	ranked = eligible


func advance(delta: float, action: bool, normal_speed: bool, paused: bool = false) -> void:
	if paused or finished:
		return
	started = started or action
	if not started:
		return
	ranked = ranked and normal_speed
	seconds += maxf(0.0, delta)


func finish() -> void:
	finished = true


static func format_time(value: float) -> String:
	var centiseconds: int = maxi(0, roundi(value * 100.0))
	return "%02d:%02d.%02d" % [floori(float(centiseconds) / 6000.0), floori(float(centiseconds) / 100.0) % 60, centiseconds % 100]
