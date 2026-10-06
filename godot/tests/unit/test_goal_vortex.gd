extends TestCase


func test_exit_uses_existing_goal_and_leaves_physics_unchanged() -> void:
	var sim: GameSim = GameSim.new()
	sim.load_level(1, LevelLibrary.built_in_level(1), BossState.Kind.NONE)
	sim.player.won = true
	var before: Vector2 = Vector2(sim.player.x, sim.player.y)
	var vortex: GoalVortex = GoalVortex.new()
	vortex.advance(0.016, sim)
	check(vortex.active)
	check_eq(sim.level.get_cell(floori(vortex.center.y / Tile.SIZE), floori(vortex.center.x / Tile.SIZE)), Tile.GOAL)
	check_near(vortex.position().x, sim.player.center_x())
	vortex.advance(GoalVortex.DURATION * 0.5, sim)
	check(not vortex.finished())
	check(vortex.position().distance_to(vortex.center) < vortex.origin.distance_to(vortex.center))
	vortex.advance(GoalVortex.DURATION, sim)
	check(vortex.finished())
	check_near(vortex.position().x, vortex.center.x)
	check_near(vortex.position().y, vortex.center.y)
	check_near(sim.player.x, before.x)
	check_near(sim.player.y, before.y)


func test_restart_cancels_exit_and_replaying_starts_from_zero() -> void:
	var sim: GameSim = GameSim.new()
	sim.load_level(1, LevelLibrary.built_in_level(1), BossState.Kind.NONE)
	var vortex: GoalVortex = GoalVortex.new()
	sim.player.won = true
	vortex.advance(0.0, sim)
	vortex.advance(0.7, sim)
	sim.reset()
	vortex.advance(0.016, sim)
	check(not vortex.active and not vortex.finished())
	check_near(vortex.age, 0.0)
	sim.player.won = true
	vortex.advance(0.016, sim)
	check(vortex.active)
	check_near(vortex.progress(), 0.0)
