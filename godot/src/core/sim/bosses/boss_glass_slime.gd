class_name BossGlassSlime
extends RefCounted
## The glass slime, boss of the fourth world: it flies, ringed by orbiting shields.
##
## Everything about the fight follows from what glass is in this game: it
## cannot be eaten, it costs a spat block to break, and it shatters at the
## first knock. Below the open top of its arena lies glass without end, with
## a little dirt buried in it. The boss makes no ammunition of its own: the
## dirt is all there is, and its attacks are what dig it out.
##
## It roams above, drifting from side to side, randomly choosing four
## moves, with repair less likely. Each is announced before it happens:
## - slam: it lines up over the player, marks the column and drops straight
##   down, smashing through glass until something else stops it. It is left
##   stunned where it lands, still behind its shields;
## - swoop: it draws back to one side and flies a low arc through the spot
##   where the player stands, shaving the top off the glass, then climbs
##   away again unless it strikes dirt and is stunned;
## - throws: shields flash, draw back and are thrown as glass, stopping at
##   first contact and breaking only the glass they touch.
## - repair: announces two, three or four replacement shields;
##   a core hit interrupts it.
## Direct hits from thrown glass and crushing kill; body contact alone does not.
## The shields are what keep a spat block from the core, and
## bombing spends them: every bomb thrown is a shield gone. A block that
## reaches the core costs it one point of durability, regrows a larger ring
## and speeds it up.
enum Move { SLAM, SWOOP, BOMBS, REPAIR }

const REPAIR_WARNING_TICKS: int = 90
const INTRO_TICKS: int = 120
## It keeps this far above the player, give or take [constant BOB_HEIGHT],
## and wanders up to [constant ROAM_REACH] to either side of them.
const HOVER_HEIGHT: float = 310.0
const BOB_HEIGHT: float = 45.0
## How far above the player the camera looks during the fight, so that the
## boss is on screen while the player stays near the bottom of it.
const CAMERA_LIFT: float = 120.0
const BOB_PERIOD_MS: float = 1700.0
const ROAM_REACH: float = 430.0
const ROAM_PERIOD_MS: float = 2300.0
## A quicker, smaller wobble on top of the roaming, so it never glides evenly.
const WOBBLE_REACH: float = 70.0
const WOBBLE_PERIOD_MS: float = 900.0
const ORBIT_PERIOD_MS: float = 1500.0

## Rows of fill under the open top of the arena when the fight starts, the
## rows kept between the player and the bottom, and how many are added at a
## time to keep them: the arena has no bottom to reach.
const ARENA_START_DEPTH: int = 24
const ARENA_DEPTH_AHEAD: int = 16
const ARENA_GROWTH: int = 12
const ARENA_DIRT_SHARE: float = 0.03

## Slam and swoop follow the player for this share of their warning, then commit.
const TRACKING_SHARE: float = 0.6
const SLAM_ACCELERATION: float = 1.6
const SLAM_MAX_SPEED: float = 26.0
## Horizontal distance from the low point of the swoop to each of its ends.
const SWOOP_REACH: float = 320.0
## How far below the player's feet the body dips at the low point.
const SWOOP_DIP: float = 80.0

## A thrown shield keeps its original one-tile size, including collision.
const BOMB_RADIUS: float = Tile.SIZE * 0.5
## Reduced alongside flight speed so slower bombs keep a similar arc.
const BOMB_GRAVITY: float = 0.14
## Ticks a bomb is in the air on its way to where the player stood.
const BOMB_FLIGHT_TICKS: float = 80.0
const BOMB_AIM_SPREAD_X: float = 140.0
const BOMB_AIM_SPREAD_Y: float = 40.0
## How far a shield draws back before it is thrown, and the ticks between
## two throws of one volley.
const WINDUP_PULL: float = 46.0
const WINDUP_STAGGER_TICKS: int = 14
## A spat block within this distance of a shield centre shatters it.
const SHIELD_HIT_RADIUS: float = 32.0
const CORE_HIT_RADIUS: float = 60.0
const HIT_RECOVERY_TICKS: int = 30
const BODY_COLOR: Color = Palette.CYAN_500
const SPARK_COLOR: Color = Palette.CYAN_400

## Shields in the ring for a given durability: 4, then 8, then 12.
static func shield_count_for(durability: int) -> int:
	return 4 + 4 * _lost(durability)


static func repair_count_for(durability: int) -> int:
	return 2 + _lost(durability)


## The displayed intent respects the current phase's shield limit.
static func repair_amount(boss: BossState) -> int:
	var active_count: int = 0
	for shield: ShieldState in boss.shields:
		if shield.active:
			active_count += 1
	return mini(repair_count_for(boss.durability), maxi(0, shield_count_for(boss.durability) - active_count))


## Ticks between two moves; shorter as the boss weakens.
static func move_cooldown_for(durability: int) -> int:
	return 110 - 15 * _lost(durability)


## Ticks a slam or a swoop is announced for.
static func warning_ticks_for(durability: int) -> int:
	return 70 - 12 * _lost(durability)


## Ticks the boss lies stunned after a slam.
static func stun_ticks_for(durability: int) -> int:
	return 130 - 15 * _lost(durability)


## Speed along the arc of the swoop, in units per tick.
static func swoop_speed_for(durability: int) -> float:
	return 13.0 + 2.5 * float(_lost(durability))


## Bombs in one volley: 1, then 2, then 3.
static func bomb_count_for(durability: int) -> int:
	return 1 + _lost(durability)


static func _lost(durability: int) -> int:
	return clampi(BossState.MAX_DURABILITY - durability, 0, 2)


## Turns the arena into an open top over deep glass: the floor it came with
## is opened up and the level is extended downward, filled as it goes. Only
## empty cells are filled, so a level that already has something there keeps it.
static func build_arena(sim: GameSim) -> void:
	var level: LevelGrid = sim.level
	if level.rows < 4 or level.cols < 3:
		return
	sim.boss.glass_arena_rng = SimRandom.new(sim.rng.next_below(1000000000) + 1)
	sim.boss.arena_fill_row = level.rows - 2
	_fill_row(sim, sim.boss.arena_fill_row)
	_deepen(sim, ARENA_START_DEPTH)


## Adds [param count] rows of fill under the arena. The old floor becomes
## fill and a new steel floor closes the bottom.
static func _deepen(sim: GameSim, count: int) -> void:
	var level: LevelGrid = sim.level
	var old_floor: int = level.rows - 1
	level.append_rows(count, Tile.STEEL)
	for row: int in range(old_floor, level.rows - 1):
		for col: int in range(1, level.cols - 1):
			level.set_cell(row, col, Tile.AIR)
		_fill_row(sim, row)


static func _fill_row(sim: GameSim, row: int) -> void:
	var level: LevelGrid = sim.level
	var start: Vector2i = Vector2i(Tile.cell_of(sim.player.center_x()), Tile.cell_of(sim.player.center_y()))
	var available: Array[int] = []
	for col: int in range(1, level.cols - 1):
		if level.get_cell(row, col) != Tile.AIR or Vector2i(col, row) == start:
			continue
		available.append(col)
		level.set_cell(row, col, Tile.GLASS)
	if available.is_empty():
		return
	# A small row quota prevents random stretches with no ammunition at all.
	var dirt_count: int = maxi(1, roundi(float(available.size()) * ARENA_DIRT_SHARE))
	if row == sim.boss.arena_fill_row:
		dirt_count = maxi(2, dirt_count)
	for _cell: int in mini(dirt_count, available.size()):
		var col: int = available.pop_at(sim.boss.glass_arena_rng.next_below(available.size()))
		level.set_cell(row, col, Tile.DIRT)


## Keeps glass under the player however far down they go.
static func _keep_arena_deep(sim: GameSim) -> void:
	var level: LevelGrid = sim.level
	var feet_row: int = Tile.cell_of(sim.player.y + sim.player.h)
	while level.rows - 1 - feet_row < ARENA_DEPTH_AHEAD:
		_deepen(sim, ARENA_GROWTH)

## A fresh ring is immediately usable for both rendering and collision.
static func regenerate_shields(sim: GameSim) -> void:
	sim.boss.shields = BossState.make_shield_ring(shield_count_for(sim.boss.durability))
	sync_orbiting_shields(sim)


static func sync_orbiting_shields(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	for shield: ShieldState in boss.shields:
		if not shield.active or shield.winding_up:
			continue
		var angle: float = sim.clock_ms() / ORBIT_PERIOD_MS + shield.angle_offset
		shield.radius = BossState.SHIELD_ORBIT_RADIUS
		shield.cx = boss.center_x() + cos(angle) * shield.radius
		shield.cy = boss.center_y() + sin(angle) * shield.radius
		if not shield.position_initialized:
			shield.prev_cx = shield.cx
			shield.prev_cy = shield.cy
			shield.position_initialized = true


static func update(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	if boss.glass_hit_recovery > 0:
		boss.glass_hit_recovery -= 1
	_keep_arena_deep(sim)
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
				_return_to_hover(sim)
				sim.camera.shake = 18.0
				sim.play(Sfx.Id.BOUNCE)
				sim.spawn_particles(boss.center_x(), boss.center_y(), BODY_COLOR, 35, 6.5)
		BossState.State.CHARGING:
			if boss.current_move == Move.REPAIR:
				_update_repair_warning(sim)
			elif boss.current_move == Move.SWOOP:
				_update_swoop_warning(sim)
			else:
				_update_slam_warning(sim)
		BossState.State.JUMPING:
			if boss.current_move == Move.SWOOP:
				_update_swooping(sim)
			else:
				_update_slamming(sim)
		BossState.State.STUNNED:
			boss.cooldown -= 1
			if boss.cooldown <= 0:
				_return_to_hover(sim)
				sim.play(Sfx.Id.BOUNCE)
				sim.spawn_particles(boss.center_x(), boss.center_y(), BODY_COLOR, 25, 6.5)
		_:
			_hover(sim)
			boss.cooldown -= 1
			if boss.cooldown <= 0:
				_begin_next_move(sim)
	_update_windups(sim)
	_update_bombs(sim)
	sync_orbiting_shields(sim)


## The move the boss will make next.
static func next_move(sim: GameSim) -> Move:
	var choices: Array[Move] = [Move.SLAM, Move.SLAM, Move.SLAM, Move.SWOOP, Move.SWOOP, Move.SWOOP]
	for shield: ShieldState in sim.boss.shields:
		if shield.active and not shield.winding_up:
			choices.append_array([Move.BOMBS, Move.BOMBS, Move.BOMBS])
			break
	if repair_amount(sim.boss) > 0:
		choices.append(Move.REPAIR)
	return choices[sim.rng.next_below(choices.size())]


## Handles a player projectile at ([param cx], [param cy]). Returns true when
## it hit a shield or the core and must be removed.
static func hit_by_projectile(sim: GameSim, cx: float, cy: float, preview: bool = false) -> bool:
	var boss: BossState = sim.boss
	if not boss.active or boss.dead or boss.state in [BossState.State.SUSPENDED, BossState.State.INTRO]:
		return false
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

	if preview or boss.glass_hit_recovery > 0:
		return true
	boss.durability -= 1
	boss.glass_hit_recovery = HIT_RECOVERY_TICKS
	boss.damage_flash = 1.0
	boss.scale_x = 1.45
	boss.scale_y = 0.6
	sim.camera.shake = 25.0
	sim.play(Sfx.Id.HURT)
	sim.spawn_particles(bcx, bcy, BODY_COLOR, 30, 7.0)
	sim.spawn_particles(bcx, bcy, Palette.AMBER_400, 20, 6.0)

	if boss.durability > 0:
		# One hit per opening: it shakes off the stun and takes to the air.
		regenerate_shields(sim)
		_return_to_hover(sim)
		return true

	BossSystem.defeat(sim)
	boss.bombs.clear()
	sim.camera.shake = 40.0
	sim.play(Sfx.Id.WIN)
	sim.spawn_particles(bcx, bcy, BODY_COLOR, 60, 9.0)
	sim.spawn_particles(bcx, bcy, Palette.AMBER_400, 40, 8.0)
	sim.spawn_particles(bcx, bcy, SPARK_COLOR, 40, 8.0)

	_reveal_goal(sim)
	return true


## The goal appears beside the player, wherever in the depths they are: in
## the free cell to their left or right, or right on top of them when both
## sides are walled in. Nowhere else is sure to be reachable.
static func _reveal_goal(sim: GameSim) -> void:
	var level: LevelGrid = sim.level
	var row: int = Tile.cell_of(sim.player.center_y())
	var col: int = Tile.cell_of(sim.player.center_x())
	for candidate: int in [col + 1, col - 1, col]:
		if level.is_interior(row, candidate) and level.get_cell(row, candidate) == Tile.AIR:
			level.set_cell(row, candidate, Tile.GOAL)
			return
	level.set_cell(row, col, Tile.GOAL)


static func _return_to_hover(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	boss.state = BossState.State.ACTIVE
	boss.grounded = false
	boss.cooldown = move_cooldown_for(boss.durability)
	boss.max_cooldown = boss.cooldown


## Roams high above the player: wide, slow drifts from side to side with a
## quicker wobble on top, bobbing up and down. It follows the player's depth
## but is never parked over their head.
static func _hover(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var player: PlayerState = sim.player
	var clock: float = sim.clock_ms()
	var target_x: float = (
		player.center_x() - boss.w / 2.0
		+ sin(clock / ROAM_PERIOD_MS) * ROAM_REACH + sin(clock / WOBBLE_PERIOD_MS) * WOBBLE_REACH
	)
	target_x = clampf(target_x, _min_x(), _max_x(sim.level, boss.w))
	var target_y: float = maxf(Tile.SIZE, player.y - HOVER_HEIGHT + sin(clock / BOB_PERIOD_MS) * BOB_HEIGHT)
	boss.vx = (target_x - boss.x) * 0.035
	boss.vy = (target_y - boss.y) * 0.045
	boss.x += boss.vx
	boss.y += boss.vy

## Leftmost and rightmost X the body may have inside the arena walls.
static func _min_x() -> float:
	return Tile.SIZE


static func _max_x(level: LevelGrid, boss_w: float) -> float:
	return level.pixel_width() - Tile.SIZE - boss_w


static func _begin_next_move(sim: GameSim) -> void:
	_begin_move(sim, next_move(sim))


static func _begin_move(sim: GameSim, move: Move) -> void:
	var boss: BossState = sim.boss
	boss.action_count += 1
	boss.current_move = move
	boss.cooldown = move_cooldown_for(boss.durability)
	boss.max_cooldown = boss.cooldown
	match move:
		Move.SLAM, Move.SWOOP:
			boss.state = BossState.State.CHARGING
			boss.charge_timer = warning_ticks_for(boss.durability)
			boss.max_charge_timer = boss.charge_timer
			if move == Move.SLAM:
				_aim_slam(sim)
			else:
				_aim_swoop(sim)
			sim.play(Sfx.Id.JUMP)
		Move.BOMBS:
			# With no shield left to throw, it goes straight on to the next move.
			if not _wind_up_bombs(sim):
				_begin_move(sim, Move.SLAM)
		Move.REPAIR:
			boss.state = BossState.State.CHARGING
			boss.charge_timer = REPAIR_WARNING_TICKS
			boss.max_charge_timer = REPAIR_WARNING_TICKS
			boss.vx = 0.0
			boss.vy = 0.0
			sim.play(Sfx.Id.BOUNCE)


static func _update_repair_warning(sim: GameSim) -> void:
	if not _tick_warning(sim):
		return
	var remaining: int = repair_amount(sim.boss)
	for shield: ShieldState in sim.boss.shields:
		if remaining <= 0:
			break
		if shield.active:
			continue
		shield.active = true
		shield.position_initialized = false
		shield.winding_up = false
		shield.windup_timer = 0
		remaining -= 1
	sync_orbiting_shields(sim)
	sim.spawn_particles(sim.boss.center_x(), sim.boss.center_y(), SPARK_COLOR, 24, 3.0)
	sim.play(Sfx.Id.BOUNCE)
	_return_to_hover(sim)


## Share of the warning that has passed, 0..1.
static func _warning_elapsed(boss: BossState) -> float:
	return 1.0 - float(boss.charge_timer) / float(maxi(1, boss.max_charge_timer))


## Shakes harder the closer the attack is, and counts the warning down. True
## when it has run out.
static func _tick_warning(sim: GameSim) -> bool:
	var boss: BossState = sim.boss
	var elapsed: float = _warning_elapsed(boss)
	boss.scale_x = 1.0 + (sim.rng.next_float() - 0.5) * 0.14 * elapsed
	boss.scale_y = 1.0 + (sim.rng.next_float() - 0.5) * 0.14 * elapsed
	if boss.charge_timer % 4 == 0:
		BossSystem.spawn_converging_spark(sim, 90.0, 16.0, SPARK_COLOR, 3.0, 3.0)
	boss.charge_timer -= 1
	return boss.charge_timer <= 0


# --- Slam -----------------------------------------------------------------------------

## Points the slam at the column the player is in. Right up to the walls:
## there is no safe corner to wait it out in.
static func _aim_slam(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var level: LevelGrid = sim.level
	boss.dive_x = clampf(sim.player.center_x() - boss.w / 2.0, _min_x(), _max_x(level, boss.w))
	boss.dive_floor_y = slam_floor_y(level, boss.dive_x, boss.w, boss.y + boss.h)


## Slides over the marked column, which follows the player for a while and
## then commits, so the mark can be read and left in time.
static func _update_slam_warning(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	if _warning_elapsed(boss) < TRACKING_SHARE:
		_aim_slam(sim)
	boss.vx = (boss.dive_x - boss.x) * 0.2
	boss.vy = 0.0
	boss.x += boss.vx
	if not _tick_warning(sim):
		return
	boss.x = boss.dive_x
	boss.vx = 0.0
	boss.vy = 4.0
	boss.dive_floor_y = slam_floor_y(sim.level, boss.dive_x, boss.w, boss.y + boss.h)
	boss.state = BossState.State.JUMPING
	boss.scale_x = 0.7
	boss.scale_y = 1.4
	sim.play(Sfx.Id.JUMP)


## Drops straight down through any glass, to rest on the first thing that is
## not glass.
static func _update_slamming(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	# Recheck the terrain: a player may have removed the marked support.
	boss.dive_floor_y = slam_floor_y(sim.level, boss.x, boss.w, boss.y + boss.h)
	boss.vy = minf(SLAM_MAX_SPEED, boss.vy + SLAM_ACCELERATION)
	boss.y += boss.vy
	if boss.y + boss.h < boss.dive_floor_y:
		_shatter_glass_under_body(sim)
		return
	boss.y = boss.dive_floor_y - boss.h
	boss.vy = 0.0
	boss.grounded = true
	_shatter_glass_under_body(sim)
	BossCollision.resolve(sim)
	var row: int = roundi(boss.dive_floor_y / Tile.SIZE)
	for col: int in range(BossSystem.left_col(boss), BossSystem.right_col(boss) + 1):
		if _is_dirt(sim.level.get_cell(row, col)):
			sim.damage_cell_at(row, col)
	_stun(sim)


static func _stun(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	boss.vx = 0.0
	boss.vy = 0.0
	boss.state = BossState.State.STUNNED
	boss.cooldown = stun_ticks_for(boss.durability)
	boss.max_cooldown = boss.cooldown
	boss.scale_x = 1.6
	boss.scale_y = 0.5
	sim.camera.shake = 28.0
	sim.play(Sfx.Id.LAND)
	sim.spawn_particles(boss.center_x(), boss.y + boss.h, BODY_COLOR, 40, 7.0)


static func _is_dirt(tile: int) -> bool:
	return tile == Tile.DIRT or tile == Tile.DIRT_EATEN_1 or tile == Tile.DIRT_EATEN_2


## Y of the surface a boss [param boss_w] wide at [param x] comes to rest on
## when it drops from [param from_y]: the top of the first solid tile under
## any part of it, or the bottom row of the level when there is none. Glass
## does not count; it breaks.
static func slam_floor_y(level: LevelGrid, x: float, boss_w: float, from_y: float) -> float:
	var first_col: int = clampi(floori(x / Tile.SIZE), 0, level.cols - 1)
	var last_col: int = clampi(floori((x + boss_w - 0.001) / Tile.SIZE), 0, level.cols - 1)
	var first_row: int = maxi(0, ceili(from_y / Tile.SIZE))
	for row: int in range(first_row, level.rows):
		for col: int in range(first_col, last_col + 1):
			var tile: int = level.get_cell(row, col)
			if Tile.is_solid(tile) and tile != Tile.GLASS:
				return float(row) * Tile.SIZE
	return float(level.rows - 1) * Tile.SIZE


# --- Swoop ----------------------------------------------------------------------------

## Lays the arc out: its low point where the player stands, and an end
## [constant SWOOP_REACH] to either side, at the height the boss hangs at.
## It starts from the side it is already on.
static func _aim_swoop(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var level: LevelGrid = sim.level
	var player: PlayerState = sim.player
	var low: float = clampf(player.center_x() - boss.w / 2.0, _min_x(), _max_x(level, boss.w))
	var side: float = 1.0 if boss.x >= low else -1.0
	boss.dive_x = low
	boss.dive_floor_y = player.y + player.h + SWOOP_DIP
	boss.swoop_from = Vector2(clampf(low + side * SWOOP_REACH, _min_x(), _max_x(level, boss.w)), boss.y)
	boss.swoop_to = Vector2(clampf(low - side * SWOOP_REACH, _min_x(), _max_x(level, boss.w)), boss.y)


## Top-left of the body [param t] (0..1) of the way along the arc.
static func swoop_point(boss: BossState, t: float) -> Vector2:
	var low: Vector2 = Vector2(boss.dive_x, boss.dive_floor_y - boss.h)
	var x: float
	if t < 0.5:
		x = lerpf(boss.swoop_from.x, low.x, t * 2.0)
	else:
		x = lerpf(low.x, boss.swoop_to.x, t * 2.0 - 1.0)
	var top: float = lerpf(boss.swoop_from.y, boss.swoop_to.y, t)
	var dip: float = 1.0 - (2.0 * t - 1.0) * (2.0 * t - 1.0)
	return Vector2(x, lerpf(top, low.y, dip))


## Draws back to the start of the arc while its low point follows the player
## for a while and then commits.
static func _update_swoop_warning(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	if _warning_elapsed(boss) < TRACKING_SHARE:
		_aim_swoop(sim)
	boss.vx = (boss.swoop_from.x - boss.x) * 0.2
	boss.vy = 0.0
	boss.x += boss.vx
	if not _tick_warning(sim):
		return
	boss.swoop_from = Vector2(boss.x, boss.y)
	boss.swoop_progress = 0.0
	boss.state = BossState.State.JUMPING
	boss.scale_x = 1.3
	boss.scale_y = 0.8
	sim.play(Sfx.Id.JUMP)


## Flies the arc at a steady speed, breaking the glass it brushes, and goes
## back to hovering at the far end.
static func _update_swooping(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var low: Vector2 = Vector2(boss.dive_x, boss.dive_floor_y - boss.h)
	var length: float = maxf(1.0, boss.swoop_from.distance_to(low) + low.distance_to(boss.swoop_to))
	boss.swoop_progress = minf(1.0, boss.swoop_progress + swoop_speed_for(boss.durability) / length)
	var at: Vector2 = swoop_point(boss, boss.swoop_progress)
	boss.vx = at.x - boss.x
	boss.vy = at.y - boss.y
	var start: Vector2 = Vector2(boss.x, boss.y)
	var steps: int = maxi(1, ceili(start.distance_to(at) / 8.0))
	for step: int in range(1, steps + 1):
		var safe: Vector2 = Vector2(boss.x, boss.y)
		var point: Vector2 = start.lerp(at, float(step) / float(steps))
		boss.x = point.x
		boss.y = point.y
		_shatter_glass_under_body(sim)
		BossCollision.resolve(sim)
		var hit_dirt: bool = false
		for row: int in range(floori(boss.y / Tile.SIZE), floori((boss.y + boss.h - 0.001) / Tile.SIZE) + 1):
			for col: int in range(BossSystem.left_col(boss), BossSystem.right_col(boss) + 1):
				if _is_dirt(sim.level.get_cell(row, col)):
					sim.damage_cell_at(row, col)
					hit_dirt = true
		if hit_dirt:
			boss.x = safe.x
			boss.y = safe.y
			_stun(sim)
			return
	if boss.swoop_progress >= 1.0:
		boss.vx = 0.0
		boss.vy = 0.0
		_return_to_hover(sim)


# --- Bombs ----------------------------------------------------------------------------

## Picks the shields that will be thrown and starts them winding up, one
## after another. False when no shield is left in the ring.
static func _wind_up_bombs(sim: GameSim) -> bool:
	var boss: BossState = sim.boss
	var orbiting: Array[ShieldState] = []
	for shield: ShieldState in boss.shields:
		if shield.active and not shield.winding_up:
			orbiting.append(shield)
	if orbiting.is_empty():
		return false
	var count: int = mini(orbiting.size(), bomb_count_for(boss.durability))
	for i: int in count:
		var chosen: ShieldState = orbiting.pop_at(sim.rng.next_below(orbiting.size()))
		chosen.winding_up = true
		chosen.windup_timer = ShieldState.WINDUP_TICKS + i * WINDUP_STAGGER_TICKS
		chosen.hold_offset = Vector2(chosen.cx - boss.center_x(), chosen.cy - boss.center_y())
	sim.play(Sfx.Id.BOUNCE)
	return true


## A shield that is winding up flashes, draws back away from the player and,
## when its time is up, is thrown at them as a bomb. The shield is spent.
static func _update_windups(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var player: PlayerState = sim.player
	for shield: ShieldState in boss.shields:
		if not shield.active or not shield.winding_up:
			continue
		shield.windup_timer -= 1
		var held: Vector2 = Vector2(boss.center_x(), boss.center_y()) + shield.hold_offset
		var aim: Vector2 = (Vector2(player.center_x(), player.center_y()) - held).normalized()
		# It only starts to draw back once its own turn in the volley has come.
		var drawn: float = clampf(1.0 - float(shield.windup_timer) / float(ShieldState.WINDUP_TICKS), 0.0, 1.0)
		var at: Vector2 = held - aim * WINDUP_PULL * drawn * drawn
		at.x = clampf(at.x, Tile.SIZE + BOMB_RADIUS, sim.level.pixel_width() - Tile.SIZE - BOMB_RADIUS)
		at.y = maxf(Tile.SIZE + BOMB_RADIUS, at.y)
		shield.cx = at.x
		shield.cy = at.y
		if shield.windup_timer > 0:
			continue
		shield.active = false
		_throw_bomb(sim, at)


## Throws a bomb from [param from] so that gravity brings it down where the
## player stands after the flight time.
static func _throw_bomb(sim: GameSim, from: Vector2) -> void:
	var boss: BossState = sim.boss
	var player: PlayerState = sim.player
	var bomb: GlassBomb = GlassBomb.new()
	bomb.x = clampf(from.x, Tile.SIZE + BOMB_RADIUS, sim.level.pixel_width() - Tile.SIZE - BOMB_RADIUS)
	bomb.y = maxf(Tile.SIZE + BOMB_RADIUS, from.y)
	bomb.prev_x = bomb.x
	bomb.prev_y = bomb.y
	var target_x: float = clampf(player.center_x() + (sim.rng.next_float() * 2.0 - 1.0) * BOMB_AIM_SPREAD_X, Tile.SIZE + BOMB_RADIUS, sim.level.pixel_width() - Tile.SIZE - BOMB_RADIUS)
	var target_y: float = player.center_y() + (sim.rng.next_float() * 2.0 - 1.0) * BOMB_AIM_SPREAD_Y
	bomb.vx = (target_x - bomb.x) / BOMB_FLIGHT_TICKS
	bomb.vy = (
		(target_y - bomb.y) / BOMB_FLIGHT_TICKS - BOMB_GRAVITY * (BOMB_FLIGHT_TICKS + 1.0) / 2.0
	)
	boss.bombs.append(bomb)
	sim.add_shake(8.0)
	sim.play(Sfx.Id.JUMP)
	sim.spawn_particles(bomb.x, bomb.y, BODY_COLOR, 18, 5.0)

static func _update_bombs(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var level: LevelGrid = sim.level
	for i: int in range(boss.bombs.size() - 1, -1, -1):
		var bomb: GlassBomb = boss.bombs[i]
		bomb.prev_x = bomb.x
		bomb.prev_y = bomb.y
		if bomb.landed or _fly_bomb(level, bomb, sim.player):
			_shatter_throw(sim, bomb)
			boss.bombs.remove_at(i)
		elif bomb.y - BOMB_RADIUS > level.pixel_height():
			boss.bombs.remove_at(i)


## Swept flight stops at the first player or terrain contact.
static func _fly_bomb(level: LevelGrid, bomb: GlassBomb, player: PlayerState = null) -> bool:
	# Also recover bombs whose winding-up shield was already outside a wall.
	var inside_x: float = clampf(bomb.x, Tile.SIZE + BOMB_RADIUS, level.pixel_width() - Tile.SIZE - BOMB_RADIUS)
	if inside_x != bomb.x:
		bomb.x = inside_x
		bomb.vx = 0.0
	bomb.vy += BOMB_GRAVITY
	var steps: int = maxi(1, ceili(maxf(absf(bomb.vx), absf(bomb.vy)) / 8.0))
	for _step: int in steps:
		if player != null and _bomb_touches_player(bomb, player):
			return true
		if bomb.vx != 0.0:
			var next_x: float = bomb.x + bomb.vx / float(steps)
			var edge_x: float = next_x + signf(bomb.vx) * BOMB_RADIUS
			if next_x < Tile.SIZE + BOMB_RADIUS or next_x > level.pixel_width() - Tile.SIZE - BOMB_RADIUS or _bomb_edge_is_solid(level, edge_x, bomb.y, true, bomb):
				var wall_col: int = floori(edge_x / Tile.SIZE)
				bomb.x = float(wall_col) * Tile.SIZE - BOMB_RADIUS if bomb.vx > 0.0 else float(wall_col + 1) * Tile.SIZE + BOMB_RADIUS
				bomb.vx = 0.0
				return true
			else:
				bomb.x = next_x
		var next_y: float = bomb.y + bomb.vy / float(steps)
		if bomb.vy > 0.0 and _bomb_edge_is_solid(level, bomb.x, next_y + BOMB_RADIUS, false, bomb):
			bomb.y = floorf((next_y + BOMB_RADIUS) / Tile.SIZE) * Tile.SIZE - BOMB_RADIUS
			bomb.vx = 0.0
			bomb.vy = 0.0
			bomb.landed = true
			return true
		if bomb.vy < 0.0 and _bomb_edge_is_solid(level, bomb.x, next_y - BOMB_RADIUS, false, bomb):
			bomb.y = (floorf((next_y - BOMB_RADIUS) / Tile.SIZE) + 1.0) * Tile.SIZE + BOMB_RADIUS
			bomb.vy = 0.0
			return true
		bomb.y = next_y
	return player != null and _bomb_touches_player(bomb, player)


static func _bomb_touches_player(bomb: GlassBomb, player: PlayerState) -> bool:
	var nearest: Vector2 = Vector2(clampf(bomb.x, player.x, player.x + player.w), clampf(bomb.y, player.y, player.y + player.h))
	return nearest.distance_squared_to(Vector2(bomb.x, bomb.y)) <= BOMB_RADIUS * BOMB_RADIUS


## Check the full leading edge, excluding mere corner contact with the floor.
static func _bomb_edge_is_solid(level: LevelGrid, x: float, y: float, horizontal: bool, bomb: GlassBomb = null) -> bool:
	var hit: bool = false
	for offset: float in [-(BOMB_RADIUS - 0.001), 0.0, BOMB_RADIUS - 0.001]:
		var point: Vector2 = Vector2(x if horizontal else x + offset, y + offset if horizontal else y)
		if _is_solid_at(level, point.x, point.y):
			hit = true
			var cell: Vector2i = Vector2i(Tile.cell_of(point.x), Tile.cell_of(point.y))
			if bomb != null and not bomb.hit_cells.has(cell):
				bomb.hit_cells.append(cell)
	return hit


## Interior obstacles stop thrown glass; an open bottom still lets it leave.
static func _is_solid_at(level: LevelGrid, x: float, y: float) -> bool:
	var col: int = floori(x / Tile.SIZE)
	var row: int = floori(y / Tile.SIZE)
	if col < 0 or col >= level.cols or row < 0:
		return true
	if row >= level.rows:
		return false
	var type: int = level.get_cell(row, col)
	return Tile.is_solid(type) or Tile.is_spike(type)


## Shatter the thrown piece and directly contacted glass, without a blast.
static func _shatter_throw(sim: GameSim, bomb: GlassBomb) -> void:
	if _bomb_touches_player(bomb, sim.player) and sim.kill_player():
		sim.play(Sfx.Id.HURT)
	for cell: Vector2i in bomb.hit_cells:
		if sim.level.get_cell(cell.y, cell.x) == Tile.GLASS:
			sim.level.set_cell(cell.y, cell.x, Tile.AIR)
			sim.tile_motions.erase(cell)
			sim.sliding_cells.erase(cell)
			sim.ceiling_slides.erase(cell)
			var center: Vector2 = (Vector2(cell) + Vector2.ONE * 0.5) * Tile.SIZE
			sim.spawn_particles(center.x, center.y, SPARK_COLOR, 6, 2.5)
	sim.add_shake(3.0)
	sim.play(Sfx.Id.BOUNCE)
	sim.spawn_particles(bomb.x, bomb.y, SPARK_COLOR, 10, 3.0)


# --- Shared ---------------------------------------------------------------------------

## Breaks the glass tiles the body covers.
static func _shatter_glass_under_body(sim: GameSim) -> void:
	var boss: BossState = sim.boss
	var level: LevelGrid = sim.level
	var first_row: int = floori(boss.y / Tile.SIZE)
	var last_row: int = floori((boss.y + boss.h - 0.001) / Tile.SIZE)
	for row: int in range(first_row, last_row + 1):
		for col: int in range(BossSystem.left_col(boss), BossSystem.right_col(boss) + 1):
			if level.in_bounds(row, col) and level.get_cell(row, col) == Tile.GLASS:
				sim.damage_cell_at(row, col)
