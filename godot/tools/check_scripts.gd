extends SceneTree
## Loads every GDScript file and scene in the project so that parse errors,
## strict-typing violations and broken scene references surface in one run.
##
## Usage:  godot --headless --path godot -s res://tools/check_scripts.gd

const ROOTS: Array[String] = ["res://src", "res://tests", "res://tools"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var paths: PackedStringArray = PackedStringArray()
	for root_path: String in ROOTS:
		_collect(root_path, paths)
	paths.sort()

	var failed: PackedStringArray = PackedStringArray()
	for path: String in paths:
		var resource: Resource = load(path)
		if resource == null:
			failed.append(path)
		elif resource is GDScript:
			var script: GDScript = resource
			if not script.can_instantiate():
				failed.append(path)

	for path: String in failed:
		print("FAILED  " + path)
	print("%d files checked, %d failed" % [paths.size(), failed.size()])
	quit(1 if not failed.is_empty() else 0)


func _collect(dir_path: String, out: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for file_name: String in dir.get_files():
		if file_name.ends_with(".gd") or file_name.ends_with(".tscn"):
			out.append(dir_path.path_join(file_name))
