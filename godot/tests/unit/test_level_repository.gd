extends TestCase
## Custom level storage, import and export.

const TEST_DIR: String = "user://test_tmp/levels"

var repo: LevelRepository


func before_each() -> void:
	_wipe()
	repo = LevelRepository.new(TEST_DIR)


func after_each() -> void:
	_wipe()


func test_slot_without_save_resolves_to_built_in() -> void:
	check(not repo.has_custom(2))
	check(repo.resolve(2).equals(LevelLibrary.shipped_level(2)))
	check(repo.custom_rows(2).is_empty())
	check_eq(repo.export_slot(2), "")
	check_eq(repo.export_all(), "")


func test_wired_level_save_export_and_import_keep_connections() -> void:
	var data: LevelData = LevelCodec.decode(LevelLibrary.default_rows())
	data.grid.set_cell(5, 4, Tile.SENSOR)
	data.grid.set_cell(5, 7, Tile.RAIL_RIGHT)
	for col: int in range(4, 8):
		data.grid.set_wire(Vector2i(col, 5), true)
	check_eq(repo.save_custom(61, data), OK)
	check(repo.resolve(61).equals(data))
	var single: String = repo.export_slot(61)
	check(repo.import_text(single, 62).ok)
	check(repo.resolve(62).equals(data), "single wired level imports without losing connections")
	var pack: String = repo.export_all()
	repo.delete_custom(61)
	repo.delete_custom(62)
	check(repo.import_text(pack, 63).ok)
	check(repo.resolve(61).equals(data))
	check(repo.resolve(62).equals(data), "wired pack imports preserve metadata")


func test_save_load_and_delete() -> void:
	var level: LevelData = LevelLibrary.built_in_level(5)
	level.grid.set_cell(3, 3, Tile.BOUNCY)
	level.start_cell = Vector2i(4, 4)
	check_eq(repo.save_custom(7, level), OK)
	check(repo.has_custom(7))
	check(repo.resolve(7).equals(level), "saved level is what the slot now plays")
	check(not FileAccess.file_exists(repo.path_for(7) + ".tmp"), "no temporary file left behind")
	check_eq(repo.custom_slots(), PackedInt32Array([7]))

	check_eq(repo.delete_custom(7), OK)
	check(not repo.has_custom(7))
	check(repo.resolve(7).equals(LevelLibrary.shipped_level(7)), "falls back to the shipped level")
	check_eq(repo.delete_custom(7), OK, "deleting twice is harmless")


func test_overwriting_a_save() -> void:
	check_eq(repo.save_custom(3, LevelLibrary.built_in_level(1)), OK)
	check_eq(repo.save_custom(3, LevelLibrary.built_in_level(2)), OK)
	check(repo.resolve(3).equals(LevelLibrary.built_in_level(2)))


func test_damaged_save_is_ignored() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	for content: String in ["{not json", "[1, 2, 3]", "[\"@@\"]", ""]:
		var file: FileAccess = FileAccess.open(repo.path_for(4), FileAccess.WRITE)
		file.store_string(content)
		file.close()
		check(repo.custom_rows(4).is_empty(), "content %s" % content)
		check(repo.is_custom_damaged(4), "flagged as damaged: %s" % content)
		check(repo.resolve(4).equals(LevelLibrary.shipped_level(4)), "falls back for %s" % content)


func test_export_uses_the_web_format() -> void:
	repo.save_custom(2, LevelLibrary.built_in_level(2))
	repo.save_custom(9, LevelLibrary.built_in_level(9))
	var single: Variant = JSON.parse_string(repo.export_slot(2))
	check(single is Array, "one level exports as an array of strings")
	check_eq(LevelValidator.rows_from_json(single), LevelLibrary.built_in_rows(2))

	var pack: Variant = JSON.parse_string(repo.export_all())
	check(pack is Dictionary, "all levels export as an object")
	var pack_dict: Dictionary = pack
	check_eq(pack_dict.size(), 2)
	check(pack_dict.has("slime_maker_level_2"))
	check(pack_dict.has("slime_maker_level_9"))


func test_import_single_level_goes_to_the_current_slot() -> void:
	var text: String = JSON.stringify(Array(LevelLibrary.built_in_rows(6)))
	var result: LevelRepository.ImportResult = repo.import_text(text, 31)
	check(result.ok, result.message)
	check_eq(result.slots, PackedInt32Array([31]))
	check(repo.resolve(31).equals(LevelLibrary.built_in_level(6)))


func test_import_pack_round_trip() -> void:
	repo.save_custom(2, LevelLibrary.built_in_level(4))
	repo.save_custom(48, LevelLibrary.built_in_level(5))
	var text: String = repo.export_all()
	_wipe()
	var result: LevelRepository.ImportResult = repo.import_text(text, 1)
	check(result.ok, result.message)
	check_eq(result.slots, PackedInt32Array([2, 48]))
	check(repo.resolve(2).equals(LevelLibrary.built_in_level(4)))
	check(repo.resolve(48).equals(LevelLibrary.built_in_level(5)))


func test_import_rejects_bad_input_without_writing() -> void:
	var good: Array = Array(LevelLibrary.built_in_rows(6))
	var cases: Dictionary[String, String] = {
		"empty": "   ",
		"not json": "hello",
		"number": "42",
		"array of numbers": "[1, 2, 3]",
		"object without level keys": "{\"other\": 1}",
		"slot out of range": JSON.stringify({"slime_maker_level_%d" % (GameConstants.SLOT_COUNT + 1): good}),
		"slot not a number": JSON.stringify({"slime_maker_level_abc": good}),
		"level too small": "[\"@@@\", \"@P@\", \"@@@\"]",
		"one bad level in a pack": JSON.stringify(
			{"slime_maker_level_1": good, "slime_maker_level_2": ["@@@", "@P@", "@@@"]}
		),
	}
	for label: String in cases:
		var result: LevelRepository.ImportResult = repo.import_text(cases[label], 1)
		check(not result.ok, "%s should be rejected" % label)
		check(not result.message.is_empty(), "%s should explain itself" % label)
		check(repo.custom_slots().is_empty(), "%s must not write anything" % label)


func _wipe() -> void:
	var dir: DirAccess = DirAccess.open(TEST_DIR)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)


func test_complete_document_load_and_shipped_mechanism_layers() -> void:
	var data: LevelData = LevelCodec.decode(LevelLibrary.default_rows())
	var cell: Vector2i = Vector2i(8, 5)
	data.grid.set_sensor(cell, true)
	data.grid.set_wire(cell, true)
	data.grid.set_rail(cell, Tile.RAIL_DOWN)
	data.grid.set_cell(cell.y, cell.x, Tile.SAND)
	check_eq(repo.save_custom(61, data), OK)
	var document: Variant = repo.custom_document(61)
	check(document is Dictionary)
	check(LevelCodec.decode_document(document).equals(data))
	var existed: bool = LevelLibrary._designer_documents.has(61)
	var previous: Variant = LevelLibrary._designer_documents.get(61)
	LevelLibrary._designer_documents[61] = document
	check(LevelLibrary.has_designer_level(61))
	check(LevelLibrary.shipped_level(61).equals(data), "shipped documents retain covered mechanisms")
	check_eq(LevelLibrary.shipped_rows(61), LevelCodec.encode(data))
	if existed:
		LevelLibrary._designer_documents[61] = previous
	else:
		LevelLibrary._designer_documents.erase(61)


class FailSecondWrite extends LevelRepository:
	var writes: int = 0
	func _write_document(slot: int, document: Variant) -> Error:
		writes += 1
		if writes == 2:
			return ERR_CANT_CREATE
		return super._write_document(slot, document)


func test_failed_pack_import_restores_original_and_removes_new_partial_files() -> void:
	var first: LevelData = LevelLibrary.built_in_level(4)
	var second: LevelData = LevelLibrary.built_in_level(5)
	check_eq(repo.save_custom(2, first), OK)
	var original_text: String = FileAccess.get_file_as_string(repo.path_for(2))
	var pack: Dictionary = {"slime_maker_level_2": Array(LevelCodec.encode(second)), "slime_maker_level_3": Array(LevelCodec.encode(second))}
	var failing: FailSecondWrite = FailSecondWrite.new(TEST_DIR)
	var result: LevelRepository.ImportResult = failing.import_text(JSON.stringify(pack), 1)
	check(not result.ok)
	check(result.slots.is_empty())
	check_eq(FileAccess.get_file_as_string(repo.path_for(2)), original_text, "failed pack preserves original file bytes")
	check(not repo.has_custom(3))
	repo.delete_custom(2)
	failing = FailSecondWrite.new(TEST_DIR)
	result = failing.import_text(JSON.stringify(pack), 1)
	check(not result.ok)
	check(not repo.has_custom(2), "newly written prefix is removed on failure")
	check(not repo.has_custom(3))


func test_invalid_destination_and_duplicate_slot_alias_are_rejected() -> void:
	var rows: Array = Array(LevelLibrary.default_rows())
	for slot: int in [0, GameConstants.SLOT_COUNT + 1]:
		check(not repo.import_text(JSON.stringify(rows), slot).ok)
		check_eq(repo.save_custom(slot, LevelCodec.decode(LevelLibrary.default_rows())), ERR_INVALID_PARAMETER)
	var aliases: Dictionary = {"slime_maker_level_1": rows, "slime_maker_level_01": rows}
	check(not repo.import_text(JSON.stringify(aliases), 1).ok)
	check(repo.custom_slots().is_empty())


func test_failed_pack_preserves_damaged_save_bytes() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var original: PackedByteArray = PackedByteArray([239, 187, 191, 255, 0, 128, 13, 10])
	var file: FileAccess = FileAccess.open(repo.path_for(2), FileAccess.WRITE)
	file.store_buffer(original)
	file.close()
	var rows: Array = Array(LevelLibrary.default_rows())
	var pack: Dictionary = {"slime_maker_level_2": rows, "slime_maker_level_3": rows}
	var failing: FailSecondWrite = FailSecondWrite.new(TEST_DIR)
	var result: LevelRepository.ImportResult = failing.import_text(JSON.stringify(pack), 1)
	check(not result.ok)
	check(result.slots.is_empty())
	check_eq(FileAccess.get_file_as_bytes(repo.path_for(2)), original, "rollback retains BOM, invalid UTF-8 and zero bytes")
	check(not repo.has_custom(3))


const Baker = preload("res://tools/bake_levels.gd")


func test_bake_retains_mechanism_layers_and_unedited_slots() -> void:
	var target: String = TEST_DIR.path_join("baked.json")
	var old_rows: Array = Array(LevelLibrary.default_rows())
	var file: FileAccess = FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		DirAccess.make_dir_recursive_absolute(TEST_DIR)
		file = FileAccess.open(target, FileAccess.WRITE)
	file.store_string(JSON.stringify({"format": 1, "slots": {"4": old_rows}}))
	file.close()
	var data: LevelData = LevelCodec.decode(LevelLibrary.default_rows())
	var cell: Vector2i = Vector2i(8, 5)
	data.grid.set_cell(cell.y, cell.x, Tile.SAND)
	data.grid.set_sensor(cell, true)
	data.grid.set_wire(cell, true)
	data.grid.set_rail(cell, Tile.RAIL_DOWN)
	check_eq(repo.save_custom(61, data), OK)
	var result: Dictionary = Baker.bake(repo, target)
	check_eq(result["error"], OK)
	check_eq(result["shipped"], 2)
	check_eq(result["updated"], 1)
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(target))
	check_eq(document["slots"]["4"], old_rows, "untouched shipped slot remains intact")
	check(LevelCodec.decode_document(document["slots"]["61"]).equals(data), "baked document retains covered devices")
	check(not FileAccess.file_exists(target + ".tmp"))
	var original: PackedByteArray = FileAccess.get_file_as_bytes(target)
	result = Baker.bake(repo, target)
	check_eq(result["updated"], 0)
	check_eq(FileAccess.get_file_as_bytes(target), original, "unchanged bake preserves exact file")


func test_bake_rejects_damaged_target_without_replacing_it() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var target: String = TEST_DIR.path_join("baked.json")
	check_eq(repo.save_custom(61, LevelCodec.decode(LevelLibrary.default_rows())), OK)
	for text: String in ["{broken", "[]", '{"slots": []}', '{}']:
		var file: FileAccess = FileAccess.open(target, FileAccess.WRITE)
		file.store_string(text)
		file.close()
		var result: Dictionary = Baker.bake(repo, target)
		check((result["error"] as int) != OK, "damaged target is rejected")
		check_eq(FileAccess.get_file_as_string(target), text, "damaged data remains recoverable")


func test_bake_write_failure_preserves_original_target() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var target: String = TEST_DIR.path_join("baked.json")
	var original: String = JSON.stringify({"format": 1, "slots": {}})
	var file: FileAccess = FileAccess.open(target, FileAccess.WRITE)
	file.store_string(original)
	file.close()
	check_eq(repo.save_custom(61, LevelCodec.decode(LevelLibrary.default_rows())), OK)
	DirAccess.make_dir_recursive_absolute(target + ".tmp")
	var result: Dictionary = Baker.bake(repo, target)
	check((result["error"] as int) != OK)
	check_eq(FileAccess.get_file_as_string(target), original)
	DirAccess.remove_absolute(target + ".tmp")
