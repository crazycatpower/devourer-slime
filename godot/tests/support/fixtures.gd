class_name Fixtures
extends RefCounted
## Level layouts the tests rely on, so they do not depend on the shipped levels.

## Tile showcase: start at column 1, dirt at column 3, steel at column 5, then bouncy, glass, void and spikes.
const SHOWCASE: PackedStringArray = [
	"@@@@@@@@@@@@@@@@@@@@@@@@@",
	"@.......................@",
	"@.......................@",
	"@.......................@",
	"@.......................@",
	"@.......................@",
	"@.......................@",
	"@.......................@",
	"@.......................@",
	"@.......................@",
	"@..*.X.O................@",
	"@.......................@",
	"@.......................@",
	"@P.#.@.~.$..............@",
	"@@@@@@@@@@@@@@@@@@@@@@@@@",
]


static func showcase() -> LevelData:
	return LevelCodec.decode(SHOWCASE)


## The empty 40 x 15 room with a goal in the corner.
static func empty_room() -> LevelData:
	return LevelCodec.decode(LevelLibrary.default_rows())


## Archived layouts for codec/physics tests; independent of campaign redesigns.
static func legacy_rows(slot: int) -> PackedStringArray:
	var archive: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LevelLibrary.DATA_PATH))
	var slots: Dictionary = archive.get("slots", {})
	return LevelLibrary.to_rows(slots.get(str(slot), archive.get("boss_level")))


static func legacy_level(slot: int) -> LevelData:
	return LevelCodec.decode(legacy_rows(slot))
