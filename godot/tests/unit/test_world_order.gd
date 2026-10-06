extends TestCase


func test_campaign_order_visits_every_slot_once() -> void:
	var slot: int = 1
	var visited: Array[int] = []
	while slot != 0 and visited.size() <= 50:
		visited.append(slot)
		slot = WorldCatalog.next_slot(slot)
	check_eq(visited.size(), 50)
	check_eq(visited, range(1, 51))
	check_eq(WorldCatalog.display_world(1), 1)
	check_eq(WorldCatalog.display_world(5), 5)
