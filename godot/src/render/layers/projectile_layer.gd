class_name ProjectileLayer
extends WorldLayer
## The spat block grows out of the belly, then follows its physical trajectory.

const EMERGE_SECONDS: float = 0.085
const MAX_TRAIL_POINTS: int = 5

var _ages: Dictionary[SimProjectile, float] = {}
var _origins: Dictionary[SimProjectile, Vector2] = {}
var _trails: Dictionary[SimProjectile, Array] = {}
var _last_sim: GameSim


func _process(delta: float) -> void:
	if view == null or view.sim == null:
		return
	var sim: GameSim = view.sim
	if sim != _last_sim:
		_ages.clear()
		_origins.clear()
		_trails.clear()
		_last_sim = sim
	if view.rewinding:
		return
	for projectile: SimProjectile in sim.projectiles:
		if not _ages.has(projectile):
			_ages[projectile] = 0.0
			_origins[projectile] = view.player_position() + Vector2(sim.player.w, sim.player.h) * 0.5
			_trails[projectile] = []
		else:
			_ages[projectile] = minf(EMERGE_SECONDS, _ages[projectile] + delta)
		var trail: Array = _trails[projectile]
		var cur_pos: Vector2 = Vector2(projectile.x + projectile.w * 0.5, projectile.y + projectile.h * 0.5)
		trail.append(cur_pos)
		if trail.size() > MAX_TRAIL_POINTS:
			trail.pop_front()
	for projectile: SimProjectile in _ages.keys():
		if not sim.projectiles.has(projectile):
			_ages.erase(projectile)
			_origins.erase(projectile)
			_trails.erase(projectile)


func _paint(p: Painter, sim: GameSim) -> void:
	for charge: GameSim.TntCharge in sim.tnt_charges:
		TilePainter.draw_projectile(p, Tile.TNT, charge.center.x - 20.0, charge.center.y - 20.0, 40.0, 40.0)
		_paint_fuse(p, charge.center, charge.explode_tick - sim.tick_count)
		if charge.boss_owned or charge.returned_charge:
			p.stroke_circle(charge.center.x, charge.center.y, MechanismSystem.BLAST_RADIUS, Color(Palette.AMBER_400, 0.3), 1.5)
			p.fill_circle(charge.center.x, charge.center.y, MechanismSystem.KILL_RADIUS, Color(Palette.RED_400, 0.08))
			p.stroke_circle(charge.center.x, charge.center.y, MechanismSystem.KILL_RADIUS, Color(Palette.RED_400, 0.55), 2.0)
		if charge.boss_owned:
			p.text("吞噬拆彈", charge.center.x, charge.center.y - 31.0, 10.0, Palette.LIME_400, true)
	for projectile: SimProjectile in sim.projectiles:
		_paint_trail(p, projectile)
		var pos: Vector2 = view.tween_position(
			projectile.prev_x, projectile.prev_y, projectile.x, projectile.y
		)
		var visual_scale: float = 1.0
		if not projectile.is_enemy and _ages.has(projectile):
			var t: float = clampf(_ages[projectile] / EMERGE_SECONDS, 0.0, 1.0)
			var emerge: float = t * t * (3.0 - 2.0 * t)
			var center: Vector2 = pos + Vector2(projectile.w, projectile.h) * 0.5
			center = _origins[projectile].lerp(center, emerge)
			visual_scale = lerpf(0.5, 1.0, emerge)
			pos = center - Vector2(projectile.w, projectile.h) * visual_scale * 0.5

		var speed_sq: float = projectile.vx * projectile.vx + projectile.vy * projectile.vy
		var is_bouncy: bool = projectile.type == Tile.BOUNCY or projectile.type == Tile.BOUNCY_EATEN_1 or projectile.type == Tile.BOUNCY_EATEN_2
		if is_bouncy and speed_sq > 4.0:
			var speed: float = sqrt(speed_sq)
			var angle: float = atan2(projectile.vy, projectile.vx)
			var stretch: float = minf(0.28, speed * 0.016)
			var center: Vector2 = pos + Vector2(projectile.w, projectile.h) * 0.5 * visual_scale
			p.push()
			p.translate(center.x, center.y)
			p.rotate(angle)
			p.scale(1.0 + stretch, 1.0 - stretch * 0.45)
			TilePainter.draw_projectile(p, projectile.type, -projectile.w * 0.5 * visual_scale, -projectile.h * 0.5 * visual_scale, projectile.w * visual_scale, projectile.h * visual_scale)
			p.pop()
		else:
			TilePainter.draw_projectile(p, projectile.type, pos.x, pos.y, projectile.w * visual_scale, projectile.h * visual_scale)

		if projectile.type == Tile.TNT and projectile.fuse_ticks > 0:
			_paint_fuse(p, pos + Vector2(projectile.w, projectile.h) * visual_scale * 0.5, projectile.fuse_ticks)


func _paint_fuse(p: Painter, center: Vector2, remaining: int) -> void:
	var fraction: float = clampf(float(remaining) / MechanismSystem.TNT_FUSE_TICKS, 0.0, 1.0)
	var flash: bool = remaining % (6 if remaining > 12 else 4) < 2
	p.fill_circle(center.x, center.y, 24.0, Color(Palette.RED_400 if flash else Palette.AMBER_400, 0.28 if flash else 0.08))
	p.stroke_circle(center.x, center.y, 25.0, Color(Palette.SLATE_900, 0.6), 4.0)
	p.arc(center.x, center.y, 25.0, -PI * 0.5, -PI * 0.5 + TAU * fraction, Palette.RED_400 if flash else Palette.AMBER_400, 3.2)
	var spark_angle: float = -PI * 0.5 + TAU * fraction
	var spark_pt: Vector2 = center + Vector2(cos(spark_angle), sin(spark_angle)) * 25.0
	p.fill_circle(spark_pt.x, spark_pt.y, 2.5, Palette.WHITE)


func _paint_trail(p: Painter, projectile: SimProjectile) -> void:
	if not _trails.has(projectile):
		return
	var trail: Array = _trails[projectile]
	if trail.size() < 2:
		return
	var trail_color: Color = Palette.AMBER_500
	match projectile.type:
		Tile.GLASS:
			trail_color = Palette.CYAN_400
		Tile.BOUNCY, Tile.BOUNCY_EATEN_1, Tile.BOUNCY_EATEN_2:
			trail_color = Palette.PINK_400
		Tile.DIRT_EATEN_1, Tile.DIRT_EATEN_2:
			trail_color = Palette.LIME_400
		Tile.SAND:
			trail_color = Palette.AMBER_400
		Tile.ICE:
			trail_color = Palette.CYAN_200
		Tile.TNT:
			trail_color = Palette.RED_400
		Tile.STEEL:
			trail_color = Palette.SLATE_400

	var total: int = trail.size()
	for i: int in range(1, total):
		var prev_pt: Vector2 = trail[i - 1]
		var curr_pt: Vector2 = trail[i]
		var t: float = float(i) / float(total)
		p.line(prev_pt.x, prev_pt.y, curr_pt.x, curr_pt.y, Color(trail_color, t * 0.25), t * 6.0)
		p.line(prev_pt.x, prev_pt.y, curr_pt.x, curr_pt.y, Color(trail_color, t * 0.75), t * 3.0)
		if i >= total - 2:
			p.line(prev_pt.x, prev_pt.y, curr_pt.x, curr_pt.y, Color(Palette.WHITE, t * 0.6), 1.2)
