class_name ParticleLayer
extends WorldLayer
## Debris particles: squares that fade out over their lifetime.


func _paint(p: Painter, sim: GameSim) -> void:
	for particle: SimParticle in sim.particles:
		var pos: Vector2 = view.tween_position(
			particle.prev_x, particle.prev_y, particle.x, particle.y
		)
		var fade: float = clampf(1.0 - particle.life / particle.max_life, 0.0, 1.0)
		var half: float = particle.w / 2.0
		p.fill_rect(pos.x - half, pos.y - half, particle.w, particle.w, Color(particle.color, fade))
