class_name DeathRewind
extends RefCounted
## Bounded history with independently verified safe recovery snapshots.
## Six seconds at 30 samples/sec; no viewport readbacks or full-screen textures.

const CAPACITY: int = 180
const SAMPLE_TICKS: int = 2

var _frames: Array[GameSim] = []
var _last_tick: int = -SAMPLE_TICKS
var _last_grid: LevelGrid
var _grid_hash: int = 0
var _properties: Dictionary[Script, PackedStringArray] = {}
var _safe_frames: Array[GameSim] = []
var _target: GameSim
var _playback: Array[GameSim] = []
var _last_safe_check: int = -12

func clear() -> void:
	_frames.clear()
	_last_tick = -SAMPLE_TICKS
	_last_grid = null
	_grid_hash = 0
	_safe_frames.clear()
	_target = null
	_playback.clear()
	_last_safe_check = -12

func capture(source: GameSim) -> void:
	if source.player.dead or source.player.won or source.tick_count - _last_tick < SAMPLE_TICKS:
		return
	_last_tick = source.tick_count
	var frame: GameSim = GameSim.new()
	frame.slot = source.slot
	frame.boss_kind = source.boss_kind
	frame.boss_intro_seen = source.boss_intro_seen
	frame.tick_count = source.tick_count
	frame.bullet_time_enabled = source.bullet_time_enabled
	frame.mechanisms_enabled = source.mechanisms_enabled
	# Reuse immutable terrain snapshots while the grid has not changed.
	var grid_hash: int = hash([source.level.content_hash(), source.level.signal_revision])
	if _last_grid == null or grid_hash != _grid_hash:
		_last_grid = source.level.duplicate_grid()
		_grid_hash = grid_hash
	frame.level = _last_grid
	frame.player = _copy(source.player)
	frame.camera = _copy(source.camera)
	frame.boss = _copy(source.boss)
	frame.input = _copy(source.input)
	frame.projectiles = _copy(source.projectiles)
	frame.falling_blocks = _copy(source.falling_blocks)
	frame.particles = _copy(source.particles)
	frame.tnt_charges = _copy(source.tnt_charges)
	frame.tile_motions = _copy(source.tile_motions)
	frame.powered_cells = source.powered_cells.duplicate()
	frame.sliding_cells = source.sliding_cells.duplicate()
	frame.ceiling_slides = source.ceiling_slides.duplicate()
	frame.rng = _copy(source.rng)
	frame.fx_rng = _copy(source.fx_rng)
	_frames.append(frame)
	if _frames.size() > CAPACITY:
		_frames.pop_front()
	if source.tick_count - _last_safe_check >= 12:
		_last_safe_check = source.tick_count
		if is_safe(frame):
			_safe_frames.append(frame)
			if _safe_frames.size() > 32:
				_safe_frames.pop_front()

## Require standing room and a neutral-input future with no imminent hazard.
## Probe a copy, so moving bosses, charges and falling supports are included.
func is_safe(frame: GameSim) -> bool:
	if frame.player.dead or frame.player.won:
		return false
	if not frame.player.grounded and not _safe_frames.is_empty():
		return false
	var body: Rect2 = Rect2(frame.player.x, frame.player.y, frame.player.w, frame.player.h).grow(10.0)
	for row: int in range(floori(body.position.y / Tile.SIZE), floori(body.end.y / Tile.SIZE) + 1):
		for col: int in range(floori(body.position.x / Tile.SIZE), floori(body.end.x / Tile.SIZE) + 1):
			var tile: int = frame.level.get_cell(row, col)
			if Tile.is_spike(tile) and Tile.hazard_hits(body.position.x, body.position.y, body.size.x, body.size.y, row, col, tile):
				return false
	var probe: GameSim = GameSim.new()
	_restore(frame, probe)
	probe.external_death_recovery = true
	for tick: int in 90:
		probe.step(SimInput.new())
		if probe.player.dead or probe.player.won:
			return false
	return probe.player.grounded and absf(probe.player.x - frame.player.x) < 12.0 and absf(probe.player.y - frame.player.y) < Tile.SIZE

func begin(death_tick: int) -> void:
	_target = null
	for index: int in range(_safe_frames.size() - 1, -1, -1):
		if _safe_frames[index].tick_count <= death_tick - 24:
			_target = _safe_frames[index]
			break
	if _target == null and not _safe_frames.is_empty():
		_target = _safe_frames[0]
	# An unusual authored spawn may have no safe standing point yet. Keep the
	# earliest live state instead of silently rebuilding the level.
	if _target == null and not _frames.is_empty():
		_target = _frames[0]
	_playback.clear()
	if _target != null:
		_playback.append(_target)
		for frame: GameSim in _frames:
			if frame.tick_count > _target.tick_count:
				_playback.append(frame)

func recover(destination: GameSim) -> bool:
	if _target == null:
		return false
	_restore(_target, destination)
	# Keep the earlier branch: a second mistake must still have older safe
	# points available. Discard only the future that has just been undone.
	var restored_tick: int = destination.tick_count
	while not _frames.is_empty() and _frames[-1].tick_count > restored_tick:
		_frames.pop_back()
	while not _safe_frames.is_empty() and _safe_frames[-1].tick_count > restored_tick:
		_safe_frames.pop_back()
	_last_tick = restored_tick
	_last_safe_check = restored_tick
	_last_grid = null
	_target = null
	_playback.clear()
	return true

func _restore(frame: GameSim, destination: GameSim) -> void:
	for property: StringName in [&"slot", &"boss_kind", &"boss_intro_seen", &"tick_count", &"bullet_time_enabled", &"mechanisms_enabled", &"player", &"camera", &"boss", &"projectiles", &"falling_blocks", &"particles", &"tnt_charges", &"tile_motions", &"powered_cells", &"sliding_cells", &"ceiling_slides", &"rng", &"fx_rng"]:
		destination.set(property, _copy(frame.get(property)))
	destination.level = frame.level.duplicate_grid()
	destination.signal_grid = null
	destination.signal_revision = -1
	destination.signal_sources.clear()
	destination.signal_detectors.clear()
	destination.death_timer = 0
	destination.input = SimInput.new()
	destination.player.dead = false
	destination.player.vx = 0.0
	destination.player.vy = 0.0
	destination.player.in_bullet_time = false
	destination.player.prev_x = destination.player.x
	destination.player.prev_y = destination.player.y
	destination.player.jump_buffer = 0
	destination.player.has_eating_target = false
	destination.player.eating_progress = 0.0
	destination.player.eating_charge = null
	destination.camera.shake = 0.0
	destination.camera.prev_x = destination.camera.x
	destination.camera.prev_y = destination.camera.y

## Interpolate a presentation copy, never the saved state used for recovery.
## Use simulation timestamps so sparse older points do not cause camera jumps.
func visual_frame_at(progress: float) -> GameSim:
	var frames: Array[GameSim] = _playback if not _playback.is_empty() else _frames
	if frames.is_empty():
		return null
	var eased: float = smoothstep(0.05, 0.92, clampf(progress, 0.0, 1.0))
	var time: float = lerpf(float(frames[-1].tick_count), float(frames[0].tick_count), eased)
	if time <= float(frames[0].tick_count):
		return frames[0]
	if time >= float(frames[-1].tick_count):
		return frames[-1]
	var index: int = frames.size() - 1
	while index > 0 and float(frames[index - 1].tick_count) > time:
		index -= 1
	var newer: GameSim = frames[index]
	var older: GameSim = frames[maxi(0, index - 1)]
	var weight: float = clampf((time - float(older.tick_count)) / maxf(1.0, float(newer.tick_count - older.tick_count)), 0.0, 1.0)
	var display: GameSim = GameSim.new()
	for property: StringName in [&"slot", &"boss_kind", &"tick_count", &"mechanisms_enabled", &"level", &"projectiles", &"falling_blocks", &"particles", &"tnt_charges", &"tile_motions", &"powered_cells", &"sliding_cells", &"ceiling_slides"]:
		display.set(property, newer.get(property))
	display.player = _copy(newer.player)
	display.camera = _copy(newer.camera)
	display.boss = _copy(newer.boss)
	for pair: Array in [[display.player, older.player, newer.player], [display.camera, older.camera, newer.camera], [display.boss, older.boss, newer.boss]]:
		var subject: RefCounted = pair[0]
		var before: RefCounted = pair[1]
		var after: RefCounted = pair[2]
		for axis: StringName in [&"x", &"y"]:
			var from: float = before.get(axis)
			var to: float = after.get(axis)
			subject.set(axis, lerpf(from, to, weight))
	return display

func frame_at(progress: float) -> GameSim:
	var frames: Array[GameSim] = _playback if not _playback.is_empty() else _frames
	if frames.is_empty():
		return null
	var offset: int = roundi(clampf(progress, 0.0, 1.0) * float(frames.size() - 1))
	return frames[frames.size() - 1 - offset]

func sample_count() -> int:
	return _frames.size()

## Only plain simulation records enter this copier: no nodes, signals or assets.
## Typed containers retain their types, including the mechanism boss records.
func _copy(value: Variant) -> Variant:
	if typeof(value) in [TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY]:
		@warning_ignore("unsafe_method_access")
		return value.duplicate()
	if value is Array:
		var result: Array = (value as Array).duplicate()
		for index: int in result.size():
			result[index] = _copy(result[index])
		return result
	if value is Dictionary:
		var result: Dictionary = (value as Dictionary).duplicate()
		for key: Variant in result:
			result[key] = _copy(result[key])
		return result
	if value is RefCounted:
		var source: RefCounted = value
		var script: GDScript = source.get_script() as GDScript
		var result: RefCounted = script.new()
		if not _properties.has(script):
			var names: PackedStringArray = PackedStringArray()
			for property: Dictionary in source.get_property_list():
				var usage: int = property.usage
				if usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
					var property_name: String = property.name
					names.append(property_name)
			_properties[script] = names
		for property_name: String in _properties[script]:
			result.set(property_name, _copy(source.get(property_name)))
		return result
	# Numeric/vector values are already values.
	return value
