extends Node
## Remembers which levels the player has cleared (autoload `Progress`).
##
## Stored in the file named by [method SavePaths.progress_file]. Clearing a level never locks or unlocks
## anything; it only lets the level select show what has been beaten.

signal changed

var _cleared: Dictionary[int, bool] = {}


func _ready() -> void:
	var config: ConfigFile = ConfigFile.new()
	if SafeConfig.load_file(config, SavePaths.progress_file()) != OK:
		return
	var stored: Variant = config.get_value("progress", "cleared", PackedInt32Array())
	if stored is PackedInt32Array:
		var slots: PackedInt32Array = stored
		for slot: int in slots:
			if slot >= 1 and slot <= GameConstants.SLOT_COUNT:
				_cleared[slot] = true


func is_cleared(slot: int) -> bool:
	return _cleared.has(slot)


func cleared_count() -> int:
	return _cleared.size()


func mark_cleared(slot: int) -> void:
	if _cleared.has(slot) or slot < 1 or slot > GameConstants.SLOT_COUNT:
		return
	_cleared[slot] = true
	_save()
	changed.emit()


func _save() -> void:
	var slots: PackedInt32Array = PackedInt32Array()
	for slot: int in _cleared:
		slots.append(slot)
	slots.sort()
	var config: ConfigFile = ConfigFile.new()
	config.set_value("progress", "cleared", slots)
	DirAccess.make_dir_recursive_absolute(SavePaths.root())
	var error: Error = SafeConfig.save_file(config, SavePaths.progress_file())
	if error != OK:
		push_warning("Progress: could not save (%s)" % error_string(error))
