class_name BossMotion
extends RefCounted
## Presentation only: smooth poses and gaze without moving collision boxes.

var body_scale: Vector2 = Vector2.ONE
var look: Vector2 = Vector2.ZERO
var lean: float = 0.0
var impact: float = 0.0
var tension: float = 0.0
var _boss: BossState
var _last_tick: int = -1
var _velocity: Vector2 = Vector2.ZERO
var _grounded: bool = false


func advance(delta: float, sim: GameSim) -> void:
	var boss: BossState = sim.boss
	if boss != _boss or sim.tick_count < _last_tick:
		_boss = boss
		body_scale = Vector2.ONE
		look = Vector2.ZERO
		lean = 0.0
		impact = 0.0
		tension = 0.0
		_velocity = Vector2(boss.vx, boss.vy)
		_grounded = boss.grounded
		_last_tick = sim.tick_count
	var dt: float = clampf(delta, 0.0, 0.05)
	if sim.tick_count != _last_tick:
		var landed: bool = not _grounded and boss.grounded and _velocity.y > 2.0
		var bounced: bool = boss.kind == BossState.Kind.BOUNCY_SLIME and (
			(_velocity.y > 4.0 and boss.vy < -4.0) or (_velocity.x * boss.vx < 0.0 and absf(_velocity.x) > 4.0)
		)
		if landed or bounced:
			impact = 1.0
		_velocity = Vector2(boss.vx, boss.vy)
		_grounded = boss.grounded
		_last_tick = sim.tick_count
	impact = maxf(0.0, impact - dt * 3.5)
	var target_tension: float = 0.0
	if boss.state == BossState.State.CHARGING and boss.max_charge_timer > 0:
		target_tension = clampf(1.0 - float(boss.charge_timer) / boss.max_charge_timer, 0.0, 1.0)
	elif boss.state == BossState.State.PRE_JUMP and boss.max_pre_jump_timer > 0:
		target_tension = clampf(1.0 - float(boss.pre_jump_timer) / boss.max_pre_jump_timer, 0.0, 1.0)
	tension = lerpf(tension, target_tension, 1.0 - exp(-18.0 * dt))
	var elastic: bool = boss.kind in [BossState.Kind.BOUNCY_SLIME, BossState.Kind.VOID_SLIME]
	var target: Vector2 = Vector2(boss.scale_x, boss.scale_y)
	if elastic and boss.state in [BossState.State.CHARGING, BossState.State.PRE_JUMP]:
		# A continuous compression replaces frame-random size jitter.
		var pulse: float = sin(sim.clock_ms() / 80.0) * 0.018 * tension
		target = Vector2(1.0 + 0.3 * tension + pulse, 1.0 - 0.25 * tension - pulse)
	if elastic:
		body_scale = body_scale.lerp(target.clamp(Vector2(0.5, 0.5), Vector2(1.9, 1.9)), 1.0 - exp(-22.0 * dt))
		lean = lerpf(lean, clampf(boss.vx * 0.006, -0.1, 0.1), 1.0 - exp(-14.0 * dt))
	else:
		body_scale = Vector2.ONE
		lean = 0.0
	var from: Vector2 = Vector2(boss.center_x(), boss.center_y())
	if boss.kind == BossState.Kind.MUD_GOLEM:
		from = Vector2(boss.cell_x(boss.center_c), boss.cell_y(boss.center_r)) + Vector2.ONE * Tile.SIZE / 2.0
	var to_player: Vector2 = Vector2(sim.player.center_x(), sim.player.center_y()) - from
	look = look.lerp(to_player.normalized(), 1.0 - exp(-12.0 * dt))
