class_name PlayerLayer
extends WorldLayer
## The player slime: a squashy rounded body, the block it carries, eyes that
## follow the aim, and its reactions (head-bump streaks, dizzy stars, sweat).

const CARRIED_SIZE: float = 20.0
const GAUGE_WIDTH: float = 36.0
const GAUGE_HEIGHT: float = 4.0
## Distance from the top of the slime up to the gauge.
const GAUGE_GAP: float = 12.0
## Below this the gauge turns red.
const GAUGE_LOW: float = 0.25
## A head bump throws streaks off both sides of the head, then shakes grit
## loose from the ceiling.
const BUMP_STREAK_SECONDS: float = 0.2
const BUMP_DUST_SECONDS: float = 0.6
## Grit specks as (x offset, sideways drift, initial fall speed), in world units.
const BUMP_DUST: Array[Vector3] = [
	Vector3(-12.0, -14.0, 18.0), Vector3(-4.0, -5.0, 40.0),
	Vector3(5.0, 6.0, 28.0), Vector3(13.0, 15.0, 10.0),
]
const DAZE_STARS: int = 3
## The stars come out as the squeezed eyes open.
const DAZE_STARS_DELAY: float = 0.2
const SWEAT_PERIOD: float = 1.1
## A pixel teardrop, 6 by 8 world units around its centre.
const SWEAT_SHAPE: Array[Rect2] = [
	Rect2(-1.0, -4.0, 2.0, 2.0), Rect2(-2.0, -2.0, 4.0, 2.0),
	Rect2(-3.0, 0.0, 6.0, 2.5), Rect2(-2.0, 2.5, 4.0, 1.5),
]

class LandingDust:
	var pos: Vector2
	var vel: Vector2
	var age: float = 0.0
	var max_age: float = 0.22
	var size: float = 3.0
	var color: Color = Color.WHITE

var _motion: SlimeMotion = SlimeMotion.new()
var _last_sim: GameSim
var _last_player: PlayerState
var _last_tick: int = -1
var _look: Vector2 = Vector2.ZERO
var _was_grounded: bool = false
var _prev_player_vy: float = 0.0
var _dust_particles: Array[LandingDust] = []
var _current_tint_color: Color = Palette.GREEN_500
var _current_tint_strength: float = 0.0


func _process(delta: float) -> void:
	if view == null or view.sim == null:
		return
	if view.sim != _last_sim or view.sim.player != _last_player or view.sim.tick_count < _last_tick:
		_motion.reset()
		_look = Vector2.ZERO
		_dust_particles.clear()
		_was_grounded = false
		_prev_player_vy = 0.0
		_current_tint_strength = 0.0
		_current_tint_color = Palette.GREEN_500
	_last_sim = view.sim
	_last_player = view.sim.player
	_last_tick = view.sim.tick_count
	if view.rewinding:
		_motion.reset()
		_motion.body_scale = Vector2(view.sim.player.scale_x, view.sim.player.scale_y)
		_look = Vector2(float(view.sim.player.facing) * 0.45, 0.0)
		_current_tint_color = view.sim.player.ability_color()
		_current_tint_strength = 1.0 if view.sim.player.has_block else 0.0
		_dust_particles.clear()
		return
	var dt: float = clampf(delta, 0.0, 0.1)

	var active_dust: Array[LandingDust] = []
	for d: LandingDust in _dust_particles:
		d.age += dt
		if d.age < d.max_age:
			d.pos += d.vel * dt
			active_dust.append(d)
	_dust_particles = active_dust

	var player: PlayerState = view.sim.player
	if player.grounded and not _was_grounded and _prev_player_vy > 1.5:
		_spawn_landing_dust(player, _prev_player_vy)
	elif not player.grounded and _was_grounded and player.vy < -1.0:
		_spawn_jump_dust(player)
	_was_grounded = player.grounded
	_prev_player_vy = player.vy

	var target_color: Color = Palette.GREEN_500
	var target_strength: float = 0.0
	if player.has_block:
		target_strength = 1.0
		target_color = player.ability_color()
	elif player.has_eating_target and player.eating_progress > 0.0:
		var tr: int = player.eating_target_r
		var tc: int = player.eating_target_c
		var block_t: int = view.sim.boss.cell(tr, tc) if player.eating_target_is_boss_cell else view.sim.level.get_cell(tr, tc)
		target_strength = player.eating_progress * 0.4
		target_color = PlayerState.material_color(block_t)

	if target_strength > 0.0:
		_current_tint_color = _current_tint_color.lerp(target_color, clampf(dt * 14.0, 0.0, 1.0))
		_current_tint_strength = move_toward(_current_tint_strength, target_strength, dt * 6.0)
	else:
		_current_tint_strength = move_toward(_current_tint_strength, 0.0, dt * 4.0)

	var daze_age_before: float = _motion.daze_age if _motion.daze > 0.0 else 0.0
	_motion.advance(
		delta, view.sim.player, view.eat_held or view.shoot_held or view.editor != null,
		SlimeMotion.wall_contact(view.sim), SlimeMotion.ledge_drop(view.sim)
	)
	if view.editor == null:
		_play_reaction_sounds(daze_age_before)
	var mouse: Vector2 = view.mouse_in_view()
	var aim: PlayerSystem.Aim = PlayerSystem.aim_of(view.sim, mouse.x, mouse.y)
	var target_look: Vector2 = Vector2(aim.x, aim.y) * minf(1.0, aim.mag / 85.0)
	if not aim.aiming or view.editor != null:
		target_look = Vector2(float(view.sim.player.facing) * 0.45 + _motion.look_offset, 0.0)
	# Teetering on a ledge, the slime peers down at the drop.
	target_look = target_look.lerp(Vector2(signf(_motion.teeter) * 0.7, 0.9), absf(_motion.teeter) * 0.85)
	_look = _look.lerp(target_look, 1.0 - exp(-18.0 * dt))


func _spawn_landing_dust(player: PlayerState, fall_speed: float) -> void:
	var position: Vector2 = view.player_position()
	var ground_y: float = position.y + player.h
	var center_x: float = position.x + player.w * 0.5
	var count: int = 4 if fall_speed < 8.0 else 6
	for i: int in count:
		var d: LandingDust = LandingDust.new()
		var side: float = -1.0 if (i % 2 == 0) else 1.0
		var spread: float = (float(i) * 0.5 + 1.0) * 16.0
		d.pos = Vector2(center_x + side * (player.w * 0.3), ground_y)
		d.vel = Vector2(side * (24.0 + spread), -randf_range(4.0, 14.0))
		d.size = randf_range(2.0, 3.5)
		if not player.has_block:
			d.color = Color(Palette.SLATE_400, 0.7)
		else:
			d.color = Color(player.ability_color(), 0.75)
		d.max_age = 0.22
		_dust_particles.append(d)


func _spawn_jump_dust(player: PlayerState) -> void:
	var position: Vector2 = view.player_position()
	var ground_y: float = position.y + player.h
	var center_x: float = position.x + player.w * 0.5
	for side: float in [-1.0, 1.0]:
		var d: LandingDust = LandingDust.new()
		d.pos = Vector2(center_x + side * (player.w * 0.25), ground_y)
		d.vel = Vector2(side * 18.0, 2.0)
		d.size = 2.5
		if not player.has_block:
			d.color = Color(Palette.SLATE_400, 0.6)
		else:
			d.color = Color(player.ability_color(), 0.65)
		d.max_age = 0.16
		_dust_particles.append(d)


## The bump and hard-landing sounds come from the presentation, so the
## simulation's sound requests (and the reference traces) stay unchanged. A
## springy ceiling already plays the simulation's bounce.
func _play_reaction_sounds(daze_age_before: float) -> void:
	if _motion.bump_age == 0.0 and not _motion.bump_soft:
		AudioDirector.play_cue(SfxLibrary.Cue.BONK)
	if _motion.daze > 0.0 and daze_age_before < DAZE_STARS_DELAY and _motion.daze_age >= DAZE_STARS_DELAY:
		AudioDirector.play_cue(SfxLibrary.Cue.DIZZY)
	if _motion.landed_hard:
		AudioDirector.play_cue(SfxLibrary.Cue.THUD)


func _paint(p: Painter, sim: GameSim) -> void:
	var player: PlayerState = sim.player
	if player.dead:
		return
	var pos: Vector2 = view.player_position()
	var w: float = player.w
	var h: float = player.h
	var exit_scale: float = 1.0
	var exit_spin: float = 0.0
	if player.won and view.exit_vortex.active:
		var progress: float = view.exit_vortex.progress()
		if progress >= 1.0:
			return
		var center: Vector2 = view.exit_vortex.position()
		pos = center - Vector2(w, h) * 0.5
		exit_scale = maxf(0.02, 1.0 - pow(progress, 1.4))
		exit_spin = progress * progress * TAU * 2.0
	_paint_landing_dust(p)
	if not player.won:
		_paint_bump(p)
	# Right after a head bump the squash pivots on the head instead, so the
	# top stays flattened against the ceiling.
	var head_pin: float = h * 1.08 * (1.0 - _motion.body_scale.y) * _motion.head_anchor

	p.push()
	# Squash and stretch pivot on the feet.
	p.translate(pos.x + w / 2.0, pos.y + h)
	if player.won:
		p.translate(0.0, -h * 0.5)
		p.rotate(exit_spin)
		p.scale(exit_scale, exit_scale)
		p.translate(0.0, h * 0.5)
	if player.grounded and not player.won:
		p.shear_x(-_motion.lean * (1.0 - absf(_motion.wall_pressure)))
	else:
		p.rotate(_motion.lean)
	var wall: float = _motion.wall_pressure if not player.won else 0.0
	p.translate(wall * (w * 0.5 - w * 0.54 * _motion.body_scale.x), -head_pin)
	p.scale(_motion.body_scale.x, _motion.body_scale.y)
	p.fill_rect(-w * 0.45, -2.0, w * 0.9, 4.0, Color(0.0, 0.0, 0.0, 0.3))
	p.push()
	p.translate(-w * 0.54, -h * 1.08)
	p.scale(w * 1.08 / 40.0, h * 1.08 / 40.0)
	SlimeFace.paint_body(p, _current_tint_color, _current_tint_strength)
	p.pop()

	if player.has_block:
		_paint_carried_block(p, player)
	_paint_eyes(p, sim)
	if absf(_motion.teeter) > 0.6:
		_paint_sweat(p, w, h)
	p.pop()

	if _motion.daze > 0.0 and not player.won:
		var head_top: float = pos.y + h - h * 1.08 * _motion.body_scale.y - head_pin
		_paint_daze_stars(p, Vector2(pos.x + w / 2.0, head_top - 6.0))
	if view.bullet_time_energy < 1.0 and view.editor == null:
		_paint_bullet_time_gauge(p, pos.x + w / 2.0, pos.y - GAUGE_GAP)


func _paint_landing_dust(p: Painter) -> void:
	for d: LandingDust in _dust_particles:
		var t: float = d.age / d.max_age
		var fade: float = 1.0 - t
		var sz: float = d.size * (1.0 - t * 0.35)
		p.fill_rect(d.pos.x - sz * 0.5, d.pos.y - sz * 0.5, sz, sz, Color(d.color, d.color.a * fade))


## A small bar over the slime's head, shown while bullet time is being used
## or is still recharging.
func _paint_bullet_time_gauge(p: Painter, center_x: float, y: float) -> void:
	var left: float = center_x - GAUGE_WIDTH / 2.0
	var energy: float = clampf(view.bullet_time_energy, 0.0, 1.0)
	var color: Color = Palette.SKY_400 if energy > GAUGE_LOW else Palette.RED_400
	p.fill_round_rect(left - 1.5, y - 1.5, GAUGE_WIDTH + 3.0, GAUGE_HEIGHT + 3.0, 3.5, Color(Palette.SLATE_900, 0.8))
	p.fill_round_rect(left, y, GAUGE_WIDTH * energy, GAUGE_HEIGHT, 2.0, color)


## The swallowed block shows through the body, darker the more it is worn.
func _paint_carried_block(p: Painter, player: PlayerState) -> void:
	var bx: float = -CARRIED_SIZE / 2.0
	var by: float = -player.h / 2.0 - CARRIED_SIZE / 2.0 + sin(view.time_ms * 0.006) * 0.8
	# Drawn like the block it becomes when spat out, worn state included.
	var type: int = player.carried_block_type
	if player.carried_block_eaten_count >= 2 and type != Tile.GLASS:
		type = Tile.BOUNCY_EATEN_2 if Tile.is_bouncy(type) else Tile.DIRT_EATEN_2
	TilePainter.draw_projectile(p, type, bx, by, CARRIED_SIZE, CARRIED_SIZE)
	var bubble_pulse: float = 0.35 + sin(view.time_ms * 0.007) * 0.1
	var bubble_color: Color = _current_tint_color if player.has_block else Palette.GREEN_600
	p.fill_round_rect(bx + 3.0, by + 3.0, CARRIED_SIZE - 6.0, CARRIED_SIZE - 6.0, 3.0, Color(bubble_color, bubble_pulse))


func _paint_eyes(p: Painter, sim: GameSim) -> void:
	var player: PlayerState = sim.player
	p.push()
	p.translate(-player.w / 2.0, -player.h)
	p.scale(player.w / 40.0, player.h / 40.0)
	# The eyes ride the jelly but deform only half as much, so a hard squash
	# never crushes them into slivers.
	p.translate(20.0, 18.0)
	p.scale(1.0 / sqrt(_motion.body_scale.x), 1.0 / sqrt(_motion.body_scale.y))
	p.translate(-20.0, -18.0)
	SlimeFace.paint(p, _motion, _look)
	p.pop()


## Streaks fly off both sides of the head; on a hard ceiling, grit follows.
func _paint_bump(p: Painter) -> void:
	var age: float = _motion.bump_age
	var origin: Vector2 = _motion.bump_point
	if age < BUMP_STREAK_SECONDS:
		var t: float = age / BUMP_STREAK_SECONDS
		var reach: float = 1.0 - (1.0 - t) * (1.0 - t)
		var color: Color = Color(Palette.WHITE, 1.0 - t)
		for side: float in [-1.0, 1.0]:
			var corner: Vector2 = origin + Vector2(side * 15.0, 1.0)
			for angle: float in [0.2, 0.75]:
				var direction: Vector2 = Vector2(side * cos(angle), sin(angle))
				var from: Vector2 = corner + direction * (3.0 + reach * 10.0)
				var to: Vector2 = from + direction * (1.0 + 7.0 * (1.0 - t))
				p.line(from.x, from.y, to.x, to.y, color, 2.0)
	if not _motion.bump_soft and age < BUMP_DUST_SECONDS:
		var fade: float = 1.0 - age / BUMP_DUST_SECONDS
		for speck: Vector3 in BUMP_DUST:
			var x: float = origin.x + speck.x + speck.y * age
			var y: float = origin.y + 1.0 + speck.z * age + 260.0 * age * age
			p.fill_rect(x - 1.0, y - 1.0, 2.0, 2.0, Color(Palette.SLATE_300, 0.9 * fade))


## Pixel stars circling over the head while the slime is dizzy.
func _paint_daze_stars(p: Painter, center: Vector2) -> void:
	var strength: float = _motion.daze * clampf((_motion.daze_age - DAZE_STARS_DELAY) / 0.12, 0.0, 1.0)
	if strength <= 0.0:
		return
	for i: int in DAZE_STARS:
		var angle: float = _motion.daze_age * 7.5 + float(i) * TAU / float(DAZE_STARS)
		# The lower half of the orbit passes in front: larger and brighter.
		var depth: float = sin(angle)
		var at: Vector2 = center + Vector2(cos(angle) * 20.0, depth * 3.5)
		var size: float = (6.5 + depth * 1.5) * strength
		var alpha: float = (0.8 + depth * 0.2) * strength
		var bar: float = maxf(1.2, size * 0.34)
		p.fill_rect(at.x - size * 0.5, at.y - bar * 0.5, size, bar, Color(Palette.AMBER_400, alpha))
		p.fill_rect(at.x - bar * 0.5, at.y - size * 0.5, bar, size, Color(Palette.AMBER_400, alpha))
		p.fill_rect(at.x - bar * 0.5, at.y - bar * 0.5, bar, bar, Color(Palette.YELLOW_200, alpha))


## A nervous sweat drop sliding down by the head, on the side away from the
## drop. It grows in and shrinks away rather than fading, so the overlapping
## pieces never show their seams.
func _paint_sweat(p: Painter, w: float, h: float) -> void:
	var cycle: float = fmod(_motion.time, SWEAT_PERIOD) / SWEAT_PERIOD
	var size: float = (
		minf(cycle / 0.15, 1.0) * minf((1.0 - cycle) / 0.2, 1.0)
		* clampf((absf(_motion.teeter) - 0.6) / 0.4, 0.0, 1.0)
	)
	if size <= 0.0:
		return
	var center: Vector2 = Vector2(-signf(_motion.teeter) * (w * 0.54 + 2.0), -h * 0.98 + cycle * 7.0)
	for outline: bool in [true, false]:
		var color: Color = Palette.CYAN_600 if outline else Palette.CYAN_200
		for part: Rect2 in SWEAT_SHAPE:
			var rect: Rect2 = part.grow(0.8 if outline else 0.0)
			p.fill_rect(
				center.x + rect.position.x * size, center.y + rect.position.y * size,
				rect.size.x * size, rect.size.y * size, color
			)
	p.fill_rect(center.x - 1.6 * size, center.y + 0.4 * size, 1.2 * size, 1.6 * size, Palette.WHITE)
