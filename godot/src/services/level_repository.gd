class_name LevelRepository
extends RefCounted
## Stores the player's custom levels, one JSON file per slot.
##
## A slot plays its custom level when one is saved and the built-in layout
## otherwise. Files hold array-of-strings JSON for the level editor.

## Result of [method import_text].
class ImportResult:
	extends RefCounted
	var ok: bool = false
	var message: String = ""
	## Slots that were written.
	var slots: PackedInt32Array = PackedInt32Array()


## Stable key prefix for multi-level export files.
const EXPORT_KEY_PREFIX: String = "slime_maker_level_"

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
	return LevelValidator.rows_from_json(custom_document(slot))


## Read and validate the complete document once, including mechanism layers.
func custom_document(slot: int) -> Variant:
	if not has_custom(slot):
		return null
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path_for(slot))) != OK:
		return null
	if not LevelValidator.problem_with_document(json.data).is_empty():
		return null
	return json.data


## True when [param slot] has a save file that cannot be used. Such a slot
## plays its built-in layout until the file is overwritten or deleted.
func is_custom_damaged(slot: int) -> bool:
	return has_custom(slot) and custom_rows(slot).is_empty()


## The level that [param slot] plays: the custom one if present and valid,
## otherwise the level the game ships with.
func resolve(slot: int) -> LevelData:
	var document: Variant = custom_document(slot)
	if document == null:
		return LevelLibrary.shipped_level(slot)
	return LevelCodec.decode_document(document)


## True when [param slot] has a level of its own: a custom save, or one that
## ships with the game. False for the empty room every unused slot falls back to.
func has_level(slot: int) -> bool:
	return has_custom(slot) or not LevelLibrary.is_placeholder(slot)


## True when at least one slot of [param world] has a level. A world without
## any is closed: the campaign does not lead into it.
func world_has_levels(world: int) -> bool:
	var first: int = (world - 1) * GameConstants.LEVELS_PER_WORLD + 1
	for slot: int in range(first, first + GameConstants.LEVELS_PER_WORLD):
		if has_level(slot):
			return true
	return false


## Slots that have a level, in every world.
func level_count() -> int:
	var count: int = 0
	for slot: int in range(1, GameConstants.SLOT_COUNT + 1):
		if has_level(slot):
			count += 1
	return count


## The slot the campaign goes to after [param slot], or 0 when it ends there:
## after the last world, or before a world that has no levels yet.
func next_campaign_slot(slot: int) -> int:
	var next: int = WorldCatalog.next_slot(slot)
	if next == 0:
		return 0
	var next_world: int = GameConstants.world_of_slot(next)
	if next_world != GameConstants.world_of_slot(slot) and not world_has_levels(next_world):
		return 0
	return next


func save_custom(slot: int, data: LevelData) -> Error:
	if slot < 1 or slot > GameConstants.SLOT_COUNT:
		return ERR_INVALID_PARAMETER
	return _write_document(slot, LevelCodec.encode_document(data))


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
	return FileAccess.get_file_as_string(path_for(slot))


## JSON text of every custom level, keyed by the stable export prefix.
## Returns an empty string when nothing is saved.
func export_all() -> String:
	var all: Dictionary = {}
	for slot: int in custom_slots():
		var document: Variant = custom_document(slot)
		if document != null:
			all[EXPORT_KEY_PREFIX + str(slot)] = document
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
	var documents: Dictionary[int, Variant] = {}
	var single_document: bool = false
	if parsed is Dictionary:
		var parsed_object: Dictionary = parsed
		single_document = parsed_object.has("rows")
	if parsed is Array or single_document:
		if current_slot < 1 or current_slot > GameConstants.SLOT_COUNT:
			result.message = "目前的 SLOT 編號無效。"
			return result
		var rows: PackedStringArray = LevelValidator.rows_from_json(parsed)
		if rows.is_empty():
			result.message = "關卡內容格式錯誤（必須是字串陣列）。"
			return result
		pending[current_slot] = rows
		documents[current_slot] = parsed
	elif parsed is Dictionary:
		var pack: Dictionary = parsed
		for key: Variant in pack:
			var key_text: String = str(key)
			if not key_text.begins_with(EXPORT_KEY_PREFIX):
				continue
			var slot_text: String = key_text.trim_prefix(EXPORT_KEY_PREFIX)
			var slot: int = slot_text.to_int()
			if not slot_text.is_valid_int() or slot < 1 or slot > GameConstants.SLOT_COUNT:
				result.message = "關卡包含無效的欄位編號「%s」。" % slot_text
				return result
			if pending.has(slot):
				result.message = "匯入資料重複指定 SLOT %d。" % slot
				return result
			var rows: PackedStringArray = LevelValidator.rows_from_json(pack[key])
			if rows.is_empty():
				result.message = "SLOT %d 的內容格式錯誤（必須是字串陣列）。" % slot
				return result
			pending[slot] = rows
			documents[slot] = pack[key]
		if pending.is_empty():
			result.message = "格式不符！找不到任何 %s 鍵值。" % EXPORT_KEY_PREFIX
			return result
	else:
		result.message = "未知的 JSON 格式，無法解析。"
		return result

	for slot: int in pending:
		var problem: String = LevelValidator.problem_with_document(documents[slot])
		if not problem.is_empty():
			result.message = "SLOT %d：%s" % [slot, problem]
			return result

	# Keep exact original bytes so a failed batch can restore damaged saves too.
	var backups: Dictionary[int, PackedByteArray] = {}
	for slot: int in pending:
		if has_custom(slot):
			var original: FileAccess = FileAccess.open(path_for(slot), FileAccess.READ)
			if original == null:
				result.message = "無法備份 SLOT %d，匯入未變更任何存檔。" % slot
				return result
			backups[slot] = original.get_buffer(original.get_length())
			original.close()
	for slot: int in pending:
		var error: Error = _write_document(slot, documents[slot])
		if error != OK:
			var unrestored: PackedInt32Array = PackedInt32Array()
			for written: int in result.slots:
				var restore_error: Error = _write_bytes(written, backups[written]) if backups.has(written) else delete_custom(written)
				if restore_error != OK:
					unrestored.append(written)
			result.slots = unrestored
			result.message = "寫入 SLOT %d 失敗（%s）。" % [slot, error_string(error)]
			result.message += "已還原原有存檔。" if unrestored.is_empty() else "部分存檔無法還原：%s。" % str(unrestored)
			return result
		result.slots.append(slot)
	result.slots.sort()
	result.ok = true
	if parsed is Array or single_document:
		result.message = "成功將關卡載入至 SLOT %d！" % current_slot
	else:
		result.message = "成功匯入 %d 個自訂關卡！" % result.slots.size()
	return result


## Writes through a temporary file so a crash mid-write cannot leave a
## half-written level behind.
func _write_document(slot: int, document: Variant) -> Error:
	return _write_text(slot, JSON.stringify(document))


func _write_text(slot: int, text: String) -> Error:
	return _write_bytes(slot, text.to_utf8_buffer())


func _write_bytes(slot: int, bytes: PackedByteArray) -> Error:
	var error: Error = DirAccess.make_dir_recursive_absolute(_dir)
	if error != OK:
		return error
	var path: String = path_for(slot)
	var temp_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temp_path)
		return write_error
	var rename_error: Error = DirAccess.rename_absolute(temp_path, path)
	if rename_error != OK:
		DirAccess.remove_absolute(temp_path)
	return rename_error
