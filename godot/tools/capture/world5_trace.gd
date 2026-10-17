extends "res://tools/capture/world5_driver.gd"
func _ready() -> void:
	OUT="res://build/recordings/world5"
	stage=48
	var sim: Recorder=fresh()
	var replay: ReplayInput=ReplayInput.new()
	replay.sim=sim
	var from: String="ammo48candidate"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--from="): from=a.trim_prefix("--from=")
	replay.frames=JSON.parse_string(FileAccess.get_file_as_string(OUT+"/"+from+".json"))
	var carry: bool=false
	for i: int in replay.frames.size():
		sim.step(replay.sample(Vector2.ZERO))
		if i>2200 and (i%60==0 or carry!=sim.player.has_block):
			print(i," pos=",Vector2(sim.player.x,sim.player.y)," carry=",sim.player.has_block," cells=",sim.level.get_cell(2,20),",",sim.level.get_cell(3,20))
		carry=sim.player.has_block
	get_tree().quit()
