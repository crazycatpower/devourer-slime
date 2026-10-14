extends TestCase


func test_history_reverses_and_drops_old_frames() -> void:
	var sim: GameSim = GameSim.new()
	sim.load_level(1, LevelLibrary.shipped_level(1), BossState.Kind.NONE)
	var history: DeathRewind = DeathRewind.new()
	var total_ticks: int = DeathRewind.CAPACITY * 2 + 20
	for tick: int in total_ticks:
		sim.tick_count = tick
		sim.player.x = float(tick)
		history.capture(sim)
	check(history.sample_count() == DeathRewind.CAPACITY, "history remains bounded")
	check_near(history.frame_at(0.0).player.x, float(total_ticks - 2))
	check_near(history.frame_at(1.0).player.x, 20.0)
	check(history.frame_at(0.25).tick_count > history.frame_at(0.75).tick_count, "playback moves backward")
	sim.player.dead = true
	sim.tick_count = total_ticks + 2
	history.capture(sim)
	check_near(history.frame_at(0.0).player.x, float(total_ticks - 2), 0.0, "death cannot overwrite the last live frame")
	history.clear()
	check(history.frame_at(0.0) == null, "restart discards the previous attempt")


func test_snapshots_isolate_mutable_entities_and_signal_layers() -> void:
	var sim: GameSim = GameSim.new()
	sim.load_level(1, LevelLibrary.shipped_level(1), BossState.Kind.NONE)
	var projectile: SimProjectile = SimProjectile.new()
	projectile.x = 120.0
	sim.projectiles.append(projectile)
	sim.boss.mechanism.path.append(Vector2(12.0, 34.0))
	var history: DeathRewind = DeathRewind.new()
	history.capture(sim)
	var first: GameSim = history.frame_at(0.0)
	var cell: Vector2i = Vector2i(2, 2)
	var original_wire: bool = sim.level.wires.has(cell)
	sim.level.set_wire(cell, not original_wire)
	sim.projectiles[0].x = 999.0
	sim.boss.mechanism.path[0] = Vector2.ZERO
	sim.tick_count += 2
	history.capture(sim)
	check_near(first.projectiles[0].x, 120.0, 0.0, "projectiles are independent records")
	check(first.boss.mechanism.path[0] == Vector2(12.0, 34.0), "nested boss data stays historical")
	check(first.level.wires.has(cell) == original_wire, "old signal layer remains intact")
	check(history.frame_at(0.0).level.wires.has(cell) != original_wire, "signal-only changes invalidate terrain cache")


func test_recovery_preserves_progress_and_stops_before_hazard() -> void:
	var sim: GameSim = GameSim.new()
	sim.load_level(9, LevelLibrary.shipped_level(9), LevelLibrary.boss_kind_for_slot(9))
	sim.external_death_recovery = true
	var history: DeathRewind = DeathRewind.new()
	var start_x: float = sim.player.x
	# An already changed non-solid layer distinguishes rollback from reset.
	var cell: Vector2i = Vector2i(1, 1)
	sim.level.set_wire(cell, true)
	history.capture(sim)
	for tick: int in 300:
		var move: SimInput = SimInput.new()
		move.right = true
		sim.step(move)
		history.capture(sim)
		if sim.player.dead:
			break
	check(sim.player.dead, "ordinary movement reaches the shipped stage hazard")
	history.begin(sim.tick_count)
	var destination_x: float = history.frame_at(1.0).player.x
	check(destination_x > start_x + 10.0, "safe recovery keeps progress instead of returning to spawn")
	for tick: int in 90:
		sim.step(SimInput.new())
	check(sim.player.dead, "external recovery prevents automatic level reset")
	check(history.recover(sim), "safe snapshot restores successfully")
	check_near(sim.player.x, destination_x)
	check_near(sim.player.vx, 0.0)
	check(sim.level.wires.has(cell), "level changes are restored instead of rebuilt")
	for tick: int in 60:
		sim.step(SimInput.new())
	check(not sim.player.dead, "recovered player survives without immediate input")
	check(history.sample_count() > 1, "recovery retains earlier history for repeated mistakes")


func test_visual_interpolation_is_smooth_and_never_mutates_history() -> void:
	var sim: GameSim = GameSim.new()
	sim.load_level(1, LevelLibrary.shipped_level(1), BossState.Kind.NONE)
	var history: DeathRewind = DeathRewind.new()
	sim.player.x = 100.0
	sim.camera.x = 0.0
	history.capture(sim)
	sim.tick_count += 2
	sim.player.x = 120.0
	sim.camera.x = 20.0
	history.capture(sim)
	var visual: GameSim = history.visual_frame_at(0.485)
	check_near(visual.player.x, 110.0, 0.01)
	check_near(visual.camera.x, 10.0, 0.01)
	visual.player.x = 999.0
	check_near(history.frame_at(0.0).player.x, 120.0, 0.0, "drawing cannot corrupt recovery state")
	check_near(history.visual_frame_at(1.0).player.x, 100.0, 0.0, "playback lands exactly on the saved target")
