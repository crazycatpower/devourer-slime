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
	check(repo.resolve(2).equals(LevelLibrary.built_in_level(2)))
	check(repo.custom_rows(2).is_empty())
	check_eq(repo.export_slot(2), "")
	check_eq(repo.export_all(), "")


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
	check(repo.resolve(7).equals(LevelLibrary.built_in_level(7)), "falls back to the built-in level")
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
		check(repo.resolve(4).equals(LevelLibrary.built_in_level(4)), "falls back for %s" % content)


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
		"slot out of range": JSON.stringify({"slime_maker_level_51": good}),
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
