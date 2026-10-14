class_name AimLayer
extends WorldLayer
## Material-colored first-contact preview. Unresolved horizons are not targets.

const PREVIEW_STEPS: int = 40


func _paint(p: Painter, sim: GameSim) -> void:
	var player: PlayerState = sim.player
	if player.dead or player.won or not player.has_block or view.editor != null:
		return
	if not view.shoot_held or player.waiting_for_shoot_release:
		return
	if sim.bullet_time_enabled and not player.in_bullet_time:
		return
	var cursor: Vector2 = view.mouse_in_view()
	var aim: PlayerSystem.Aim = PlayerSystem.aim_of(sim, cursor.x, cursor.y)
	if not aim.aiming:
		return

	var trajectory: ProjectileSystem.Trajectory = ProjectileSystem.preview_trajectory(sim, aim, PREVIEW_STEPS)
	var points: PackedVector2Array = trajectory.points
	if points.size() < 2:
		return

	# Color matched to the carried material
	var color: Color = player.ability_color()
	if player.carried_block_type == Tile.GLASS:
		color = Palette.CYAN_400
	elif player.carried_block_type == Tile.TNT:
		color = Palette.RED_400

	p.dashed_polyline(points, Color(color, 0.10), 4.0, 6.0)
	p.dashed_polyline(points, Color(color, 0.72), 1.8, 6.0)
	if trajectory.end in [ProjectileSystem.PreviewEnd.HORIZON, ProjectileSystem.PreviewEnd.BOUNDARY]:
		return
	var last_pt: Vector2 = points[-1]
	if player.carried_block_type == Tile.TNT:
		# Informative outline only; never mask terrain with a filled blast disk.
		p.stroke_circle(last_pt.x, last_pt.y, MechanismSystem.BLAST_RADIUS, Color(color, 0.25), 1.0)
		if trajectory.end == ProjectileSystem.PreviewEnd.FUSE:
			p.text("空中引爆", last_pt.x, last_pt.y - 17.0, 10.0, Color(color, 0.9), true)
	p.stroke_circle(last_pt.x, last_pt.y, 6.0, Color(color, 0.7), 1.5)
	for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var t1: Vector2 = last_pt + dir * 9.0
		var t2: Vector2 = last_pt + dir * 12.0
		p.line(t1.x, t1.y, t2.x, t2.y, Color(color, 0.85), 1.5)
	p.fill_circle(last_pt.x, last_pt.y, 2.2, Palette.WHITE)
