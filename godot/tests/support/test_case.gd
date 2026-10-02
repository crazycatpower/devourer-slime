class_name TestCase
extends RefCounted
## Base class for the project's unit tests.
##
## A test file extends this class and defines methods whose names start with
## `test_`. `tests/run_tests.gd` discovers and runs them. Checks record
## failures instead of aborting, so one run reports every broken expectation.

var failures: PackedStringArray = PackedStringArray()
var check_count: int = 0
var current_test: String = ""


## Called before every test method.
func before_each() -> void:
	pass


## Called after every test method.
func after_each() -> void:
	pass


func fail(message: String) -> void:
	failures.append("%s: %s" % [current_test, message])


func check(condition: bool, message: String = "expected condition to be true") -> void:
	check_count += 1
	if not condition:
		fail(message)


func check_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	check_count += 1
	if typeof(actual) != typeof(expected) or actual != expected:
		fail("%sexpected %s, got %s" % [_prefix(message), var_to_str(expected), var_to_str(actual)])


func check_near(
	actual: float, expected: float, tolerance: float = 1e-6, message: String = ""
) -> void:
	check_count += 1
	if absf(actual - expected) > tolerance:
		fail("%sexpected %.9f, got %.9f (tolerance %s)" % [_prefix(message), expected, actual, tolerance])


func _prefix(message: String) -> String:
	return "" if message.is_empty() else message + " - "
