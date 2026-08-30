extends RefCounted
class_name WardKeepTest
## Minimal GUT-shaped test base.
##
## Technical Architecture §7 specifies GUT. GUT is not vendored here (it is a
## third-party addon and this environment cannot fetch it), so the suites use
## the same `test_*` method convention and the same assertion names — dropping
## GUT into res://addons/ later means changing `extends WardKeepTest` to
## `extends GutTest` and deleting this file, nothing else.

var failures: Array[String] = []
var assertions: int = 0

func before_each() -> void:
	pass

func after_each() -> void:
	pass

func _fail(message: String) -> void:
	failures.append(message)

func assert_true(value: bool, message: String = "") -> void:
	assertions += 1
	if not value:
		_fail("expected true — %s" % message)

func assert_false(value: bool, message: String = "") -> void:
	assertions += 1
	if value:
		_fail("expected false — %s" % message)

func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	assertions += 1
	if actual != expected:
		_fail("expected %s got %s — %s" % [expected, actual, message])

func assert_ne(actual: Variant, expected: Variant, message: String = "") -> void:
	assertions += 1
	if actual == expected:
		_fail("expected something other than %s — %s" % [expected, message])

func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.001, message: String = "") -> void:
	assertions += 1
	if absf(actual - expected) > tolerance:
		_fail("expected %f ± %f got %f — %s" % [expected, tolerance, actual, message])

func assert_gt(actual: float, floor_value: float, message: String = "") -> void:
	assertions += 1
	if actual <= floor_value:
		_fail("expected > %f got %f — %s" % [floor_value, actual, message])

func assert_not_null(value: Variant, message: String = "") -> void:
	assertions += 1
	if value == null:
		_fail("expected non-null — %s" % message)
