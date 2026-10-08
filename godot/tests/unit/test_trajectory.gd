extends TestCase
## Existing official layouts only; the preview must remain a read-only query.


func _sim(slot: int) -> GameSim:
	var sim: GameSim = GameSim.new()
	sim.load_level(slot, LevelLibrary.built_in_level(slot), LevelLibrary.boss_kind_for_slot(slot))
	return sim


func test_preview_matches_real_flight_until_first_contact() -> void:
	for slot: int in [1, 10, 20, 30, 40, 50]:
		for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2(1.0, -1.0).normalized()]:
			var sim: GameSim = _sim(slot)
			var aim: PlayerSystem.Aim = PlayerSystem.Aim.new()
			aim.x = direction.x
			aim.y = direction.y
			var points: PackedVector2Array = ProjectileSystem.preview_path(sim, aim)
			PlayerSystem._fire(sim, aim)
			var shot: SimProjectile = sim.projectiles[0]
			check_near(points[0].x, shot.x + shot.w / 2.0, 0.001)
			check_near(points[0].y, shot.y + shot.h / 2.0, 0.001)
			# Last point may be a collision or the end of the prediction horizon.
			for tick: int in range(1, points.size() - 1):
				ProjectileSystem.update(sim)
				check(not sim.projectiles.is_empty(), "no actual contact before predicted contact")
				if sim.projectiles.is_empty():
					break
				check_near(points[tick].x, shot.x + shot.w / 2.0, 0.001)
				check_near(points[tick].y, shot.y + shot.h / 2.0, 0.001)


func test_preview_does_not_change_level_boss_or_randomness() -> void:
	for slot: int in [10, 20, 30, 40, 50]:
		var sim: GameSim = _sim(slot)
		sim.boss.state = BossState.State.ACTIVE
		var rows: PackedStringArray = LevelCodec.encode(LevelLibrary.built_in_level(slot))
		# Snapshot the actual arena, including its normal boss initialization.
		var cells: Array[int] = []
		for r: int in sim.level.rows:
			for c: int in sim.level.cols:
				cells.append(sim.level.get_cell(r, c))
		var grid: Variant = sim.boss.grid.duplicate()
		var durability: int = sim.boss.durability
		var rng_draws: int = sim.rng.draw_count
		var fx_draws: int = sim.fx_rng.draw_count
		for angle: int in 36:
			var direction: Vector2 = Vector2.RIGHT.rotated(float(angle) * TAU / 36.0)
			var aim: PlayerSystem.Aim = PlayerSystem.Aim.new()
			aim.x = direction.x
			aim.y = direction.y
			ProjectileSystem.preview_path(sim, aim)
		check_eq(sim.boss.grid, grid)
		check_eq(sim.boss.durability, durability)
		check_eq(sim.rng.draw_count, rng_draws)
		check_eq(sim.fx_rng.draw_count, fx_draws)
		check_eq(sim.projectiles.size(), 0)
		check_eq(sim.particles.size(), 0)
		var index: int = 0
		for r: int in sim.level.rows:
			for c: int in sim.level.cols:
				check_eq(sim.level.get_cell(r, c), cells[index])
				index += 1
		check(not rows.is_empty(), "official source remains available")


func test_boss_contacts_in_preview_do_not_consume_shields_or_blocks() -> void:
	for slot: int in [20, 30, 40, 50]:
		var sim: GameSim = _sim(slot)
		sim.boss.state = BossState.State.ACTIVE
		sim.boss.x = 600.0
		sim.boss.y = 200.0
		if sim.boss_kind == BossState.Kind.MUD_GOLEM:
			# Its initial body is only the non-colliding core; model one fed cell.
			sim.boss.set_cell(sim.boss.center_r, sim.boss.center_c + 1, Tile.DIRT)
			BossMudGolem.update_bounds(sim)
		var shot: SimProjectile = SimProjectile.new()
		var grid: PackedInt32Array = sim.boss.grid.duplicate()
		var durability: int = sim.boss.durability
		if slot == 40:
			var shield: ShieldState = sim.boss.shields[0]
			shield.cx = 500.0
			shield.cy = 200.0
			check_eq(ProjectileSystem._hits_boss(sim, shot, shield.cx, shield.cy, true), ProjectileSystem.BossHit.SPENT)
			check(shield.active, "query does not consume the shield")
			check_eq(ProjectileSystem._hits_boss(sim, shot, sim.boss.center_x(), sim.boss.center_y(), true), ProjectileSystem.BossHit.SPENT)
		else:
			var contacts: int = 0
			for row: int in range(sim.boss.min_r, sim.boss.max_r + 1):
				for col: int in range(sim.boss.min_c, sim.boss.max_c + 1):
					if ProjectileSystem._hits_boss(sim, shot, sim.boss.cell_x(col) + 20.0, sim.boss.cell_y(row) + 20.0, true) != ProjectileSystem.BossHit.NONE:
						contacts += 1
			check(contacts > 0, "boss collision is included in the query")
		check_eq(sim.boss.grid, grid)
		check_eq(sim.boss.durability, durability)
		check_eq(sim.particles.size(), 0)
