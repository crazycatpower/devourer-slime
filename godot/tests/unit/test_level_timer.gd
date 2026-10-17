extends TestCase


func test_first_action_pause_and_finish() -> void:
	var clock: LevelTimer = LevelTimer.new()
	clock.advance(10.0, false, true)
	check_eq(clock.seconds, 0.0, "loading and waiting do not count")
	clock.advance(0.25, true, true)
	clock.advance(2.0, false, true, true)
	check_eq(clock.seconds, 0.25, "pause does not count")
	clock.advance(0.5, false, true)
	clock.finish()
	clock.advance(5.0, true, true)
	check_eq(clock.seconds, 0.75, "exit animation does not count")


func test_speed_changes_make_whole_attempt_practice() -> void:
	var clock: LevelTimer = LevelTimer.new()
	clock.advance(1.0, true, true)
	clock.advance(0.5, false, false)
	clock.advance(0.5, false, true)
	check(not clock.ranked, "restoring normal speed cannot restore eligibility")
	check_eq(clock.seconds, 2.0, "time follows real play time, not simulation speed")
	clock.reset()
	check(clock.ranked and not clock.started and not clock.finished)
	check_eq(clock.seconds, 0.0)
	clock.reset(false)
	clock.advance(1.0, true, true)
	check(not clock.ranked, "editor testing remains practice")


func test_rewind_does_not_restore_run_clock() -> void:
	var clock: LevelTimer = LevelTimer.new()
	var sim: GameSim = GameSim.new()
	sim.load_level(11, LevelLibrary.built_in_level(11), BossState.Kind.NONE)
	var rewind: DeathRewind = DeathRewind.new()
	rewind.capture(sim)
	clock.advance(3.0, true, true)
	rewind.begin(sim.tick_count)
	clock.advance(0.75, false, true)
	check(rewind.recover(sim))
	check_eq(clock.seconds, 3.75, "death and recovery time remain on the clock")


func test_time_format_carries_minutes_and_centiseconds() -> void:
	check_eq(LevelTimer.format_time(0), "00:00.00")
	check_eq(LevelTimer.format_time(59.999), "01:00.00")
	check_eq(LevelTimer.format_time(125.42), "02:05.42")
	check_eq(LevelTimer.format_time(3600), "60:00.00")


func test_records_survive_config_round_trip_and_only_improve() -> void:
	var records: LevelRecords = LevelRecords.new()
	var key: String = LevelRecords.key_for(11, LevelLibrary.built_in_level(11))
	check(records.record(key, 12.5))
	check(not records.record(key, 13.0))
	check(not records.record(key, 12.5))
	check(records.record(key, 11.25))
	var config: ConfigFile = ConfigFile.new()
	config.set_value("progress", "best_times_v1", records.times)
	var restored_config: ConfigFile = ConfigFile.new()
	check_eq(restored_config.parse(config.encode_to_text()), OK)
	var restored: LevelRecords = LevelRecords.new()
	restored.load_data(restored_config.get_value("progress", "best_times_v1"))
	check_eq(restored.best(key), 11.25)
	check_eq(restored.best(LevelRecords.key_for(11, LevelLibrary.built_in_level(31))), 0.0, "different source layout has its own record")


func test_invalid_record_data_is_ignored() -> void:
	var records: LevelRecords = LevelRecords.new()
	records.load_data({"valid": 2.5, "negative": -1, "infinite": INF, "text": "2.5", "": 10, 4: 2})
	check_eq(records.times.size(), 1)
	check_eq(records.best("valid"), 2.5)
