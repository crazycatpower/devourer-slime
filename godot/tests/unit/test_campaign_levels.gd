extends "res://tests/unit/test_world4_levels.gd"
## Replays intended campaign routes through the actual input/physics systems.

func test_campaign_routes_and_layouts() -> void:
	var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/campaign_solutions.json"))
	var hashes: Array[int] = []
	for key: String in routes:
		var slot: int = key.to_int()
		if slot == 10:
			continue # Steel chase has its own input-only completion regression.
		var rows: PackedStringArray = LevelLibrary.built_in_rows(slot)
		check_eq(LevelValidator.problem_with(rows), "", "valid stage %d" % slot)
		var data: LevelData = LevelCodec.decode(rows)
		check(not hashes.has(data.grid.checksum()), "distinct stage %d" % slot)
		hashes.append(data.grid.checksum())
		for enabled: bool in [false, true]:
			var sim: GameSim = GameSim.new()
			sim.rng.set_seed(7)
			sim.load_level(slot, data, BossState.Kind.NONE)
			sim.bullet_time_enabled = enabled
			for _i: int in 15:
				sim.step(SimInput.new())
			for action: Dictionary in routes[key]:
				if sim.player.dead or sim.player.won:
					break
				_execute(sim, action)
				if sim.player.dead:
					print("campaign death ",slot," action ",action," pos ",sim.player.x,",",sim.player.y)
			check(not sim.player.dead and sim.player.won, "stage %d bullet=%s completes x=%.1f y=%.1f" % [slot, enabled, sim.player.x, sim.player.y])
	for slot: int in range(1, 51):
		check(not LevelLibrary.is_placeholder(slot), "stage %d populated" % slot)


func test_original_worlds_match_layouts() -> void:
	for slot: int in range(11, 40):
		if slot in [20, 30, 34, 35, 36, 37]:
			continue
		check_eq(LevelLibrary.built_in_rows(slot), Fixtures.legacy_rows(slot), "restored stage %d" % slot)
