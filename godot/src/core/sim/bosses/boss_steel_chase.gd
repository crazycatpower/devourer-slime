class_name BossSteelChase
extends RefCounted
## A moving, full-height steel crusher. Winning means escaping to the goal.

const TRIGGER_RUN: float = 160.0
const WARNING_TICKS: int = 90
const RETRY_WARNING_TICKS: int = 60
const SPEED: float = 1.6
const SPEED_VARIATION: float = 0.5
const NEAR_GAP: float = 0.0
const FAR_GAP: float = 10.0 * Tile.SIZE
const SPIKE_LENGTH: float = 16.0


static func setup(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	boss.w = 120.0
	boss.h = sim.level.pixel_height()
	boss.x = -boss.w - SPIKE_LENGTH
	boss.y = 0.0
	boss.prev_x = boss.x
	boss.prev_y = boss.y
	boss.target_vx = sim.player.x + TRIGGER_RUN
	boss.intro_freezes_player = true
	boss.grid.fill(Tile.STEEL)


static func update(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	if sim.player.won:
		BossSystem.defeat(sim)
		return
	if sim.player.dead:
		return
	if boss.state == BossState.State.SUSPENDED:
		if sim.player.x >= boss.target_vx:
			boss.state = BossState.State.INTRO
			boss.triggered = true
			boss.intro_duration = RETRY_WARNING_TICKS if sim.boss_intro_seen else WARNING_TICKS
			boss.intro_timer = boss.intro_duration
			sim.boss_intro_seen = true
			sim.add_shake(8.0)
			sim.play(Sfx.Id.LAND)
		return
	if boss.state == BossState.State.INTRO:
		boss.intro_timer -= 1
		# The steel face enters from the left during the warning.
		boss.x = lerpf(-boss.w - SPIKE_LENGTH, Tile.SIZE, 1.0 - float(boss.intro_timer) / float(boss.intro_duration))
		if boss.intro_timer <= 0:
			boss.state = BossState.State.ACTIVE
		return
	var gap: float = sim.player.x - (boss.x + boss.w + SPIKE_LENGTH)
	var distance_ratio: float = smoothstep(NEAR_GAP, FAR_GAP, gap)
	boss.vx = SPEED * lerpf(1.0 - SPEED_VARIATION, 1.0 + SPEED_VARIATION, distance_ratio)
	boss.x += boss.vx
	# The region behind the crushing face is lethal too; it cannot be bypassed.
	if sim.player.x < boss.x + boss.w + SPIKE_LENGTH:
		if sim.kill_player():
			sim.play(Sfx.Id.HURT)
			sim.add_shake(14.0)
