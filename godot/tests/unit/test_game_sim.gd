extends TestCase
## Behaviour of the simulation on the built-in levels, plus regression tests
## for the web-version defects this port fixes.

const FLOOR_ROW: int = 14


func test_player_falls_and_lands() -> void:
	var sim: GameSim = _sim(23)
	check(not sim.player.grounded)
	_run(sim, SimInput.new(), 120)
	check(sim.player.grounded, "resting on the floor")
	check_near(sim.player.y + sim.player.h, float(FLOOR_ROW) * Tile.SIZE, 0.01)
	check_near(sim.player.vy, 0.0)


func test_walking_accelerates_and_brakes() -> void:
	var sim: GameSim = _sim(23)
	_run(sim, SimInput.new(), 120)
	var right: SimInput = SimInput.new()
	right.right = true
	var before: float = sim.player.x
	_run(sim, right, 10)
	check(sim.player.x - before < GameConstants.MAX_SPEED * 10.0, "accelerates into motion")
	_run(sim, SimInput.new(), 1)
	check(sim.player.vx > 0.0, "brief braking drift")
	_run(sim, SimInput.new(), 5)
	check_near(sim.player.vx, 0.0, 1e-9, "brakes promptly")


func test_jump_height_and_short_hop() -> void:
	var full: GameSim = _sim(23)
	_run(full, SimInput.new(), 120)
	var ground_y: float = full.player.y
	check_near(_jump_apex(full, 75), ground_y - 150.0, 2.0, "held jump rises about 150 units")

	var short: GameSim = _sim(23)
	_run(short, SimInput.new(), 120)
	var apex: float = _jump_apex(short, 3)
	check(apex > ground_y - 150.0 + 40.0, "releasing early cuts the jump short")
	check(apex < ground_y - 20.0, "but it is still a jump")


func test_jump_is_buffered_before_landing() -> void:
	var sim: GameSim = _sim(23)
	# Fall almost to the floor, then press jump a few ticks early.
	while sim.player.y + sim.player.h < float(FLOOR_ROW) * Tile.SIZE - 30.0:
		sim.step(SimInput.new())
	var press: SimInput = SimInput.new()
	press.jump = true
	press.jump_pressed = true
	sim.step(press)
	var hold: SimInput = SimInput.new()
	hold.jump = true
	var jumped: bool = false
	for _i: int in 12:
		sim.step(hold)
		jumped = jumped or sim.player.is_jumping
	check(jumped, "the early press still triggers a jump on landing")


func test_eating_takes_twenty_four_ticks_and_spitting_places_a_worn_block() -> void:
	var sim: GameSim = _sim(21)  # Start at column 1, dirt at column 3, steel at column 5.
	_run(sim, SimInput.new(), 30)
	var eat: SimInput = _aim_at_cell(sim, 13, 3)
	eat.eat = true
	_run(sim, eat, 23)
	check(not sim.player.has_block, "23 ticks are not enough")
	check_eq(sim.level.get_cell(13, 3), Tile.DIRT)
	sim.step(eat)
	check(sim.player.has_block, "the 24th tick swallows the block")
	check_eq(sim.player.carried_block_type, Tile.DIRT)
	check_eq(sim.player.carried_block_eaten_count, 1)
	check_eq(sim.level.get_cell(13, 3), Tile.AIR)

	# Hold and release shoot: the block flies right and settles before the steel.
	var hold: SimInput = _aim_at_cell(sim, 13, 5)
	hold.shoot = true
	_run(sim, hold, 3)
	check(sim.player.in_bullet_time, "holding shoot enters bullet time")
	var release: SimInput = _aim_at_cell(sim, 13, 5)
	release.shoot_released = true
	sim.step(release)
	check(not sim.player.has_block)
	check(not sim.player.in_bullet_time)
	check_eq(sim.projectiles.size(), 1)
	_run(sim, SimInput.new(), 30)
	check_eq(sim.projectiles.size(), 0)
	check_eq(sim.level.get_cell(13, 4), Tile.DIRT_EATEN_1, "lands one stage worn")


func test_moving_away_while_eating_does_not_abort_swallow() -> void:
	var sim: GameSim = _sim(21)  # Player near column 1, dirt at column 3.
	_run(sim, SimInput.new(), 30)
	var eat_left: SimInput = _aim_at_cell(sim, 13, 3)
	eat_left.eat = true
	sim.step(eat_left)
	check(sim.player.has_eating_target, "locked onto target")
	# Move away to the left while keeping eat held
	eat_left.left = true
	_run(sim, eat_left, 23)
	check(sim.player.has_block, "moving away while swallowing successfully swallows the block")
	check_eq(sim.level.get_cell(13, 3), Tile.AIR)


func test_bullet_time_can_be_disabled() -> void:
	var sim: GameSim = _sim(21)
	sim.bullet_time_enabled = false
	_run(sim, SimInput.new(), 30)
	var eat: SimInput = _aim_at_cell(sim, 13, 3)
	eat.eat = true
	_run(sim, eat, 24)
	var hold: SimInput = _aim_at_cell(sim, 13, 5)
	hold.shoot = true
	_run(sim, hold, 3)
	check(sim.player.has_block)
	check(not sim.player.in_bullet_time, "bullet time stays off")


func test_spikes_kill_and_the_level_restarts_by_itself() -> void:
	var sim: GameSim = _sim(24)  # Start at column 1, floor spikes at column 3.
	var right: SimInput = SimInput.new()
	right.right = true
	var ticks: int = 0
	while not sim.player.dead and ticks < 200:
		sim.step(right)
		ticks += 1
	check(sim.player.dead, "walked into the spikes")
	var start_x: float = Fixtures.legacy_level(24).start_x()
	# The tick the player died on already counts as the first.
	_run(sim, SimInput.new(), GameSim.DEATH_RESTART_TICKS - 1)
	check(sim.player.dead, "still on the death screen")
	sim.step(SimInput.new())
	check(not sim.player.dead, "restarted")
	check_near(sim.player.x, start_x)
	check_eq(sim.death_timer, 0)


func test_reaching_the_goal_wins_and_freezes_the_player() -> void:
	var sim: GameSim = _sim(11)
	var right: SimInput = SimInput.new()
	right.right = true
	_run(sim, right, 300)
	check(sim.player.won, "walked to the goal")
	var x: float = sim.player.x
	_run(sim, right, 30)
	check_near(sim.player.x, x, 1e-9, "no more movement after winning")
	check(not sim.player.dead)


func test_reset_gives_a_clean_player() -> void:
	# Restart must clear grounded/coyote/wall-bounce/facing state.
	var sim: GameSim = _sim(23)
	_run(sim, SimInput.new(), 120)
	sim.player.wall_bounce_timer = 9
	sim.player.coyote_timer = 4
	sim.player.facing = -1
	sim.player.has_block = true
	sim.reset()
	check(not sim.player.grounded)
	check_eq(sim.player.wall_bounce_timer, 0)
	check_eq(sim.player.coyote_timer, 0)
	check_eq(sim.player.facing, 1)
	check(not sim.player.has_block)
	check_eq(sim.particles.size(), 0)


func test_same_seed_and_input_give_the_same_run() -> void:
	var a: GameSim = _sim(19, 77)
	var b: GameSim = _sim(19, 77)
	var other_seed: GameSim = _sim(19, 78)
	var script: SimRandom = SimRandom.new(5)
	for _i: int in 400:
		var inp: SimInput = SimInput.new()
		inp.right = script.next_float() < 0.7
		inp.jump = script.next_float() < 0.2
		inp.jump_pressed = inp.jump
		inp.eat = script.next_float() < 0.5
		inp.mouse_x = 600.0
		inp.mouse_y = 400.0
		a.step(inp)
		b.step(inp)
		other_seed.step(inp)
	check_near(a.player.x, b.player.x, 0.0)
	check_near(a.player.y, b.player.y, 0.0)
	check_eq(a.level.checksum(), b.level.checksum())
	check_eq(a.particles.size(), b.particles.size())
	check_eq(a.rng.draw_count, b.rng.draw_count)
	check_near(a.player.x, other_seed.player.x, 0.0, "randomness is cosmetic on a normal level")


func test_cosmetic_particles_leave_gameplay_randomness_alone() -> void:
	var sim: GameSim = _sim(23)
	var draws: int = sim.rng.draw_count
	sim.spawn_cosmetic_particles(10.0, 10.0, Palette.WHITE, 5, 2.0)
	check_eq(sim.particles.size(), 5)
	check_eq(sim.rng.draw_count, draws)


func test_camera_centres_levels_smaller_than_the_view() -> void:
	# Slot 11 is 20 tiles (800 units) wide; the view is 1040.
	var sim: GameSim = _sim(11)
	check_near(sim.camera.x, (800.0 - GameConstants.VIEW_WIDTH) / 2.0)
	_run(sim, SimInput.new(), 30)
	sim.update_camera()
	check_near(sim.camera.x, -120.0, 1e-9, "stays centred while following")
	# A wide level scrolls and never shows past its edges.
	var wide: GameSim = _sim(40)
	check_near(wide.camera.x, 0.0)


func test_boss_setup() -> void:
	var none: GameSim = _sim(23)
	check(not none.boss.active)
	check(none.boss.dead)

	var steel: GameSim = _sim(10)
	check(steel.boss.active)
	check_eq(steel.boss_kind, BossState.Kind.STEEL_CHASE)

	var mud_golem: GameSim = _sim(20)
	check(mud_golem.boss.active)
	check_eq(mud_golem.boss.state, BossState.State.SUSPENDED)
	check_eq(mud_golem.boss.grid_size, 21)
	check_eq(mud_golem.boss.cell(10, 10), Tile.GOAL)
	check_near(mud_golem.boss.w, Tile.SIZE)
	var mound: int = 0
	for r: int in range(11, 14):
		for c: int in range(21, 29):
			if mud_golem.level.get_cell(r, c) == Tile.DIRT:
				mound += 1
	check_eq(mound, 24, "the mound the boss feeds on")

	var bouncy_slime: GameSim = _sim(30)
	check_eq(bouncy_slime.boss.filled_count(), 8, "shielded by bouncy blocks")
	check_eq(bouncy_slime.boss.durability, 3)
	var glass_slime: GameSim = _sim(40)
	check_eq(glass_slime.boss.shields.size(), 4)
	var void_slime: GameSim = _sim(50)
	check_eq(void_slime.boss.filled_count(), 0)
	check(not void_slime.boss.is_filled())


func test_boss_wakes_when_the_player_comes_near() -> void:
	var sim: GameSim = _sim(50)
	_run(sim, SimInput.new(), 60)
	check_eq(sim.boss.state, BossState.State.SUSPENDED, "far away: still dormant")
	var right: SimInput = SimInput.new()
	right.right = true
	var ticks: int = 0
	while sim.boss.state == BossState.State.SUSPENDED and ticks < 400:
		sim.step(right)
		ticks += 1
	check_eq(sim.boss.state, BossState.State.INTRO)
	check(absf(BossSystem.player_dx(sim)) < BossSystem.TRIGGER_DISTANCE)
	# The player is frozen during the entrance.
	var x: float = sim.player.x
	_run(sim, right, 20)
	check_near(sim.player.x, x, 1e-9)


func test_mud_golem_phase_profile_escalates() -> void:
	var sim: GameSim = _sim(20)
	var boss: BossState = sim.boss
	for i: int in boss.grid.size():
		boss.grid[i] = Tile.AIR
	boss.set_cell(10, 10, Tile.GOAL)
	boss.set_cell(10, 9, Tile.DIRT)
	boss.set_cell(9, 10, Tile.DIRT)
	boss.set_cell(10, 11, Tile.DIRT)
	boss.set_cell(11, 10, Tile.DIRT)
	var early: Dictionary = BossMudGolem.phase_profile(sim)
	var early_phase: int = early["phase"]
	check_eq(early_phase, 0, "early pressure is the gentle opening")

	for i: int in boss.grid.size():
		boss.grid[i] = Tile.DIRT
	boss.set_cell(10, 10, Tile.GOAL)
	var late: Dictionary = BossMudGolem.phase_profile(sim)
	var late_phase: int = late["phase"]
	check_eq(late_phase, 2, "a fully fed boss enters frenzy mode")


func test_no_win_on_the_tick_the_player_dies() -> void:
	# Web defect: touching a hazard and the goal together showed "cleared",
	# then restarted the level.
	var sim: GameSim = _sim(23)
	_run(sim, SimInput.new(), 120)
	var player: PlayerState = sim.player
	player.x = 5.0 * Tile.SIZE - player.w / 2.0  # Straddling columns 4 and 5.
	sim.level.set_cell(13, 4, Tile.SPIKE_UP)
	sim.level.set_cell(13, 5, Tile.GOAL)
	sim.step(SimInput.new())
	check(player.dead)
	check(not player.won)


func test_boss_does_not_hang_on_the_right_wall() -> void:
	# Web defect: a boss pressed against the right wall counted the wall
	# column as floor and hovered in mid-air.
	var sim: GameSim = _sim(20)
	var boss: BossState = sim.boss
	boss.state = BossState.State.ACTIVE
	boss.has_initial_reorg = true
	boss.cooldown = 100000
	boss.x = sim.level.pixel_width() - Tile.SIZE - boss.w
	boss.y = 200.0
	boss.vy = 0.0
	_run(sim, SimInput.new(), 5)
	check(boss.y > 200.0, "falls instead of hovering")
	_run(sim, SimInput.new(), 120)
	check(boss.grounded)
	check_near(boss.y + boss.h, float(FLOOR_ROW) * Tile.SIZE, 0.01, "rests on the floor")


func test_block_fed_to_boss_is_consumed_exactly_once() -> void:
	# Web defects: a block absorbed by the boss stayed alive, and could also
	# land in the level on the same tick.
	var sim: GameSim = _sim(50)
	var boss: BossState = sim.boss
	boss.state = BossState.State.ACTIVE
	boss.cooldown = 100000
	boss.x = 800.0
	boss.y = float(FLOOR_ROW) * Tile.SIZE - boss.h
	boss.grounded = true
	var level_before: int = sim.level.checksum()

	var shot: SimProjectile = SimProjectile.new()
	shot.type = Tile.DIRT
	shot.eaten_count = 1
	shot.x = boss.x - 60.0
	shot.y = boss.y + Tile.SIZE  # In line with the middle row.
	shot.vx = GameConstants.BULLET_SPEED
	sim.projectiles.append(shot)
	_run(sim, SimInput.new(), 6)

	check_eq(sim.projectiles.size(), 0, "the block is gone")
	check_eq(boss.filled_count(), 1, "one cell was fed")
	check_eq(boss.cell(1, 0), Tile.DIRT_EATEN_2)
	check_eq(sim.level.checksum(), level_before, "and nothing landed in the level")


func test_boss_arena_writes_stay_inside_small_levels() -> void:
	# Web defect: boss code wrote to fixed coordinates, which broke on custom
	# levels smaller than the stock arena.
	var small: LevelData = LevelLibrary.built_in_level(11)  # 20 x 15.
	for kind: BossState.Kind in [BossState.Kind.MUD_GOLEM, BossState.Kind.BOUNCY_SLIME, BossState.Kind.GLASS_SLIME]:
		var sim: GameSim = GameSim.new()
		sim.rng.set_seed(3)
		sim.load_level(10, small, kind)
		check_eq(sim.level.cols, 20)
		for r: int in sim.level.rows:
			check_eq(sim.level.get_cell(r, 19), Tile.STEEL, "right border intact")
	var sim_2: GameSim = GameSim.new()
	sim_2.load_level(20, small, BossState.Kind.BOUNCY_SLIME)
	sim_2.boss.state = BossState.State.ACTIVE
	sim_2.boss.durability = 1
	sim_2.boss.y = sim_2.level.pixel_height() + 10.0
	check(sim_2.boss.x + sim_2.boss.w <= sim_2.level.pixel_width(), "boss spawns inside the level")
	sim_2.step(SimInput.new())
	check(sim_2.boss.dead, "defeated")
	var goals: int = 0
	for r: int in sim_2.level.rows:
		for c: int in sim_2.level.cols:
			if sim_2.level.get_cell(r, c) == Tile.GOAL:
				goals += 1
				check(sim_2.level.is_interior(r, c), "the goal is reachable, not in the border")
	check_eq(goals, 2, "the level's own goal plus the trophy")
	for c: int in sim_2.level.cols:
		check_eq(sim_2.level.get_cell(0, c), Tile.STEEL, "top border intact")


func test_spit_in_a_tunnel_never_pushes_the_player_through_the_wall() -> void:
	# Web defect: a block settling on the player moved them aside unchecked.
	# In a one-tile tunnel that put them inside the ceiling, and the collision
	# code then carried them up through any thickness of wall.
	var sim: GameSim = _sim(23)
	for r: int in range(10, 13):
		for c: int in range(5, 16):
			sim.level.set_cell(r, c, Tile.STEEL)
	_stand(sim, 10)
	_give_block(sim, Tile.DIRT)
	var fire: SimInput = _aim_offset(sim, 0.0, 200.0)
	fire.shoot_released = true
	sim.step(fire)
	for _i: int in 30:
		sim.step(SimInput.new())
		var p: PlayerState = sim.player
		check(sim.solid_boxes(p.x, p.y, p.w, p.h).is_empty(), "never inside a solid tile")
	check_eq(Tile.cell_of(sim.player.center_y()), 13, "still in the tunnel")
	check_eq(sim.level.get_cell(13, 10), Tile.AIR, "the block crumbled instead")
	check_eq(sim.projectiles.size(), 0)

	# With room above, spitting straight down still lifts the slime onto the block.
	var open: GameSim = _sim(23)
	_stand(open, 10)
	_give_block(open, Tile.DIRT)
	fire = _aim_offset(open, 0.0, 200.0)
	fire.shoot_released = true
	open.step(fire)
	_run(open, SimInput.new(), 60)
	check_eq(open.level.get_cell(13, 10), Tile.DIRT_EATEN_1, "the block landed under the player")
	check(open.player.grounded)
	check_eq(Tile.cell_of(open.player.center_y()), 12, "standing on it")


func test_jump_never_weakens_a_bounce() -> void:
	# Web defect: pressing jump while landing on a bouncy block replaced the
	# bounce with an ordinary jump, cutting a 390-unit rebound to 163.
	var heights: PackedFloat64Array = PackedFloat64Array()
	for press_jump: bool in [false, true]:
		var sim: GameSim = _sim(23)
		for c: int in range(5, 16):
			sim.level.set_cell(FLOOR_ROW, c, Tile.BOUNCY)
		var floor_y: float = float(FLOOR_ROW) * Tile.SIZE
		sim.player.place_at(10.0 * Tile.SIZE + 3.0, floor_y - sim.player.h - 400.0)
		var bounced: bool = false
		var apex: float = floor_y
		for _i: int in 200:
			var inp: SimInput = SimInput.new()
			inp.jump = press_jump
			if press_jump and not bounced and floor_y - (sim.player.y + sim.player.h) < 30.0:
				inp.jump_pressed = true
			sim.step(inp)
			bounced = bounced or sim.player.vy < 0.0
			if bounced:
				apex = minf(apex, sim.player.y)
		heights.append(floor_y - sim.player.h - apex)
	check(heights[0] > 380.0, "a 400-unit fall bounces back about as high")
	check(heights[1] >= heights[0] - 0.001, "and pressing jump takes nothing away")


func test_a_jump_still_adds_to_a_weak_bounce() -> void:
	var sim: GameSim = _sim(23)
	for c: int in range(5, 16):
		sim.level.set_cell(FLOOR_ROW, c, Tile.BOUNCY)
	var floor_y: float = float(FLOOR_ROW) * Tile.SIZE
	# A one-tile drop bounces at about 6 units per tick, half a jump.
	sim.player.place_at(10.0 * Tile.SIZE + 3.0, floor_y - sim.player.h - Tile.SIZE)
	var press: SimInput = SimInput.new()
	press.jump = true
	press.jump_pressed = true
	var hold: SimInput = SimInput.new()
	hold.jump = true
	var apex: float = floor_y
	var pressed: bool = false
	for _i: int in 120:
		var near_floor: bool = floor_y - (sim.player.y + sim.player.h) < 12.0
		if not pressed and near_floor and sim.player.vy > 0.0:
			sim.step(press)
			pressed = true
		else:
			sim.step(hold if pressed else SimInput.new())
		apex = minf(apex, sim.player.y)
	check(floor_y - sim.player.h - apex > 140.0, "the buffered jump turns it into a full jump")


func test_recoil_carries_in_the_air_but_not_on_the_ground() -> void:
	# Web defect: walking overwrote the horizontal speed every tick, so the
	# sideways kick of a spit moved the slime 18 units and stopped.
	var grounded: GameSim = _sim(23)
	_stand(grounded, 20)
	_give_block(grounded, Tile.DIRT)
	var x0: float = grounded.player.x
	var fire: SimInput = _aim_offset(grounded, 200.0, 0.0)
	fire.shoot_released = true
	grounded.step(fire)
	_run(grounded, SimInput.new(), 30)
	check_near(x0 - grounded.player.x, 18.0, 0.01, "on the ground the kick lasts one tick")

	var airborne: GameSim = _sim(23)
	airborne.player.place_at(20.0 * Tile.SIZE + 3.0, 5.0 * Tile.SIZE)
	airborne.step(SimInput.new())
	_give_block(airborne, Tile.DIRT)
	x0 = airborne.player.x
	fire = _aim_offset(airborne, 200.0, 0.0)
	fire.shoot_released = true
	airborne.step(fire)
	_run(airborne, SimInput.new(), 60)
	var pushed: float = x0 - airborne.player.x
	check(pushed > 110.0 and pushed < 125.0, "in the air it fades over about three tiles (%.1f)" % pushed)
	check_near(airborne.player.recoil_vx, 0.0, 1e-9, "and is spent on landing")

	# A wall ends the push.
	var walled: GameSim = _sim(23)
	walled.player.place_at(2.0 * Tile.SIZE + 3.0, 5.0 * Tile.SIZE)
	walled.step(SimInput.new())
	_give_block(walled, Tile.DIRT)
	fire = _aim_offset(walled, 200.0, 0.0)
	fire.shoot_released = true
	walled.step(fire)
	_run(walled, SimInput.new(), 8)
	check_near(walled.player.x, Tile.SIZE + Collision.SKIN, 0.01, "stopped at the left wall")
	check_near(walled.player.recoil_vx, 0.0, 1e-9)


func test_coyote_time_and_jump_buffer_last_what_they_say() -> void:
	# Web defect: both timers were counted down before being read, so "4
	# frames" of coyote time were 3 and "12 frames" of buffer were 10.
	var jumped_on: Array[bool] = []
	for airborne_tick: int in range(1, 7):
		var sim: GameSim = _sim(23)
		sim.level.set_cell(13, 10, Tile.STEEL)
		sim.player.place_at(10.0 * Tile.SIZE + 3.0, 13.0 * Tile.SIZE - sim.player.h - 0.001)
		_run(sim, SimInput.new(), 5)
		var right: SimInput = SimInput.new()
		right.right = true
		var guard: int = 0
		while sim.player.grounded and guard < 60:
			sim.step(right)
			guard += 1
		# The loop ends after the first tick spent in the air.
		_run(sim, right, airborne_tick - 1)
		var press: SimInput = SimInput.new()
		press.right = true
		press.jump = true
		press.jump_pressed = true
		sim.step(press)
		jumped_on.append(sim.player.is_jumping)
	check_eq(jumped_on, [true, true, true, true, false, false] as Array[bool])

	check_eq(PlayerSystem.COYOTE_TICKS, 4)
	check_eq(PlayerSystem.JUMP_BUFFER_TICKS, 12)
	var buffered: GameSim = _sim(23)
	_run(buffered, SimInput.new(), 120)
	buffered.player.jump_buffer = 0
	var tap: SimInput = SimInput.new()
	tap.jump_pressed = true
	# Hold the player off the ground so the press can only wait.
	buffered.player.grounded = false
	buffered.player.coyote_timer = 0
	buffered.player.y -= 300.0
	buffered.step(tap)
	var remembered: int = 1
	while buffered.player.jump_buffer > 0 and remembered < 40:
		buffered.step(SimInput.new())
		remembered += 1
	check_eq(remembered, PlayerSystem.JUMP_BUFFER_TICKS + 1, "the press is live for 12 ticks, then gone")


func test_boss_leap_lands_where_it_aimed_despite_the_ceiling() -> void:
	# Web defect: leaps were aimed with the free-flight time although the
	# boss stops rising at the ceiling, so high leaps covered about half the
	# intended distance.
	check_near(BossSystem.leap_flight_ticks(440.0, 4.0, 0.2), 39.0, 1e-9, "a low hop flies freely")
	var clipped: float = BossSystem.leap_flight_ticks(440.0, 11.5 * 1.732, BossVoidSlime.GRAVITY)
	check(clipped < 100.0, "a high leap is cut short by the ceiling (%d ticks)" % int(clipped))

	for sim_seed: int in [1, 2, 3, 4, 5, 6]:
		var sim: GameSim = _sim(50, sim_seed)
		var boss: BossState = sim.boss
		boss.state = BossState.State.ACTIVE
		boss.cooldown = 1
		boss.x = 1100.0  # Close enough for even the slowest leap to reach.
		boss.y = float(FLOOR_ROW) * Tile.SIZE - boss.h
		boss.grounded = true
		var target_x: float = 700.0
		var leapt: bool = false
		var ticks: int = 0
		while ticks < 600:
			ticks += 1
			sim.player.x = target_x - sim.player.w / 2.0
			sim.player.y = float(FLOOR_ROW) * Tile.SIZE - sim.player.h - 0.001
			sim.step(SimInput.new())
			if boss.state == BossState.State.JUMPING:
				leapt = true
			elif leapt:
				break
		check(leapt, "the boss leapt")
		var miss: float = absf(boss.center_x() - target_x)
		check(miss < 30.0, "seed %d: landed %.0f units from its target" % [sim_seed, miss])


func test_block_bounces_off_an_occupied_boss_cell() -> void:
	# Web defect: a block that struck a filled boss cell was given a bounce
	# and then deleted anyway.
	var sim: GameSim = _sim(50)
	var boss: BossState = sim.boss
	boss.state = BossState.State.ACTIVE
	boss.cooldown = 100000
	boss.x = 800.0
	boss.y = float(FLOOR_ROW) * Tile.SIZE - boss.h
	boss.grounded = true
	boss.set_cell(1, 0, Tile.DIRT_EATEN_2)
	var level_before: int = sim.level.checksum()

	var shot: SimProjectile = SimProjectile.new()
	shot.type = Tile.DIRT
	shot.eaten_count = 1
	shot.x = boss.x - 60.0
	shot.y = boss.y + Tile.SIZE
	shot.vx = GameConstants.BULLET_SPEED
	sim.projectiles.append(shot)
	_run(sim, SimInput.new(), 6)
	check_eq(sim.projectiles.size(), 1, "the block is still in play")
	check(shot.vx < 0.0, "flying back the way it came")
	check(shot.x + shot.w <= boss.x + 0.001, "outside the boss")
	check_eq(boss.filled_count(), 1, "the boss did not swallow it")

	_run(sim, SimInput.new(), 400)
	check_eq(sim.projectiles.size(), 0)
	check(sim.level.checksum() != level_before, "it landed in the arena as a block again")


func test_retry_shortens_the_boss_entrance() -> void:
	var sim: GameSim = _sim(50)
	var right: SimInput = SimInput.new()
	right.right = true
	_run_until_boss_state(sim, right, BossState.State.INTRO)
	check_eq(sim.boss.intro_timer, BossVoidSlime.INTRO_TICKS, "the first entrance is shown in full")

	sim.reset()
	_run_until_boss_state(sim, right, BossState.State.INTRO)
	check_eq(sim.boss.intro_timer, BossSystem.RETRY_INTRO_TICKS, "a retry gets the short one")

	sim.load_level(50, LevelLibrary.built_in_level(50), BossState.Kind.VOID_SLIME)
	_run_until_boss_state(sim, right, BossState.State.INTRO)
	check_eq(sim.boss.intro_timer, BossVoidSlime.INTRO_TICKS, "loading the level afresh starts over")


func test_player_keeps_control_when_the_bouncy_slime_returns() -> void:
	# Web defect: the boss floating back in froze the player for two seconds,
	# in an arena whose floor has holes by then.
	var sim: GameSim = _sim(30)
	_run(sim, SimInput.new(), 60)
	var boss: BossState = sim.boss
	boss.state = BossState.State.ACTIVE
	boss.y = sim.level.pixel_height() + 10.0
	sim.step(SimInput.new())
	check_eq(boss.durability, 2)
	check_eq(boss.state, BossState.State.INTRO, "floating back in")
	check(not boss.intro_freezes_player)
	var x: float = sim.player.x
	var right: SimInput = SimInput.new()
	right.right = true
	_run(sim, right, 10)
	check(sim.player.x - x > GameConstants.MAX_SPEED * 8.0, "the player can still accelerate and walk during reentry")


func test_bouncy_slime_returns_over_floor_and_lands_gently() -> void:
	var sim: GameSim = _sim(30)
	_run(sim, SimInput.new(), 60)
	var boss: BossState = sim.boss
	var level: LevelGrid = sim.level
	var usual_col: int = roundi(BossSystem.spawn_x(level, boss.w) / Tile.SIZE)
	# Knock out everything under the usual place, so nothing carries it there.
	for col: int in range(usual_col - 1, usual_col + 4):
		for row: int in range(1, level.rows):
			level.set_cell(row, col, Tile.AIR)
	boss.state = BossState.State.ACTIVE
	boss.y = level.pixel_height() + 10.0
	sim.step(SimInput.new())
	check_eq(boss.durability, 2)
	var col: int = roundi(boss.x / Tile.SIZE)
	check(col != usual_col, "it does not come back over the hole")
	check(absi(col - usual_col) <= 4, "it picks the nearest place with floor")
	var before: LevelGrid = level.duplicate_grid()
	_run_until_boss_state(sim, SimInput.new(), BossState.State.ACTIVE)
	check_eq(boss.state, BossState.State.ACTIVE, "it lands instead of falling through")
	check_eq(boss.durability, 2, "and loses nothing more")
	check(level.equals(before), "the landing leaves the floor intact")
	check(not boss.soft_landing, "only that one landing is gentle")


func test_bouncy_slime_respawn_falls_back_to_the_usual_place() -> void:
	var bare: LevelGrid = LevelGrid.new(40, 15)
	check_eq(BossBouncySlime.respawn_x(bare, BossState.BODY_SIZE), BossSystem.spawn_x(bare, BossState.BODY_SIZE), "no floor anywhere")
	var full: LevelGrid = LevelLibrary.built_in_level(30).grid
	check_eq(BossBouncySlime.respawn_x(full, BossState.BODY_SIZE), BossSystem.spawn_x(full, BossState.BODY_SIZE), "an intact floor keeps the usual place")


func _run_until_boss_state(sim: GameSim, inp: SimInput, state: BossState.State) -> void:
	var ticks: int = 0
	while sim.boss.state != state and ticks < 600:
		sim.step(inp)
		ticks += 1


## Puts the player on the floor of the stock room in column [param col].
func _stand(sim: GameSim, col: int) -> void:
	sim.player.place_at(
		float(col) * Tile.SIZE + 3.0, float(FLOOR_ROW) * Tile.SIZE - sim.player.h - 0.001
	)
	_run(sim, SimInput.new(), 5)


func _give_block(sim: GameSim, type: int) -> void:
	sim.player.has_block = true
	sim.player.carried_block_type = type
	sim.player.carried_block_eaten_count = 1
	sim.player.waiting_for_shoot_release = false


## Input whose mouse sits at an offset from the player's centre.
func _aim_offset(sim: GameSim, dx: float, dy: float) -> SimInput:
	var inp: SimInput = SimInput.new()
	inp.mouse_x = sim.player.center_x() + dx - sim.camera.x
	inp.mouse_y = sim.player.center_y() + dy - sim.camera.y
	return inp


func _sim(slot: int, sim_seed: int = 1) -> GameSim:
	var sim: GameSim = GameSim.new()
	sim.rng.set_seed(sim_seed)
	var level: LevelData = Fixtures.legacy_level(slot)
	if slot == 21:
		level = Fixtures.showcase()
	elif slot == 23:
		level = Fixtures.empty_room()
	sim.load_level(slot, level, LevelLibrary.boss_kind_for_slot(slot))
	return sim


func _run(sim: GameSim, inp: SimInput, ticks: int) -> void:
	for _i: int in ticks:
		sim.step(inp)


## Jumps, holding the button for [param hold_ticks]; returns the highest point.
func _jump_apex(sim: GameSim, hold_ticks: int) -> float:
	var press: SimInput = SimInput.new()
	press.jump = true
	press.jump_pressed = true
	sim.step(press)
	var apex: float = sim.player.y
	for i: int in 80:
		var inp: SimInput = SimInput.new()
		inp.jump = i < hold_ticks
		sim.step(inp)
		apex = minf(apex, sim.player.y)
	return apex


## Input whose mouse points at the centre of a level cell.
func _aim_at_cell(sim: GameSim, r: int, c: int) -> SimInput:
	var inp: SimInput = SimInput.new()
	inp.mouse_x = float(c) * Tile.SIZE + Tile.SIZE / 2.0 - sim.camera.x
	inp.mouse_y = float(r) * Tile.SIZE + Tile.SIZE / 2.0 - sim.camera.y
	return inp


func test_dirt_reduces_speed_to_eighty_percent_and_lowers_jump_height() -> void:
	var right: SimInput = SimInput.new()
	right.right = true

	var sim_empty: GameSim = _sim(23)
	_run(sim_empty, SimInput.new(), 120)
	_run(sim_empty, right, 10)
	check_eq(sim_empty.player.vx, GameConstants.MAX_SPEED, "empty player reaches normal max speed")

	var sim_jump: GameSim = _sim(23)
	_run(sim_jump, SimInput.new(), 120)
	var ground_y: float = sim_jump.player.y
	var empty_apex: float = _jump_apex(sim_jump, 75)
	var empty_jump_height: float = ground_y - empty_apex

	var sim_dirt: GameSim = _sim(23)
	_run(sim_dirt, SimInput.new(), 120)
	sim_dirt.player.has_block = true
	sim_dirt.player.carried_block_type = Tile.DIRT
	sim_dirt.player.carried_block_eaten_count = 1
	_run(sim_dirt, right, 10)
	check_eq(sim_dirt.player.vx, GameConstants.MAX_SPEED * 0.8, "carrying dirt reduces horizontal speed to 80%")

	var sim_dirt_jump: GameSim = _sim(23)
	_run(sim_dirt_jump, SimInput.new(), 120)
	sim_dirt_jump.player.has_block = true
	sim_dirt_jump.player.carried_block_type = Tile.DIRT
	sim_dirt_jump.player.carried_block_eaten_count = 1
	ground_y = sim_dirt_jump.player.y
	var dirt_apex: float = _jump_apex(sim_dirt_jump, 75)
	var dirt_jump_height: float = ground_y - dirt_apex
	check(dirt_jump_height < empty_jump_height, "carrying dirt slightly reduces jump height")
	check(dirt_jump_height > empty_jump_height * 0.94, "dirt jump height is only slightly reduced")

	var sim_bouncy: GameSim = _sim(23)
	_run(sim_bouncy, SimInput.new(), 120)
	sim_bouncy.player.has_block = true
	sim_bouncy.player.carried_block_type = Tile.BOUNCY
	sim_bouncy.player.carried_block_eaten_count = 1
	_run(sim_bouncy, right, 10)
	check_eq(sim_bouncy.player.vx, GameConstants.MAX_SPEED, "carrying bouncy block retains full 100% speed")


func test_bouncy_block_returns_to_exact_fall_height_and_sustains_bounces() -> void:
	var sim: GameSim = GameSim.new()
	var level: LevelGrid = LevelGrid.new(15, 15)
	for c: int in 15:
		level.set_cell(10, c, Tile.BOUNCY)
	sim.level = level
	var initial_y: float = 4.0 * Tile.SIZE  # 160.0
	sim.player.x = 5.0 * Tile.SIZE
	sim.player.y = initial_y
	sim.player.w = 28.0
	sim.player.h = 28.0
	sim.player.grounded = false
	sim.player.fall_start_y = initial_y

	var apex_list: Array[float] = []
	var vy_before: float = 0.0
	var apex_y: float = sim.player.y

	for _tick: int in 800:
		var curr_vy: float = sim.player.vy
		sim.step(SimInput.new())
		if curr_vy < 0.0:
			apex_y = minf(apex_y, sim.player.y)
		elif vy_before < 0.0 and curr_vy >= 0.0:
			apex_list.append(apex_y)
			apex_y = sim.player.y
		vy_before = curr_vy

	check(apex_list.size() >= 5, "bounces multiple times continuously (got %d bounces)" % apex_list.size())
	for i: int in apex_list.size():
		check(apex_list[i] < initial_y, "bounce %d clears the drop height" % (i + 1))
		check_near(apex_list[i], initial_y - Collision.BOUNCE_CLEARANCE, 0.6, "bounce %d apex is just above the drop height" % (i + 1))
	check_near(apex_list[4], apex_list[0], 0.1, "repeated bounces maintain identical apex height")


func test_bouncy_block_returns_a_tall_fall_in_full() -> void:
	# A speed limit used to cut the rebound of falls above about 15 tiles.
	for tiles: float in [16.0, 30.0, 100.0]:
		var sim: GameSim = GameSim.new()
		var level: LevelGrid = LevelGrid.new(15, 120)
		for c: int in 15:
			level.set_cell(110, c, Tile.BOUNCY)
		sim.level = level
		var floor_y: float = 110.0 * Tile.SIZE - 28.0 - 0.001
		var initial_y: float = floor_y - tiles * Tile.SIZE
		sim.player.x = 5.0 * Tile.SIZE
		sim.player.y = initial_y
		sim.player.w = 28.0
		sim.player.h = 28.0
		sim.player.grounded = false
		sim.player.fall_start_y = initial_y

		var bounced: bool = false
		var apex_y: float = INF
		for _tick: int in 3000:
			var vy_prev: float = sim.player.vy
			sim.step(SimInput.new())
			if vy_prev > 0.0 and sim.player.vy < 0.0:
				if bounced:
					break
				bounced = true
			if bounced:
				apex_y = minf(apex_y, sim.player.y)
		check_near(apex_y, initial_y - Collision.BOUNCE_CLEARANCE, 0.6, "a %d-tile fall bounces back to just above its start" % int(tiles))


func test_being_squeezed_into_a_wall_kills() -> void:
	var standing: GameSim = _sim(23)
	_run(standing, SimInput.new(), 120)
	check(standing.player.grounded and not standing.player.dead, "standing on the floor is not being crushed")
	var right: SimInput = SimInput.new()
	right.right = true
	_run(standing, right, 600)
	check(not standing.player.dead, "nor is walking into a wall")

	# One block appearing under the player just lifts them onto it.
	var lifted: GameSim = _sim(23)
	_run(lifted, SimInput.new(), 120)
	var lifted_row: int = Tile.cell_of(lifted.player.center_y())
	var lifted_col: int = Tile.cell_of(lifted.player.center_x())
	lifted.level.set_cell(lifted_row, lifted_col, Tile.GLASS)
	_run(lifted, SimInput.new(), 5)
	check(not lifted.player.dead, "with room above, the player is pushed up, not crushed")

	# With something solid above as well there is nowhere to go.
	var buried: GameSim = _sim(23)
	_run(buried, SimInput.new(), 120)
	var player: PlayerState = buried.player
	var row: int = Tile.cell_of(player.center_y())
	var col: int = Tile.cell_of(player.center_x())
	buried.level.set_cell(row, col, Tile.GLASS)
	buried.level.set_cell(row - 1, col, Tile.GLASS)
	_run(buried, SimInput.new(), 5)
	check(player.dead, "squeezed between two blocks, the player is crushed")

	# Only the edge of the body is inside a block: collision pushes it out.
	var grazed: GameSim = _sim(23)
	_run(grazed, SimInput.new(), 120)
	var side_row: int = Tile.cell_of(grazed.player.center_y())
	var side_col: int = Tile.cell_of(grazed.player.x + grazed.player.w + 3.0)
	if grazed.level.get_cell(side_row, side_col) == Tile.AIR:
		grazed.level.set_cell(side_row, side_col, Tile.STEEL)
		grazed.player.x = float(side_col) * Tile.SIZE - grazed.player.w + 3.0
		grazed.step(SimInput.new())
		check(not grazed.player.dead, "a shallow overlap is not a crush")


func test_bounce_returns_onto_the_ledge_stepped_off() -> void:
	# A steel pillar three tiles tall beside a bouncy floor.
	var level: LevelGrid = LevelGrid.new(15, 15)
	for c: int in 15:
		level.set_cell(12, c, Tile.BOUNCY if c >= 5 else Tile.STEEL)
	for r: int in range(9, 12):
		level.set_cell(r, 4, Tile.STEEL)
	var sim: GameSim = GameSim.new()
	sim.level = level
	var top_y: float = 9.0 * Tile.SIZE - sim.player.h - Collision.SKIN
	sim.player.place_at(4.0 * Tile.SIZE + 6.0, top_y)
	sim.player.grounded = true

	var right: SimInput = SimInput.new()
	right.right = true
	var left: SimInput = SimInput.new()
	left.left = true
	var bounced: bool = false
	var left_ledge: bool = false
	var returned: bool = false
	for _tick: int in 400:
		var vy_prev: float = sim.player.vy
		sim.step(left if bounced else right)
		if not sim.player.grounded:
			left_ledge = true
		if vy_prev > 0.0 and sim.player.vy < 0.0:
			bounced = true
		if bounced and sim.player.grounded:
			returned = absf(sim.player.y - top_y) < 1.0
			break
	check(left_ledge and bounced, "the player walked off and hit the bouncy floor")
	check(returned, "one bounce carries the player back onto the ledge")


func test_bouncy_ceiling_returns_the_full_speed() -> void:
	var sim: GameSim = GameSim.new()
	var level: LevelGrid = LevelGrid.new(15, 15)
	for c: int in 15:
		level.set_cell(2, c, Tile.BOUNCY)
	sim.level = level
	sim.player.x = 5.0 * Tile.SIZE
	sim.player.y = 3.0 * Tile.SIZE + 20.0
	sim.player.w = 28.0
	sim.player.h = 28.0
	sim.player.grounded = false
	sim.player.vy = -40.0
	var speed_in: float = 0.0
	for _tick: int in 5:
		var vy_prev: float = sim.player.vy
		sim.step(SimInput.new())
		if vy_prev < 0.0 and sim.player.vy > 0.0:
			speed_in = absf(vy_prev) - GameConstants.GRAVITY * GameConstants.AIR_STEP
			break
	check(speed_in > 30.0, "the ceiling was hit at speed")
	check_near(sim.player.vy, speed_in, 0.01, "a bouncy ceiling keeps all of the speed")


func test_bounce_ignored_when_fall_height_under_one_tile() -> void:
	var level: LevelGrid = LevelGrid.new(15, 15)
	for c: int in 15:
		level.set_cell(10, c, Tile.BOUNCY)
	var floor_y: float = 10.0 * Tile.SIZE - 28.0 - 0.001

	# Fall from less than 1 tile (30 units < 40 units) onto bouncy block:
	var sim_short: GameSim = GameSim.new()
	sim_short.level = level
	sim_short.player.x = 5.0 * Tile.SIZE
	sim_short.player.y = floor_y - 30.0
	sim_short.player.w = 28.0
	sim_short.player.h = 28.0
	sim_short.player.grounded = false
	sim_short.player.fall_start_y = sim_short.player.y

	for _i: int in 60:
		sim_short.step(SimInput.new())
	check(sim_short.player.grounded, "fall under 1 tile lands without bouncing")
	check_near(sim_short.player.vy, 0.0, 0.01, "velocity settles at zero")

	# Fall from 1 full tile (40 units) onto bouncy block:
	var sim_one_tile: GameSim = GameSim.new()
	sim_one_tile.level = level
	sim_one_tile.player.x = 5.0 * Tile.SIZE
	sim_one_tile.player.y = floor_y - Tile.SIZE
	sim_one_tile.player.w = 28.0
	sim_one_tile.player.h = 28.0
	sim_one_tile.player.grounded = false
	sim_one_tile.player.fall_start_y = sim_one_tile.player.y

	var bounced: bool = false
	for _i: int in 60:
		var vy_prev: float = sim_one_tile.player.vy
		sim_one_tile.step(SimInput.new())
		if vy_prev > 0.0 and sim_one_tile.player.vy < 0.0:
			bounced = true
			break
	check(bounced, "fall of 1 full tile triggers a bounce")



