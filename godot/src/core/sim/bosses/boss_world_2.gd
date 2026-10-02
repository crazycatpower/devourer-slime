class_name BossWorld2
extends RefCounted
## World 2 boss: a bouncy slime inside a shield that cannot be eaten.
##
## It charges up, then pinballs around the arena, cracking the floor wherever
## it lands. Each time it drops out of the bottom of the map it loses one
## point of durability and returns angrier; at zero it is defeated.

const GRAVITY_RESTING: float = 0.25
const GRAVITY_LEAPING: float = 0.2
const INTRO_TICKS: int = 120
const REST_TICKS: int = 120
const CHARGE_TICKS: int = 180
const LEAP_SPEED: float = 18.0
const BOUNCE_RESTITUTION: float = 1.05
const SPARK_COLOR: Color = Palette.FUCHSIA_400
const BODY_COLOR: Color = Palette.PINK_600

## Where the trophy (goal ringed by bouncy blocks) appears on defeat.
const TROPHY_ROW: int = 9
const TROPHY_COL: int = 24


## Ground bounces a leap makes; grows as the boss loses durability.
static func bounces_for(durability: int) -> int:
	return 3 + 2 * (BossState.MAX_DURABILITY - durability)


## Horizontal launch speed for a leap toward a player [param dx] away.
static func leap_vx(dx: float) -> float:
	var direction: float = 1.0 if dx >= 0.0 else -1.0
	return direction * maxf(2.5, minf(14.0, absf(dx * 0.035)))


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
			_update_intro(sim)
		BossState.State.FALLING:
			_update_falling(sim)
		BossState.State.ACTIVE:
			boss.vx = 0.0
			BossSystem.settle_on_floor(sim, GRAVITY_RESTING)
			if boss.grounded:
				boss.cooldown -= 1
				if boss.cooldown <= 0:
					boss.state = BossState.State.CHARGING
					boss.charge_timer = CHARGE_TICKS
					boss.max_charge_timer = CHARGE_TICKS
					boss.vx = 0.0
		BossState.State.CHARGING:
			_update_charging(sim)
		BossState.State.JUMPING:
			_update_leaping(sim)

	if boss.y > sim.level.pixel_height():
		_on_fell_out_of_map(sim)


static func _update_intro(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	boss.intro_timer -= 1
	if boss.y < 80.0:
		boss.y += 1.5
	if boss.intro_timer % 2 == 0:
		BossSystem.spawn_converging_spark(sim, 100.0, 20.0, SPARK_COLOR, 3.0, 3.0)
	if boss.intro_timer <= 0:
		boss.state = BossState.State.FALLING
		boss.vy = 2.0
		sim.camera.shake = 18.0
		sim.play(Sfx.Id.BOUNCE)
		sim.spawn_particles(boss.center_x(), boss.center_y(), BODY_COLOR, 30, 6.0)


static func _update_falling(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	boss.vy += GRAVITY_RESTING
	boss.y += boss.vy
	var r_floor: int = BossSystem.floor_row(boss)
	if BossSystem.rests_on_floor(sim, r_floor):
		boss.y = float(r_floor) * Tile.SIZE - boss.h
		boss.vy = 0.0
		boss.state = BossState.State.ACTIVE
		boss.grounded = true
		boss.cooldown = REST_TICKS
		boss.scale_y = 0.5
		boss.scale_x = 1.6
		sim.camera.shake = 24.0
		sim.play(Sfx.Id.LAND)
		sim.spawn_particles(boss.center_x(), boss.y + boss.h, BODY_COLOR, 30, 5.5)
		sim.damage_tiles_under_boss(r_floor)


static func _update_charging(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	boss.vx = 0.0
	BossSystem.settle_on_floor(sim, GRAVITY_RESTING)

	# Telegraph: the body jitters, flashes and draws in sparks.
	boss.scale_x = 1.0 + (sim.rng.next_float() - 0.5) * 0.18
	boss.scale_y = 1.0 + (sim.rng.next_float() - 0.5) * 0.18
	boss.damage_flash = 0.4 + sin(sim.clock_ms() / 40.0) * 0.4
	if boss.charge_timer % 3 == 0:
		BossSystem.spawn_converging_spark(sim, 110.0, 20.0, SPARK_COLOR, 4.0, 3.0)

	boss.charge_timer -= 1
	if boss.charge_timer <= 0:
		boss.state = BossState.State.JUMPING
		boss.vy = -LEAP_SPEED
		boss.vx = leap_vx(BossSystem.player_dx(sim))
		boss.grounded = false
		boss.scale_y = 1.9
		boss.scale_x = 0.4
		sim.camera.shake = 22.0
		sim.play(Sfx.Id.JUMP)
		sim.spawn_particles(boss.center_x(), boss.y + boss.h, BODY_COLOR, 45, 8.0)
		boss.bounces_remaining = bounces_for(boss.durability)


static func _update_leaping(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var level: LevelGrid = sim.level
	boss.vy += GRAVITY_LEAPING
	boss.x += boss.vx

	# Blocks in the way are damaged and the boss rebounds off them.
	var col_start: int = maxi(0, floori(boss.x / Tile.SIZE))
	var col_end: int = mini(level.cols - 1, floori((boss.x + boss.w - 1.0) / Tile.SIZE))
	var row_start: int = maxi(0, floori(boss.y / Tile.SIZE))
	var row_end: int = mini(level.rows - 1, floori((boss.y + boss.h - 1.0) / Tile.SIZE))
	var target_col: int = -1
	var hit_rows: PackedInt32Array = PackedInt32Array()
	for r: int in range(row_start, row_end + 1):
		for c: int in range(col_start, col_end + 1):
			if Tile.is_solid(level.get_cell(r, c)):
				target_col = c
				if not hit_rows.has(r):
					hit_rows.append(r)

	if target_col >= 0:
		if boss.vx > 0.0:
			boss.x = float(target_col) * Tile.SIZE - boss.w - 0.1
			sim.spawn_particles(boss.x + boss.w, boss.center_y(), BODY_COLOR, 15, 4.0)
		elif boss.vx < 0.0:
			boss.x = float(target_col + 1) * Tile.SIZE + 0.1
			sim.spawn_particles(boss.x, boss.center_y(), BODY_COLOR, 15, 4.0)
		for r: int in hit_rows:
			sim.damage_cell_at(r, target_col)
		boss.vx = -boss.vx * BOUNCE_RESTITUTION
		sim.add_shake(18.0)
		sim.play(Sfx.Id.BOUNCE)

	boss.y += boss.vy

	# Walls and ceiling are elastic and do not use up a bounce.
	var right_limit: float = level.pixel_width() - Tile.SIZE
	if boss.x < Tile.SIZE:
		boss.x = Tile.SIZE
		boss.vx = -boss.vx * BOUNCE_RESTITUTION
		sim.add_shake(15.0)
		sim.play(Sfx.Id.BOUNCE)
		sim.spawn_particles(boss.x, boss.center_y(), BODY_COLOR, 15, 4.0)
	elif boss.x + boss.w > right_limit:
		boss.x = right_limit - boss.w
		boss.vx = -boss.vx * BOUNCE_RESTITUTION
		sim.add_shake(15.0)
		sim.play(Sfx.Id.BOUNCE)
		sim.spawn_particles(boss.x + boss.w, boss.center_y(), BODY_COLOR, 15, 4.0)

	if boss.y < Tile.SIZE:
		boss.y = Tile.SIZE
		boss.vy = -boss.vy * BOUNCE_RESTITUTION
		sim.add_shake(15.0)
		sim.play(Sfx.Id.BOUNCE)
		sim.spawn_particles(boss.center_x(), boss.y, BODY_COLOR, 15, 4.0)

	var r_floor: int = BossSystem.floor_row(boss)
	if not (BossSystem.rests_on_floor(sim, r_floor) and boss.vy >= 0.0):
		return
	boss.y = float(r_floor) * Tile.SIZE - boss.h
	if boss.bounces_remaining > 0:
		# Only touching the ground uses up a bounce.
		boss.vy = -LEAP_SPEED
		if absf(boss.vx) < 5.0:
			boss.vx = (1.0 if boss.vx >= 0.0 else -1.0) * 6.0
		else:
			boss.vx = boss.vx * BOUNCE_RESTITUTION
		boss.bounces_remaining -= 1
		sim.add_shake(22.0)
		sim.play(Sfx.Id.BOUNCE)
		sim.spawn_particles(boss.center_x(), boss.y + boss.h, BODY_COLOR, 30, 6.0)
		sim.damage_tiles_under_boss(r_floor)
	else:
		boss.vy = 0.0
		boss.vx = 0.0
		boss.grounded = true
		boss.state = BossState.State.ACTIVE
		boss.cooldown = REST_TICKS
		boss.scale_y = 0.5
		boss.scale_x = 1.6
		sim.camera.shake = 26.0
		sim.play(Sfx.Id.LAND)
		sim.spawn_particles(boss.center_x(), boss.y + boss.h, BODY_COLOR, 40, 7.0)
		sim.damage_tiles_under_boss(r_floor)


static func _on_fell_out_of_map(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var level: LevelGrid = sim.level
	boss.durability -= 1
	if boss.durability > 0:
		# Back to the top for another round.
		boss.x = BossSystem.spawn_x(level, boss.w)
		boss.y = BossState.SPAWN_Y
		boss.prev_x = boss.x
		boss.prev_y = boss.y
		boss.vx = 0.0
		boss.vy = 0.0
		boss.state = BossState.State.INTRO
		boss.intro_timer = INTRO_TICKS
		# The fight is on: the player keeps control while the boss floats back
		# down, instead of being dropped into whatever hole they are over.
		boss.intro_freezes_player = false
		sim.camera.shake = 30.0
		sim.play(Sfx.Id.HURT)
		sim.spawn_particles(boss.x + boss.w / 2.0, 100.0, SPARK_COLOR, 55, 7.5)
		return

	BossSystem.defeat(sim)
	sim.camera.shake = 40.0
	sim.play(Sfx.Id.HURT)
	sim.spawn_particles(boss.center_x(), boss.y - boss.h, BODY_COLOR, 60, 9.0)
	sim.spawn_particles(boss.center_x(), boss.y - boss.h, Palette.PURPLE_500, 40, 8.0)
	sim.spawn_particles(boss.center_x(), boss.y - boss.h, Palette.EMERALD_400, 40, 8.0)

	# Clear the middle of the arena and leave the goal ringed by bouncy blocks.
	BossSystem.place_trophy(
		level, BossSystem.trophy_cell(level, TROPHY_ROW, TROPHY_COL), Tile.BOUNCY, 3
	)
