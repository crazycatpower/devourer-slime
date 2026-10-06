extends SceneTree
## End-to-end smoke test: boots the real application and drives it through
## its main flows (see `smoke_driver.gd`).
##
## Must run sandboxed so it never touches a real player's saves:
##   godot --headless --path godot -s res://tests/smoke/smoke_test.gd ++ --sandbox
##
## Exits with status 1 when an expectation fails. Script errors show up in the
## output; `tools/test.ps1` treats those as failures too.
##
## This file only bootstraps: a `-s` script is compiled before the project's
## autoloads exist, so everything that touches the game lives in the driver,
## which is loaded once the tree is up.


func _initialize() -> void:
	if not "--sandbox" in OS.get_cmdline_user_args():
		print("smoke_test: refusing to run without `++ --sandbox`")
		quit(2)
		return
	_start.call_deferred()


func _start() -> void:
	var driver_path: String = "res://tests/smoke/smoke_driver.gd"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--driver="):
			driver_path = argument.trim_prefix("--driver=")
	var script: GDScript = load(driver_path) as GDScript
	if script == null or not script.can_instantiate():
		print("smoke_test: the driver script failed to compile")
		quit(1)
		return
	var driver: Node = Node.new()
	driver.set_script(script)
	root.add_child(driver)
	driver.call(&"run")
