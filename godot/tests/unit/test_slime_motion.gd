extends TestCase


func test_stopping_rebounds_and_wall_pressure_relaxes() -> void:
	var player: PlayerState = PlayerState.new()
	player.grounded = true
	player.vx = 4.2
	var motion: SlimeMotion = SlimeMotion.new()
	for _i: int in 30:
		motion.advance(1.0 / 60.0, player)
	player.vx = 0.0
	for _i: int in 4:
		motion.advance(1.0 / 60.0, player)
	check(motion.body_scale.x > 1.04, "stopping squashes and spreads the base")
	check(motion.lean > 0.02, "stopping preserves forward follow-through")
	for _i: int in 40:
		motion.advance(1.0 / 60.0, player, false, 1.0)
	check(motion.wall_pressure > 0.99, "wall pressure eases into contact")
	check(motion.body_scale.y > motion.body_scale.x, "wall contact squeezes sideways and grows upward")
	for _i: int in 60:
		motion.advance(1.0 / 60.0, player)
	check(absf(motion.wall_pressure) < 0.001, "leaving the wall releases the squeeze")
	motion.reset()
	check_near(motion.ground_contact, 0.0)
	check_near(motion.wall_pressure, 0.0)


func test_wall_query_detects_both_sides_without_mistaking_floor() -> void:
	var sim: GameSim = GameSim.new()
	sim.load_level(23, Fixtures.empty_room(), BossState.Kind.NONE)
	sim.player.place_at(40.0, 560.0 - sim.player.h)
	check_near(SlimeMotion.wall_contact(sim), -1.0)
	sim.player.place_at(sim.level.pixel_width() - 40.0 - sim.player.w, 560.0 - sim.player.h)
	check_near(SlimeMotion.wall_contact(sim), 1.0)
	sim.player.place_at(400.0, 560.0 - sim.player.h)
	check_near(SlimeMotion.wall_contact(sim), 0.0)
	check_near(sim.player.x, 400.0, 0.0, "contact query is presentation-only")


func test_carried_block_increases_volume_and_reduces_deformation() -> void:
	var empty: PlayerState = PlayerState.new()
	var full: PlayerState = PlayerState.new()
	full.has_block = true
	empty.scale_x = 0.85
	empty.scale_y = 1.2
	full.scale_x = empty.scale_x
	full.scale_y = empty.scale_y
	var soft: SlimeMotion = SlimeMotion.new()
	var firm: SlimeMotion = SlimeMotion.new()
	for _i: int in 60:
		soft.advance(1.0 / 60.0, empty)
		firm.advance(1.0 / 60.0, full)
	check(firm.body_scale.x * firm.body_scale.y > soft.body_scale.x * soft.body_scale.y, "carrying increases visible volume")
	check(absf(log(firm.body_scale.y / firm.body_scale.x)) < absf(log(soft.body_scale.y / soft.body_scale.x)), "carrying reduces deformation")
	check(not empty.has_block and full.has_block, "visual animation preserves simulation state")


func test_animation_is_consistent_across_frame_rates() -> void:
	var player: PlayerState = PlayerState.new()
	player.grounded = true
	var slow: SlimeMotion = SlimeMotion.new()
	var fast: SlimeMotion = SlimeMotion.new()
	for _i: int in 120:
		slow.advance(1.0 / 30.0, player)
	for _i: int in 480:
		fast.advance(1.0 / 120.0, player)
	check_near(slow.body_scale.x, fast.body_scale.x, 0.015)
	check_near(slow.body_scale.y, fast.body_scale.y, 0.015)
	check(slow.happy and fast.happy, "same idle expression at four seconds")


func test_landing_rebounds_without_changing_player_state() -> void:
	var player: PlayerState = PlayerState.new()
	player.x = 100.0
	player.y = 150.0
	player.vy = 12.0
	var motion: SlimeMotion = SlimeMotion.new()
	motion.advance(1.0 / 60.0, player)
	player.grounded = true
	player.vy = 0.0
	for _i: int in 4:
		motion.advance(1.0 / 60.0, player)
	check(motion.body_scale.x > 1.05, "landing squashes outward")
	check(motion.body_scale.y < 0.95, "landing compresses vertically")
	for _i: int in 80:
		motion.advance(0.1, player)
		check(motion.body_scale.x > 0.6 and motion.body_scale.x < 1.7, "spring stays bounded on slow frames")
	check_near(player.x, 100.0)
	check_near(player.y, 150.0)
	check_near(player.scale_x, 1.0)
	check_near(player.scale_y, 1.0)


func test_interaction_exits_idle_and_reset_clears_reactions() -> void:
	var player: PlayerState = PlayerState.new()
	player.grounded = true
	var motion: SlimeMotion = SlimeMotion.new()
	for _i: int in 110:
		motion.advance(0.1, player)
	check(motion.sleepy, "long idle becomes sleepy")
	player.has_block = true
	motion.advance(0.016, player, true)
	check(not motion.sleepy and not motion.happy, "aiming or eating cancels idle")
	check(motion.chew > 0.0, "swallow triggers chew")
	motion.reset()
	check_near(motion.body_scale.x, 1.0)
	check_near(motion.chew, 0.0)
	check_near(motion.idle_seconds, 0.0)


func test_head_bump_flattens_against_the_ceiling_then_dazes() -> void:
	var player: PlayerState = PlayerState.new()
	player.place_at(200.0, 300.0)
	player.vy = -9.0
	var motion: SlimeMotion = SlimeMotion.new()
	motion.advance(1.0 / 60.0, player)
	# The ceiling stops the rise.
	player.prev_y = player.y
	player.y -= 6.0
	player.vy = 0.0
	motion.advance(1.0 / 60.0, player)
	check_near(motion.bump_age, 0.0, 1e-9, "a stopped rise is a head bump")
	check_near(motion.bump_point.x, player.center_x())
	check_near(motion.bump_point.y, player.y, 1e-9, "the bump is placed on the head")
	check(not motion.bump_soft, "a hard ceiling does not bounce")
	check(motion.wince > 0.99, "the bump squeezes the eyes shut")
	check(motion.head_anchor > 0.99, "the squash pivots on the head")
	for _i: int in 5:
		player.vy += 0.4
		player.prev_y = player.y
		player.y += player.vy * 0.8
		motion.advance(1.0 / 60.0, player)
	check(motion.body_scale.y < 0.93 and motion.body_scale.x > 1.05, "the bump flattens the body")
	check(motion.daze > 0.99, "a hard bump leaves the slime dizzy")
	var y_before: float = player.y
	for _i: int in 24:
		motion.advance(1.0 / 60.0, player)
	check_near(motion.wince, 0.0, 1e-9, "the eyes open again")
	check_near(motion.head_anchor, 0.0, 1e-9, "the pivot returns to the feet")
	check(motion.daze > 0.0, "dizziness outlasts the wince")
	for _i: int in 90:
		motion.advance(1.0 / 60.0, player)
	check_near(motion.daze, 0.0, 1e-9, "dizziness wears off")
	check_near(player.y, y_before, 0.0, "reactions are presentation-only")
	check_near(player.vy, 2.0, 1e-9)


func test_jump_arcs_spits_and_short_hops_are_not_bumps() -> void:
	# Gravity alone never reads as a bump, even when a frame spans many ticks.
	for ticks_per_frame: int in [1, 2, 8]:
		var player: PlayerState = PlayerState.new()
		player.place_at(200.0, 300.0)
		player.grounded = true
		var motion: SlimeMotion = SlimeMotion.new()
		motion.advance(1.0 / 60.0, player)
		player.grounded = false
		player.vy = -GameConstants.JUMP_FORCE
		var tick: int = 0
		while player.vy < 8.0:
			player.vy += GameConstants.GRAVITY * GameConstants.AIR_STEP
			player.prev_y = player.y
			player.y += player.vy * GameConstants.AIR_STEP
			tick += 1
			if tick % ticks_per_frame == 0:
				motion.advance(1.0 / 60.0, player)
		check(motion.bump_age > 1e6, "free arc at %d ticks per frame" % ticks_per_frame)
		check_near(motion.wince, 0.0)
	var spitter: PlayerState = PlayerState.new()
	spitter.has_block = true
	spitter.vy = -6.0
	var recoil: SlimeMotion = SlimeMotion.new()
	recoil.advance(1.0 / 60.0, spitter)
	# Spitting straight up kicks the slime down.
	spitter.has_block = false
	spitter.vy += GameConstants.RECOIL_FORCE
	recoil.advance(1.0 / 60.0, spitter)
	check(recoil.bump_age > 1e6, "the recoil of an upward spit is not a bump")
	var hopper: PlayerState = PlayerState.new()
	hopper.vy = -10.0
	var hop: SlimeMotion = SlimeMotion.new()
	hop.advance(1.0 / 60.0, hopper)
	hopper.vy = PlayerSystem.SHORT_HOP_SPEED
	hop.advance(1.0 / 60.0, hopper)
	check(hop.bump_age > 1e6, "releasing jump early is not a bump")


func test_bouncy_ceiling_winces_without_dizziness() -> void:
	var player: PlayerState = PlayerState.new()
	player.place_at(200.0, 300.0)
	player.vy = -10.0
	var motion: SlimeMotion = SlimeMotion.new()
	motion.advance(1.0 / 60.0, player)
	player.prev_y = player.y
	player.y -= 4.0
	player.vy = 10.0
	motion.advance(1.0 / 60.0, player)
	check_near(motion.bump_age, 0.0, 1e-9, "bouncing off a ceiling is a bump")
	check(motion.bump_soft, "the bump is marked as springy")
	check(motion.wince > 0.99, "the impact still squeezes the eyes")
	check_near(motion.daze, 0.0, 1e-9, "a springy ceiling does not daze")


func test_low_ceiling_stops_a_jump_within_one_frame() -> void:
	var player: PlayerState = PlayerState.new()
	player.place_at(200.0, 300.0)
	player.grounded = true
	var motion: SlimeMotion = SlimeMotion.new()
	motion.advance(1.0 / 60.0, player)
	# The jump and the bump fall in the same tick: six units of headroom.
	player.grounded = false
	player.prev_y = player.y
	player.y -= 6.0
	player.vy = 0.0
	motion.advance(1.0 / 60.0, player)
	check_near(motion.bump_age, 0.0, 1e-9, "a jump cut short by a low ceiling is a bump")
	check(motion.daze > 0.99, "it hits at full jump speed")
	# Walking off a ledge also leaves the ground with no upward speed.
	var walker: PlayerState = PlayerState.new()
	walker.place_at(200.0, 300.0)
	walker.grounded = true
	var stepping: SlimeMotion = SlimeMotion.new()
	stepping.advance(1.0 / 60.0, walker)
	walker.grounded = false
	walker.prev_y = walker.y
	walker.vy = 0.4
	walker.y += 0.32
	stepping.advance(1.0 / 60.0, walker)
	check(stepping.bump_age > 1e6, "stepping off a ledge is not a bump")
	# Being moved far up at once is a teleport, not a jump cut short.
	var lifted: PlayerState = PlayerState.new()
	lifted.place_at(200.0, 500.0)
	lifted.grounded = true
	var teleport: SlimeMotion = SlimeMotion.new()
	teleport.advance(1.0 / 60.0, lifted)
	lifted.grounded = false
	lifted.place_at(200.0, 40.0)
	teleport.advance(1.0 / 60.0, lifted)
	check(teleport.bump_age > 1e6, "a teleport is not a bump")


func test_long_falls_widen_the_eyes_and_land_with_a_wince() -> void:
	var player: PlayerState = PlayerState.new()
	player.place_at(200.0, 0.0)
	var motion: SlimeMotion = SlimeMotion.new()
	motion.advance(1.0 / 60.0, player)
	var widest: float = 0.0
	while player.y < 560.0:
		player.vy = minf(player.vy + 0.4, 12.0)
		player.prev_y = player.y
		player.y += player.vy * 0.8
		motion.advance(1.0 / 60.0, player)
		widest = maxf(widest, motion.alarm)
		if player.y < SlimeMotion.ALARM_FALL_START:
			check_near(motion.alarm, 0.0, 0.0, "a fall within a jump's height stays calm")
	check(widest > 0.8, "a long fall widens the eyes")
	player.grounded = true
	player.vy = 0.0
	motion.advance(1.0 / 60.0, player)
	check(motion.wince > 0.99, "a hard landing squeezes the eyes")
	check(motion.landed_hard, "the hard landing is announced for its sound")
	for _i: int in 30:
		motion.advance(1.0 / 60.0, player)
		check(not motion.landed_hard, "only on the frame of landing")
	check_near(motion.wince, 0.0, 1e-9)
	check(motion.alarm < 0.05, "standing again calms the eyes")
	# The top of an ordinary jump is not high enough to wince.
	player.grounded = false
	player.vy = -1.0
	motion.advance(1.0 / 60.0, player)
	player.y -= 148.0
	motion.advance(1.0 / 60.0, player)
	player.y += 148.0
	player.vy = 12.0
	motion.advance(1.0 / 60.0, player)
	player.grounded = true
	player.vy = 0.0
	motion.advance(1.0 / 60.0, player)
	check_near(motion.wince, 0.0, 1e-9, "landing from a normal jump does not wince")


func test_ledge_query_finds_the_side_of_the_drop() -> void:
	# Level 21 has a lone dirt block on its floor, open on both sides.
	var sim: GameSim = GameSim.new()
	sim.load_level(21, Fixtures.showcase(), BossState.Kind.NONE)
	check(Tile.is_solid(sim.level.get_cell(13, 3)), "fixture: dirt block")
	check(not Tile.is_solid(sim.level.get_cell(13, 2)) and not Tile.is_solid(sim.level.get_cell(13, 4)), "fixture: open sides")
	var top: float = 13.0 * Tile.SIZE - sim.player.h - 0.001
	var edge_right: float = 4.0 * Tile.SIZE
	var edge_left: float = 3.0 * Tile.SIZE
	sim.player.grounded = true
	sim.player.place_at(edge_right + 8.0 - sim.player.w * 0.5, top)
	check_near(SlimeMotion.ledge_drop(sim), 1.0, 0.0, "middle past the right edge")
	sim.player.place_at(edge_left - 8.0 - sim.player.w * 0.5, top)
	check_near(SlimeMotion.ledge_drop(sim), -1.0, 0.0, "middle past the left edge")
	sim.player.place_at(edge_left + 3.0, top)
	check_near(SlimeMotion.ledge_drop(sim), 0.0, 0.0, "middle supported")
	sim.player.place_at(edge_right + 8.0 - sim.player.w * 0.5, top)
	sim.player.grounded = false
	check_near(SlimeMotion.ledge_drop(sim), 0.0, 0.0, "airborne")
	check_near(sim.player.x, edge_right + 8.0 - sim.player.w * 0.5, 0.0, "the query is presentation-only")
	var flat: GameSim = GameSim.new()
	flat.load_level(23, Fixtures.empty_room(), BossState.Kind.NONE)
	flat.player.place_at(400.0, 560.0 - flat.player.h)
	flat.player.grounded = true
	check_near(SlimeMotion.ledge_drop(flat), 0.0, 0.0, "flat floor")


func test_teetering_tips_toward_the_drop_and_wobbles() -> void:
	var player: PlayerState = PlayerState.new()
	player.grounded = true
	var motion: SlimeMotion = SlimeMotion.new()
	for _i: int in 60:
		motion.advance(1.0 / 60.0, player, false, 0.0, 1.0)
	check_near(motion.teeter, 1.0, 1e-9, "standing at a ledge starts a teeter")
	check_near(motion.idle_seconds, 0.0, 0.0, "teetering replaces the idle moods")
	var lowest: float = 1.0
	var highest: float = -1.0
	for _i: int in 60:
		motion.advance(1.0 / 60.0, player, false, 0.0, 1.0)
		lowest = minf(lowest, motion.lean)
		highest = maxf(highest, motion.lean)
	check(lowest > 0.0, "the body keeps tipping toward the drop")
	check(highest - lowest > 0.03, "the balance wobbles")
	for _i: int in 30:
		motion.advance(1.0 / 60.0, player, true, 0.0, 1.0)
	check_near(motion.teeter, 0.0, 1e-9, "aiming steadies the slime")
	for _i: int in 60:
		motion.advance(1.0 / 60.0, player, false, 0.0, -1.0)
	check_near(motion.teeter, -1.0, 1e-9, "a drop on the left mirrors the teeter")
	check(motion.lean < 0.0, "and the lean")


func test_walking_squashes_once_per_stride() -> void:
	var walker: PlayerState = PlayerState.new()
	var treadmill: PlayerState = PlayerState.new()
	for player: PlayerState in [walker, treadmill]:
		player.grounded = true
		player.vx = GameConstants.MAX_SPEED
	var walking: SlimeMotion = SlimeMotion.new()
	var stuck: SlimeMotion = SlimeMotion.new()
	var deviation: float = 0.0
	for i: int in 90:
		walker.x += walker.vx
		walking.advance(1.0 / 60.0, walker)
		stuck.advance(1.0 / 60.0, treadmill)
		if i >= 30:
			deviation = maxf(deviation, absf(walking.body_scale.y - stuck.body_scale.y))
	check(deviation > 0.015, "covering ground adds a squash-and-stretch bob")
	check(deviation < 0.06, "the bob stays subtle")


func test_reactions_match_across_frame_rates_and_reset() -> void:
	var results: Array[SlimeMotion] = []
	for frames_per_second: float in [30.0, 120.0]:
		var dt: float = 1.0 / frames_per_second
		var player: PlayerState = PlayerState.new()
		player.place_at(200.0, 300.0)
		player.vy = -8.0
		var motion: SlimeMotion = SlimeMotion.new()
		motion.advance(dt, player)
		player.vy = 0.0
		for _i: int in roundi(frames_per_second * 0.5):
			motion.advance(dt, player)
		results.append(motion)
	check(results[0].daze > 0.99 and results[1].daze > 0.99, "still dizzy half a second later")
	check_near(results[0].daze_age, results[1].daze_age, 1e-6)
	check_near(results[0].wince, results[1].wince, 1e-6)
	check_near(results[0].body_scale.y, results[1].body_scale.y, 0.02)
	var motion: SlimeMotion = results[0]
	motion.reset()
	check_near(motion.wince, 0.0)
	check_near(motion.daze, 0.0)
	check_near(motion.alarm, 0.0)
	check_near(motion.teeter, 0.0)
	check_near(motion.head_anchor, 0.0)
	check(motion.bump_age > 1e6, "reset forgets the last bump")


func test_restart_does_not_read_as_a_bump() -> void:
	var rising: PlayerState = PlayerState.new()
	rising.vy = -10.0
	var motion: SlimeMotion = SlimeMotion.new()
	motion.advance(1.0 / 60.0, rising)
	# A restart puts a fresh, motionless player in the air at the start point.
	motion.advance(1.0 / 60.0, PlayerState.new())
	check(motion.bump_age > 1e6, "a new player is not a stopped rise")
	check_near(motion.wince, 0.0)
