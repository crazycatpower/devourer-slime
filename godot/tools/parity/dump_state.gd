extends SceneTree
## Prints the simulation's moving parts after a given tick of a reference
## trace, in the same shape as `make_reference.mjs --dump`, so the two can be
## diffed when a parity test fails.
##
## Usage (`++` separates Godot's arguments from the script's):
##   godot --headless --path godot -s res://tools/parity/dump_state.gd ++ <scenario> <tick>


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		print("usage: dump_state.gd ++ <scenario name> <tick>")
		quit(2)
		return
	var player: TracePlayer = TracePlayer.new()
	if not player.load_trace("res://tests/parity/reference/%s.json.gz" % args[0]):
		print("cannot read trace %s" % args[0])
		quit(2)
		return
	var last_tick: int = mini(args[1].to_int(), player.tick_total)

	# Cumulative random draws after each of the last 12 ticks.
	var draws: PackedInt32Array = PackedInt32Array()
	var sim: GameSim = player.sim
	while player.tick < last_tick:
		player.advance()
		if player.tick > last_tick - 12:
			draws.append(sim.rng.draw_count)

	var particles: Array = []
	for q: SimParticle in sim.particles:
		particles.append([q.x, q.y, q.vx, q.vy, q.life, q.max_life])
	var projectiles: Array = []
	for q: SimProjectile in sim.projectiles:
		projectiles.append([q.x, q.y, q.vx, q.vy, q.type, 1 if q.is_enemy else 0])
	var falling: Array = []
	for q: SimFallingBlock in sim.falling_blocks:
		falling.append([q.x, q.y, q.vy, q.type, q.delay])
	var state_names: PackedStringArray = [
		"suspended", "intro", "falling", "active", "jumping", "charging", "pre_jump",
	]
	print(JSON.stringify({
		"draws": draws,
		"particles": particles,
		"projectiles": projectiles,
		"fallingBlocks": falling,
		"boss": {
			"x": sim.boss.x, "y": sim.boss.y, "vx": sim.boss.vx, "vy": sim.boss.vy,
			"state": state_names[sim.boss.state], "cooldown": sim.boss.cooldown,
		},
		"player": {
			"x": sim.player.x, "y": sim.player.y, "vx": sim.player.vx, "vy": sim.player.vy,
			"dead": sim.player.dead,
		},
	}))
	quit(0)
