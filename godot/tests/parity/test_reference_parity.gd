extends TestCase
## Golden-master test: replays the recorded inputs of every reference trace
## through [GameSim] and compares the state and the sounds after each tick
## with what the web engine produced (see `tools/parity/make_reference.mjs`).

const REFERENCE_DIR: String = "res://tests/parity/reference"
## The reference stores six decimals; allow for that rounding plus a little
## accumulated floating-point noise from the two maths libraries.
const TOLERANCE: float = 2e-5


func test_matches_web_engine() -> void:
	var dir: DirAccess = DirAccess.open(REFERENCE_DIR)
	check(dir != null, "reference directory is missing; run tools/parity/make_reference.mjs")
	if dir == null:
		return
	var files: PackedStringArray = dir.get_files()
	files.sort()
	var replayed: int = 0
	for file_name: String in files:
		if file_name.ends_with(".json.gz"):
			_replay(REFERENCE_DIR.path_join(file_name))
			replayed += 1
	check(replayed > 0, "no reference traces found")


func _replay(path: String) -> void:
	var player: TracePlayer = TracePlayer.new()
	if not player.load_trace(path):
		fail("%s: cannot read trace" % path.get_file())
		return

	while not player.is_finished():
		player.advance()
		var actual: PackedFloat64Array = player.snapshot()
		var expected: Array = player.states[player.tick - 1]
		for i: int in expected.size():
			check_count += 1
			var want: float = expected[i]
			if absf(actual[i] - want) > TOLERANCE * maxf(1.0, absf(want)):
				fail("%s tick %d: %s expected %s, got %s" % [
					player.trace_name, player.tick, player.fields[i], want, actual[i],
				])
				return

		check_count += 1
		var want_sounds: String = player.sounds[player.tick - 1]
		if player.heard != want_sounds:
			fail("%s tick %d: sounds expected \"%s\", got \"%s\"" % [
				player.trace_name, player.tick, want_sounds, player.heard,
			])
			return
