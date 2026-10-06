class_name ToneSynth
extends RefCounted
## Offline synthesiser that renders oscillator voices into an [AudioStreamWAV].
##
## The game has no recorded audio: every sound is a short oscillator sweep,
## rendered once to PCM and then played like any other sample.

enum Wave { SINE, TRIANGLE, SAWTOOTH }
enum Ramp { SET, LINEAR, EXPONENTIAL }

const MIX_RATE: int = 44100
## Every voice ends with a short fade so that cutting it off cannot click.
const FADE_OUT_SEC: float = 0.004


## A value that changes over time, described the way Web Audio parameters
## are: a list of points that are jumped to or ramped toward.
class Automation:
	extends RefCounted

	var _times: PackedFloat64Array = PackedFloat64Array()
	var _values: PackedFloat64Array = PackedFloat64Array()
	var _ramps: PackedInt32Array = PackedInt32Array()
	var _cursor: int = 0

	func set_at(time: float, value: float) -> Automation:
		return _add(time, value, Ramp.SET)

	func linear_to(time: float, value: float) -> Automation:
		return _add(time, value, Ramp.LINEAR)

	func exponential_to(time: float, value: float) -> Automation:
		return _add(time, value, Ramp.EXPONENTIAL)

	## Value at [param time]. Times must not decrease between calls; call
	## [method rewind] to start over.
	func value_at(time: float) -> float:
		var count: int = _times.size()
		if count == 0:
			return 0.0
		while _cursor + 1 < count and _times[_cursor + 1] <= time:
			_cursor += 1
		var next: int = _cursor + 1
		if time < _times[_cursor] or next >= count or _ramps[next] == Ramp.SET:
			return _values[_cursor]
		var from_value: float = _values[_cursor]
		var to_value: float = _values[next]
		var span: float = _times[next] - _times[_cursor]
		var f: float = clampf((time - _times[_cursor]) / span, 0.0, 1.0) if span > 0.0 else 1.0
		if _ramps[next] == Ramp.EXPONENTIAL and from_value > 0.0 and to_value > 0.0:
			return from_value * pow(to_value / from_value, f)
		return from_value + (to_value - from_value) * f

	func rewind() -> void:
		_cursor = 0

	func _add(time: float, value: float, ramp: Ramp) -> Automation:
		_times.append(time)
		_values.append(value)
		_ramps.append(int(ramp))
		return self


## One oscillator with its own pitch and loudness envelopes. Envelope times
## are relative to [member start].
class Voice:
	extends RefCounted

	var wave: Wave = Wave.SINE
	var start: float = 0.0
	var duration: float = 0.1
	var frequency: Automation = Automation.new()
	var gain: Automation = Automation.new()


static func make_voice(wave: Wave, start: float, duration: float) -> Voice:
	var voice: Voice = Voice.new()
	voice.wave = wave
	voice.start = start
	voice.duration = duration
	return voice


## Mixes [param voices] into a mono 16-bit stream.
static func render(voices: Array[Voice]) -> AudioStreamWAV:
	var length_sec: float = 0.0
	for voice: Voice in voices:
		length_sec = maxf(length_sec, voice.start + voice.duration)
	var sample_count: int = ceili(length_sec * float(MIX_RATE))
	var mix: PackedFloat32Array = PackedFloat32Array()
	mix.resize(sample_count)

	var rate: float = float(MIX_RATE)
	var fade_samples: int = maxi(1, int(FADE_OUT_SEC * rate))
	for voice: Voice in voices:
		var first: int = int(voice.start * rate)
		var last: int = mini(sample_count, int((voice.start + voice.duration) * rate))
		var phase: float = 0.0
		voice.frequency.rewind()
		voice.gain.rewind()
		for n: int in range(first, last):
			var t: float = float(n - first) / rate
			phase += voice.frequency.value_at(t) / rate
			var sample: float = sample_wave(voice.wave, phase) * voice.gain.value_at(t)
			var remaining: int = last - 1 - n
			if remaining < fade_samples:
				sample *= float(remaining) / float(fade_samples)
			mix[n] += sample
	return to_stream(mix)


## Oscillator output in [-1, 1] for a phase measured in cycles.
static func sample_wave(wave: Wave, phase: float) -> float:
	match wave:
		Wave.TRIANGLE:
			return 4.0 * absf(fposmod(phase + 0.75, 1.0) - 0.5) - 1.0
		Wave.SAWTOOTH:
			return 2.0 * fposmod(phase + 0.5, 1.0) - 1.0
	return sin(TAU * phase)


static func to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


## A few cycles of a waveform that loop seamlessly, for voices that are
## pitched by changing the playback speed. The sawtooth is band-limited so it
## stays clean when played above its base frequency.
static func render_loop(wave: Wave, base_frequency: float, cycles: int) -> AudioStreamWAV:
	var samples_per_cycle: int = roundi(float(MIX_RATE) / base_frequency)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(samples_per_cycle * cycles)
	for n: int in samples.size():
		var phase: float = float(n) / float(samples_per_cycle)
		if wave == Wave.SAWTOOTH:
			var value: float = 0.0
			for harmonic: int in range(1, 25):
				var sign_value: float = 1.0 if harmonic % 2 == 1 else -1.0
				value += sign_value * sin(TAU * float(harmonic) * phase) / float(harmonic)
			samples[n] = value * (2.0 / PI)
		else:
			samples[n] = sample_wave(wave, phase)
	var stream: AudioStreamWAV = to_stream(samples)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = samples.size()
	return stream
