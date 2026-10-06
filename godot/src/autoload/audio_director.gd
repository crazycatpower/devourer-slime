extends Node
## Plays sound effects and music (autoload `AudioDirector`).
##
## The simulation only names the sounds it wants (see [Sfx]); this node owns
## the streams, the players and the mixer state, and follows [Settings] for
## volume and mute.

const SFX_POLYPHONY: int = 12
const SFX_BUS: StringName = &"SFX"
## The devour pulse is requested every tick while it applies; this spaces the
## actual sounds out.
const PULSE_INTERVAL_MSEC: int = 100
const PULSE_STEPS: int = 16

var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _streams: Dictionary[int, AudioStreamWAV] = {}
var _cue_streams: Dictionary[int, AudioStreamWAV] = {}
var _pulse_streams: Dictionary[int, AudioStreamWAV] = {}
var _last_pulse_msec: int = -PULSE_INTERVAL_MSEC
var _music: MusicSequencer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bus: StringName = SFX_BUS if AudioServer.get_bus_index(SFX_BUS) >= 0 else &"Master"
	for _i: int in SFX_POLYPHONY:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = bus
		add_child(player)
		_players.append(player)

	# Render the fixed effects up front so the first use never hitches.
	for id: int in Sfx.Id.values():
		if id != Sfx.Id.DEVOUR_PULSE:
			_streams[id] = SfxLibrary.build(id as Sfx.Id)
	for cue: int in SfxLibrary.Cue.values():
		_cue_streams[cue] = SfxLibrary.build_cue(cue as SfxLibrary.Cue)

	_music = MusicSequencer.new()
	_music.name = "Music"
	add_child(_music)

	Settings.audio_changed.connect(_apply_volume)
	_apply_volume()


## Plays a sound effect, optionally after [param delay_sec]. [param param]
## is the devour progress for [constant Sfx.Id.DEVOUR_PULSE].
func play_sfx(id: Sfx.Id, param: float = 0.0, delay_sec: float = 0.0) -> void:
	if Settings.muted:
		return
	if delay_sec > 0.0:
		get_tree().create_timer(delay_sec).timeout.connect(play_sfx.bind(id, param, 0.0))
		return
	var stream: AudioStreamWAV
	if id == Sfx.Id.DEVOUR_PULSE:
		var now: int = Time.get_ticks_msec()
		if now - _last_pulse_msec < PULSE_INTERVAL_MSEC:
			return
		_last_pulse_msec = now
		stream = _pulse_stream(param)
	else:
		stream = _streams.get(id)
	_play_stream(stream)


## Plays one of the slime's presentation-only reaction sounds.
func play_cue(cue: SfxLibrary.Cue) -> void:
	if Settings.muted:
		return
	var stream: AudioStreamWAV = _cue_streams.get(cue)
	_play_stream(stream)


func _play_stream(stream: AudioStreamWAV) -> void:
	if stream == null:
		return
	var player: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = stream
	player.play()


## Starts or stops the background music. It only plays while a level is
## being played and the sound is on.
func set_music_playing(playing: bool) -> void:
	if playing and not Settings.muted:
		_music.start()
	else:
		_music.stop()


## Tells the music which mood to play: boss fights are tenser and speed up as
## the boss fills.
func set_music_context(is_boss: bool, boss_filled_count: int) -> void:
	_music.is_boss = is_boss
	_music.boss_filled_count = boss_filled_count


func _pulse_stream(progress: float) -> AudioStreamWAV:
	var step: int = clampi(roundi(progress * float(PULSE_STEPS)), 0, PULSE_STEPS)
	if not _pulse_streams.has(step):
		_pulse_streams[step] = SfxLibrary.build(
			Sfx.Id.DEVOUR_PULSE, float(step) / float(PULSE_STEPS)
		)
	return _pulse_streams[step]


func _apply_volume() -> void:
	var master: int = AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_volume_db(master, linear_to_db(Settings.volume))
	AudioServer.set_bus_mute(master, Settings.muted or Settings.volume <= 0.0)
	if Settings.muted:
		_music.stop()
