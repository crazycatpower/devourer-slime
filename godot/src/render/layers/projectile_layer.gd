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
	for projectile: SimProjectile in sim.projectiles:
		if not _ages.has(projectile):
			_ages[projectile] = 0.0
			_origins[projectile] = Vector2(sim.player.center_x(), sim.player.center_y())
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


func _paint_trail(p: Painter, projectile: SimProjectile) -> void:
	if not _trails.has(projectile):
		return
	var trail: Array = _trails[projectile]
	if trail.size() < 2:
		return
	var trail_color: Color = Palette.AMBER_500
	if projectile.type == Tile.GLASS:
		trail_color = Palette.CYAN_400
	elif projectile.type == Tile.BOUNCY or projectile.type == Tile.BOUNCY_EATEN_1 or projectile.type == Tile.BOUNCY_EATEN_2:
		trail_color = Palette.PINK_400
	elif projectile.type == Tile.DIRT_EATEN_1 or projectile.type == Tile.DIRT_EATEN_2:
		trail_color = Palette.LIME_400
	var total: int = trail.size()
	for i: int in range(1, total):
		var prev_pt: Vector2 = trail[i - 1]
		var curr_pt: Vector2 = trail[i]
		var alpha: float = (float(i) / float(total)) * 0.38
		var width: float = (float(i) / float(total)) * 3.5
		p.line(prev_pt.x, prev_pt.y, curr_pt.x, curr_pt.y, Color(trail_color, alpha), width)