class_name BossWorld3
extends RefCounted
## World 3 boss: a flying glass slime ringed by orbiting shields.
##
## It hovers above the player and fires its shields one by one. Once they are
## spent it lobs dirt three times (ammunition for the player) and regrows a
## larger ring. A block spat into its core costs it one point of durability.

const INTRO_TICKS: int = 120
const ATTACK_COOLDOWN_TICKS: int = 110
const HOVER_HEIGHT: float = 320.0
const SWAY_AMPLITUDE: float = 190.0
const SWAY_PERIOD_MS: float = 1300.0
const ORBIT_PERIOD_MS: float = 1500.0
const DETACHED_RADIUS: float = 140.0
const SHIELD_SHOT_SPEED: float = 7.0
const DIRT_SHOT_SPEED: float = 5.5
## Angle between neighbouring dirt shots in a volley (about 12 degrees).
const DIRT_SPREAD: float = 0.22
const DIRT_VOLLEYS_PER_CYCLE: int = 3
## A spat block within this distance of a shield centre shatters it.
const SHIELD_HIT_RADIUS: float = 32.0
const CORE_HIT_RADIUS: float = 60.0
const BODY_COLOR: Color = Palette.CYAN_500
const SPARK_COLOR: Color = Palette.CYAN_400

## Where the trophy (goal ringed by glass) appears on defeat.
const TROPHY_ROW: int = 9
const TROPHY_COL: int = 24


## Shields in the ring for a given durability: 4, then 8, then 12.
static func shield_count_for(durability: int) -> int:
	if durability >= 3:
		return 4
	return 8 if durability == 2 else 12


## A fresh ring is immediately usable for both rendering and collision.
static func regenerate_shields(sim: GameSim) -> void:
	sim.boss.shields = BossState.make_shield_ring(shield_count_for(sim.boss.durability))
	sync_orbiting_shields(sim)


static func sync_orbiting_shields(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	for shield: ShieldState in boss.shields:
		if not shield.active or shield.mode != ShieldState.Mode.ORBIT:
			continue
		var angle: float = sim.clock_ms() / ORBIT_PERIOD_MS + shield.angle_offset
		shield.radius = BossState.SHIELD_ORBIT_RADIUS
		shield.cx = boss.center_x() + cos(angle) * shield.radius
		shield.cy = boss.center_y() + sin(angle) * shield.radius


static func update(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	if boss.damage_flash > 0.0:
		boss.damage_flash -= 0.05
	boss.scale_x += (1.0 - boss.scale_x) * 0.15
	boss.scale_y += (1.0 - boss.scale_y) * 0.15

	match boss.state:
		BossState.State.SUSPENDED:
			if BossSystem.player_in_trigger_range(sim):
				BossSystem.begin_intro(sim, INTRO_TICKS)
				sim.camera.shake = 15.0
				sim.spawn_particles(boss.center_x(), boss.center_y(), BODY_COLOR, 30, 5.0)
				sim.play(Sfx.Id.BOUNCE)
		BossState.State.INTRO:
			boss.intro_timer -= 1
			if boss.y < 130.0:
				boss.y += 1.8
			if boss.intro_timer % 2 == 0:
				BossSystem.spawn_converging_spark(sim, 100.0, 20.0, SPARK_COLOR, 3.0, 3.0)
			if boss.intro_timer <= 0:
				boss.state = BossState.State.ACTIVE
				boss.cooldown = ATTACK_COOLDOWN_TICKS
				boss.max_cooldown = ATTACK_COOLDOWN_TICKS
				sim.camera.shake = 18.0
				sim.play(Sfx.Id.BOUNCE)
				sim.spawn_particles(boss.center_x(), boss.center_y(), BODY_COLOR, 35, 6.5)
		_:
			_hover(sim)
			_update_shields(sim)
			boss.cooldown -= 1
			if boss.cooldown <= 0:
				boss.cooldown = ATTACK_COOLDOWN_TICKS
				_attack(sim)
	sync_orbiting_shields(sim)


## Handles a player projectile at ([param cx], [param cy]). Returns true when
## it hit a shield or the core and must be removed.
static func hit_by_projectile(sim: GameSim, cx: float, cy: float, preview: bool = false) -> bool:
	var boss: BossState = sim.boss
	for shield: ShieldState in boss.shields:
		if not shield.active:
			continue
		var sdx: float = cx - shield.cx
		var sdy: float = cy - shield.cy
		if sqrt(sdx * sdx + sdy * sdy) < SHIELD_HIT_RADIUS:
			if preview:
				return true
			shield.active = false
			sim.play(Sfx.Id.BOUNCE)
			sim.spawn_particles(cx, cy, BODY_COLOR, 20, 5.0)
			return true

	var bcx: float = boss.center_x()
	var bcy: float = boss.center_y()
	var cdx: float = cx - bcx
	var cdy: float = cy - bcy
	if sqrt(cdx * cdx + cdy * cdy) >= CORE_HIT_RADIUS:
		return false

	if preview:
		return true
	boss.durability -= 1
	boss.damage_flash = 1.0
	boss.scale_x = 1.45
	boss.scale_y = 0.6
	sim.camera.shake = 25.0
	sim.play(Sfx.Id.HURT)
	sim.spawn_particles(bcx, bcy, BODY_COLOR, 30, 7.0)
	sim.spawn_particles(bcx, bcy, Palette.AMBER_400, 20, 6.0)

	if boss.durability > 0:
		regenerate_shields(sim)
		return true

	BossSystem.defeat(sim)
	sim.camera.shake = 40.0
	sim.play(Sfx.Id.WIN)
	sim.spawn_particles(bcx, bcy, BODY_COLOR, 60, 9.0)
	sim.spawn_particles(bcx, bcy, Palette.AMBER_400, 40, 8.0)
	sim.spawn_particles(bcx, bcy, SPARK_COLOR, 40, 8.0)

	# Clear the middle of the arena and leave the goal ringed by glass.
	BossSystem.place_trophy(
		sim.level, BossSystem.trophy_cell(sim.level, TROPHY_ROW, TROPHY_COL), Tile.GLASS, 2
	)
	return true


## Drifts above the player, swaying left and right inside the arena.
static func _hover(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var player: PlayerState = sim.player
	var level: LevelGrid = sim.level
	var target_y: float = player.y - HOVER_HEIGHT
	target_y = maxf(50.0, minf(level.pixel_height() - 380.0, target_y))
	var target_x: float = player.x + sin(sim.clock_ms() / SWAY_PERIOD_MS) * SWAY_AMPLITUDE
	target_x = maxf(
		Tile.SIZE * 2.5, minf(level.pixel_width() - Tile.SIZE * 2.5 - boss.w, target_x)
	)
	boss.vx = (target_x - boss.x) * 0.035
	boss.vy = (target_y - boss.y) * 0.045
	boss.x += boss.vx
	boss.y += boss.vy


static func _update_shields(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var player: PlayerState = sim.player
	var bcx: float = boss.center_x()
	var bcy: float = boss.center_y()
	for shield: ShieldState in boss.shields:
		if not shield.active:
			continue
		var angle: float = (sim.clock_ms() / ORBIT_PERIOD_MS) + shield.angle_offset
		if shield.mode == ShieldState.Mode.ORBIT:
			shield.radius = BossState.SHIELD_ORBIT_RADIUS
			shield.cx = bcx + cos(angle) * shield.radius
			shield.cy = bcy + sin(angle) * shield.radius
			continue

		# Detaching: step out of the ring, glow, then launch at the player.
		shield.detaching_timer -= 1
		var progress: float = 1.0 - (float(shield.detaching_timer) / float(ShieldState.DETACH_TICKS))
		shield.radius = (
			BossState.SHIELD_ORBIT_RADIUS
			+ (DETACHED_RADIUS - BossState.SHIELD_ORBIT_RADIUS) * minf(1.0, progress)
		)
		shield.cx = bcx + cos(angle) * shield.radius
		shield.cy = bcy + sin(angle) * shield.radius

		if shield.detaching_timer % 3 == 0:
			var px: float = shield.cx + (sim.rng.next_float() - 0.5) * 16.0
			var py: float = shield.cy + (sim.rng.next_float() - 0.5) * 16.0
			var pvx: float = (sim.rng.next_float() - 0.5) * 2.5
			var pvy: float = (sim.rng.next_float() - 0.5) * 2.5
			sim.add_particle(px, py, pvx, pvy, 12.0, SPARK_COLOR, sim.rng.next_float() * 2.5 + 2.5)

		if shield.detaching_timer <= 0:
			shield.active = false
			var dx: float = player.center_x() - shield.cx
			var dy: float = player.center_y() - shield.cy
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist > 0.0:
				_fire(
					sim, shield.cx, shield.cy,
					(dx / dist) * SHIELD_SHOT_SPEED, (dy / dist) * SHIELD_SHOT_SPEED, Tile.GLASS
				)
				sim.play(Sfx.Id.JUMP)
				sim.spawn_particles(shield.cx, shield.cy, BODY_COLOR, 22, 5.5)


static func _attack(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var orbiting: Array[ShieldState] = []
	var any_active: bool = false
	for shield: ShieldState in boss.shields:
		if shield.active:
			any_active = true
			if shield.mode == ShieldState.Mode.ORBIT:
				orbiting.append(shield)

	if any_active:
		if orbiting.is_empty():
			return
		# The lower its durability, the more shields it may fire at once.
		var count: int = mini(orbiting.size(), _volley_size(sim))
		for _k: int in count:
			if orbiting.is_empty():
				break
			var chosen: ShieldState = orbiting.pop_at(sim.rng.next_below(orbiting.size()))
			chosen.mode = ShieldState.Mode.DETACHING
			chosen.detaching_timer = ShieldState.DETACH_TICKS
		sim.play(Sfx.Id.BOUNCE)
		return

	# Out of shields: throw dirt, and regrow the ring after the third volley.
	boss.dirt_shots_fired += 1
	var bx: float = boss.center_x()
	var by: float = boss.center_y()
	var dx: float = sim.player.center_x() - bx
	var dy: float = sim.player.center_y() - by
	var dist: float = sqrt(dx * dx + dy * dy)
	var num_dirt: int = _volley_size(sim)
	if dist > 0.0:
		var base_angle: float = atan2(dy, dx)
		var start_angle: float = base_angle - (float(num_dirt - 1) / 2.0) * DIRT_SPREAD
		for i: int in num_dirt:
			var cur_angle: float = start_angle + float(i) * DIRT_SPREAD
			_fire(
				sim, bx, by,
				cos(cur_angle) * DIRT_SHOT_SPEED, sin(cur_angle) * DIRT_SHOT_SPEED, Tile.DIRT
			)
		sim.spawn_particles(bx, by, Palette.AMBER_600, 20, 5.5)
		sim.play(Sfx.Id.JUMP)

	if boss.dirt_shots_fired >= DIRT_VOLLEYS_PER_CYCLE:
		boss.dirt_shots_fired = 0
		regenerate_shields(sim)
		sim.spawn_particles(bx, by, BODY_COLOR, 25, 6.5)
		sim.play(Sfx.Id.BOUNCE)


## Shots per attack: 1 at full durability, 1-3 at two, 1-5 at one.
static func _volley_size(sim: GameSim) -> int:
	var hp: int = sim.boss.durability
	if hp == 2:
		return sim.rng.next_below(3) + 1
	if hp <= 1:
		return sim.rng.next_below(5) + 1
	return 1


static func _fire(sim: GameSim, cx: float, cy: float, pvx: float, pvy: float, type: int) -> void:
	var projectile: SimProjectile = SimProjectile.new()
	projectile.x = cx - 20.0
	projectile.y = cy - 20.0
	projectile.prev_x = projectile.x
	projectile.prev_y = projectile.y
	projectile.vx = pvx
	projectile.vy = pvy
	projectile.type = type
	projectile.is_enemy = true
	sim.projectiles.append(projectile)
