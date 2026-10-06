class_name SafeConfig
extends RefCounted
## Keeps the previous valid settings/progress file while replacing the primary.


static func load_file(config: ConfigFile, path: String) -> Error:
	var error: Error = config.load(path)
	if error == OK:
		return OK
	config.clear()
	return config.load(path + ".bak")


static func save_file(config: ConfigFile, path: String) -> Error:
	var error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK:
		return error
	var temporary: String = path + ".tmp"
	error = config.save(temporary)
	if error != OK:
		return error
	var previous: ConfigFile = ConfigFile.new()
	if previous.load(path) == OK:
		error = previous.save(path + ".bak")
		if error != OK:
			return error
	# Godot's rename replaces an existing destination; never delete it first.
	return DirAccess.rename_absolute(temporary, path)
