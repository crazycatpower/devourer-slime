extends SceneTree
## Headless test runner.
##
## Usage:
##   godot --headless --path godot -s res://tests/run_tests.gd [++ filter]
##
## Runs every `test_*.gd` under `res://tests/unit`
## whose path contains the optional filter (for example `unit` or
## `level`). Exits with status 1 when any check fails.

const TEST_DIRS: Array[String] = ["res://tests/unit"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var name_filter: String = ""
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if not user_args.is_empty():
		name_filter = user_args[0]

	var files: PackedStringArray = PackedStringArray()
	for dir_path: String in TEST_DIRS:
		_collect(dir_path, name_filter, files)
	files.sort()

	var total_tests: int = 0
	var total_checks: int = 0
	var all_failures: PackedStringArray = PackedStringArray()
	var started_ms: int = Time.get_ticks_msec()

	for path: String in files:
		var script: GDScript = load(path) as GDScript
		# A script with a parse error still loads as an object; it just cannot
		# be instantiated.
		if script == null or not script.can_instantiate():
			all_failures.append("%s: failed to compile" % path)
			continue
		var instance: Variant = script.new()
		if not instance is TestCase:
			all_failures.append("%s: does not extend TestCase" % path)
			continue
		var test: TestCase = instance
		var file_started_ms: int = Time.get_ticks_msec()
		var ran: int = 0
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			test.current_test = "%s::%s" % [path.get_file(), method_name]
			test.before_each()
			test.call(method_name)
			test.after_each()
			ran += 1
		total_tests += ran
		total_checks += test.check_count
		var status: String = "ok" if test.failures.is_empty() else "FAILED"
		print("  %-34s %3d tests  %7d checks  %5d ms  %s" % [
			path.get_file(), ran, test.check_count, Time.get_ticks_msec() - file_started_ms, status,
		])
		all_failures.append_array(test.failures)

	print("")
	for failure: String in all_failures:
		print("FAIL  " + failure)
	print("%d tests, %d checks, %d failures in %d ms" % [
		total_tests, total_checks, all_failures.size(), Time.get_ticks_msec() - started_ms,
	])
	quit(1 if not all_failures.is_empty() or total_tests == 0 else 0)


func _collect(dir_path: String, name_filter: String, out: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		if not file_name.begins_with("test_") or not file_name.ends_with(".gd"):
			continue
		var path: String = dir_path.path_join(file_name)
		if name_filter.is_empty() or path.contains(name_filter):
			out.append(path)
