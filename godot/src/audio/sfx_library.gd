class_name SfxLibrary
extends RefCounted
## Recipes for the game's sound effects.
##
## Frequencies, envelopes and durations are those of the web version's
## `audio.ts`.

const _W := ToneSynth.Wave


## Builds the stream for [param id]. [param param] is the devour progress
## (0..1) for [constant Sfx.Id.DEVOUR_PULSE] and unused otherwise.
static func build(id: Sfx.Id, param: float = 0.0) -> AudioStreamWAV:
	match id:
		Sfx.Id.JUMP:
			var voice: ToneSynth.Voice = ToneSynth.make_voice(_W.TRIANGLE, 0.0, 0.13)
			voice.frequency.set_at(0.0, 140.0).exponential_to(0.12, 360.0)
			voice.gain.set_at(0.0, 0.12).exponential_to(0.12, 0.01)
			return ToneSynth.render([voice])
		Sfx.Id.EAT:
			var voice: ToneSynth.Voice = ToneSynth.make_voice(_W.SINE, 0.0, 0.19)
			voice.frequency.set_at(0.0, 240.0).exponential_to(0.18, 100.0)
			voice.gain.set_at(0.0, 0.16).exponential_to(0.18, 0.01)
			return ToneSynth.render([voice])
		Sfx.Id.SHOOT:
			var voice: ToneSynth.Voice = ToneSynth.make_voice(_W.SAWTOOTH, 0.0, 0.15)
			voice.frequency.set_at(0.0, 550.0).exponential_to(0.14, 100.0)
			voice.gain.set_at(0.0, 0.08).exponential_to(0.14, 0.01)
			return ToneSynth.render([voice])
		Sfx.Id.BOUNCE:
			var voice: ToneSynth.Voice = ToneSynth.make_voice(_W.TRIANGLE, 0.0, 0.23)
			voice.frequency.set_at(0.0, 160.0).linear_to(0.08, 340.0).exponential_to(0.22, 180.0)
			voice.gain.set_at(0.0, 0.16).exponential_to(0.22, 0.01)
			return ToneSynth.render([voice])
		Sfx.Id.HURT:
			var voice: ToneSynth.Voice = ToneSynth.make_voice(_W.SAWTOOTH, 0.0, 0.39)
			voice.frequency.set_at(0.0, 160.0).linear_to(0.35, 40.0)
			voice.gain.set_at(0.0, 0.15).exponential_to(0.38, 0.01)
			return ToneSynth.render([voice])
		Sfx.Id.WIN:
			# A rising arpeggio, one note every 80 ms.
			var notes: PackedFloat64Array = [261.63, 329.63, 392.00, 523.25, 659.25, 783.99, 1046.50]
			var voices: Array[ToneSynth.Voice] = []
			for i: int in notes.size():
				var voice: ToneSynth.Voice = ToneSynth.make_voice(_W.TRIANGLE, float(i) * 0.08, 0.2)
				voice.frequency.set_at(0.0, notes[i])
				voice.gain.set_at(0.0, 0.08).exponential_to(0.18, 0.01)
				voices.append(voice)
			return ToneSynth.render(voices)
		Sfx.Id.LAND:
			var voice: ToneSynth.Voice = ToneSynth.make_voice(_W.SINE, 0.0, 0.09)
			voice.frequency.set_at(0.0, 95.0).exponential_to(0.08, 45.0)
			voice.gain.set_at(0.0, 0.08).exponential_to(0.08, 0.01)
			return ToneSynth.render([voice])
		Sfx.Id.DEVOUR_PULSE:
			# Rises in pitch and loudness as the boss is consumed.
			var voice: ToneSynth.Voice = ToneSynth.make_voice(_W.SINE, 0.0, 0.26)
			voice.frequency.set_at(0.0, 220.0 + param * 150.0).exponential_to(0.25, 440.0 + param * 440.0)
			voice.gain.set_at(0.0, 0.015 + param * 0.05).exponential_to(0.25, 0.001)
			return ToneSynth.render([voice])
	return null


## The boss music's percussive tick: a fast downward thump.
static func build_drum_tick() -> AudioStreamWAV:
	var voice: ToneSynth.Voice = ToneSynth.make_voice(_W.TRIANGLE, 0.0, 0.07)
	voice.frequency.set_at(0.0, 80.0).exponential_to(0.05, 10.0)
	voice.gain.set_at(0.0, 0.02).exponential_to(0.06, 0.001)
	return ToneSynth.render([voice])
