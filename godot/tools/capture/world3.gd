extends SceneTree

func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	if not SavePaths.is_sandboxed():
		quit(2)
		return
	var script: GDScript = load("res://tools/capture/world3_routes.gd" if "--routes" in OS.get_cmdline_user_args() else "res://tools/capture/world3_driver.gd") as GDScript
	if script == null or not script.can_instantiate():
		quit(1)
		return
	var driver: Node = script.new()
	root.add_child(driver)
