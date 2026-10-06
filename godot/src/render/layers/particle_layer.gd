class_name ParticleLayer
extends WorldLayer
## Debris particles: squares that fade out over their lifetime.


func _paint(p: Painter, sim: GameSim) -> void:
	var visible: Rect2 = Rect2(view.camera_position, view.size / maxf(view.world_scale, 0.001)).grow(12.0)
	var drawn: int = 0
	# Prefer recent impacts, keeping large boss bursts from masking hazards.
	# This is presentation-only: simulation particles and random draws are unchanged.
	for index: int in range(sim.particles.size() - 1, -1, -1):
		var particle: SimParticle = sim.particles[index]
		var pos: Vector2 = view.tween_position(
			particle.prev_x, particle.prev_y, particle.x, particle.y
		)
		if not visible.has_point(pos):
			continue
		drawn += 1
		if drawn > 80:
			break
		var life_ratio: float = particle.life / maxf(particle.max_life, 0.001)
		var fade: float = clampf(1.0 - life_ratio, 0.0, 1.0)
		var shrink: float = clampf(fade * 1.15, 0.35, 1.0)
		var size: float = particle.w * shrink
		var half: float = size / 2.0
		var rot: float = (particle.vx * 0.4 + particle.vy * 0.15) * (particle.life * 0.05)
		p.push()
		p.translate(pos.x, pos.y)
		p.rotate(rot)
		p.fill_rect(-half, -half, size, size, Color(particle.color, fade * 0.7))
		if size >= 3.0:
			p.fill_rect(-half, -half, size, maxf(1.0, size * 0.28), Color(Palette.WHITE, fade * 0.35))
		p.pop()
