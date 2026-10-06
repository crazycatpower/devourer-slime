extends SceneTree
func _initialize() -> void:
	var s: Object = (load("res://tools/solve/solve.gd") as GDScript).new()
	var data: LevelData = LevelCodec.decode(LevelLibrary.built_in_rows(3))
	var sim: GameSim = GameSim.new()
	sim.load_level(1, data, BossState.Kind.NONE)
	var t0: int = Time.get_ticks_usec()
	for _i in 200:
		var _c: Variant = s.call("_clone_sim", sim)
	var t1: int = Time.get_ticks_usec()
	var inp: SimInput = SimInput.new()
	for _i in 2000:
		sim.step(inp)
	var t2: int = Time.get_ticks_usec()
	print("clone %.0f us, step %.0f us" % [(t1-t0)/200.0, (t2-t1)/2000.0])
	quit()
