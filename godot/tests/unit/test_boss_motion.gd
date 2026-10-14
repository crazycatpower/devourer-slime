extends TestCase
## Actual boss updates in existing arenas, plus presentation continuity.


func _sim(slot: int) -> GameSim:
	var sim: GameSim = GameSim.new()
	sim.load_level(slot, LevelLibrary.built_in_level(slot), LevelLibrary.boss_kind_for_slot(slot))
	return sim


func test_bouncy_health_changes_the_actual_charge_launch_and_recovery() -> void:
	var previous_speed: float = 0.0
	var previous_charge: int = 1000
	var previous_rest: int = 1000
	for hp: int in [3, 2, 1]:
		var sim: GameSim = _sim(30)
		var boss: BossState = sim.boss
		boss.durability = hp
		boss.x = 800.0
		boss.y = 440.0
		boss.grounded = true
		boss.state = BossState.State.ACTIVE
		boss.cooldown = 1
		BossBouncySlime.update(sim)
		check_eq(boss.state, BossState.State.CHARGING)
		check(boss.charge_timer < previous_charge)
		previous_charge = boss.charge_timer
		var warning: int = boss.charge_timer
		check(warning >= 100, "even final phase leaves a readable warning")
		for _i: int in warning:
			BossBouncySlime.update(sim)
		check_eq(boss.state, BossState.State.JUMPING)
		check(-boss.vy > previous_speed)
		previous_speed = -boss.vy
		check_near(absf(boss.vx), absf(BossBouncySlime.leap_vx(BossSystem.player_dx(sim), hp)))
		check_eq(boss.bounces_remaining, BossBouncySlime.bounces_for(hp))
		# Final landing enters a shorter recovery, and updates its UI duration.
		boss.x = 800.0
		boss.y = 440.0
		boss.vx = 0.0
		boss.vy = 1.0
		boss.bounces_remaining = 0
		BossBouncySlime.update(sim)
		check_eq(boss.state, BossState.State.ACTIVE)
		check(boss.cooldown < previous_rest)
		previous_rest = boss.cooldown
		check_eq(boss.max_cooldown, boss.cooldown)


func test_bouncy_preview_tracks_each_phase_without_changing_the_arena() -> void:
	for hp: int in [3, 2, 1]:
		var sim: GameSim = _sim(30)
		var boss: BossState = sim.boss
		boss.durability = hp
		boss.x = 800.0
		boss.y = 440.0
		boss.state = BossState.State.JUMPING
		boss.vx = BossBouncySlime.leap_vx(BossSystem.player_dx(sim), hp)
		boss.vy = -BossBouncySlime.leap_speed_for(hp)
		boss.bounces_remaining = BossBouncySlime.bounces_for(hp)
		var renderer: BossLayer = BossLayer.new()
		var checksum: int = sim.level.checksum()
		var points: PackedVector2Array = renderer._simulate_bouncing_leap(sim, Vector2(boss.center_x(), boss.center_y()))
		check_eq(sim.level.checksum(), checksum)
		for tick: int in range(1, 16):
			BossBouncySlime.update(sim)
			check_near(boss.center_x(), points[tick].x, 0.01)
			check_near(boss.center_y(), points[tick].y, 0.01)
		renderer.free()


func test_bouncy_loss_keeps_player_control_and_escalates_until_defeat() -> void:
	var sim: GameSim = _sim(30)
	for hp: int in [2, 1, 0]:
		sim.boss.y = sim.level.pixel_height() + 1.0
		BossBouncySlime._on_fell_out_of_map(sim)
		check_eq(sim.boss.durability, hp)
		if hp > 0:
			check(not sim.boss.intro_freezes_player)
			check(sim.boss.soft_landing)
			check_eq(sim.boss.state, BossState.State.INTRO)
			check_near(sim.boss.prev_y, sim.boss.y)
		else:
			check(sim.boss.dead and not sim.boss.active)
	check_eq(BossBouncySlime.phase_for(-50), 2)
	check_eq(BossBouncySlime.phase_for(50), 0)


func test_pose_transitions_are_smooth_and_do_not_change_collision_or_rng() -> void:
	for slot: int in [10, 20, 30, 40, 50]:
		var sim: GameSim = _sim(slot)
		var boss: BossState = sim.boss
		boss.state = BossState.State.ACTIVE
		var motion: BossMotion = BossMotion.new()
		motion.advance(1.0 / 60.0, sim)
		var bounds: Rect2 = Rect2(boss.x, boss.y, boss.w, boss.h)
		var draws: int = sim.rng.draw_count
		boss.scale_x = 0.5
		boss.scale_y = 1.8
		motion.advance(1.0 / 60.0, sim)
		if slot in [30, 50]:
			check(motion.body_scale.x > 0.5 and motion.body_scale.x < 1.0, "elastic body eases into launch")
			check(motion.body_scale.y > 1.0 and motion.body_scale.y < 1.8)
		else:
			check_eq(motion.body_scale, Vector2.ONE, "glass, steel and mud remain rigid")
		check_eq(Rect2(boss.x, boss.y, boss.w, boss.h), bounds)
		check_eq(sim.rng.draw_count, draws)
		check_near(boss.scale_x, 0.5, 0.0, "presentation preserves simulation pose")
		# Restart must clear impact and tension rather than carrying an old pose.
		motion.impact = 1.0
		sim.load_level(slot, LevelLibrary.built_in_level(slot), LevelLibrary.boss_kind_for_slot(slot))
		motion.advance(0.0, sim)
		check_near(motion.impact, 0.0)
		check_near(motion.tension, 0.0)
		check_eq(motion.body_scale, Vector2.ONE)


func test_pose_has_matching_timing_at_different_frame_rates() -> void:
	var sim: GameSim = _sim(30)
	sim.boss.state = BossState.State.JUMPING
	sim.boss.scale_x = 0.6
	sim.boss.scale_y = 1.7
	sim.boss.vx = 10.0
	var slow: BossMotion = BossMotion.new()
	var fast: BossMotion = BossMotion.new()
	for _i: int in 15:
		slow.advance(1.0 / 30.0, sim)
	for _i: int in 60:
		fast.advance(1.0 / 120.0, sim)
	check_near(slow.body_scale.x, fast.body_scale.x, 0.00001)
	check_near(slow.body_scale.y, fast.body_scale.y, 0.00001)
	check_near(slow.lean, fast.lean, 0.00001)
	check_near(slow.look.x, fast.look.x, 0.00001)


func test_glass_shields_initialize_and_interpolate_from_the_previous_tick() -> void:
	var sim: GameSim = _sim(40)
	for shield: ShieldState in sim.boss.shields:
		check_near(shield.prev_cx, shield.cx)
		check_near(shield.prev_cy, shield.cy)
	var shield: ShieldState = sim.boss.shields[0]
	var previous: Vector2 = Vector2(shield.cx, shield.cy)
	sim.boss.state = BossState.State.ACTIVE
	sim.step(SimInput.new())
	check_near(shield.prev_cx, previous.x, 0.001)
	check_near(shield.prev_cy, previous.y, 0.001)
	BossGlassSlime.regenerate_shields(sim)
	for fresh: ShieldState in sim.boss.shields:
		check_near(fresh.prev_cx, fresh.cx)
		check_near(fresh.prev_cy, fresh.cy)


func test_mud_resize_preserves_core_position_in_both_render_snapshots() -> void:
	var sim: GameSim = _sim(20)
	var boss: BossState = sim.boss
	boss.prev_x = boss.x - 3.0
	boss.prev_y = boss.y - 2.0
	var core: Vector2 = Vector2(boss.cell_x(boss.center_c), boss.cell_y(boss.center_r))
	boss.set_cell(boss.center_r - 1, boss.center_c - 1, Tile.DIRT)
	BossMudGolem.update_bounds(sim)
	check_eq(Vector2(boss.cell_x(boss.center_c), boss.cell_y(boss.center_r)), core)
	check_near(boss.x - boss.prev_x, 3.0, 0.001, "resizing does not create an extra X interpolation jump")
	check_near(boss.y - boss.prev_y, 2.0, 0.001, "resizing does not create an extra Y interpolation jump")
