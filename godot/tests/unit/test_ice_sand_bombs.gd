extends TestCase
## Isolated material contacts in the existing default room.


func _sim() -> GameSim:
	var sim: GameSim = GameSim.new()
	sim.load_level(61, LevelCodec.decode(LevelLibrary.default_rows()), BossState.Kind.NONE)
	sim.mechanisms_enabled = true
	return sim


func test_shot_ice_attaches_to_ceiling_slides_to_wall_and_stops() -> void:
	for direction: int in [-1, 1]:
		var sim: GameSim = _sim()
		for col: int in range(4, 11):
			sim.level.set_cell(4, col, Tile.STEEL)
		sim.level.set_cell(5, 4 if direction < 0 else 10, Tile.STEEL)
		var shot: SimProjectile = SimProjectile.new()
		shot.type = Tile.ICE
		shot.x = 280.0
		shot.y = 190.0
		shot.vx = direction * 12.0
		shot.vy = -25.0
		sim.projectiles.append(shot)
		ProjectileSystem.update(sim)
		check(sim.projectiles.is_empty(), "upward shot settles beneath the ceiling")
		check(not sim.ceiling_slides.is_empty(), "upward contact selects ceiling sliding")
		for tick: int in range(4, 36, 4):
			sim.tick_count = tick
			MechanismSystem.update(sim)
		check_eq(sim.level.get_cell(5, 5 if direction < 0 else 9), Tile.ICE)
		check(sim.sliding_cells.is_empty() and sim.ceiling_slides.is_empty(), "wall ends sliding")


func test_ice_drops_when_the_ceiling_ends_and_reset_clears_attachment() -> void:
	var sim: GameSim = _sim()
	sim.level.set_cell(4, 7, Tile.STEEL)
	sim.level.set_cell(4, 8, Tile.STEEL)
	sim.level.set_cell(5, 7, Tile.ICE)
	MechanismSystem.start_slide(sim, Vector2i(7, 5), 12.0)
	sim.tick_count = 4
	MechanismSystem.update(sim)
	check_eq(sim.level.get_cell(5, 8), Tile.ICE, "ice stays beneath the ceiling")
	check(sim.ceiling_slides.has(Vector2i(8, 5)))
	sim.tick_count = 8
	MechanismSystem.update(sim)
	check_eq(sim.level.get_cell(6, 9), Tile.ICE, "ice falls at the end of the ceiling")
	check(sim.ceiling_slides.is_empty())
	sim.reset()
	check(sim.ceiling_slides.is_empty() and sim.sliding_cells.is_empty())


func test_sand_falls_into_each_spike_type_and_breaks_without_removing_spikes() -> void:
	for spike: int in [Tile.SPIKE_UP, Tile.SPIKE_DOWN, Tile.SPIKE_LEFT, Tile.SPIKE_RIGHT]:
		var sim: GameSim = _sim()
		sim.level.set_cell(5, 8, Tile.SAND)
		sim.level.set_cell(6, 8, spike)
		sim.tick_count = 6
		MechanismSystem.update(sim)
		check_eq(sim.level.get_cell(5, 8), Tile.AIR)
		check_eq(sim.level.get_cell(6, 8), spike)
		check(sim.level.sand_cells.is_empty())
		check(not sim.particles.is_empty(), "sand fragments show the destruction")


func test_sliding_ice_shatters_and_clears_motion_and_eating_target() -> void:
	var sim: GameSim = _sim()
	sim.level.set_cell(4, 7, Tile.STEEL)
	sim.level.set_cell(4, 8, Tile.STEEL)
	sim.level.set_cell(5, 7, Tile.ICE)
	sim.level.set_cell(5, 8, Tile.SPIKE_LEFT)
	sim.animate_tile_from(Vector2(260.0, 200.0), Vector2i(7, 5), 4)
	sim.player.set_eating_target(5, 7, false)
	MechanismSystem.start_slide(sim, Vector2i(7, 5), 12.0)
	sim.tick_count = 4
	MechanismSystem.update(sim)
	check_eq(sim.level.get_cell(5, 7), Tile.AIR)
	check_eq(sim.level.get_cell(5, 8), Tile.SPIKE_LEFT)
	check(sim.sliding_cells.is_empty() and sim.ceiling_slides.is_empty())
	check(not sim.tile_motions.has(Vector2i(7, 5)))
	check(not sim.player.has_eating_target)


func test_ice_and_sand_projectile_corners_break_on_spikes_and_preview_agrees() -> void:
	for type: int in [Tile.ICE, Tile.SAND]:
		var sim: GameSim = _sim()
		sim.level.set_cell(5, 8, Tile.SPIKE_LEFT)
		var shot: SimProjectile = SimProjectile.new()
		shot.type = type
		shot.x = 290.0
		shot.y = 182.0
		shot.vx = 18.0
		var preview: SimProjectile = SimProjectile.new()
		preview.type = type
		preview.x = shot.x
		preview.y = shot.y
		preview.vx = shot.vx
		check(ProjectileSystem._sweep(sim, preview, true), "preview sees corner contact before the center reaches the spike cell")
		check(sim.particles.is_empty(), "preview has no destruction effects")
		sim.projectiles.append(shot)
		ProjectileSystem.update(sim)
		check(sim.projectiles.is_empty())
		check_eq(sim.level.get_cell(5, 8), Tile.SPIKE_LEFT)
		check(not sim.particles.is_empty())


func test_thrown_glass_stops_at_every_interior_material() -> void:
	for type: int in [Tile.DIRT, Tile.GLASS, Tile.STEEL, Tile.BOUNCY, Tile.ICE, Tile.SAND, Tile.TNT]:
		var sim: GameSim = _sim()
		sim.level.set_cell(5, 6, type)
		var bomb: GlassBomb = GlassBomb.new()
		bomb.x = 200.0
		bomb.y = 220.0
		bomb.vx = 100.0
		check(BossGlassSlime._fly_bomb(sim.level, bomb))
		check_near(bomb.x, 240.0 - BossGlassSlime.BOMB_RADIUS, 0.001)
		check_eq(sim.level.get_cell(5, 6), type)
		check(not bomb.landed)


func test_thrown_glass_cannot_hit_player_behind_cover() -> void:
	var sim: GameSim = _sim()
	sim.level.set_cell(5, 6, Tile.STEEL)
	sim.player.place_at(300.0, 200.0)
	var bomb: GlassBomb = GlassBomb.new()
	bomb.x = 180.0
	bomb.y = 217.0
	bomb.vx = 200.0
	sim.boss.bombs.append(bomb)
	BossGlassSlime._update_bombs(sim)
	check(not sim.player.dead, "steel stops thrown glass and protects the player")
	check(sim.boss.bombs.is_empty(), "terrain impact removes thrown glass immediately")
	check_eq(sim.level.get_cell(5, 6), Tile.STEEL)


func test_thrown_glass_stops_at_all_arena_boundaries() -> void:
	for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var sim: GameSim = _sim()
		var bomb: GlassBomb = GlassBomb.new()
		bomb.x = 100.0 if direction.x <= 0.0 else sim.level.pixel_width() - 100.0
		bomb.y = 100.0 if direction.y <= 0.0 else sim.level.pixel_height() - 100.0
		bomb.vx = direction.x * 200.0
		bomb.vy = direction.y * 200.0
		check(BossGlassSlime._fly_bomb(sim.level, bomb), "outer wall stops the throw")
		check(bomb.x - BossGlassSlime.BOMB_RADIUS >= Tile.SIZE - 0.001)
		check(bomb.x + BossGlassSlime.BOMB_RADIUS <= sim.level.pixel_width() - Tile.SIZE + 0.001)
		check(bomb.y - BossGlassSlime.BOMB_RADIUS >= Tile.SIZE - 0.001)
		check(bomb.y + BossGlassSlime.BOMB_RADIUS <= sim.level.pixel_height() - Tile.SIZE + 0.001)


func test_thrown_glass_breaks_only_first_contact_without_blast_or_chain() -> void:
	for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var sim: GameSim = _sim()
		var target: Vector2i = Vector2i(8, 5)
		var adjacent: Vector2i = target + Vector2i(direction)
		sim.level.set_cell(target.y, target.x, Tile.GLASS)
		sim.level.set_cell(adjacent.y, adjacent.x, Tile.GLASS)
		sim.level.set_cell(7, 9, Tile.TNT)
		var center: Vector2 = (Vector2(target) + Vector2.ONE * 0.5) * Tile.SIZE
		var start: Vector2 = center - direction * 90.0
		var bomb: GlassBomb = GlassBomb.new()
		bomb.x = start.x
		bomb.y = start.y
		bomb.vx = direction.x * 200.0
		bomb.vy = direction.y * 200.0
		sim.player.place_at(center.x + 45.0, center.y + 30.0)
		sim.boss.bombs.append(bomb)
		BossGlassSlime._update_bombs(sim)
		check(sim.boss.bombs.is_empty(), "first contact consumes the throw")
		check_eq(sim.level.get_cell(target.y, target.x), Tile.AIR, "contacted glass breaks")
		check_eq(sim.level.get_cell(adjacent.y, adjacent.x), Tile.GLASS, "glass behind impact survives")
		check_eq(sim.level.get_cell(7, 9), Tile.TNT, "nearby TNT is not triggered")
		check(sim.tnt_charges.is_empty())
		check(not sim.player.dead, "nearby player receives no area damage")


func test_thrown_glass_direct_hit_still_hits_without_tunneling() -> void:
	var sim: GameSim = _sim()
	sim.player.place_at(300.0, 200.0)
	sim.level.set_cell(6, 8, Tile.GLASS)
	var bomb: GlassBomb = GlassBomb.new()
	bomb.x = 180.0
	bomb.y = 217.0
	bomb.vx = 200.0
	sim.boss.bombs.append(bomb)
	BossGlassSlime._update_bombs(sim)
	check(sim.player.dead, "direct swept contact hits the player")
	check(sim.boss.bombs.is_empty())
	check_eq(sim.level.get_cell(6, 8), Tile.GLASS, "direct player hit does not break nearby terrain")
