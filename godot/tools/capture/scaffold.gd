extends SceneTree
func _initialize() -> void:
	_start.call_deferred()
func _start() -> void:
	var script: GDScript = load("res://tools/capture/scaffold_driver.gd") as GDScript
	if not script.can_instantiate():
		quit(1)
		return
	var driver: Node = script.new()
	root.add_child(driver)
