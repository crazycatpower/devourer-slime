extends SceneTree
func _initialize() -> void:
	_start.call_deferred()
func _start() -> void:
	var path: String="res://tools/capture/world5_manual.gd" if "--manual" in OS.get_cmdline_user_args() else "res://tools/capture/world5_driver.gd"
	if "--boss" in OS.get_cmdline_user_args(): path="res://tools/capture/world5_boss.gd"
	if "--trace" in OS.get_cmdline_user_args(): path="res://tools/capture/world5_trace.gd"
	var script: GDScript=load(path) as GDScript
	var node: Node=script.new()
	root.add_child(node)


