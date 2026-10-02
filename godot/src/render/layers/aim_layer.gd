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
	var aim: PlayerSystem.Aim = PlayerSystem.aim_of(sim, sim.input.mouse_x, sim.input.mouse_y)
	if not aim.aiming:
		return

	var level: LevelGrid = sim.level
	var origin: Vector2 = view.tween_position(player.prev_x, player.prev_y, player.x, player.y)
	var x: float = origin.x + player.w / 2.0
	var y: float = origin.y + player.h / 2.0
	var vx: float = aim.x * GameConstants.BULLET_SPEED
	var vy: float = aim.y * GameConstants.BULLET_SPEED
	var points: PackedVector2Array = PackedVector2Array([Vector2(x, y)])
	for _i: int in PREVIEW_STEPS:
		vy += GameConstants.GRAVITY * ProjectileSystem.GRAVITY_SCALE
		x += vx
		y += vy
		points.append(Vector2(x, y))
		# Stop where the block would: at anything solid or spiky, or at the
		# edge of the map.
		var col: int = floori(x / Tile.SIZE)
		var row: int = floori(y / Tile.SIZE)
		if not level.in_bounds(row, col):
			break
		var t: int = level.get_cell(row, col)
		if Tile.is_solid(t) or Tile.is_spike(t):
			break
	p.dashed_polyline(points, LINE_COLOR, 3.0, 6.0)
