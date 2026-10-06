class_name HintLayer
extends WorldLayer
## Aiming aids drawn above everything else: the block the player is about to
## swallow, and the warning that a boss is lurking overhead.

const LURK_WARNING_DISTANCE: float = 500.0


func _paint(p: Painter, sim: GameSim) -> void:
	if view.editor != null:
		return
	_paint_lurking_warning(p, sim)
	_paint_eat_target(p, sim)


func _paint_lurking_warning(p: Painter, sim: GameSim) -> void:
	var boss: BossState = sim.boss
	if sim.boss_kind == BossState.Kind.STEEL_CHASE:
		if boss.active and not boss.dead and boss.x + boss.w < view.camera_position.x:
			var edge_x: float = view.camera_position.x + 110.0
			var edge_y: float = view.camera_position.y + 46.0
			p.text("← 壓碎機逼近・向右逃離", edge_x, edge_y, 12.0, Palette.AMBER_400, true)
		return
	if not boss.active or boss.state != BossState.State.SUSPENDED:
		return
	if absf(BossSystem.player_dx(sim)) >= LURK_WARNING_DISTANCE:
		return
	var x: float = boss.center_x()
	var color: Color = Color(Palette.RED_500, 0.85)
	var label: String = "危險 // 上方有東西潛伏著…"
	var width: float = p.text_width(label, 13.0, true)
	p.icon_warning(x - width / 2.0 - 14.0, 145.0, 16.0, color)
	p.text(label, x, 150.0, 13.0, color, true)
	var bob: float = sin(view.time_ms / 80.0) * 5.0
	p.triangle(
		Vector2(x - 7.0, 162.0 + bob), Vector2(x + 7.0, 162.0 + bob), Vector2(x, 172.0 + bob), color
	)


## Outlines the block in the player's mouth range, and shrinks it away while
## it is being swallowed.
func _paint_eat_target(p: Painter, sim: GameSim) -> void:
	var player: PlayerState = sim.player
	if player.dead or player.won or player.has_block:
		return
	var boss: BossState = sim.boss
	var aim: PlayerSystem.Aim = PlayerSystem.aim_of(sim, sim.input.mouse_x, sim.input.mouse_y)

	var r: int
	var c: int
	var type: int
	var is_boss_cell: bool
	if player.eating_progress > 0.0 and player.has_eating_target:
		r = player.eating_target_r
		c = player.eating_target_c
		is_boss_cell = player.eating_target_is_boss_cell
		type = boss.cell(r, c) if is_boss_cell else sim.level.get_cell(r, c)
	else:
		var target: EatTarget = sim.get_eat_target(
			player.center_x(), player.center_y(), aim.x, aim.y
		)
		if target == null:
			return
		r = target.r
		c = target.c
		type = target.type
		is_boss_cell = target.is_boss_cell
	if not (aim.aiming or player.eating_progress > 0.0 or view.eat_held):
		return

	var x: float = float(c) * Tile.SIZE
	var y: float = float(r) * Tile.SIZE
	if is_boss_cell:
		# Boss cells move with the boss, so follow its interpolated position.
		var boss_pos: Vector2 = view.tween_position(boss.prev_x, boss.prev_y, boss.x, boss.y)
		x = boss_pos.x + float(c - boss.min_c) * Tile.SIZE
		y = boss_pos.y + float(r - boss.min_r) * Tile.SIZE

	if player.eating_progress > 0.0 and is_boss_cell:
		var progress: float = clampf(player.eating_progress, 0.0, 1.0)
		var pull: float = progress * progress * (3.0 - 2.0 * progress)
		var source: Vector2 = Vector2(x, y) + Vector2.ONE * Tile.SIZE * 0.5
		var body: Vector2 = view.tween_position(player.prev_x, player.prev_y, player.x, player.y) + Vector2(player.w, player.h) * 0.5
		var center: Vector2 = source.lerp(body, pull)
		var shrink: float = lerpf(1.0, 0.5, pull)
		p.push()
		p.translate(center.x, center.y)
		p.scale(shrink, shrink)
		TilePainter.draw(p, type, -Tile.SIZE * 0.5, -Tile.SIZE * 0.5, view.time_ms)
		p.pop()
	if player.eating_progress <= 0.0:
		p.stroke_rect(x, y, Tile.SIZE, Tile.SIZE, Palette.GREEN_500, 3.0)
