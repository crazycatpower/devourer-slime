class_name SlimeMotion
extends RefCounted
## Presentation-only jelly spring, idle expressions and reactions (head bumps,
## hard landings, long falls, teetering on a ledge); never changes physics.

## Rising faster than this, then stopping in mid-air, counts as a head bump.
## Gravity alone slows a rise by 0.4 per tick, so even a frame spanning eight
## ticks cannot mistake the top of a jump for a bump.
const BUMP_MIN_SPEED: float = 3.5
## A jump covers at most this much height within one frame of eight ticks;
## a bigger leap is a teleport, not a jump cut short.
const MAX_FRAME_RISE: float = 80.0
## Head bumps at least this fast leave the slime dizzy.
const DAZE_MIN_SPEED: float = 5.5
const WINCE_SECONDS: float = 0.28
const HARD_LANDING_WINCE_SECONDS: float = 0.22
## Falls longer than this, in world units, end in a wince.
const HARD_LANDING_FALL: float = 180.0
## The eyes widen as a fall grows between these distances, beyond a jump's height.
const ALARM_FALL_START: float = 200.0
const ALARM_FALL_FULL: float = 320.0
## Distance walked per squash-and-stretch cycle, in world units.
const GAIT_STRIDE: float = 52.0
const GAIT_SQUASH: float = 0.035

var body_scale: Vector2 = Vector2.ONE
var lean: float = 0.0
var idle_seconds: float = 0.0
var time: float = 0.0
var happy: bool = false
var sleepy: bool = false
var blink: float = 0.0
var look_offset: float = 0.0
var chew: float = 0.0
var wall_pressure: float = 0.0
var ground_contact: float = 0.0
## 0..1: eyes squeezed shut after an impact.
var wince: float = 0.0
## 0..1: dizziness after a hard head bump; [member daze_age] drives the swirl.
var daze: float = 0.0
var daze_age: float = 0.0
## 0..1: eyes widen during a long fall.
var alarm: float = 0.0
## -1..1: balancing on a ledge, signed toward the drop.
var teeter: float = 0.0
## 0..1: share of the squash pivoting on the head instead of the feet.
var head_anchor: float = 0.0
## Seconds since the last head bump, and the middle of the head when it hit.
var bump_age: float = INF
var bump_point: Vector2 = Vector2.ZERO
## The last bump bounced the slime back down (a bouncy ceiling or a boss).
var bump_soft: bool = false
## True only during the frame the slime lands from a long fall.
var landed_hard: bool = false

var _spring: float = 0.0
var _lean_speed: float = 0.0
var _speed: float = 0.0
var _was_grounded: bool = false
var _had_block: bool = false
var _last_vy: float = 0.0
var _last_vx: float = 0.0
var _last_x: float = 0.0
var _last_y: float = 0.0
## Highest point (smallest y) since the slime last stood or bounced.
var _air_top_y: float = 0.0
var _gait_phase: float = 0.0
var _wince_left: float = 0.0
var _daze_left: float = 0.0
var _initialized: bool = false
## A restart replaces the player; its new state must not read as motion.
var _player: PlayerState


func advance(
	delta: float, player: PlayerState, active: bool = false, wall: float = 0.0, ledge: float = 0.0
) -> void:
	var dt: float = clampf(delta, 0.0, 0.1)
	time += dt
	if player != _player:
		reset()
		_player = player
	if not _initialized:
		_was_grounded = player.grounded
		_had_block = player.has_block
		_last_vx = player.vx
		_last_vy = player.vy
		_last_x = player.x
		_last_y = player.y
		_air_top_y = player.y
		_initialized = true
	if player.dead:
		reset()
		return
	bump_age += dt
	landed_hard = false
	ground_contact = lerpf(ground_contact, 1.0 if player.grounded else 0.0, 1.0 - exp(-24.0 * dt))
	wall_pressure = lerpf(wall_pressure, clampf(wall, -1.0, 1.0), 1.0 - exp(-18.0 * dt))
	if dt > 0.0 and absf(player.vx) < absf(_last_vx):
		var braking: float = minf(absf(player.vx - _last_vx), 6.0)
		_speed -= braking * 0.65
		_lean_speed += signf(_last_vx) * braking * 0.075
	_last_vx = player.vx
	if player.grounded and not _was_grounded:
		_speed -= clampf(absf(_last_vy) * 0.55, 1.5, 7.0)
		if player.y - _air_top_y > HARD_LANDING_FALL:
			_wince_left = maxf(_wince_left, HARD_LANDING_WINCE_SECONDS)
			landed_hard = true
	elif not player.grounded and _was_grounded and player.vy < 0.0:
		_speed += 3.0
	_detect_bump(player)
	if player.has_block != _had_block:
		_speed += -4.5 if player.has_block else 5.0
		chew = 1.0
	if player.grounded:
		_air_top_y = player.y
	else:
		if player.vy < 0.0 and _last_vy > 0.0:
			# Bounced: the next fall is measured from the new peak.
			_air_top_y = player.y
		_air_top_y = minf(_air_top_y, player.y)
	if player.grounded:
		_gait_phase = fmod(_gait_phase + minf(absf(player.x - _last_x), 24.0) / GAIT_STRIDE, 1.0)
	_was_grounded = player.grounded
	_had_block = player.has_block
	_last_vy = player.vy
	_last_x = player.x
	_last_y = player.y
	chew = maxf(0.0, chew - dt * 2.2)
	_wince_left = maxf(0.0, _wince_left - dt)
	wince = clampf(_wince_left / 0.06, 0.0, 1.0)
	if _daze_left > 0.0:
		_daze_left = maxf(0.0, _daze_left - dt)
		daze_age += dt
	daze = clampf(_daze_left / 0.3, 0.0, 1.0)
	head_anchor = 1.0 - smoothstep(0.08, 0.26, bump_age)
	var falling: float = 0.0
	if not player.grounded and not player.won and player.vy > 0.0:
		falling = player.y - _air_top_y
	alarm = lerpf(alarm, smoothstep(ALARM_FALL_START, ALARM_FALL_FULL, falling), 1.0 - exp(-10.0 * dt))
	var still: bool = player.grounded and not player.won and absf(player.vx) < 0.25 and not active
	teeter = move_toward(teeter, signf(ledge) if still else 0.0, dt * 4.0)
	var idle: bool = still and is_zero_approx(ledge)
	idle_seconds = idle_seconds + dt if idle else 0.0
	var phase: float = fmod(idle_seconds, 14.0)
	happy = idle_seconds > 2.0 and phase >= 3.0 and phase < 5.0
	sleepy = idle_seconds > 10.0 and phase >= 10.5 and phase < 12.8
	look_offset = sin((phase - 6.0) * 2.4) * 0.8 if phase >= 6.0 and phase < 8.6 else 0.0
	var wiggle: float = 0.0
	if happy:
		wiggle = sin((phase - 3.0) * TAU * 1.6) * 0.07
	var intake: float = clampf(player.eating_progress, 0.0, 1.0)
	var charging: bool = player.has_block and player.in_bullet_time and not player.waiting_for_shoot_release
	var action_squash: float = -intake * 0.10 + sin(time * 32.0) * intake * 0.025
	if charging:
		action_squash -= 0.09 + sin(time * 20.0) * 0.025
	var breath: float = sin(time * 2.8) * (0.045 if idle else 0.012)
	# One squash and stretch per stride, locked to the distance actually walked.
	var pace: float = clampf(absf(player.vx) / GameConstants.MAX_SPEED, 0.0, 1.0) * ground_contact
	var gait: float = sin(_gait_phase * TAU) * GAIT_SQUASH * pace
	# Integrate at small steps so the spring stays stable even after a slow frame.
	var left: float = dt
	while left > 0.000001:
		var step: float = minf(left, 1.0 / 240.0)
		_speed += (-180.0 * _spring - 12.0 * _speed) * step
		_spring = clampf(_spring + _speed * step, -0.23, 0.23)
		left -= step
	var firmness: float = 0.45 if player.has_block else 1.0
	var flow: float = sin(time * 5.2 + sin(time * 1.7) * 0.5) * 0.012
	var contact_squash: float = -ground_contact * 0.035 + absf(wall_pressure) * 0.11
	var stretch: float = clampf((_spring + breath + wiggle + action_squash + flow + contact_squash + gait) * firmness, -0.23, 0.23)
	var fullness: float = 1.075 if player.has_block else 1.0
	var target: Vector2 = Vector2(
		lerpf(1.0, clampf(player.scale_x, 0.8, 1.25), firmness) * fullness / (1.0 + stretch),
		lerpf(1.0, clampf(player.scale_y, 0.8, 1.25), firmness) * fullness * (1.0 + stretch)
	)
	body_scale = body_scale.lerp(target, 1.0 - exp(-30.0 * dt))
	var lean_target: float = clampf(player.vx * 0.01, -0.09, 0.09)
	lean_target *= 1.0 - absf(wall_pressure)
	if happy:
		lean_target += sin((phase - 3.0) * TAU * 0.8) * 0.055
	elif sleepy:
		lean_target += sin((phase - 10.5) * PI / 2.3) * 0.04
	# Balancing on a ledge: tip toward the drop and wobble back.
	lean_target += teeter * (0.075 + sin(time * 9.0) * 0.045)
	left = dt
	while left > 0.000001:
		var step: float = minf(left, 1.0 / 240.0)
		_lean_speed += (100.0 * (lean_target * firmness - lean) - 11.0 * _lean_speed) * step
		lean = clampf(lean + _lean_speed * step, -0.14, 0.14)
		left -= step
	# Two soft blinks per cycle, rather than an abrupt eye swap.
	var blink_phase: float = fmod(time, 4.8)
	blink = maxf(_blink_at(blink_phase, 0.15), _blink_at(blink_phase, 0.48))
	if sleepy:
		blink = maxf(blink, 0.65)


func reset() -> void:
	body_scale = Vector2.ONE
	lean = 0.0
	_lean_speed = 0.0
	_last_vx = 0.0
	_last_vy = 0.0
	wall_pressure = 0.0
	ground_contact = 0.0
	idle_seconds = 0.0
	_spring = 0.0
	_speed = 0.0
	_initialized = false
	happy = false
	sleepy = false
	chew = 0.0
	look_offset = 0.0
	blink = 0.0
	wince = 0.0
	_wince_left = 0.0
	daze = 0.0
	daze_age = 0.0
	_daze_left = 0.0
	alarm = 0.0
	teeter = 0.0
	head_anchor = 0.0
	bump_age = INF
	bump_soft = false
	landed_hard = false
	_gait_phase = 0.0


## A rise that stops in mid-air hit something overhead. Spitting a block
## upward also stops a rise, so a frame where the block changes is skipped.
func _detect_bump(player: PlayerState) -> void:
	if player.grounded or player.vy < -0.5 or player.has_block != _had_block:
		return
	if _last_vy < -BUMP_MIN_SPEED:
		_bump(player, -_last_vy)
	elif _was_grounded and player.y < _last_y - 0.5 and player.y > _last_y - MAX_FRAME_RISE:
		# A low ceiling stopped the jump within the frame it started.
		_bump(player, GameConstants.JUMP_FORCE)


func _bump(player: PlayerState, speed: float) -> void:
	bump_age = 0.0
	bump_point = Vector2(player.center_x(), minf(player.y, player.prev_y))
	bump_soft = player.vy > 3.0
	_speed -= clampf(speed * 0.6, 2.0, 7.5)
	_wince_left = maxf(_wince_left, WINCE_SECONDS)
	if not bump_soft and speed >= DAZE_MIN_SPEED:
		if _daze_left <= 0.0:
			daze_age = 0.0
		_daze_left = maxf(_daze_left, 0.7 + 0.6 * clampf((speed - DAZE_MIN_SPEED) / 6.0, 0.0, 1.0))


static func _blink_at(phase: float, center: float) -> float:
	return maxf(0.0, 1.0 - absf(phase - center) / 0.10)


## Read-only terrain contact query, independent of input or facing direction.
static func wall_contact(sim: GameSim) -> float:
	var player: PlayerState = sim.player
	var top: int = floori((player.y + 3.0) / Tile.SIZE)
	var bottom: int = floori((player.y + player.h - 3.0) / Tile.SIZE)
	var left: int = floori((player.x - 1.0) / Tile.SIZE)
	var right: int = floori((player.x + player.w + 1.0) / Tile.SIZE)
	var touches_left: bool = false
	var touches_right: bool = false
	for r: int in range(top, bottom + 1):
		touches_left = touches_left or sim.is_solid_or_boundary(r, left)
		touches_right = touches_right or sim.is_solid_or_boundary(r, right)
	if touches_left and touches_right:
		return -1.0 if sim.input.left else (1.0 if sim.input.right else 0.0)
	return -1.0 if touches_left else (1.0 if touches_right else 0.0)


## Read-only ledge query: the side (-1 or 1) where a standing slime hangs over
## a drop with its middle unsupported, otherwise 0.
static func ledge_drop(sim: GameSim) -> float:
	var player: PlayerState = sim.player
	if not player.grounded:
		return 0.0
	var below: float = player.y + player.h + 1.0
	if not sim.solid_boxes(player.center_x() - 1.0, below, 2.0, 2.0).is_empty():
		return 0.0
	var on_left: bool = not sim.solid_boxes(player.x, below, 2.0, 2.0).is_empty()
	var on_right: bool = not sim.solid_boxes(player.x + player.w - 2.0, below, 2.0, 2.0).is_empty()
	if on_left == on_right:
		return 0.0
	return 1.0 if on_left else -1.0
