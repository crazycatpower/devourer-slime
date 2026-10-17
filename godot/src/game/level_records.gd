class_name LevelRecords
extends RefCounted
## Records belong to the exact source layout, never a mutated/rewound grid.

var times: Dictionary[String, float] = {}


static func key_for(slot: int, level: LevelData) -> String:
	return "%d:%s" % [slot, JSON.stringify(LevelCodec.encode_document(level)).sha256_text()]


func best(key: String) -> float:
	return times.get(key, 0.0)


func record(key: String, seconds: float) -> bool:
	if key.is_empty() or not is_finite(seconds) or seconds <= 0.0:
		return false
	if times.has(key) and times[key] <= seconds:
		return false
	times[key] = seconds
	return true


func load_data(stored: Variant) -> void:
	times.clear()
	if not stored is Dictionary:
		return
	for key: Variant in stored:
		var value: Variant = stored[key]
		if not key is String:
			continue
		if value is float:
			record(key as String, value as float)
		elif value is int:
			record(key as String, float(value as int))
