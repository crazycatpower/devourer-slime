class_name BossCollision
extends RefCounted
## Contact between the player and a boss body.

## An empty cell of the void slime kills on touch. Brushing its corner by
## less than this is forgiven, so standing on the cell beside it is safe.
const VOID_GRAZE: float = 3.0


static func resolve(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	if not boss.active or boss.dead:
		return
	if boss.state == BossState.State.SUSPENDED or boss.state == BossState.State.INTRO:
		return
	if BossMechanism.is_kind(sim.boss_kind):
		_resolve_glass_body(sim)
		return
	match sim.boss_kind:
		BossState.Kind.MUD_GOLEM:
			_resolve_block_body(sim)
		BossState.Kind.BOUNCY_SLIME:
			_resolve_trampoline(sim)
		BossState.Kind.GLASS_SLIME:
			_resolve_glass_body(sim)
		BossState.Kind.VOID_SLIME:
			_resolve_void_body(sim)


## Solid glass contact separates bodies and stops the blocked velocity axis.
static func _resolve_glass_body(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var player: PlayerState = sim.player
	var overlap_x: float = minf(player.x + player.w, boss.x + boss.w) - maxf(player.x, boss.x)
	var overlap_y: float = minf(player.y + player.h, boss.y + boss.h) - maxf(player.y, boss.y)
	if overlap_x <= 0.0 or overlap_y <= 0.0:
		return
	var original_position: Vector2 = Vector2(player.x, player.y)
	player.recoil_vx = 0.0
	player.wall_bounce_timer = 0
	player.grounded = false
	if overlap_x < overlap_y:
		player.x += -overlap_x if player.center_x() < boss.center_x() else overlap_x
		player.vx = 0.0
	elif player.center_y() < boss.center_y():
		player.y -= overlap_y
		player.vy = 0.0
		player.grounded = true
		player.is_jumping = false
	else:
		player.y += overlap_y
		player.vy = 0.0
		player.is_jumping = false
	if not sim.solid_boxes(player.x, player.y, player.w, player.h).is_empty():
		player.x = original_position.x
		player.y = original_position.y
		if sim.kill_player():
			sim.spawn_particles(player.center_x(), player.center_y(), Palette.CYAN_500, 40, 8.0)
			sim.play(Sfx.Id.HURT)


## The bouncy slime launches the player like an oversized bouncy block.
static func _resolve_trampoline(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var player: PlayerState = sim.player
	var overlap_x: float = (
		minf(player.x + player.w, boss.x + boss.w) - maxf(player.x, boss.x)
	)
	var overlap_y: float = (
		minf(player.y + player.h, boss.y + boss.h) - maxf(player.y, boss.y)
	)
	if overlap_x <= 0.0 or overlap_y <= 0.0:
		return

	var bounce_color: Color = Palette.PINK_500
	var sub_bounce_color: Color = Palette.PINK_400
	var original_vx: float = player.vx
	var original_vy: float = player.vy
	# All contact directions launch the player, including side and underside.
	player.grounded = false
	player.recoil_vx = 0.0

	if overlap_x < overlap_y:
		var kick: float = maxf(absf(original_vx) * 1.5, 20.0)
		if player.center_x() < boss.center_x():
			player.x -= overlap_x
			player.vx = -kick
		else:
			player.x += overlap_x
			player.vx = kick
		player.vy = -10.5
		player.wall_bounce_timer = 18
		player.scale_x = 0.5
		player.scale_y = 1.5
		sim.add_shake(absf(original_vx) * 0.8 + 8.0)
		sim.spawn_particles(player.center_x(), player.center_y(), bounce_color, 20, 5.5)
		sim.play(Sfx.Id.BOUNCE)
	elif player.center_y() < boss.center_y():
		# Landing on top: a super trampoline.
		player.y -= overlap_y
		var fall_height: float = player.y - player.fall_start_y
		var bounce_speed: float = maxf(sqrt(maxf(32.0, fall_height)) * 2.2, 19.0)
		player.vy = maxf(-bounce_speed, -25.0)
		player.grounded = false
		player.is_jumping = false
		player.coyote_timer = 30
		player.scale_x = 0.4
		player.scale_y = 1.6
		sim.add_shake(bounce_speed * 0.8 + 6.0)
		sim.spawn_particles(player.center_x(), player.y + player.h, bounce_color, 30, 7.5)
		sim.play(Sfx.Id.BOUNCE)
	else:
		# Bumping it from below sends the player straight back down.
		player.y += overlap_y
		var bounce_speed: float = maxf(absf(original_vy) * 1.2, 14.0)
		player.vy = minf(bounce_speed, 18.0)
		player.is_jumping = false
		player.scale_y = 0.6
		player.scale_x = 1.4
		sim.add_shake(bounce_speed * 0.6 + 4.0)
		sim.spawn_particles(player.center_x(), player.y, sub_bounce_color, 20, 5.5)
		sim.play(Sfx.Id.BOUNCE)


## Void slime: a solid body whose unfilled cells are lethal void.
static func _resolve_void_body(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var player: PlayerState = sim.player
	var px_r: float = player.x + player.w
	var py_b: float = player.y + player.h
	var overlap_x: float = minf(px_r, boss.x + boss.w) - maxf(player.x, boss.x)
	var overlap_y: float = minf(py_b, boss.y + boss.h) - maxf(player.y, boss.y)

	for r: int in 3:
		for c: int in 3:
			if r == 1 and c == 1:
				continue
			# Consumed cells are remains, not new lethal void during devouring.
			if boss.cell(r, c) != 0 or boss.eating_progress > 0.0:
				continue
			var cell_x: float = boss.x + float(c) * Tile.SIZE
			var cell_y: float = boss.y + float(r) * Tile.SIZE
			# The body is solid, so the player only ever sinks a little into a
			# cell before being pushed out: any overlap counts, as long as it is
			# wide enough along the touching side.
			var touch_x: float = minf(px_r, cell_x + Tile.SIZE) - maxf(player.x, cell_x)
			var touch_y: float = minf(py_b, cell_y + Tile.SIZE) - maxf(player.y, cell_y)
			var touches: bool = touch_x > 0.0 and touch_y > 0.0 and maxf(touch_x, touch_y) > VOID_GRAZE
			if touches and sim.kill_player():
				sim.spawn_particles(
					player.center_x(), player.center_y(), Palette.PURPLE_500, 40, 8.0
				)
				sim.play(Sfx.Id.HURT)

	if overlap_x <= 0.0 or overlap_y <= 0.0:
		return
	if overlap_x < overlap_y:
		var push_speed: float = maxf(4.0, absf(player.vx)) * 0.8
		if player.center_x() < boss.center_x():
			player.x -= overlap_x
			player.vx = -push_speed
		else:
			player.x += overlap_x
			player.vx = push_speed
	elif player.center_y() < boss.center_y():
		player.y -= overlap_y
		player.vy = 0.0
		player.grounded = true
		player.is_jumping = false
	else:
		player.y += overlap_y
		player.vy = maxf(0.0, player.vy)


## Mud golem: the boss is a cluster of blocks. A leaping boss kills on touch;
## otherwise its blocks push the player like moving terrain.
static func _resolve_block_body(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var player: PlayerState = sim.player
	var n: int = boss.grid_size

	var overlapping: Array[Vector2i] = []
	for r: int in range(boss.min_r, boss.max_r + 1):
		for c: int in range(boss.min_c, boss.max_c + 1):
			if boss.grid[r * n + c] <= 0:
				continue
			var cell_x: float = boss.cell_x(c)
			var cell_y: float = boss.cell_y(r)
			if not (
				player.x + player.w <= cell_x or player.x >= cell_x + Tile.SIZE
				or player.y + player.h <= cell_y or player.y >= cell_y + Tile.SIZE
			):
				overlapping.append(Vector2i(c, r))

	if overlapping.is_empty():
		return

	if boss.state == BossState.State.JUMPING:
		if sim.kill_player():
			sim.spawn_particles(player.center_x(), player.center_y(), Palette.RED_500, 40, 8.0)
			sim.spawn_particles(player.center_x(), player.center_y(), Palette.YELLOW_500, 25, 6.0)
			sim.play(Sfx.Id.HURT)
		return

	for cell: Vector2i in overlapping:
		var cell_x: float = boss.cell_x(cell.x)
		var cell_y: float = boss.cell_y(cell.y)
		var overlap_x: float = (
			minf(player.x + player.w, cell_x + Tile.SIZE) - maxf(player.x, cell_x)
		)
		var overlap_y: float = (
			minf(player.y + player.h, cell_y + Tile.SIZE) - maxf(player.y, cell_y)
		)
		if overlap_x <= 0.0 or overlap_y <= 0.0:
			continue
		if overlap_x < overlap_y:
			var push_speed: float = maxf(4.0, absf(player.vx)) * 0.8
			if player.center_x() < cell_x + Tile.SIZE / 2.0:
				player.x -= overlap_x
				player.vx = -push_speed
			else:
				player.x += overlap_x
				player.vx = push_speed
		elif player.center_y() < cell_y + Tile.SIZE / 2.0:
			player.y -= overlap_y
			player.vy = minf(player.vy, boss.vy)
			player.grounded = true
			player.is_jumping = false
		else:
			player.y += overlap_y
			player.vy = maxf(player.vy, boss.vy) + 0.5
