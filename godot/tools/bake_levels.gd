extends SceneTree
## Copies the levels saved in the in-game editor into the project, so they ship
## with the game instead of living only in this computer's save folder.
##
## Every valid custom level replaces its slot in data/levels/designer_levels.json.
## Slots without a custom level keep what the file already holds.
##
## Usage:  godot --headless --path godot -s res://tools/bake_levels.gd


func _initialize() -> void:
	var repository: LevelRepository = LevelRepository.new(SavePaths.custom_levels_dir())
	var slots: Dictionary = {}
	var existing: Variant = null
	if FileAccess.file_exists(LevelLibrary.DESIGNER_PATH):
		existing = JSON.parse_string(FileAccess.get_file_as_string(LevelLibrary.DESIGNER_PATH))
	if existing is Dictionary:
		var existing_dict: Dictionary = existing
		slots = existing_dict.get("slots", {})

	var baked: int = 0
	var skipped: PackedInt32Array = PackedInt32Array()
	for slot: int in repository.custom_slots():
		var rows: PackedStringArray = repository.custom_rows(slot)
		if rows.is_empty():
			skipped.append(slot)
			continue
		if not slots.has(str(slot)) or LevelLibrary.to_rows(slots[str(slot)]) != rows:
			baked += 1
		slots[str(slot)] = Array(rows)

	var file: FileAccess = FileAccess.open(LevelLibrary.DESIGNER_PATH, FileAccess.WRITE)
	if file == null:
		push_error("bake_levels: cannot write %s" % LevelLibrary.DESIGNER_PATH)
		quit(1)
		return
	file.store_string(JSON.stringify({"format": 1, "slots": slots}, "  ") + "\n")
	file.close()

	for slot: int in skipped:
		print("SKIPPED  slot %d: the save file is damaged" % slot)
	print("%d levels shipped, %d updated, %d skipped" % [slots.size(), baked, skipped.size()])
	quit(1 if not skipped.is_empty() else 0)
