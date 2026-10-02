extends SceneTree
## Saves a screenshot of every screen to `tests/output/`, for reviewing the
## game's look without playing through it. Needs a real window (no
## `--headless`) and runs sandboxed so it leaves real saves alone:
##
##   godot --path godot --resolution 1280x720 -s res://tools/capture/capture_screens.gd ++ --sandbox
##
## This file only bootstraps; see `capture_driver.gd` (a `-s` script is
## compiled before the project's autoloads exist).


func _initialize() -> void:
	if not "--sandbox" in OS.get_cmdline_user_args():
		print("capture_screens: refusing to run without `++ --sandbox`")
		quit(2)
		return
	_start.call_deferred()


func _start() -> void:
	var script: GDScript = load("res://tools/capture/capture_driver.gd") as GDScript
	if script == null or not script.can_instantiate():
		print("capture_screens: the driver script failed to compile")
		quit(1)
		return
	var driver: Node = Node.new()
	driver.process_mode = Node.PROCESS_MODE_ALWAYS
	driver.set_script(script)
	root.add_child(driver)
	driver.call(&"run")
