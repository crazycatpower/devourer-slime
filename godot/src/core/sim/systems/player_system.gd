class_name PlayerSystem
extends RefCounted
## Player movement, jumping, swallowing and spitting.

## Swallowing a block takes 8 ticks of holding the eat button.
const EAT_RATE: float = 2.0 / 15.0
## A swallow is abandoned when the player drifts further than this from it.
const EAT_MAX_DISTANCE: float = 85.0
## A jump press is remembered for this many ticks.
const JUMP_BUFFER_TICKS: int = 12
## Ticks after leaving the ground during which a jump still works.
const COYOTE_TICKS: int = 4
## Share of the horizontal recoil that carries over to the next tick while
## the player is airborne. A spit sideways in mid-air pushes the slime about
## three tiles; on the ground the kick is spent in a single tick.
const RECOIL_CARRY: float = 0.85
const RECOIL_CUTOFF: float = 0.1
## Horizontal recoil is this much stronger than vertical recoil.
const RECOIL_X_SCALE: float = 1.8
## Vertical speed a jump is cut to when the jump button is released early.
const SHORT_HOP_SPEED: float = -4.0
const TERMINAL_SOFT_SPEED: float = 12.0
const CARRY_SPEED_FACTOR: float = 0.8
## Distance from the player at which a spat block appears, in tiles.
const MUZZLE_DISTANCE: float = 0.8


## Aim direction from the player toward the mouse.
class Aim:
	extends RefCounted
	## Unit direction; falls back to the facing direction when not aiming.
	var x: float = 1.0
	var y: float = 0.0
	## Raw offset from the player's centre to the aim point.
	var dx: float = 0.0
	var dy: float = 0.0
	var mag: float = 0.0
	var aiming: bool = false


static func aim_of(sim: GameSim, mouse_x: float, mouse_y: float) -> Aim:
	var player: PlayerState = sim.player
	var aim: Aim = Aim.new()
	aim.dx = (mouse_x + sim.camera.x) - player.center_x()
	aim.dy = (mouse_y + sim.camera.y) - player.center_y()
	aim.mag = sqrt(aim.dx * aim.dx + aim.dy * aim.dy)
	aim.x = float(player.facing)
	aim.y = 0.0
	if aim.mag > 0.0:
		aim.x = aim.dx / aim.mag
		aim.y = aim.dy / aim.mag
		aim.aiming = true
	return aim


static func update(sim: GameSim) -> void:
	var player: PlayerState = sim.player
	var inp: SimInput = sim.input

	# The player is frozen in place while a boss makes its entrance.
	if (
		sim.boss.active and sim.boss.state == BossState.State.INTRO
		and sim.boss.intro_freezes_player
	):
		player.vx = 0.0
		player.recoil_vx = 0.0
		player.vy += 0.4
		player.in_bullet_time = false
		Collision.solve_y(sim)
		# Keep easing out of any squash, or the slime would sit frozen in
		# whatever shape it had when the entrance began.
		player.scale_x += (1.0 - player.scale_x) * 0.15
		player.scale_y += (1.0 - player.scale_y) * 0.15
		return

	var aim: Aim = aim_of(sim, inp.mouse_x, inp.mouse_y)

	var move_left: bool = inp.left
	var move_right: bool = inp.right
	if player.wall_bounce_timer > 0:
		player.wall_bounce_timer -= 1
		move_left = false
		move_right = false

	var mov_x: int = 0
	if move_left:
		mov_x -= 1
	if move_right:
		mov_x += 1

	if aim.aiming:
		player.facing = 1 if aim.dx > 0.0 else -1
	elif mov_x != 0:
		player.facing = mov_x

	_apply_horizontal_movement(player, move_left, move_right)
	_carry_recoil(player)

	player.vy += GameConstants.GRAVITY
	if player.vy > TERMINAL_SOFT_SPEED:
		player.vy -= (player.vy - TERMINAL_SOFT_SPEED) * 0.15

	_update_jump(sim)
	_update_eating(sim, aim)
	_update_shooting(sim, aim)

	if player.grounded:
		player.fall_start_y = player.y
	elif player.vy < 0.0:
		# While rising, only ever push the fall origin lower.
		player.fall_start_y = maxf(player.fall_start_y, player.y)

	Collision.solve_x(sim)
	Collision.solve_y(sim)

	_check_hazards_and_goal(sim)

	# Stretch along the vertical velocity while airborne.
	if not player.grounded and absf(player.scale_y - 1.0) < 0.2:
		var stretch: float = minf(absf(player.vy) * 0.04, 0.3)
		player.scale_x = 1.0 - stretch * 0.5
		player.scale_y = 1.0 + stretch

	if not player.grounded and absf(player.vy) > 10.0 and sim.rng.next_float() < 0.3:
		sim.spawn_particles(player.center_x(), player.center_y(), Palette.GREEN_400, 1, 0.5)

	player.scale_x += (1.0 - player.scale_x) * 0.15
	player.scale_y += (1.0 - player.scale_y) * 0.15


static func _apply_horizontal_movement(
	player: PlayerState, move_left: bool, move_right: bool
) -> void:
	if player.wall_bounce_timer > 0:
		return  # Keep the bounce velocity.
	var max_speed: float = GameConstants.MAX_SPEED
	if player.has_block:
		max_speed *= CARRY_SPEED_FACTOR
	if move_left:
		player.vx = -max_speed
	elif move_right:
		player.vx = max_speed
	else:
		if player.grounded:
			# A gentle pull toward the tile centre helps line up with blocks.
			var cx: float = player.center_x()
			var tile_center: float = floorf(cx / Tile.SIZE) * Tile.SIZE + Tile.SIZE / 2.0
			var diff_x: float = tile_center - cx
			if absf(diff_x) < 6.0:
				player.x += diff_x * 0.25
		player.vx = 0.0


## Walking sets the horizontal speed outright every tick, so the sideways
## kick of a spit is tracked separately and added on top while it fades.
static func _carry_recoil(player: PlayerState) -> void:
	if player.recoil_vx == 0.0:
		return
	if player.wall_bounce_timer > 0 or player.grounded:
		player.recoil_vx = 0.0
		return
	player.recoil_vx *= RECOIL_CARRY
	if absf(player.recoil_vx) < RECOIL_CUTOFF:
		player.recoil_vx = 0.0
	player.vx += player.recoil_vx


static func _update_jump(sim: GameSim) -> void:
	var player: PlayerState = sim.player
	# Both timers are counted down before they are read, hence the extra tick.
	if sim.input.jump_pressed:
		player.jump_buffer = JUMP_BUFFER_TICKS + 1
	if player.jump_buffer > 0:
		player.jump_buffer -= 1

	# Being just above a bouncy surface counts as standing on it, but not
	# while falling onto it: jumping there would cancel the bounce that is
	# about to happen. The press waits in the buffer until after the bounce.
	if player.grounded or (player.vy <= 0.0 and _is_near_bouncy(sim)):
		player.coyote_timer = COYOTE_TICKS + 1
	elif player.coyote_timer > 0:
		player.coyote_timer -= 1

	# Nor does a jump replace a stronger upward speed: right after a big
	# bounce it would only cut it down. The press stays buffered instead.
	if (
		player.jump_buffer > 0 and player.coyote_timer > 0
		and player.vy > -GameConstants.JUMP_FORCE
	):
		player.vy = -GameConstants.JUMP_FORCE
		player.grounded = false
		player.jump_buffer = 0
		player.coyote_timer = 0
		player.scale_x = 0.6
		player.scale_y = 1.4
		player.is_jumping = true
		sim.spawn_particles(player.center_x(), player.y + player.h, Palette.WHITE, 12, 2.5)
		sim.play(Sfx.Id.JUMP)

	if not sim.input.jump and player.vy < SHORT_HOP_SPEED and player.is_jumping:
		player.vy = SHORT_HOP_SPEED


## True when a bouncy surface is within reach below the player, which grants
## jump eligibility. Carrying a bouncy block makes every solid tile count.
static func _is_near_bouncy(sim: GameSim) -> bool:
	var player: PlayerState = sim.player
	var level: LevelGrid = sim.level
	var is_player_bouncy: bool = player.has_block and player.carried_block_type == Tile.BOUNCY
	var left: int = floori((player.x + 0.001) / Tile.SIZE)
	var right: int = floori((player.x + player.w - 0.001) / Tile.SIZE)
	var top: int = floori((player.y + 0.001) / Tile.SIZE)
	var bottom: int = floori((player.y + player.h + 24.0 - 0.001) / Tile.SIZE)
	for r: int in range(top, bottom + 1):
		for c: int in range(left, right + 1):
			if not level.in_bounds(r, c):
				continue
			var t: int = level.get_cell(r, c)
			if Tile.is_bouncy(t):
				return true
			if is_player_bouncy and Tile.is_solid(t):
				return true
	return false


static func _update_eating(sim: GameSim, aim: Aim) -> void:
	var player: PlayerState = sim.player
	var boss: BossState = sim.boss
	var level: LevelGrid = sim.level
	var target: EatTarget = sim.get_eat_target(player.center_x(), player.center_y(), aim.x, aim.y)

	if not sim.input.eat or player.has_block:
		player.clear_eating()
		return

	if player.eating_progress == 0.0:
		if target != null:
			player.set_eating_target(target.r, target.c, target.is_boss_cell)
			player.eating_progress += EAT_RATE
		return
	if not player.has_eating_target:
		return

	var tr: int = player.eating_target_r
	var tc: int = player.eating_target_c
	var is_boss: bool = player.eating_target_is_boss_cell
	var block_type: int = boss.cell(tr, tc) if is_boss else level.get_cell(tr, tc)
	if not (Tile.is_eatable(block_type) or (is_boss and block_type == Tile.GOAL)):
		player.clear_eating()
		return

	var tx: float = float(tc) * Tile.SIZE + Tile.SIZE / 2.0
	var ty: float = float(tr) * Tile.SIZE + Tile.SIZE / 2.0
	if is_boss:
		tx = boss.cell_x(tc) + Tile.SIZE / 2.0
		ty = boss.cell_y(tr) + Tile.SIZE / 2.0
	var ddx: float = player.center_x() - tx
	var ddy: float = player.center_y() - ty
	if sqrt(ddx * ddx + ddy * ddy) > EAT_MAX_DISTANCE:
		player.clear_eating()
		return

	player.eating_progress += EAT_RATE
	if player.eating_progress < 1.0:
		return

	# The block is swallowed.
	if is_boss:
		boss.set_cell(tr, tc, Tile.AIR)
		if sim.boss_kind == BossState.Kind.WORLD_1:
			if block_type == Tile.GOAL:
				BossWorld1.kill_and_reveal_goal(sim)
			else:
				BossWorld1.update_bounds(sim)
	else:
		level.set_cell(tr, tc, Tile.AIR)

	# Eating the boss core wins the fight; nothing is carried.
	if block_type != Tile.GOAL:
		var is_bouncy: bool = Tile.is_bouncy(block_type)
		var prev_count: int = 0
		if block_type == Tile.DIRT_EATEN_1 or block_type == Tile.BOUNCY_EATEN_1:
			prev_count = 1
		elif block_type == Tile.DIRT_EATEN_2 or block_type == Tile.BOUNCY_EATEN_2:
			prev_count = 2
		var next_count: int = prev_count + 1
		var color: Color = Palette.PINK_500 if is_bouncy else Palette.AMBER_600
		if next_count >= 3:
			# The third swallow digests the block for good.
			player.has_block = false
			player.in_bullet_time = false
			player.carried_block_type = Tile.AIR
			player.carried_block_eaten_count = 0
			sim.spawn_particles(tx, ty, color, 30, 8.0)
			sim.add_shake(8.0)
		else:
			player.has_block = true
			player.waiting_for_shoot_release = true
			player.carried_block_type = Tile.BOUNCY if is_bouncy else Tile.DIRT
			player.carried_block_eaten_count = next_count
			sim.spawn_particles(tx, ty, color, 15, 6.0)

	sim.play(Sfx.Id.EAT)
	player.clear_eating()


static func _update_shooting(sim: GameSim, aim: Aim) -> void:
	var player: PlayerState = sim.player
	var inp: SimInput = sim.input
	if not player.has_block:
		return

	if player.waiting_for_shoot_release:
		if not inp.shoot and not inp.shoot_released:
			player.waiting_for_shoot_release = false
	if player.waiting_for_shoot_release:
		return

	if inp.shoot:
		# Holding the button slows time and shows the trajectory.
		if sim.bullet_time_enabled and not player.in_bullet_time:
			player.in_bullet_time = true
			sim.play(Sfx.Id.EAT)
	elif inp.shoot_released:
		_fire(sim, aim)
	else:
		# The button is up and no release was seen (the game was paused or
		# lost focus while it was held): never leave time slowed down.
		player.in_bullet_time = false


static func _fire(sim: GameSim, aim: Aim) -> void:
	var player: PlayerState = sim.player
	var level: LevelGrid = sim.level
	player.in_bullet_time = false
	var block_type: int = player.carried_block_type if player.carried_block_type != 0 else Tile.DIRT
	var eaten_count: int = (
		player.carried_block_eaten_count if player.carried_block_eaten_count != 0 else 1
	)
	player.has_block = false
	player.carried_block_type = Tile.AIR
	player.carried_block_eaten_count = 0

	var bx: float = player.x + aim.x * Tile.SIZE * MUZZLE_DISTANCE
	var by: float = player.y + aim.y * Tile.SIZE * MUZZLE_DISTANCE

	# Point-blank shots: walk the spawn point back along the aim line until its
	# centre is in a free cell, so the block can still land and recoil applies.
	var start_rx: float = bx + 20.0
	var start_ry: float = by + 20.0
	var backtracked: bool = false
	for _step: int in 45:
		var col: int = floori(start_rx / Tile.SIZE)
		var row: int = floori(start_ry / Tile.SIZE)
		var is_cell_solid: bool = true
		if level.in_bounds(row, col):
			is_cell_solid = Tile.is_solid(level.get_cell(row, col))
		if not is_cell_solid:
			break
		start_rx -= aim.x * 1.5
		start_ry -= aim.y * 1.5
		backtracked = true
	if backtracked:
		bx = start_rx - 20.0
		by = start_ry - 20.0

	var projectile: SimProjectile = SimProjectile.new()
	projectile.x = bx
	projectile.y = by
	projectile.prev_x = bx
	projectile.prev_y = by
	projectile.vx = aim.x * GameConstants.BULLET_SPEED
	projectile.vy = aim.y * GameConstants.BULLET_SPEED
	projectile.type = block_type
	projectile.eaten_count = eaten_count
	sim.projectiles.append(projectile)
	sim.play(Sfx.Id.SHOOT)

	# Recoil. A downward shot always produces the same upward kick.
	var kick_x: float = -aim.x * GameConstants.RECOIL_FORCE * RECOIL_X_SCALE
	player.vx += kick_x
	# During a wall bounce the speed is kept as it is, kick included.
	player.recoil_vx = kick_x if player.wall_bounce_timer <= 0 else 0.0
	var recoil_y: float = -aim.y * GameConstants.RECOIL_FORCE
	if recoil_y < 0.0:
		if player.vy > 0.0:
			player.vy = recoil_y
		else:
			player.vy = minf(player.vy, recoil_y)
	else:
		player.vy += recoil_y

	sim.camera.shake = 12.0
	player.is_jumping = false
	player.scale_x = 1.5
	player.scale_y = 0.5
	sim.spawn_particles(player.center_x(), player.center_y(), Palette.WHITE, 15, 4.0)


static func _check_hazards_and_goal(sim: GameSim) -> void:
	var player: PlayerState = sim.player
	var level: LevelGrid = sim.level
	var left: int = floori((player.x + 0.001) / Tile.SIZE)
	var right: int = floori((player.x + player.w - 0.001) / Tile.SIZE)
	var top: int = floori((player.y + 0.001) / Tile.SIZE)
	var bottom: int = floori((player.y + player.h - 0.001) / Tile.SIZE)
	var touched_hazard: bool = false
	var touched_goal: bool = false
	for r: int in range(top, bottom + 1):
		for c: int in range(left, right + 1):
			if not level.in_bounds(r, c):
				continue
			var t: int = level.get_cell(r, c)
			if t == Tile.GOAL:
				touched_goal = true
			elif Tile.is_spike(t) and Tile.hazard_hits(
				player.x, player.y, player.w, player.h, r, c, t
			):
				touched_hazard = true

	if touched_hazard and not player.dead:
		player.dead = true
		sim.death_timer = 0
		sim.spawn_particles(player.center_x(), player.center_y(), Palette.GREEN_500, 40, 8.0)
		sim.play(Sfx.Id.HURT)

	# Falling out of the bottom of the map.
	if player.y > level.pixel_height() and not player.dead and not player.won:
		player.dead = true
		sim.death_timer = 0
		sim.spawn_particles(player.center_x(), player.center_y(), Palette.GREEN_400, 30, 6.0)
		sim.spawn_particles(player.center_x(), player.center_y(), Palette.RED_500, 40, 8.0)
		sim.play(Sfx.Id.HURT)

	if touched_goal and not player.won and not player.dead:
		player.won = true
		sim.play(Sfx.Id.WIN)
