class_name SavePaths
extends RefCounted
## Where the game keeps its files.
##
## Automated runs pass `--sandbox` as a user argument (after `++`), which
## redirects everything into `user://sandbox/` so that tests can never read or
## overwrite a real player's settings, progress or levels.

const SANDBOX_FLAG: String = "--sandbox"
const SANDBOX_DIR: String = "user://sandbox"


static func is_sandboxed() -> bool:
	return SANDBOX_FLAG in OS.get_cmdline_user_args()


static func root() -> String:
	return SANDBOX_DIR if is_sandboxed() else "user://"


static func settings_file() -> String:
	return root().path_join("settings.cfg")


static func progress_file() -> String:
	return root().path_join("progress.cfg")


static func custom_levels_dir() -> String:
	return root().path_join("levels")


## Deletes everything in the sandbox. Does nothing outside sandboxed runs.
static func wipe_sandbox() -> void:
	if is_sandboxed():
		_remove_recursive(SANDBOX_DIR)
		DirAccess.make_dir_recursive_absolute(SANDBOX_DIR)


static func _remove_recursive(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_remove_recursive(path.path_join(sub))
	for file_name: String in dir.get_files():
		dir.remove(file_name)
	DirAccess.remove_absolute(path)
