extends SceneTree

func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	if not "--sandbox" in OS.get_cmdline_user_args():
		quit(2)
		return
	var script: GDScript = load("res://tools/solve/replay_world3_mid_driver.gd") as GDScript
	var driver: Node = script.new()
	root.add_child(driver)
