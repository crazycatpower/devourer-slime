extends "res://tools/capture/record_world1_driver.gd"
## Walk into an existing stage's hazard, then verify the rendered history reverses.

var saw_death: bool = false
var reversed_frames: int = 0
var previous_history_tick: int = -1
var restarted_frames: int = 0
var reset_count: int = 0
var spawn_x: float = 0.0

func _begin() -> void:
	super._begin()
	spawn_x = replay.sim.player.x
	replay.sim.level_reset.connect(func() -> void: reset_count += 1)
	replay.frames = []
	for tick: int in 1200:
		replay.frames.append({"left": false, "right": true, "jump": false,
			"jp": false, "eat": false, "shoot": false, "released": false,
			"mx": 0.0, "my": 0.0})

func _process(_delta: float) -> void:
	if game == null:
		return
	movie_frame += 1
	if get_tree().paused:
		get_tree().paused = false
		(game.get_node("%PauseMenu") as Control).hide()
	var sim: GameSim = replay.sim
	var view: WorldView = game.get_node("%WorldView")
	if sim.player.dead:
		saw_death = true
		replay.frames.clear()
		if view.rewinding and view.sim != sim:
			if previous_history_tick > view.sim.tick_count:
				reversed_frames += 1
			previous_history_tick = view.sim.tick_count
	elif saw_death:
		restarted_frames += 1
		if restarted_frames == 60:
			var safe: bool = reset_count == 0 and sim.player.x > spawn_x + 10.0 and not sim.player.dead
			print("REWIND reversed_frames=%d resets=%d safe=%s recovered_x=%s spawn_x=%s" % [reversed_frames, reset_count, safe, sim.player.x, spawn_x])
			get_tree().quit(0 if reversed_frames > 5 and safe else 1)
	if movie_frame > 1200:
		push_error("Rewind capture timed out before a verified retry")
		get_tree().quit(1)
