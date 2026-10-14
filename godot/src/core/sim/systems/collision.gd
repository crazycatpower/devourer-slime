class_name Collision
extends RefCounted
## Axis-separated collision of the player box against solid tiles.
##
## Bouncy tiles (or carrying a bouncy block) turn a collision into a bounce.

const SKIN: float = 0.001
## Above ordinary walking/jump impacts; only the velocity into the surface counts.
const TNT_IMPACT_SPEED: float = 14.0
const MIN_WALL_BOUNCE_SPEED: float = 5.5
const WALL_BOUNCE_LOCK_TICKS: int = 12
## A fall shorter than this (less than 1 tile) lands on bouncy blocks without bouncing.
const MIN_BOUNCE_FALL_HEIGHT: float = Tile.SIZE - 0.05
## Limits for bounces caused by a carried bouncy block. Bouncy tiles are not
## limited: they always return the full height or speed.
const MAX_FLOOR_BOUNCE_SPEED: float = 25.0
const MAX_CEILING_BOUNCE_SPEED: float = 20.0
## A bouncy tile sends the player this far above where the fall began, so that
## after stepping off a ledge the bounce clears its edge and can land back on it.
const BOUNCE_CLEARANCE: float = 3.0


static func solve_x(sim: GameSim) -> void:
	var p: PlayerState = sim.player
	var is_player_bouncy: bool = p.ability_type() == Tile.BOUNCY
	var original_vx: float = p.vx
	var blocks: Array[SolidBox] = _advance_axis(sim, true)
	if blocks.is_empty():
		return
	# Whatever was left of a spit's sideways kick ends at the wall.
	p.recoil_vx = 0.0
	var bouncy_collision: bool = _surface_bouncy(blocks, p, true) or is_player_bouncy
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

	if absf(original_vx) >= TNT_IMPACT_SPEED:
		MechanismSystem.detonate_carried_tnt(sim)
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
	var is_player_bouncy: bool = p.ability_type() == Tile.BOUNCY
	var original_vy: float = p.vy
	var blocks: Array[SolidBox] = _advance_axis(sim, false)
	var was_grounded: bool = p.grounded
	p.grounded = false

	if blocks.is_empty():
		return
	var block_bouncy: bool = _surface_bouncy(blocks, p, false)
	var bouncy_collision: bool = block_bouncy or is_player_bouncy

	if p.vy > 0.0:
		var hit_y: float = INF
		for b: SolidBox in blocks:
			hit_y = minf(hit_y, b.y)
		p.y = hit_y - p.h - SKIN
		if original_vy >= TNT_IMPACT_SPEED:
			MechanismSystem.detonate_carried_tnt(sim)

		var fall_height: float = p.y - p.fall_start_y
		if bouncy_collision and fall_height >= MIN_BOUNCE_FALL_HEIGHT:
			var bounce_speed: float
			if block_bouncy:
				# 彈力方塊：與下落高度完全相同的反彈，多次彈跳保持相同高度
				bounce_speed = maxf(sqrt(fall_height + BOUNCE_CLEARANCE) + 0.2, 5.0)
				p.fall_start_y = p.y - fall_height
				# The extra rise is not a new, higher fall: every bounce stays alike.
				p.bounce_slack = BOUNCE_CLEARANCE + 1.0
				p.vy = -bounce_speed
			else:
				# 攜帶彈力方塊在普通地面上：提供單次緩衝彈跳，隨後能正常著地站立
				bounce_speed = maxf(sqrt(fall_height), 5.0)
				p.fall_start_y = p.y
				p.bounce_slack = 0.0
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
		if -original_vy >= TNT_IMPACT_SPEED:
			MechanismSystem.detonate_carried_tnt(sim)

		p.scale_y = 0.8
		p.scale_x = 1.2
		if bouncy_collision and original_vy <= -3.5:
			p.vy = absf(original_vy) if block_bouncy else minf(absf(original_vy), MAX_CEILING_BOUNCE_SPEED)
			p.is_jumping = false
			p.coyote_timer = 24
			sim.add_shake(absf(original_vy) * 0.3 + 1.0)
			sim.spawn_particles(p.center_x(), p.y, _bounce_color(is_player_bouncy), 8, 3.0)
			sim.play(Sfx.Id.BOUNCE)
		else:
			p.vy = 0.0


## Fast carried TNT samples its path, avoiding skipped one-cell walls.
## Ordinary materials retain the established collision behavior.
static func _advance_axis(sim: GameSim, horizontal: bool) -> Array[SolidBox]:
	var player: PlayerState = sim.player
	var velocity: float = player.vx if horizontal else player.vy
	var displacement: float = velocity * (1.0 if horizontal and player.grounded else GameConstants.AIR_STEP)
	var steps: int = 1
	if player.ability_type() == Tile.TNT and absf(velocity) >= TNT_IMPACT_SPEED:
		steps = maxi(1, ceili(absf(displacement) / (Tile.SIZE * 0.5)))
	for step: int in steps:
		if horizontal:
			player.x += displacement / steps
		else:
			player.y += displacement / steps
		var blocks: Array[SolidBox] = sim.solid_boxes(player.x, player.y, player.w, player.h)
		if not blocks.is_empty():
			return blocks
	return []


## Only the stopping face contributes its material. At a mixed-material seam,
## use the largest contact span so a tiny corner cannot override the main surface.
static func _surface_bouncy(blocks: Array[SolidBox], p: PlayerState, horizontal: bool) -> bool:
	var positive: bool = (p.vx if horizontal else p.vy) > 0.0
	var face: float = INF if positive else -INF
	for b: SolidBox in blocks:
		var edge: float = (b.x if positive else b.x + b.w) if horizontal else (b.y if positive else b.y + b.h)
		face = minf(face, edge) if positive else maxf(face, edge)
	var largest_span: float = -1.0
	var bouncy: bool = false
	for b: SolidBox in blocks:
		var edge: float = (b.x if positive else b.x + b.w) if horizontal else (b.y if positive else b.y + b.h)
		if absf(edge - face) > SKIN:
			continue
		var span: float = minf(p.y + p.h, b.y + b.h) - maxf(p.y, b.y) if horizontal else minf(p.x + p.w, b.x + b.w) - maxf(p.x, b.x)
		if span > largest_span + SKIN:
			largest_span = span
			bouncy = Tile.is_bouncy(b.type)
		elif absf(span - largest_span) <= SKIN:
			bouncy = bouncy or Tile.is_bouncy(b.type)
	return bouncy


static func _bounce_color(is_player_bouncy: bool) -> Color:
	return Palette.PURPLE_500 if is_player_bouncy else Palette.PINK_500
