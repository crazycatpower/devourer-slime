class_name LevelLibrary
extends RefCounted
## Read-only access to the level layouts that ship with the game.
##
## The layouts live in [constant DATA_PATH], which is generated from the web
## version's `constants.ts` and `default_levels.ts` by
## `tools/export_levels.mjs`. Level layouts are authored by the game's
## designer; nothing in this project edits or invents them.

const DATA_PATH: String = "res://data/levels/official_levels.json"

## Slots that host a boss encounter.
const _BOSS_BY_SLOT: Dictionary[int, int] = {
	10: BossState.Kind.WORLD_1,
	20: BossState.Kind.WORLD_2,
	30: BossState.Kind.WORLD_3,
	40: BossState.Kind.WORLD_4,
}

static var _loaded: bool = false
static var _default_rows: PackedStringArray = PackedStringArray()
static var _boss_rows: PackedStringArray = PackedStringArray()
static var _big_world_rows: PackedStringArray = PackedStringArray()
static var _slot_rows: Dictionary[int, PackedStringArray] = {}


static func boss_kind_for_slot(slot: int) -> BossState.Kind:
	var kind: int = _BOSS_BY_SLOT.get(slot, BossState.Kind.NONE)
	return kind as BossState.Kind


static func is_boss_slot(slot: int) -> bool:
	return _BOSS_BY_SLOT.has(slot)


## True when the designer authored a dedicated layout for [param slot].
static func has_authored_layout(slot: int) -> bool:
	_ensure_loaded()
	return _slot_rows.has(slot)


## True when [param slot] only has the generic empty room to offer.
static func is_placeholder(slot: int) -> bool:
	return not has_authored_layout(slot) and not is_boss_slot(slot)


## Text rows of the built-in layout for [param slot].
static func built_in_rows(slot: int) -> PackedStringArray:
	_ensure_loaded()
	if _slot_rows.has(slot):
		return _slot_rows[slot]
	if is_boss_slot(slot):
		return _boss_rows
	return _default_rows


static func built_in_level(slot: int) -> LevelData:
	return LevelCodec.decode(built_in_rows(slot))


static func default_rows() -> PackedStringArray:
	_ensure_loaded()
	return _default_rows


static func boss_rows() -> PackedStringArray:
	_ensure_loaded()
	return _boss_rows


static func big_world_rows() -> PackedStringArray:
	_ensure_loaded()
	return _big_world_rows


static func authored_slots() -> PackedInt32Array:
	_ensure_loaded()
	var slots: PackedInt32Array = PackedInt32Array()
	for slot: int in _slot_rows:
		slots.append(slot)
	slots.sort()
	return slots


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var text: String = FileAccess.get_file_as_string(DATA_PATH)
	if text.is_empty():
		push_error("LevelLibrary: cannot read %s" % DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("LevelLibrary: %s is not a JSON object" % DATA_PATH)
		return
	var root: Dictionary = parsed
	_default_rows = to_rows(root.get("default_level"))
	_boss_rows = to_rows(root.get("boss_level"))
	_big_world_rows = to_rows(root.get("big_world_default"))
	var slots: Variant = root.get("slots")
	if slots is Dictionary:
		var slot_dict: Dictionary = slots
		for key: Variant in slot_dict:
			var slot: int = str(key).to_int()
			_slot_rows[slot] = to_rows(slot_dict[key])


## Converts a parsed JSON array of strings; anything else yields an empty array.
static func to_rows(value: Variant) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if value is Array:
		var list: Array = value
		for item: Variant in list:
			if item is String:
				out.append(item as String)
	return out
