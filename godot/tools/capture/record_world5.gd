extends SceneTree

func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	if not "--sandbox" in OS.get_cmdline_user_args():
		quit(2)
		return
	var script: GDScript = load("res://tools/capture/record_world5_driver.gd") as GDScript
	if script == null or not script.can_instantiate():
		quit(1)
		return
	var driver: Node = script.new()
	root.add_child(driver)

