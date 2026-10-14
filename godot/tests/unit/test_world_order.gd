extends TestCase
func test_campaign_order_visits_every_slot_once() -> void:
	var slot: int = 1
	var visited: Array[int] = []
	while slot != 0 and visited.size() <= GameConstants.SLOT_COUNT:
		visited.append(slot)
		slot = WorldCatalog.next_slot(slot)
	check_eq(visited.size(), GameConstants.SLOT_COUNT)
	check_eq(visited, range(1, GameConstants.SLOT_COUNT + 1))
	check_eq(WorldCatalog.display_world(1), 1)
	check_eq(WorldCatalog.display_world(5), 5)
	check_eq(WorldCatalog.display_world(GameConstants.WORLD_COUNT), GameConstants.WORLD_COUNT)


func test_there_is_room_for_ten_worlds() -> void:
	check_eq(GameConstants.WORLD_COUNT, 10)
	check_eq(GameConstants.SLOT_COUNT, 100)
	check_eq(WorldCatalog.ORDER.size(), GameConstants.WORLD_COUNT, "every world has a place in the menu")
	check_eq(GameConstants.world_of_slot(51), 6)
	check_eq(GameConstants.world_of_slot(100), 10)
	check_eq(GameConstants.level_in_world(100), 10)
	check(BackdropTheme.PALETTES.size() >= GameConstants.WORLD_COUNT, "every world has its own wall colours")
	var accents: Array[Color] = []
	for world: int in WorldCatalog.ORDER:
		var accent: Color = WorldCatalog.accent(world)
		check(not accents.has(accent), "world %d has its own colour" % world)
		accents.append(accent)


func test_existing_worlds_keep_their_slots_and_bosses() -> void:
	check_eq(LevelLibrary.boss_kind_for_slot(10), BossState.Kind.STEEL_CHASE)
	check_eq(LevelLibrary.boss_kind_for_slot(50), BossState.Kind.VOID_SLIME)
	for slot: int in range(51, GameConstants.SLOT_COUNT + 1):
		check_eq(LevelLibrary.is_boss_slot(slot), slot % 10 == 0, "the tenth level hosts the world boss")
		if slot % 10 == 0 and not LevelLibrary.has_designer_level(slot):
			check_eq(LevelLibrary.shipped_rows(slot), LevelLibrary.boss_rows(), "bosses preserve the unchanged standard layouts")
		elif slot % 10 != 0:
			check(LevelLibrary.has_authored_layout(slot), "mechanism worlds have authored ordinary stages")



func test_campaign_stops_before_a_world_without_levels() -> void:
	var dir: String = "user://test_tmp/world_order"
	_wipe(dir)
	var repo: LevelRepository = LevelRepository.new(dir)
	check(repo.world_has_levels(1), "the first world ships with levels")
	check_eq(repo.next_campaign_slot(10), 11, "worlds that have levels follow on")
	check_eq(repo.next_campaign_slot(49), 50, "within a world the next slot always follows")

	# A slot counts as empty only when nothing ships there and nothing is saved there.
	var empty_world: int = 0
	for world: int in range(6, GameConstants.WORLD_COUNT + 1):
		if not repo.world_has_levels(world):
			empty_world = world
			break
	if empty_world == 0:
		check(true, "every world already has levels")
		_wipe(dir)
		return
	var before: int = (empty_world - 1) * GameConstants.LEVELS_PER_WORLD
	var first: int = before + 1
	check_eq(WorldCatalog.next_slot(before), first, "the slot order itself continues")
	check_eq(repo.next_campaign_slot(before), 0, "but the campaign ends before an empty world")
	var count: int = repo.level_count()

	check_eq(repo.save_custom(first + 3, LevelLibrary.built_in_level(1)), OK)
	check(repo.world_has_levels(empty_world), "one saved level opens the world")
	check_eq(repo.next_campaign_slot(before), first, "and the campaign leads into it")
	check_eq(repo.level_count(), count + 1)
	_wipe(dir)


func _wipe(dir: String) -> void:
	var access: DirAccess = DirAccess.open(dir)
	if access == null:
		return
	for file_name: String in access.get_files():
		access.remove(file_name)
	DirAccess.remove_absolute(dir)