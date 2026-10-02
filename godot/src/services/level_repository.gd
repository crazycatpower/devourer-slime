class_name LevelRepository
extends RefCounted
## Stores the player's custom levels, one JSON file per slot.
##
## A slot plays its custom level when one is saved and the built-in layout
## otherwise. Files hold the same array-of-strings JSON the web version kept in
## localStorage, so levels can be copied between the two.

## Result of [method import_text].
class ImportResult:
	extends RefCounted
	var ok: bool = false
	var message: String = ""
	## Slots that were written.
	var slots: PackedInt32Array = PackedInt32Array()


## Key prefix the web version used for its localStorage entries; multi-level
## exports are keyed with it.
const WEB_KEY_PREFIX: String = "slime_maker_level_"

var _dir: String


func _init(dir: String) -> void:
	_dir = dir


func path_for(slot: int) -> String:
	return _dir.path_join("slot_%02d.json" % slot)


func has_custom(slot: int) -> bool:
	return FileAccess.file_exists(path_for(slot))


## Rows of the custom level in [param slot]; empty when there is none or the
## file is damaged.
func custom_rows(slot: int) -> PackedStringArray:
	if not has_custom(slot):
		return PackedStringArray()
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path_for(slot))) != OK:
		return PackedStringArray()
	var rows: PackedStringArray = LevelValidator.rows_from_json(json.data)
	if rows.is_empty() or not LevelValidator.problem_with(rows).is_empty():
		return PackedStringArray()
	return rows


## True when [param slot] has a save file that cannot be used. Such a slot
## plays its built-in layout until the file is overwritten or deleted.
func is_custom_damaged(slot: int) -> bool:
	return has_custom(slot) and custom_rows(slot).is_empty()


## The level that [param slot] plays: the custom one if present and valid,
## otherwise the built-in layout.
func resolve(slot: int) -> LevelData:
	var rows: PackedStringArray = custom_rows(slot)
	if rows.is_empty():
		return LevelLibrary.built_in_level(slot)
	return LevelCodec.decode(rows)


func save_custom(slot: int, data: LevelData) -> Error:
	return _write_rows(slot, LevelCodec.encode(data))


## Removes the custom level so the slot falls back to its built-in layout.
func delete_custom(slot: int) -> Error:
	if not has_custom(slot):
		return OK
	return DirAccess.remove_absolute(path_for(slot))


func custom_slots() -> PackedInt32Array:
	var slots: PackedInt32Array = PackedInt32Array()
	for slot: int in range(1, GameConstants.SLOT_COUNT + 1):
		if has_custom(slot):
			slots.append(slot)
	return slots


## JSON text of one custom level, or an empty string when the slot has none.
func export_slot(slot: int) -> String:
	var rows: PackedStringArray = custom_rows(slot)
	if rows.is_empty():
		return ""
	return JSON.stringify(Array(rows))


## JSON text of every custom level, keyed like the web version's storage.
## Returns an empty string when nothing is saved.
func export_all() -> String:
	var all: Dictionary = {}
	for slot: int in custom_slots():
		var rows: PackedStringArray = custom_rows(slot)
		if not rows.is_empty():
			all[WEB_KEY_PREFIX + str(slot)] = Array(rows)
	if all.is_empty():
		return ""
	return JSON.stringify(all, "  ")


## Imports level JSON: either one level (an array of strings, written to
## [param current_slot]) or a pack (an object keyed by slot). Every level is
## validated first; nothing is written unless all of them are acceptable.
func import_text(text: String, current_slot: int) -> ImportResult:
	var result: ImportResult = ImportResult.new()
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty():
		result.message = "請先貼上關卡資料！"
		return result

	var json: JSON = JSON.new()
	if json.parse(trimmed) != OK:
		result.message = "解析失敗！請確認貼上的是正確的 JSON 格式。"
		return result
	var parsed: Variant = json.data

	var pending: Dictionary[int, PackedStringArray] = {}
	if parsed is Array:
		var rows: PackedStringArray = LevelValidator.rows_from_json(parsed)
		if rows.is_empty():
			result.message = "關卡內容格式錯誤（必須是字串陣列）。"
			return result
		pending[current_slot] = rows
	elif parsed is Dictionary:
		var pack: Dictionary = parsed
		for key: Variant in pack:
			var key_text: String = str(key)
			if not key_text.begins_with(WEB_KEY_PREFIX):
				continue
			var slot_text: String = key_text.trim_prefix(WEB_KEY_PREFIX)
			var slot: int = slot_text.to_int()
			if not slot_text.is_valid_int() or slot < 1 or slot > GameConstants.SLOT_COUNT:
				result.message = "關卡包含無效的欄位編號「%s」。" % slot_text
				return result
			var rows: PackedStringArray = LevelValidator.rows_from_json(pack[key])
			if rows.is_empty():
				result.message = "SLOT %d 的內容格式錯誤（必須是字串陣列）。" % slot
				return result
			pending[slot] = rows
		if pending.is_empty():
			result.message = "格式不符！找不到任何 %s 鍵值。" % WEB_KEY_PREFIX
			return result
	else:
		result.message = "未知的 JSON 格式，無法解析。"
		return result

	for slot: int in pending:
		var problem: String = LevelValidator.problem_with(pending[slot])
		if not problem.is_empty():
			result.message = "SLOT %d：%s" % [slot, problem]
			return result

	for slot: int in pending:
		var error: Error = _write_rows(slot, pending[slot])
		if error != OK:
			result.message = "寫入 SLOT %d 失敗（%s）。" % [slot, error_string(error)]
			return result
		result.slots.append(slot)
	result.slots.sort()
	result.ok = true
	if parsed is Array:
		result.message = "成功將關卡載入至 SLOT %d！" % current_slot
	else:
		result.message = "成功匯入 %d 個自訂關卡！" % result.slots.size()
	return result


## Writes through a temporary file so a crash mid-write cannot leave a
## half-written level behind.
func _write_rows(slot: int, rows: PackedStringArray) -> Error:
	var error: Error = DirAccess.make_dir_recursive_absolute(_dir)
	if error != OK:
		return error
	var path: String = path_for(slot)
	var temp_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(Array(rows)))
	file.close()
	if FileAccess.file_exists(path):
		error = DirAccess.remove_absolute(path)
		if error != OK:
			return error
	return DirAccess.rename_absolute(temp_path, path)
