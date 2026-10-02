extends TestCase
## The deterministic random generator and the offline synthesiser.


func test_random_sequence_is_minstd() -> void:
	var rng: SimRandom = SimRandom.new(1)
	check_near(rng.next_float(), 48271.0 / 2147483647.0, 0.0)
	check_near(rng.next_float(), 182605794.0 / 2147483647.0, 0.0)
	check_eq(rng.draw_count, 2)


func test_random_is_reproducible_and_in_range() -> void:
	var a: SimRandom = SimRandom.new(12345)
	var b: SimRandom = SimRandom.new(12345)
	for _i: int in 2000:
		var value: float = a.next_float()
		check_near(value, b.next_float(), 0.0)
		check(value > 0.0 and value < 1.0, "value in (0, 1)")
	var rng: SimRandom = SimRandom.new(9)
	var seen: Dictionary[int, bool] = {}
	for _i: int in 500:
		var n: int = rng.next_below(4)
		check(n >= 0 and n < 4, "next_below stays in range")
		seen[n] = true
	check_eq(seen.size(), 4, "every value turns up")


func test_random_seed_zero_is_usable() -> void:
	var rng: SimRandom = SimRandom.new(1)
	rng.set_seed(0)
	check(rng.next_float() > 0.0)


func test_automation_curves() -> void:
	var ramp: ToneSynth.Automation = ToneSynth.Automation.new()
	ramp.set_at(0.0, 0.0).linear_to(1.0, 10.0).exponential_to(2.0, 1000.0).set_at(3.0, 5.0)
	check_near(ramp.value_at(0.0), 0.0)
	check_near(ramp.value_at(0.5), 5.0, 1e-9, "linear midpoint")
	check_near(ramp.value_at(1.0), 10.0)
	check_near(ramp.value_at(1.5), 100.0, 1e-9, "exponential midpoint is the geometric mean")
	check_near(ramp.value_at(2.5), 1000.0, 1e-9, "holds until the next jump")
	check_near(ramp.value_at(3.0), 5.0)
	check_near(ramp.value_at(9.0), 5.0, 1e-9, "holds the last value")
	ramp.rewind()
	check_near(ramp.value_at(0.5), 5.0, 1e-9, "usable again after rewind")


func test_waveforms() -> void:
	check_near(ToneSynth.sample_wave(ToneSynth.Wave.SINE, 0.25), 1.0)
	check_near(ToneSynth.sample_wave(ToneSynth.Wave.TRIANGLE, 0.0), 0.0)
	check_near(ToneSynth.sample_wave(ToneSynth.Wave.TRIANGLE, 0.25), 1.0)
	check_near(ToneSynth.sample_wave(ToneSynth.Wave.TRIANGLE, 0.75), -1.0)
	check_near(ToneSynth.sample_wave(ToneSynth.Wave.SAWTOOTH, 0.0), 0.0)
	check_near(ToneSynth.sample_wave(ToneSynth.Wave.SAWTOOTH, 0.25), 0.5)
	for i: int in 100:
		var phase: float = float(i) * 0.137
		for wave: int in ToneSynth.Wave.values():
			var value: float = ToneSynth.sample_wave(wave as ToneSynth.Wave, phase)
			check(value >= -1.0 and value <= 1.0, "wave stays in [-1, 1]")


func test_every_sound_effect_renders() -> void:
	var expected_seconds: Dictionary[int, float] = {
		Sfx.Id.JUMP: 0.13, Sfx.Id.EAT: 0.19, Sfx.Id.SHOOT: 0.15, Sfx.Id.BOUNCE: 0.23,
		Sfx.Id.HURT: 0.39, Sfx.Id.WIN: 0.68, Sfx.Id.LAND: 0.09, Sfx.Id.DEVOUR_PULSE: 0.26,
	}
	for id: int in Sfx.Id.values():
		var stream: AudioStreamWAV = SfxLibrary.build(id as Sfx.Id, 0.5)
		check(stream != null, "sound %d renders" % id)
		if stream == null:
			continue
		check_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS)
		check_eq(stream.mix_rate, ToneSynth.MIX_RATE)
		check_near(stream.get_length(), expected_seconds[id], 0.002, "length of sound %d" % id)
		check(_peak(stream) > 100, "sound %d is not silent" % id)
		check(_peak(stream) < 32767, "sound %d does not clip" % id)
		check_eq(absi(stream.data.decode_s16(stream.data.size() - 2)), 0, "sound %d ends at zero" % id)


func test_loop_is_seamless() -> void:
	for wave: int in ToneSynth.Wave.values():
		var stream: AudioStreamWAV = ToneSynth.render_loop(wave as ToneSynth.Wave, 100.0, 4)
		check_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)
		check_eq(stream.loop_end, 1764, "four cycles of 441 samples")
		# The sample after the last one is the first one: the jump across the
		# loop point must be no bigger than between neighbouring samples.
		var first: int = stream.data.decode_s16(0)
		var second: int = stream.data.decode_s16(2)
		var last: int = stream.data.decode_s16(stream.data.size() - 2)
		var before_last: int = stream.data.decode_s16(stream.data.size() - 4)
		var step: int = maxi(absi(second - first), absi(last - before_last))
		if wave != ToneSynth.Wave.SAWTOOTH:
			check(absi(first - last) <= step * 2 + 4, "wave %d loops without a click" % wave)


func _peak(stream: AudioStreamWAV) -> int:
	var peak: int = 0
	for i: int in range(0, stream.data.size(), 2):
		peak = maxi(peak, absi(stream.data.decode_s16(i)))
	return peak
