class_name DevourEffectLayer
extends WorldLayer
## Charge and spit effects; eating animates the actual block into the body.

var _last_sim: GameSim
var _burst_age: float = 1.0
var _burst_origin: Vector2 = Vector2.ZERO
var _burst_direction: Vector2 = Vector2.RIGHT


func _process(delta: float) -> void:
	if view == null or view.sim == null:
		return
	var sim: GameSim = view.sim
	if sim != _last_sim:
		if _last_sim != null and _last_sim.sfx_requested.is_connected(_on_sfx):
			_last_sim.sfx_requested.disconnect(_on_sfx)
		_last_sim = sim
		sim.sfx_requested.connect(_on_sfx)
		_burst_age = 1.0
	_burst_age += delta


func _on_sfx(id: Sfx.Id, _param: float, _delay: float) -> void:
	if id != Sfx.Id.SHOOT:
		return
	var sim: GameSim = view.sim
	_burst_age = 0.0
	_burst_origin = Vector2(sim.player.center_x(), sim.player.center_y())
	var aim: PlayerSystem.Aim = PlayerSystem.aim_of(sim, sim.input.mouse_x, sim.input.mouse_y)
	_burst_direction = Vector2(aim.x, aim.y)


func _paint(p: Painter, sim: GameSim) -> void:
	var player: PlayerState = sim.player
	if player.dead or view.editor != null:
		return
	if player.won:
		if view.exit_vortex.active:
			_paint_exit_motes(p)
		return
	var body: Vector2 = view.tween_position(player.prev_x, player.prev_y, player.x, player.y) + Vector2(player.w, player.h) * 0.5
	if player.has_eating_target and not player.eating_target_is_boss_cell:
		_paint_devour_stream(p, body, player)
	if player.has_block and view.shoot_held and not player.waiting_for_shoot_release:
		var pulse: float = 0.5 + sin(view.time_ms * 0.018) * 0.5
		p.stroke_rect(body.x - 23.0 - pulse * 2.0, body.y - 23.0 - pulse * 2.0, 46.0 + pulse * 4.0, 46.0 + pulse * 4.0, Color(Palette.LIME_400, 0.15 + pulse * 0.25), 1.5)
		_paint_charge_focus(p, body, sim)
	if _burst_age < 0.3:
		var t: float = _burst_age / 0.3
		for i: int in 7:
			var direction: Vector2 = _burst_direction.rotated((float(i) - 3.0) * 0.12)
			var point: Vector2 = _burst_origin + direction * (18.0 + t * 44.0)
			p.fill_rect(point.x - 2.0, point.y - 2.0, 4.0, 4.0, Color(Palette.LIME_400, 1.0 - t))


## Viscous slime suction stream and enzyme motes connecting mouth to target block.
func _paint_devour_stream(p: Painter, body: Vector2, player: PlayerState) -> void:
	var progress: float = clampf(player.eating_progress, 0.0, 1.0)
	var origin: Vector2 = Vector2(float(player.eating_target_c) * Tile.SIZE + Tile.SIZE * 0.5, float(player.eating_target_r) * Tile.SIZE + Tile.SIZE * 0.5)
	var pull: float = progress * progress * (3.0 - 2.0 * progress)
	var current_block: Vector2 = origin.lerp(body, pull)
	var diff: Vector2 = body - current_block
	var dist: float = diff.length()
	if dist > 3.0:
		var dir: Vector2 = diff / dist
		var norm: Vector2 = Vector2(-dir.y, dir.x)
		var stream_points: PackedVector2Array = PackedVector2Array()
		for s: int in 7:
			var st: float = float(s) / 6.0
			var base_pt: Vector2 = current_block.lerp(body, st)
			var wave: float = sin(view.time_ms * 0.025 + float(s) * 1.6) * (1.0 - progress * 0.6) * 3.5 * sin(st * PI)
			stream_points.append(base_pt + norm * wave)
		var alpha: float = 1.0 - progress * 0.4
		p.polyline(stream_points, Color(Palette.GREEN_600, 0.45 * alpha), 3.5)
		p.polyline(stream_points, Color(Palette.LIME_400, 0.75 * alpha), 1.5)
		for m: int in 4:
			var mt: float = fposmod(float(m) * 0.25 - view.time_ms * 0.003, 1.0)
			var mpt: Vector2 = current_block.lerp(body, mt)
			var mwave: float = sin(view.time_ms * 0.025 + mt * 8.0) * 2.2 * sin(mt * PI)
			var mpos: Vector2 = mpt + norm * mwave
			var msize: float = lerpf(3.5, 1.5, mt)
			p.fill_rect(mpos.x - msize * 0.5, mpos.y - msize * 0.5, msize, msize, Color(Palette.LIME_400, 0.85 * alpha))
	var ripple: float = fposmod(view.time_ms * 0.004, 1.0)
	var r_size: float = 18.0 + ripple * 14.0
	p.stroke_rect(current_block.x - r_size * 0.5, current_block.y - r_size * 0.5, r_size, r_size, Color(Palette.LIME_400, (1.0 - ripple) * 0.35), 1.2)


## Converging focus sparks and aim trajectory guide during spit charge.
func _paint_charge_focus(p: Painter, body: Vector2, sim: GameSim) -> void:
	for i: int in 6:
		var st: float = fposmod(view.time_ms * 0.003 + float(i) / 6.0, 1.0)
		var a: float = float(i) * (TAU / 6.0) + view.time_ms * 0.001
		var radius: float = lerpf(34.0, 9.0, st)
		var sp: Vector2 = body + Vector2(cos(a), sin(a)) * radius
		p.fill_rect(sp.x - 1.5, sp.y - 1.5, 3.0, 3.0, Color(Palette.LIME_400, st * 0.8))
	var aim: PlayerSystem.Aim = PlayerSystem.aim_of(sim, sim.input.mouse_x, sim.input.mouse_y)
	if aim.aiming:
		var aim_dir: Vector2 = Vector2(aim.x, aim.y)
		for dot: int in 4:
			var d: float = 24.0 + float(dot) * 14.0
			var pt: Vector2 = body + aim_dir * d
			var dot_size: float = 3.0 - float(dot) * 0.5
			var dot_alpha: float = 0.65 - float(dot) * 0.12
			p.fill_rect(pt.x - dot_size * 0.5, pt.y - dot_size * 0.5, dot_size, dot_size, Color(Palette.LIME_400, dot_alpha))


## Exit particles appear only during absorption; the original gold goal stays intact.
func _paint_exit_motes(p: Painter) -> void:
	var vortex: GoalVortex = view.exit_vortex
	var progress: float = vortex.progress()
	var strength: float = sin(progress * PI)
	for i: int in 20:
		var t: float = fposmod(float(i) / 20.0 - progress * 1.8, 1.0)
		var angle: float = t * TAU * 2.0 + progress * TAU
		var radius: float = 4.0 + t * 26.0 * strength
		var point: Vector2 = vortex.center + Vector2(cos(angle), sin(angle)) * radius
		p.fill_rect(point.x - 1.5, point.y - 1.5, 3.0, 3.0, Color(Palette.AMBER_100, strength * (1.0 - t * 0.5)))