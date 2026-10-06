extends TestCase

const PATH: String = "user://test_tmp/config_recovery.cfg"


func after_each() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)


func test_replace_and_recover_last_valid_save() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("progress", "cleared", PackedInt32Array([10]))
	check_eq(SafeConfig.save_file(config, PATH), OK)
	config.set_value("progress", "cleared", PackedInt32Array([10, 20]))
	check_eq(SafeConfig.save_file(config, PATH), OK)
	var loaded: ConfigFile = ConfigFile.new()
	check_eq(SafeConfig.load_file(loaded, PATH), OK)
	check_eq(loaded.get_value("progress", "cleared"), PackedInt32Array([10, 20]))
	# Model an interrupted write without touching the player's files.
	var broken: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	broken.store_string("[progress\ncleared=broken")
	broken.close()
	# ConfigFile reports expected malformed syntax through the engine logger.
	var printed_errors: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	check_eq(SafeConfig.load_file(loaded, PATH), OK)
	check_eq(loaded.get_value("progress", "cleared"), PackedInt32Array([10]))
	check_eq(SafeConfig.save_file(config, PATH), OK)
	Engine.print_error_messages = printed_errors
	var backup: ConfigFile = ConfigFile.new()
	check_eq(backup.load(PATH + ".bak"), OK)
	check_eq(backup.get_value("progress", "cleared"), PackedInt32Array([10]), "corrupt primary does not replace backup")
	check(not FileAccess.file_exists(PATH + ".tmp"))
