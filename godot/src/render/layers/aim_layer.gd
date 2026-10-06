class_name AimLayer
extends WorldLayer
## The dashed trajectory shown while the player holds the shoot button.

const PREVIEW_STEPS: int = 40
const LINE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.4)


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

	var points: PackedVector2Array = ProjectileSystem.preview_path(sim, aim, PREVIEW_STEPS)
	p.dashed_polyline(points, LINE_COLOR, 3.0, 6.0)
