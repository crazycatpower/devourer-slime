extends SceneTree
## Ships complete editor documents, preserving existing slots and mechanism layers.
## Usage: godot --headless --path godot -s res://tools/bake_levels.gd


func _initialize() -> void:
	var repository: LevelRepository = LevelRepository.new(SavePaths.custom_levels_dir())
	var result: Dictionary = bake(repository, LevelLibrary.DESIGNER_PATH)
	var error: Error = result["error"] as Error
	if error != OK:
		push_error("bake_levels: %s (%s)" % [result["message"], error_string(error)])
		quit(1)
		return
	var skipped: PackedInt32Array = result["skipped"]
	for slot: int in skipped:
		print("SKIPPED  slot %d: the save file is damaged" % slot)
	print("%d levels shipped, %d updated, %d skipped" % [result["shipped"], result["updated"], skipped.size()])
	quit(1 if not skipped.is_empty() else 0)


## Separate from the CLI entry point so tests can use an isolated target file.
static func bake(repository: LevelRepository, target_path: String) -> Dictionary:
	var result: Dictionary = {"error": OK, "message": "", "shipped": 0, "updated": 0, "skipped": PackedInt32Array()}
	var slots: Dictionary = {}
	var exists: bool = FileAccess.file_exists(target_path)
	if exists:
		var json: JSON = JSON.new()
		var error: Error = json.parse(FileAccess.get_file_as_string(target_path))
		if error != OK or not json.data is Dictionary:
			return _failure(ERR_PARSE_ERROR, "existing shipped levels are damaged; original file preserved")
		var root: Dictionary = json.data
		if not root.get("slots") is Dictionary:
			return _failure(ERR_INVALID_DATA, "existing shipped slots are invalid; original file preserved")
		slots = root["slots"]
	var skipped: PackedInt32Array = PackedInt32Array()
	var updated: int = 0
	for slot: int in repository.custom_slots():
		var document: Variant = repository.custom_document(slot)
		if document == null:
			skipped.append(slot)
			continue
		if not slots.has(str(slot)) or JSON.stringify(slots[str(slot)]) != JSON.stringify(document):
			updated += 1
		slots[str(slot)] = document
	result["shipped"] = slots.size()
	result["updated"] = updated
	result["skipped"] = skipped
	if exists and updated == 0:
		return result
	var error: Error = DirAccess.make_dir_recursive_absolute(target_path.get_base_dir())
	if error != OK:
		return _failure(error, "cannot create shipped level directory")
	var temp_path: String = target_path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return _failure(FileAccess.get_open_error(), "cannot open temporary shipped levels")
	file.store_string(JSON.stringify({"format": 1, "slots": slots}, "  ") + "\n")
	file.flush()
	error = file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(temp_path, target_path)
	if error != OK:
		DirAccess.remove_absolute(temp_path)
		return _failure(error, "cannot replace shipped levels; original file preserved")
	return result


static func _failure(error: Error, message: String) -> Dictionary:
	return {"error": error, "message": message}
