class_name Collision
extends RefCounted
## Axis-separated collision of the player box against solid tiles.
##
## Bouncy tiles (or carrying a bouncy block) turn a collision into a bounce.

const SKIN: float = 0.001
const MIN_WALL_BOUNCE_SPEED: float = 5.5
const WALL_BOUNCE_LOCK_TICKS: int = 12
## A fall shorter than this lands on bouncy blocks without bouncing.
const MIN_BOUNCE_FALL_HEIGHT: float = 32.0
const MAX_FLOOR_BOUNCE_SPEED: float = 25.0
const MAX_CEILING_BOUNCE_SPEED: float = 20.0


static func solve_x(sim: GameSim) -> void:
	var p: PlayerState = sim.player
	var is_player_bouncy: bool = p.has_block and p.carried_block_type == Tile.BOUNCY
	var original_vx: float = p.vx
	p.x += p.vx

	var blocks: Array[SolidBox] = sim.solid_boxes(p.x, p.y, p.w, p.h)
	if blocks.is_empty():
		return
	# Whatever was left of a spit's sideways kick ends at the wall.
	p.recoil_vx = 0.0
	var bouncy_collision: bool = _any_bouncy(blocks) or is_player_bouncy
	var did_bounce: bool = false

	if p.vx > 0.0:
		var hit_x: float = INF
		for b: SolidBox in blocks:
			hit_x = minf(hit_x, b.x)
		p.x = hit_x - p.w - SKIN
		if bouncy_collision:
			p.vx = -maxf(absf(original_vx), MIN_WALL_BOUNCE_SPEED)
			did_bounce = true
		else:
			p.vx = 0.0
		if p.vy > 0.0 and sim.input.right and sim.rng.next_float() < 0.3:
			sim.spawn_particles(p.x + p.w, p.y + p.h / 2.0, Palette.SLATE_400, 1, 1.0)
	elif p.vx < 0.0:
		var hit_x: float = -INF
		for b: SolidBox in blocks:
			hit_x = maxf(hit_x, b.x + b.w)
		p.x = hit_x + SKIN
		if bouncy_collision:
			p.vx = maxf(absf(original_vx), MIN_WALL_BOUNCE_SPEED)
			did_bounce = true
		else:
			p.vx = 0.0
		if p.vy > 0.0 and sim.input.left and sim.rng.next_float() < 0.3:
			sim.spawn_particles(p.x, p.y + p.h / 2.0, Palette.SLATE_400, 1, 1.0)

	if did_bounce:
		p.scale_x = 0.6
		p.scale_y = 1.4
		p.wall_bounce_timer = WALL_BOUNCE_LOCK_TICKS
		sim.add_shake(absf(original_vx) * 0.4 + 2.0)
		sim.spawn_particles(p.center_x(), p.center_y(), _bounce_color(is_player_bouncy), 8, 3.0)
		sim.play(Sfx.Id.BOUNCE)
	else:
		p.vx = 0.0


static func solve_y(sim: GameSim) -> void:
	var p: PlayerState = sim.player
	var is_player_bouncy: bool = p.has_block and p.carried_block_type == Tile.BOUNCY
	var original_vy: float = p.vy
	p.y += p.vy
	var was_grounded: bool = p.grounded
	p.grounded = false

	var blocks: Array[SolidBox] = sim.solid_boxes(p.x, p.y, p.w, p.h)
	if blocks.is_empty():
		return
	var bouncy_collision: bool = _any_bouncy(blocks) or is_player_bouncy

	if p.vy > 0.0:
		var hit_y: float = INF
		for b: SolidBox in blocks:
			hit_y = minf(hit_y, b.y)
		p.y = hit_y - p.h - SKIN

		var fall_height: float = p.y - p.fall_start_y
		if bouncy_collision and fall_height >= MIN_BOUNCE_FALL_HEIGHT:
			# Bounce speed follows the fall height, so a bounce returns the
			# player to roughly where the fall started.
			var bounce_speed: float = maxf(sqrt(fall_height), 5.0)
			p.vy = maxf(-bounce_speed, -MAX_FLOOR_BOUNCE_SPEED)
			p.grounded = false
			p.coyote_timer = 24
			p.is_jumping = false
			p.scale_x = 0.6
			p.scale_y = 1.4
			sim.add_shake(bounce_speed * 0.5 + 2.0)
			sim.spawn_particles(
				p.center_x(), p.y + p.h, _bounce_color(is_player_bouncy), 12, 4.0
			)
			sim.play(Sfx.Id.BOUNCE)
		else:
			p.grounded = true
			p.is_jumping = false
			if not was_grounded:
				p.scale_x = 1.4
				p.scale_y = 0.6
				sim.spawn_particles(p.center_x(), p.y + p.h, Palette.GREEN_400, 8, 2.5)
				sim.play(Sfx.Id.LAND)
			p.vy = 0.0
	elif p.vy < 0.0:
		var hit_y: float = -INF
		for b: SolidBox in blocks:
			hit_y = maxf(hit_y, b.y + b.h)
		p.y = hit_y + SKIN

		p.scale_y = 0.8
		p.scale_x = 1.2
		if bouncy_collision and original_vy <= -3.5:
			p.vy = minf(absf(original_vy), MAX_CEILING_BOUNCE_SPEED)
			p.is_jumping = false
			p.coyote_timer = 24
			sim.add_shake(absf(original_vy) * 0.3 + 1.0)
			sim.spawn_particles(p.center_x(), p.y, _bounce_color(is_player_bouncy), 8, 3.0)
			sim.play(Sfx.Id.BOUNCE)
		else:
			p.vy = 0.0


static func _any_bouncy(blocks: Array[SolidBox]) -> bool:
	for b: SolidBox in blocks:
		if Tile.is_bouncy(b.type):
			return true
	return false


static func _bounce_color(is_player_bouncy: bool) -> Color:
	return Palette.PURPLE_500 if is_player_bouncy else Palette.PINK_500
