extends SceneTree

func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	if not SavePaths.is_sandboxed():
		quit(2)
		return
	var script: GDScript = load("res://tools/capture/world4_driver.gd") as GDScript
	if script == null or not script.can_instantiate():
		quit(1)
		return
	var driver: Node = script.new()
	root.add_child(driver)
