class_name BossWorld4
extends RefCounted
## World 4 boss: a void slime with eight hungry cells around its core.
##
## Its empty cells are lethal. The player feeds it by spitting blocks into
## them; every landing shakes blocks loose from the ceiling, and the fight
## escalates as it fills up (phase 2 at four cells, phase 3 at seven). Once
## all eight cells are full the player can devour the boss.

const GRAVITY: float = 0.2
const INTRO_TICKS: int = 180
const ULTIMATE_CHARGE_TICKS: int = 300
## Every this many attacks the boss charges its arena-wide ultimate.
const ACTIONS_PER_ULTIMATE: int = 8
const PHASE_2_FILLED: int = 4
const PHASE_3_FILLED: int = 7
const COMBO_HOPS: int = 3
const JUMP_SPEED_SCALE: float = 1.732
const MEGA_JUMP_SPEED: float = 14.0 * JUMP_SPEED_SCALE
const FALLBACK_JUMP_SPEED: float = 17.32
## Ticks of sustained devouring needed to finish the boss.
const DEVOUR_TICKS: float = 100.0
const DEVOUR_RANGE: float = 150.0


## Horizontal launch speed of the ultimate toward a player [param dx] away.
static func mega_leap_vx(dx: float) -> float:
	var direction: float = 1.0 if dx >= 0.0 else -1.0
	return direction * maxf(2.0, minf(12.0, absf(dx * 0.03)))


## True when the player's aim ray reaches the boss body.
static func is_player_aiming_at_boss(sim: GameSim) -> bool:
	var boss: BossState = sim.boss
	if not boss.active or boss.dead:
		return false
	var aim: PlayerSystem.Aim = PlayerSystem.aim_of(sim, sim.input.mouse_x, sim.input.mouse_y)
	if aim.mag == 0.0:
		return false
	var px: float = sim.player.center_x()
	var py: float = sim.player.center_y()
	for i: int in range(1, 31):
		var f: float = float(i) / 30.0
		var tx: float = px + aim.x * (DEVOUR_RANGE * f)
		var ty: float = py + aim.y * (DEVOUR_RANGE * f)
		if tx >= boss.x and tx <= boss.x + boss.w and ty >= boss.y and ty <= boss.y + boss.h:
			return true
	return false


static func update(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	if boss.damage_flash > 0.0:
		boss.damage_flash -= 0.05
	boss.scale_x += (1.0 - boss.scale_x) * 0.15
	boss.scale_y += (1.0 - boss.scale_y) * 0.15

	if boss.eating_progress > 0.0:
		# Being devoured pins the boss in place.
		boss.vx = 0.0
		boss.vy = 0.0
		if boss.state != BossState.State.ACTIVE:
			boss.state = BossState.State.ACTIVE
			boss.grounded = true
	else:
		match boss.state:
			BossState.State.SUSPENDED:
				if BossSystem.player_in_trigger_range(sim):
					BossSystem.begin_intro(sim, INTRO_TICKS)
					sim.camera.shake = 12.0
					sim.play(Sfx.Id.BOUNCE)
			BossState.State.INTRO:
				_update_intro(sim)
			BossState.State.FALLING:
				_update_falling(sim)
			BossState.State.CHARGING:
				_update_charging(sim)
			_:
				_update_fighting(sim)

	_absorb_projectiles(sim)
	_update_devouring(sim)


static func _update_intro(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	boss.intro_timer -= 1
	if boss.y < 80.0:
		boss.y += 1.3
	if boss.intro_timer % 2 == 0:
		BossSystem.spawn_converging_spark(sim, 120.0, 25.0, Palette.AMBER_400, 3.0, 4.0)
		var px: float = boss.center_x() + (sim.rng.next_float() - 0.5) * 120.0
		var py: float = boss.center_y() + (sim.rng.next_float() - 0.5) * 120.0
		var pvx: float = (sim.rng.next_float() - 0.5) * 3.0
		var pvy: float = (sim.rng.next_float() - 0.5) * 3.0
		sim.add_particle(px, py, pvx, pvy, 15.0, Palette.RED_500, sim.rng.next_float() * 2.0 + 1.0)
	if boss.intro_timer <= 0:
		BossSystem.finish_intro(sim, 30.0, Palette.RED_500, 40, 7.0)


static func _update_falling(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	boss.vy += GRAVITY
	boss.y += boss.vy
	var r_floor: int = BossSystem.floor_row(boss)
	if BossSystem.rests_on_floor(sim, r_floor):
		boss.y = float(r_floor) * Tile.SIZE - boss.h
		boss.vy = 0.0
		boss.state = BossState.State.ACTIVE
		boss.grounded = true
		boss.scale_y = 0.5
		boss.scale_x = 1.6
		sim.camera.shake = 28.0
		sim.play(Sfx.Id.LAND)
		sim.spawn_particles(boss.center_x(), boss.y + boss.h, Palette.GREEN_400, 35, 6.0)
		sim.damage_tiles_under_boss(r_floor)


## Winds up the ultimate: a huge leap that smashes through every block.
static func _update_charging(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	boss.vx *= 0.8
	boss.vy += GRAVITY
	boss.y += boss.vy
	_clamp_to_ceiling(boss)
	_settle(sim)

	boss.scale_x = 1.0 + (sim.rng.next_float() - 0.5) * 0.15
	boss.scale_y = 1.0 + (sim.rng.next_float() - 0.5) * 0.15
	if boss.charge_timer % 2 == 0:
		var color: Color = Palette.PURPLE_500 if boss.charge_timer % 4 == 0 else Palette.PINK_500
		BossSystem.spawn_converging_spark(sim, 100.0, 20.0, color, 4.0, 3.0)
	boss.damage_flash = 0.5 + sin(sim.clock_ms() / 30.0) * 0.5

	boss.charge_timer -= 1
	if boss.charge_timer <= 0:
		boss.jump_type = BossState.JumpType.MEGA
		boss.vy = -MEGA_JUMP_SPEED
		boss.vx = mega_leap_vx(BossSystem.player_dx(sim))
		boss.state = BossState.State.JUMPING
		boss.grounded = false
		boss.scale_y = 1.8
		boss.scale_x = 0.5
		boss.cooldown = 10
		boss.max_cooldown = 10
		sim.camera.shake = 15.0
		sim.play(Sfx.Id.JUMP)
		sim.spawn_particles(boss.center_x(), boss.y + boss.h, Palette.PURPLE_500, 45, 8.0)


## Standing, telegraphing a jump, or in the air.
static func _update_fighting(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	boss.vy += GRAVITY
	boss.y += boss.vy
	_clamp_to_ceiling(boss)

	var r_floor: int = BossSystem.floor_row(boss)
	if _finds_floor(sim, r_floor) and boss.vy >= 0.0:
		boss.y = float(r_floor) * Tile.SIZE - boss.h
		boss.vy = 0.0
		boss.grounded = true
		if boss.state == BossState.State.JUMPING:
			_on_landed(sim, r_floor)
	else:
		boss.grounded = false

	if boss.state == BossState.State.JUMPING:
		_move_in_air(sim)
	if boss.state == BossState.State.ACTIVE and boss.grounded:
		boss.cooldown -= 1
		if boss.cooldown <= 0:
			_choose_next_action(sim)
	if boss.state == BossState.State.PRE_JUMP:
		_update_pre_jump(sim)


static func _clamp_to_ceiling(boss: BossState) -> void:
	if boss.y < Tile.SIZE:
		boss.y = Tile.SIZE
		if boss.vy < 0.0:
			boss.vy = 0.0


static func _settle(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var r_floor: int = BossSystem.floor_row(boss)
	if BossSystem.rests_on_floor(sim, r_floor) and boss.vy >= 0.0:
		boss.y = float(r_floor) * Tile.SIZE - boss.h
		boss.vy = 0.0
		boss.grounded = true
	else:
		boss.grounded = false


## Like [method BossSystem.rests_on_floor], except that the ultimate ignores
## breakable blocks and only stops on steel or the arena boundary.
static func _finds_floor(sim: GameSim, r_floor: int) -> bool:
	var boss: BossState = sim.boss
	if r_floor < 1:
		return false
	var is_mega: bool = (
		boss.state == BossState.State.JUMPING and boss.jump_type == BossState.JumpType.MEGA
	)
	for col: int in range(BossSystem.left_col(boss), BossSystem.right_col(boss) + 1):
		if not sim.is_solid_or_boundary(r_floor, col):
			continue
		if is_mega:
			var block_type: int = sim.level.get_cell(r_floor, col)
			if block_type != Tile.STEEL and Tile.is_solid(block_type):
				continue
		return true
	return false


static func _on_landed(sim: GameSim, r_floor: int) -> void:
	var boss: BossState = sim.boss
	boss.state = BossState.State.ACTIVE
	boss.vx = 0.0
	boss.scale_y = 0.5
	boss.scale_x = 1.6
	sim.damage_tiles_under_boss(r_floor)

	var is_phase_3: bool = boss.filled_count() >= PHASE_3_FILLED
	var recovery: int = 30 if is_phase_3 else 60
	if boss.combo_count > 0:
		recovery = 15
	elif boss.jump_type == BossState.JumpType.MEGA:
		recovery = 0
	boss.cooldown = recovery
	boss.max_cooldown = recovery

	var feet_x: float = boss.center_x()
	var feet_y: float = boss.y + boss.h
	match boss.jump_type:
		BossState.JumpType.BIG:
			sim.camera.shake = 26.0
			sim.play(Sfx.Id.LAND)
			sim.spawn_particles(feet_x, feet_y, Palette.GREEN_400, 40, 8.0)
			_shake_down_blocks(sim, 5)
		BossState.JumpType.SMALL:
			sim.camera.shake = 10.0
			sim.play(Sfx.Id.LAND)
			sim.spawn_particles(feet_x, feet_y, Palette.BLUE_500, 15, 4.0)
			_shake_down_blocks(sim, 1)
		BossState.JumpType.PRECISION:
			sim.camera.shake = 18.0
			sim.play(Sfx.Id.LAND)
			sim.spawn_particles(feet_x, feet_y, Palette.RED_500, 30, 6.0)
			_shake_down_blocks(sim, 3)
		BossState.JumpType.MEGA:
			sim.camera.shake = 45.0
			sim.play(Sfx.Id.LAND)
			sim.spawn_particles(feet_x, feet_y, Palette.PURPLE_500, 60, 9.0)
			sim.spawn_particles(feet_x, feet_y, Palette.ROSE_500, 40, 7.0)
			_trigger_patterned_drop(sim)
			# Shockwaves racing along the ground to both sides.
			for _i: int in 20:
				var right_vx: float = 5.0 + sim.rng.next_float() * 5.0
				var right_vy: float = -1.0 - sim.rng.next_float() * 3.0
				sim.add_particle(
					boss.x + boss.w, feet_y - 10.0, right_vx, right_vy, 30.0, Palette.PURPLE_500, 8.0
				)
				var left_vx: float = -5.0 - sim.rng.next_float() * 5.0
				var left_vy: float = -1.0 - sim.rng.next_float() * 3.0
				sim.add_particle(
					boss.x, feet_y - 10.0, left_vx, left_vy, 30.0, Palette.PURPLE_500, 8.0
				)
		_:
			sim.camera.shake = 14.0
			sim.play(Sfx.Id.LAND)
			sim.spawn_particles(feet_x, feet_y, Palette.YELLOW_500, 20, 5.0)
			_shake_down_blocks(sim, 2)


static func _move_in_air(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var level: LevelGrid = sim.level
	boss.x += boss.vx
	var left: int = BossSystem.left_col(boss)
	var right: int = BossSystem.right_col(boss)
	if left <= 0:
		boss.x = Tile.SIZE + 1.0
		boss.vx = 0.0
	if right >= level.cols - 1:
		boss.x = float(level.cols - 1) * Tile.SIZE - boss.w - 1.0
		boss.vx = 0.0

	if boss.jump_type != BossState.JumpType.MEGA:
		return
	# The ultimate pulverises every breakable block it passes through.
	var r1: int = floori(boss.y / Tile.SIZE)
	var r2: int = floori((boss.y + boss.h) / Tile.SIZE)
	for r: int in range(r1, r2 + 1):
		for c: int in range(left, right + 1):
			if not level.is_interior(r, c):
				continue
			var block_type: int = level.get_cell(r, c)
			if block_type > 0 and block_type != Tile.STEEL and Tile.is_solid(block_type):
				level.set_cell(r, c, Tile.AIR)
				var cx: float = float(c) * Tile.SIZE + Tile.SIZE / 2.0
				var cy: float = float(r) * Tile.SIZE + Tile.SIZE / 2.0
				sim.spawn_particles(cx, cy, GameSim.debris_color(block_type), 15, 5.0)
				sim.spawn_particles(cx, cy, Palette.PURPLE_500, 10, 4.0)
				sim.play(Sfx.Id.BOUNCE)
				sim.add_shake(8.0)


static func _choose_next_action(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	boss.action_count += 1
	if boss.action_count > 0 and boss.action_count % ACTIONS_PER_ULTIMATE == 0:
		boss.state = BossState.State.CHARGING
		boss.charge_timer = ULTIMATE_CHARGE_TICKS
		boss.max_charge_timer = ULTIMATE_CHARGE_TICKS
		boss.cooldown = 0
		boss.scale_x = 1.5
		boss.scale_y = 0.6
		boss.vx = 0.0
		sim.spawn_particles(boss.center_x(), boss.center_y(), Palette.PURPLE_500, 30, 4.0)
		return

	var dx: float = BossSystem.player_dx(sim)
	var roll: float = sim.rng.next_float()
	var is_phase_3: bool = boss.filled_count() >= PHASE_3_FILLED

	if boss.combo_count > 0 and is_phase_3:
		boss.jump_type = BossState.JumpType.COMBO
	else:
		boss.combo_count = 0
		if is_phase_3:
			if roll < 0.25:
				boss.jump_type = BossState.JumpType.BIG
			elif roll < 0.50:
				boss.jump_type = BossState.JumpType.SMALL
			elif roll < 0.75:
				boss.jump_type = BossState.JumpType.PRECISION
			else:
				boss.jump_type = BossState.JumpType.COMBO
				boss.combo_count = COMBO_HOPS
		elif roll < 0.33:
			boss.jump_type = BossState.JumpType.BIG
		elif roll < 0.66:
			boss.jump_type = BossState.JumpType.SMALL
		else:
			boss.jump_type = BossState.JumpType.PRECISION

	# Telegraph before the jump; phase 3 halves the warning.
	boss.state = BossState.State.PRE_JUMP
	boss.vx = 0.0
	var telegraph: int = 90 if is_phase_3 else 180
	var max_vx: float = 8.5
	match boss.jump_type:
		BossState.JumpType.BIG:
			boss.target_vy = -11.5 * JUMP_SPEED_SCALE
			max_vx = 9.0
		BossState.JumpType.SMALL:
			boss.target_vy = -7.0 * JUMP_SPEED_SCALE
			max_vx = 4.5
		BossState.JumpType.PRECISION:
			boss.target_vy = -9.5 * JUMP_SPEED_SCALE
			max_vx = 7.5
		BossState.JumpType.COMBO:
			boss.target_vy = -7.5 * JUMP_SPEED_SCALE
			max_vx = 6.0
			# Only the first hop of a combo gets the long telegraph.
			if boss.combo_count != COMBO_HOPS:
				telegraph = 30
			boss.combo_count -= 1
	boss.max_pre_jump_timer = telegraph

	# Aim the jump so that it lands on the player's current position. The
	# boss stops moving sideways on the tick it lands, hence one tick less.
	var flight_time: float = maxf(
		1.0, BossSystem.leap_flight_ticks(boss.y, absf(boss.target_vy), GRAVITY) - 1.0
	)
	boss.target_vx = maxf(-max_vx, minf(max_vx, dx / flight_time))
	boss.pre_jump_timer = boss.max_pre_jump_timer
	boss.scale_y = 0.75
	boss.scale_x = 1.3


static func _update_pre_jump(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	boss.x += (sim.rng.next_float() - 0.5) * 2.0
	boss.scale_y = 0.75 + sin(sim.clock_ms() / 50.0) * 0.05

	boss.pre_jump_timer -= 1
	if boss.pre_jump_timer > 0:
		return

	boss.vy = boss.target_vy if boss.target_vy != 0.0 else -FALLBACK_JUMP_SPEED
	boss.vx = boss.target_vx
	var feet_x: float = boss.center_x()
	var feet_y: float = boss.y + boss.h
	match boss.jump_type:
		BossState.JumpType.BIG:
			sim.spawn_particles(feet_x, feet_y, Palette.GREEN_400, 25, 5.0)
		BossState.JumpType.SMALL:
			sim.spawn_particles(feet_x, feet_y, Palette.BLUE_500, 12, 3.0)
		BossState.JumpType.PRECISION:
			sim.spawn_particles(feet_x, feet_y, Palette.RED_500, 20, 4.5)
		BossState.JumpType.COMBO:
			sim.spawn_particles(feet_x, feet_y, Palette.YELLOW_500, 15, 4.0)

	sim.damage_tiles_under_boss(floori((boss.y + boss.h + 5.0) / Tile.SIZE))
	boss.state = BossState.State.JUMPING
	boss.grounded = false
	boss.scale_y = 1.5
	boss.scale_x = 0.6
	boss.cooldown = 0
	boss.max_cooldown = 120
	sim.play(Sfx.Id.JUMP)


## Drops [param count] blocks from the ceiling over random visible columns
## away from the boss. Void blocks become likelier as the boss fills up.
static func _shake_down_blocks(sim: GameSim, count: int) -> void:
	var boss: BossState = sim.boss
	var level: LevelGrid = sim.level
	var boss_left: int = floori(boss.x / Tile.SIZE) - 1
	var boss_right: int = BossSystem.right_col(boss) + 1
	var min_col: int = maxi(1, floori(sim.camera.x / Tile.SIZE))
	var max_col: int = mini(
		level.cols - 2, ceili((sim.camera.x + GameConstants.VIEW_WIDTH) / Tile.SIZE)
	)

	var eligible: PackedInt32Array = PackedInt32Array()
	for c: int in range(min_col, max_col + 1):
		if c < boss_left or c > boss_right:
			if level.get_cell(1, c) == Tile.AIR or level.get_cell(2, c) == Tile.AIR:
				eligible.append(c)
	if eligible.is_empty():
		return

	var chosen: PackedInt32Array = PackedInt32Array()
	for _i: int in count:
		if eligible.is_empty():
			break
		var idx: int = sim.rng.next_below(eligible.size())
		chosen.append(eligible[idx])
		eligible.remove_at(idx)

	var void_chance: float = float(boss.filled_count()) * 0.04
	for col: int in chosen:
		var type: int = Tile.DIRT
		var warning_color: Color = Palette.AMBER_600
		if sim.rng.next_float() < void_chance:
			type = Tile.VOID
			warning_color = Palette.PURPLE_500
		elif sim.rng.next_float() < 0.15:
			type = Tile.BOUNCY
			warning_color = Palette.PINK_500
		FallingBlockSystem.spawn(sim, col, type, 30, warning_color)
		sim.spawn_particles(float(col) * Tile.SIZE + Tile.SIZE / 2.0, 20.0, Palette.RED_500, 20, 3.5)


## The ultimate's aftermath: a patterned curtain of blocks across the screen.
static func _trigger_patterned_drop(sim: GameSim) -> void:
	var level: LevelGrid = sim.level
	var player_col: int = floori(sim.player.center_x() / Tile.SIZE)
	var pattern: int = sim.rng.next_below(4)
	var min_col: int = maxi(1, floori((sim.camera.x - 60.0) / Tile.SIZE))
	var max_col: int = mini(
		level.cols - 2, ceili((sim.camera.x + GameConstants.VIEW_WIDTH + 60.0) / Tile.SIZE)
	)
	for c: int in range(min_col, max_col + 1):
		var type: int = Tile.DIRT
		var warning_color: Color = Palette.AMBER_600
		var should_drop: bool = false
		match pattern:
			0:  # Dirt on every other column.
				should_drop = c % 2 == 0
			1:  # Bouncy blocks in alternating groups of four columns.
				type = Tile.BOUNCY
				warning_color = Palette.PINK_500
				should_drop = floori(float(c) / 4.0) % 2 == 0
			2:  # Glass everywhere except the five columns around the player.
				type = Tile.GLASS
				warning_color = Palette.SKY_400
				should_drop = c < player_col - 2 or c > player_col + 2
			3:  # Void on the five columns around the player.
				type = Tile.VOID
				warning_color = Palette.PURPLE_500
				should_drop = c >= player_col - 2 and c <= player_col + 2
		if should_drop:
			FallingBlockSystem.spawn(sim, c, type, 45, warning_color)
			sim.spawn_particles(
				float(c) * Tile.SIZE + Tile.SIZE / 2.0, 20.0, warning_color, 10, 3.0
			)


## Projectiles touching the body: an empty cell next to an occupied one
## swallows the block, an occupied cell knocks it away.
static func _absorb_projectiles(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	for p: SimProjectile in sim.projectiles:
		if p.dead:
			continue
		for r: int in 3:
			for c: int in 3:
				if r == 1 and c == 1:
					continue
				var cell_x: float = boss.x + float(c) * Tile.SIZE
				var cell_y: float = boss.y + float(r) * Tile.SIZE
				if (
					p.x + p.w <= cell_x or p.x >= cell_x + Tile.SIZE
					or p.y + p.h <= cell_y or p.y >= cell_y + Tile.SIZE
				):
					continue
				var val: int = boss.cell(r, c)
				if val == 0:
					if not boss.has_occupied_neighbor(r, c):
						continue
					feed_cell(sim, p, r, c, cell_x, cell_y)
					break
				# An occupied cell is solid: the block bounces off upward.
				p.vx = -p.vx * 0.8 + (sim.rng.next_float() - 0.5) * 2.0
				p.vy = -absf(p.vy) * 0.8 - 1.5
				p.y = cell_y - p.h - 1.0
				sim.add_shake(3.0)
				sim.play(Sfx.Id.BOUNCE)
				sim.spawn_particles(
					p.x, p.y, Palette.PINK_500 if val == Tile.BOUNCY else Palette.AMBER_600, 8, 3.0
				)
				break
			if p.dead:
				break


## Puts projectile [param p] into boss cell ([param r], [param c]). Blocks
## arrive one bite away from breaking.
static func feed_cell(
	sim: GameSim, p: SimProjectile, r: int, c: int, cell_x: float, cell_y: float
) -> void:
	var boss: BossState = sim.boss
	var place_type: int = p.type
	if p.type == Tile.DIRT:
		place_type = Tile.DIRT_EATEN_2
	elif p.type == Tile.BOUNCY:
		place_type = Tile.BOUNCY_EATEN_2
	boss.set_cell(r, c, place_type)
	p.dead = true
	boss.damage_flash = 1.0
	boss.scale_x = 1.35
	boss.scale_y = 0.7
	sim.camera.shake = 12.0
	sim.play(Sfx.Id.EAT)
	var mid_x: float = cell_x + Tile.SIZE / 2.0
	var mid_y: float = cell_y + Tile.SIZE / 2.0
	sim.spawn_particles(
		mid_x, mid_y, Palette.PINK_500 if p.type == Tile.BOUNCY else Palette.AMBER_600, 15, 4.0
	)
	sim.spawn_particles(mid_x, mid_y, Palette.PURPLE_500, 15, 5.0)


## Once the boss is full, holding eat while aiming at it devours it cell by
## cell. An interrupted swallow can only drain to the last consumed cell.
static func _update_devouring(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var player: PlayerState = sim.player
	if not (boss.is_filled() or boss.eating_progress > 0.0):
		return
	if not (is_player_aiming_at_boss(sim) and sim.input.eat and not player.has_block):
		var checkpoint: float = float(8 - boss.filled_count()) / 10.0
		boss.eating_progress = maxf(checkpoint, boss.eating_progress - 0.025)
		return

	boss.eating_progress += 1.0 / DEVOUR_TICKS
	boss.damage_flash = 0.6 + sin(sim.clock_ms() / 50.0) * 0.4
	boss.scale_x = 1.0 + (sim.rng.next_float() - 0.5) * 0.2
	boss.scale_y = 1.0 + (sim.rng.next_float() - 0.5) * 0.2
	if fmod(sim.clock_ms(), 250.0) < 35.0:
		sim.play(Sfx.Id.DEVOUR_PULSE, boss.eating_progress)

	var bx: float = boss.center_x()
	var by: float = boss.center_y()
	var px: float = player.center_x()
	var py: float = player.center_y()

	# Vortex streaks flowing from the boss into the player.
	if sim.rng.next_float() < 0.8:
		var t_ratio: float = sim.rng.next_float()
		var sx: float = bx + (px - bx) * t_ratio + (sim.rng.next_float() - 0.5) * 40.0
		var sy: float = by + (py - by) * t_ratio + (sim.rng.next_float() - 0.5) * 40.0
		var svx: float = (px - bx) / 25.0 + (sim.rng.next_float() - 0.5) * 3.0
		var svy: float = (py - by) / 25.0 + (sim.rng.next_float() - 0.5) * 3.0
		var max_life: float = sim.rng.next_float() * 15.0 + 15.0
		var color: Color = Palette.PURPLE_400 if sim.rng.next_float() < 0.5 else Palette.SKY_100
		sim.add_particle(sx, sy, svx, svy, max_life, color, sim.rng.next_float() * 4.0 + 2.0)

	# Cells burst one by one as the progress climbs.
	var target_filled: int = maxi(0, 8 - floori(boss.eating_progress * 10.0))
	if boss.filled_count() > target_filled:
		_burst_next_cell(sim)

	if sim.rng.next_float() < 0.45:
		var ox: float = bx + (sim.rng.next_float() - 0.5) * 80.0
		var oy: float = by + (sim.rng.next_float() - 0.5) * 80.0
		var ovx: float = (px - bx) / 20.0 + (sim.rng.next_float() - 0.5) * 2.0
		var ovy: float = (py - by) / 20.0 + (sim.rng.next_float() - 0.5) * 2.0
		sim.add_particle(ox, oy, ovx, ovy, 20.0, Palette.PURPLE_500, 4.0)

	if boss.eating_progress >= 1.0:
		BossSystem.defeat(sim)
		sim.camera.shake = 30.0
		sim.play(Sfx.Id.HURT)
		sim.play(Sfx.Id.WIN, 0.0, 0.1)
		sim.spawn_particles(bx, by, Palette.PINK_500, 40, 8.0)
		sim.spawn_particles(bx, by, Palette.PURPLE_500, 40, 8.0)
		sim.spawn_particles(bx, by, Palette.EMERALD_400, 40, 8.0)
		BossSystem.reveal_goal_at_boss(sim)


static func _burst_next_cell(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	for r: int in 3:
		for c: int in 3:
			if r == 1 and c == 1:
				continue
			var val: int = boss.cell(r, c)
			if val <= 0:
				continue
			boss.set_cell(r, c, Tile.AIR)
			var tx: float = boss.x + float(c) * Tile.SIZE + Tile.SIZE / 2.0
			var ty: float = boss.y + float(r) * Tile.SIZE + Tile.SIZE / 2.0
			sim.spawn_particles(
				tx, ty, Palette.PINK_500 if Tile.is_bouncy(val) else Palette.AMBER_600, 25, 6.0
			)
			sim.spawn_particles(tx, ty, Palette.PURPLE_500, 15, 5.0)
			sim.add_shake(12.0)
			sim.play(Sfx.Id.EAT)
			return
