extends Node
## Access to playable levels and the player's custom saves (autoload
## `LevelStore`). A thin, signal-emitting front for [LevelRepository].

## Emitted whenever a custom level is saved, deleted or imported.
signal custom_levels_changed

var _repository: LevelRepository = LevelRepository.new(SavePaths.custom_levels_dir())


func has_custom(slot: int) -> bool:
	return _repository.has_custom(slot)


## True when [param slot] has a save file that cannot be read. Such a slot
## plays its built-in layout.
func is_custom_damaged(slot: int) -> bool:
	return _repository.is_custom_damaged(slot)


## The level [param slot] plays: its custom save if any, else the built-in one.
func get_level(slot: int) -> LevelData:
	return _repository.resolve(slot)


func has_level(slot: int) -> bool:
	return _repository.has_level(slot)


func world_has_levels(world: int) -> bool:
	return _repository.world_has_levels(world)


func level_count() -> int:
	return _repository.level_count()


## The slot the campaign goes to after [param slot], or 0 when it ends there.
func next_campaign_slot(slot: int) -> int:
	return _repository.next_campaign_slot(slot)


func save_custom(slot: int, data: LevelData) -> Error:
	var error: Error = _repository.save_custom(slot, data)
	if error == OK:
		custom_levels_changed.emit()
	return error


func delete_custom(slot: int) -> Error:
	var error: Error = _repository.delete_custom(slot)
	if error == OK:
		custom_levels_changed.emit()
	return error


func export_slot(slot: int) -> String:
	return _repository.export_slot(slot)


func export_all() -> String:
	return _repository.export_all()


func import_text(text: String, current_slot: int) -> LevelRepository.ImportResult:
	var result: LevelRepository.ImportResult = _repository.import_text(text, current_slot)
	if result.ok or not result.slots.is_empty():
		custom_levels_changed.emit()
	return result
