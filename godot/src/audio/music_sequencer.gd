class_name MusicSequencer
extends Node
## Procedural background music: slow cave pads with a sparse arpeggio, and a
## tenser, faster variant for boss fights that speeds up as the boss fills.
##
## Notes are looping single-waveform samples pitched by playback speed, with
## their loudness envelope applied every frame. The chords, scales and
## envelopes are those of the web version's `audio.ts`.

const BEAT_SEC: float = 0.28
const BASE_FREQUENCY: float = 100.0
const VOICE_COUNT: int = 20
const SILENCE: float = 0.001
const RELEASE_SEC: float = 0.08
const BUS: StringName = &"Music"

const NOTES_PER_CHORD: int = 4
const CHORDS_PER_PROGRESSION: int = 4
# Four chords of four notes each, stored flat. (A nested array literal in a
# typed constant is not converted and reads back as zeros.)
const _CAVE_CHORDS: PackedFloat64Array = [
	87.31, 104.82, 130.81, 174.61,  # F minor
	69.30, 87.31, 103.83, 138.59,  # Db major
	77.78, 98.00, 116.54, 155.56,  # C minor
	58.27, 73.42, 87.31, 116.54,  # Bb minor
]
const _BOSS_CHORDS: PackedFloat64Array = [
	98.00, 116.54, 146.83, 196.00,  # G minor
	103.83, 123.47, 155.56, 207.65,  # Ab minor
	98.00, 116.54, 138.59, 196.00,  # G diminished
	103.83, 130.81, 155.56, 207.65,  # Ab major
]
const _CAVE_SCALE: PackedFloat64Array = [174.61, 196.00, 207.65, 233.08, 261.63, 311.13, 349.23]
const _BOSS_SCALE: PackedFloat64Array = [196.00, 220.00, 246.94, 293.66, 329.63, 392.00, 440.00]


## One sounding note.
class NoteVoice:
	extends RefCounted
	var player: AudioStreamPlayer
	var active: bool = false
	var age: float = 0.0
	var attack: float = 0.0
	var peak: float = 0.0
	## Age at which the note has decayed to silence.
	var decay_end: float = 1.0
	var stop_at: float = 1.0
	## Set while a cut-off note fades out.
	var releasing: bool = false
	var release_from: float = 0.0
	var release_age: float = 0.0

	func level() -> float:
		if age < attack:
			return peak * age / attack
		var f: float = clampf((age - attack) / maxf(decay_end - attack, 0.001), 0.0, 1.0)
		return peak * pow(SILENCE / peak, f)


var is_boss: bool = false
var boss_filled_count: int = 0

var _playing: bool = false
var _clock: float = 0.0
var _next_beat_time: float = 0.0
var _beat_index: int = 0
var _voices: Array[NoteVoice] = []
var _loops: Dictionary[int, AudioStreamWAV] = {}
var _drum_tick: AudioStreamWAV
var _drum_player: AudioStreamPlayer


func _ready() -> void:
	var bus: StringName = BUS if AudioServer.get_bus_index(BUS) >= 0 else &"Master"
	for wave: int in [ToneSynth.Wave.SINE, ToneSynth.Wave.TRIANGLE, ToneSynth.Wave.SAWTOOTH]:
		_loops[wave] = ToneSynth.render_loop(wave as ToneSynth.Wave, BASE_FREQUENCY, 4)
	_drum_tick = SfxLibrary.build_drum_tick()
	for _i: int in VOICE_COUNT:
		var voice: NoteVoice = NoteVoice.new()
		voice.player = AudioStreamPlayer.new()
		voice.player.bus = bus
		add_child(voice.player)
		_voices.append(voice)
	_drum_player = AudioStreamPlayer.new()
	_drum_player.bus = bus
	_drum_player.stream = _drum_tick
	add_child(_drum_player)


func is_playing() -> bool:
	return _playing


func start() -> void:
	if _playing:
		return
	_playing = true
	_clock = 0.0
	_next_beat_time = 0.0
	_beat_index = 0


## Stops scheduling and fades out whatever is still sounding.
func stop() -> void:
	if not _playing:
		return
	_playing = false
	for voice: NoteVoice in _voices:
		if voice.active and not voice.releasing:
			voice.releasing = true
			voice.release_from = voice.level()
			voice.release_age = 0.0


func _process(delta: float) -> void:
	if _playing:
		_clock += delta
		# After a long stall (window drag, breakpoint) resume instead of
		# firing every missed beat at once.
		if _clock - _next_beat_time > 0.5:
			_next_beat_time = _clock
		while _next_beat_time <= _clock:
			_schedule_beat()
	for voice: NoteVoice in _voices:
		if voice.active:
			_advance(voice, delta)


## Boss music runs faster in each phase of the fight.
func _speed() -> float:
	if not is_boss:
		return 1.0
	if boss_filled_count >= 7:
		return 2.0
	if boss_filled_count >= 4:
		return 1.5
	return 1.2


func _schedule_beat() -> void:
	var beat: float = BEAT_SEC / _speed()
	var step: int = _beat_index % 16

	# A pad chord every eight steps.
	if step == 0 or step == 8:
		var chords: PackedFloat64Array = _BOSS_CHORDS if is_boss else _CAVE_CHORDS
		var chord: int = floori(float(_beat_index) / 8.0) % CHORDS_PER_PROGRESSION
		var wave: ToneSynth.Wave = ToneSynth.Wave.SAWTOOTH if is_boss else ToneSynth.Wave.SINE
		var peak: float = 0.02 if is_boss else 0.035
		for note: int in NOTES_PER_CHORD:
			_play_note(
				wave, chords[chord * NOTES_PER_CHORD + note], 0.1, peak, beat * 7.5, beat * 8.0
			)

	if is_boss:
		# Driving arpeggio on every other step, plus a drum tick.
		if step % 2 == 0:
			var index: int = (step * 3 + floori(float(_beat_index) / 16.0)) % _BOSS_SCALE.size()
			_play_note(ToneSynth.Wave.TRIANGLE, _BOSS_SCALE[index], 0.0, 0.015, beat * 0.95, beat)
		if step % 4 == 2:
			_drum_player.play()
	elif step % 4 == 0:
		# A slow melodic note on each bar.
		var index: int = (step * 2 + floori(float(_beat_index) / 8.0)) % _CAVE_SCALE.size()
		_play_note(ToneSynth.Wave.TRIANGLE, _CAVE_SCALE[index], 0.1, 0.015, beat * 3.5, beat * 4.0)

	_beat_index += 1
	_next_beat_time += beat


func _play_note(
	wave: ToneSynth.Wave, frequency: float, attack: float, peak: float, decay_end: float, stop_at: float
) -> void:
	var voice: NoteVoice = _free_voice()
	voice.active = true
	voice.releasing = false
	voice.age = 0.0
	voice.attack = attack
	voice.peak = peak
	voice.decay_end = decay_end
	voice.stop_at = stop_at
	voice.player.stream = _loops[wave]
	voice.player.pitch_scale = frequency / BASE_FREQUENCY
	voice.player.volume_linear = voice.level()
	voice.player.play()


## An idle voice, or failing that the one closest to finishing.
func _free_voice() -> NoteVoice:
	var oldest: NoteVoice = _voices[0]
	var oldest_left: float = INF
	for voice: NoteVoice in _voices:
		if not voice.active:
			return voice
		var left: float = voice.stop_at - voice.age
		if left < oldest_left:
			oldest_left = left
			oldest = voice
	return oldest


func _advance(voice: NoteVoice, delta: float) -> void:
	voice.age += delta
	if voice.releasing:
		voice.release_age += delta
		var f: float = voice.release_age / RELEASE_SEC
		if f >= 1.0:
			_silence(voice)
		else:
			voice.player.volume_linear = voice.release_from * (1.0 - f)
		return
	if voice.age >= voice.stop_at:
		_silence(voice)
	else:
		voice.player.volume_linear = voice.level()


func _silence(voice: NoteVoice) -> void:
	voice.active = false
	voice.releasing = false
	voice.player.stop()
