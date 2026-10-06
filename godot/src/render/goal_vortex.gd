class_name GoalVortex
extends RefCounted
## Visual exit only: move the rendered slime, never its collision body.

const DURATION: float = 1.35
var age: float = 0.0
var active: bool = false
var center: Vector2 = Vector2.ZERO
var origin: Vector2 = Vector2.ZERO


func advance(delta: float, sim: GameSim) -> void:
	if not sim.player.won:
		reset()
		return
	if not active:
		active = true
		origin = Vector2(sim.player.center_x(), sim.player.center_y())
		center = origin
		var nearest: float = INF
		for row: int in sim.level.rows:
			for col: int in sim.level.cols:
				if sim.level.get_cell(row, col) == Tile.GOAL:
					var candidate: Vector2 = Vector2(col + 0.5, row + 0.5) * Tile.SIZE
					var distance: float = origin.distance_squared_to(candidate)
					if distance < nearest:
						nearest = distance
						center = candidate
	else:
		age = minf(DURATION, age + maxf(delta, 0.0))


func progress() -> float:
	return clampf(age / DURATION, 0.0, 1.0)


func finished() -> bool:
	return active and age >= DURATION


func position() -> Vector2:
	var t: float = progress()
	var pull: float = t * t * (3.0 - 2.0 * t)
	var orbit: Vector2 = Vector2(sin(t * TAU * 1.5), cos(t * TAU * 1.5)) * sin(t * PI) * 10.0
	return origin.lerp(center, pull) + orbit


func reset() -> void:
	age = 0.0
	active = false
