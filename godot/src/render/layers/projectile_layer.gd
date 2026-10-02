class_name ProjectileLayer
extends WorldLayer
## Blocks in flight.


func _paint(p: Painter, sim: GameSim) -> void:
	for projectile: SimProjectile in sim.projectiles:
		var pos: Vector2 = view.tween_position(
			projectile.prev_x, projectile.prev_y, projectile.x, projectile.y
		)
		TilePainter.draw_projectile(p, projectile.type, pos.x, pos.y, projectile.w, projectile.h)
