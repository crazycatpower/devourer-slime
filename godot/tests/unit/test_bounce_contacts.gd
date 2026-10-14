extends TestCase
## Isolated contacts in the existing default room; no new level layouts.


func _sim() -> GameSim:
	var sim: GameSim = GameSim.new()
	sim.load_level(23, LevelLibrary.built_in_level(23), LevelLibrary.boss_kind_for_slot(23))
	return sim


func test_projectile_corner_uses_the_entered_face_in_all_directions() -> void:
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for vertical: bool in [false, true]:
				var sim: GameSim = _sim()
				sim.level.set_cell(5, 5, Tile.BOUNCY)
				var corner: Vector2 = Vector2(200.0 if sx > 0.0 else 240.0, 200.0 if sy > 0.0 else 240.0)
				var start: Vector2 = corner - Vector2(sx * (1.0 if vertical else 4.0), sy * (4.0 if vertical else 1.0))
				var shot: SimProjectile = SimProjectile.new()
				shot.x = start.x - shot.w / 2.0
				shot.y = start.y - shot.h / 2.0
				shot.vx = sx * 12.0
				shot.vy = sy * 12.0 - GameConstants.GRAVITY * ProjectileSystem.GRAVITY_SCALE
				var preview: SimProjectile = SimProjectile.new()
				preview.x = shot.x
				preview.y = shot.y
				preview.vx = shot.vx
				preview.vy = shot.vy
				check(ProjectileSystem._sweep(sim, preview, true), "preview sees the same corner contact")
				var hit: Vector2 = start + Vector2(sx, sy) * 4.0
				check_near(preview.x + preview.w / 2.0, hit.x, 0.01)
				check_near(preview.y + preview.h / 2.0, hit.y, 0.01)
				sim.projectiles.append(shot)
				ProjectileSystem.update(sim)
				check_eq(sim.projectiles.size(), 1)
				check_near(shot.vx, sx * 12.0 * (-0.9 if not vertical else 1.0), 0.001, "side normal only reverses X")
				check_near(shot.vy, sy * 12.0 * (-0.9 if vertical else 1.0), 0.001, "top/bottom normal only reverses Y")
				var expected: Vector2 = start + Vector2(sx, sy) * 4.0 + Vector2(shot.vx, shot.vy) * (2.0 / 3.0)
				check_near(shot.x + shot.w / 2.0, expected.x, 0.01, "bounce continues from the contact, without snapping to a grid cell")
				check_near(shot.y + shot.h / 2.0, expected.y, 0.01)


func test_player_tiny_bouncy_seam_does_not_override_main_floor_or_wall() -> void:
	for horizontal: bool in [false, true]:
		for majority_bouncy: bool in [false, true]:
			var sim: GameSim = _sim()
			sim.level.set_cell(5, 5, Tile.BOUNCY if majority_bouncy else Tile.STEEL)
			sim.level.set_cell(5 if not horizontal else 6, 6 if not horizontal else 5, Tile.STEEL if majority_bouncy else Tile.BOUNCY)
			var p: PlayerState = sim.player
			p.x = 200.0 - p.w - 1.0 if horizontal else 240.0 - p.w + 0.5
			p.y = 240.0 - p.h + 0.5 if horizontal else 200.0 - p.h - 1.0
			p.fall_start_y = p.y - 100.0
			p.vx = 8.0 if horizontal else 0.0
			p.vy = 0.0 if horizontal else 8.0
			if horizontal:
				Collision.solve_x(sim)
				check(p.vx < 0.0 if majority_bouncy else is_zero_approx(p.vx), "wall material follows the main contact")
			else:
				Collision.solve_y(sim)
				check(p.vy < 0.0 if majority_bouncy else is_zero_approx(p.vy), "floor material follows the main contact")


func test_projectile_does_not_bounce_sideways_at_a_continuous_floor_seam() -> void:
	for gap: float in [0.0, 0.1, 3.0]:
		var sim: GameSim = _sim()
		sim.level.set_cell(5, 4, Tile.BOUNCY)
		sim.level.set_cell(5, 5, Tile.BOUNCY)
		var shot: SimProjectile = SimProjectile.new()
		shot.x = 196.0 - shot.w / 2.0
		shot.y = 196.0 + gap - shot.h / 2.0
		shot.vx = 12.0
		shot.vy = 12.0 - GameConstants.GRAVITY * ProjectileSystem.GRAVITY_SCALE
		sim.projectiles.append(shot)
		ProjectileSystem.update(sim)
		check_near(shot.vx, 12.0, 0.001, "a floor seam preserves horizontal travel")
		check_near(shot.vy, -10.8, 0.001)


func test_exact_exposed_corner_reflects_both_axes() -> void:
	var sim: GameSim = _sim()
	sim.level.set_cell(5, 5, Tile.BOUNCY)
	var shot: SimProjectile = SimProjectile.new()
	shot.x = 196.0 - shot.w / 2.0
	shot.y = 196.0 - shot.h / 2.0
	shot.vx = 12.0
	shot.vy = 12.0 - GameConstants.GRAVITY * ProjectileSystem.GRAVITY_SCALE
	sim.projectiles.append(shot)
	ProjectileSystem.update(sim)
	check_near(shot.vx, -10.8, 0.001)
	check_near(shot.vy, -10.8, 0.001)


func test_bouncy_shot_only_rebounds_once_from_an_ordinary_wall() -> void:
	var sim: GameSim = _sim()
	sim.level.set_cell(5, 5, Tile.STEEL)
	var shot: SimProjectile = SimProjectile.new()
	shot.type = Tile.BOUNCY
	shot.x = 176.0
	shot.y = 179.0
	shot.vx = 12.0
	shot.vy = 12.0 - GameConstants.GRAVITY * ProjectileSystem.GRAVITY_SCALE
	sim.projectiles.append(shot)
	ProjectileSystem.update(sim)
	check_eq(shot.bounce_count, 1)
	check_near(shot.vx, -10.8, 0.001)
	check_near(shot.vy, 12.0, 0.001)
	# A second shot at the same wall with the spent bounce must settle.
	shot.x = 176.0
	shot.y = 179.0
	shot.vx = 12.0
	shot.vy = 12.0 - GameConstants.GRAVITY * ProjectileSystem.GRAVITY_SCALE
	ProjectileSystem.update(sim)
	check_eq(sim.projectiles.size(), 0)
	check_eq(shot.bounce_count, 1)
	check_eq(sim.level.get_cell(4, 4), Tile.BOUNCY)


func test_shot_covered_by_a_moving_bouncy_tile_separates_without_repeated_rebounds() -> void:
	var sim: GameSim = _sim()
	sim.level.set_cell(5, 5, Tile.BOUNCY)
	var shot: SimProjectile = SimProjectile.new()
	shot.x = 200.0
	shot.y = 200.0
	shot.vx = 12.0
	shot.vy = 6.0 - GameConstants.GRAVITY * ProjectileSystem.GRAVITY_SCALE
	sim.projectiles.append(shot)
	ProjectileSystem.update(sim)
	check_near(shot.vx, -10.8, 0.001)
	check(shot.x + shot.w / 2.0 < 200.0, "covered shot is separated onto the reflected side")
	ProjectileSystem.update(sim)
	check_near(shot.vx, -10.8, 0.001, "the next tick does not bounce again inside the same block")
