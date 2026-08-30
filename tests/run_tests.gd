extends Node
## Test runner. Run it as a scene so the autoloads come up as they do in a
## build:
##
##   godot --headless --path . res://tests/Tests.tscn
##
## Exits non-zero if any suite fails.

const SUITE_DIR: String = "res://tests/"

func _ready() -> void:
	var suites: Array[String] = []
	var dir: DirAccess = DirAccess.open(SUITE_DIR)
	if dir != null:
		for file_name: String in dir.get_files():
			var name: String = file_name.trim_suffix(".remap")
			if name.begins_with("test_") and name.ends_with(".gd"):
				suites.append(SUITE_DIR + name)
	suites.sort()

	var total: int = 0
	var passed: int = 0
	var failures: Array[String] = []
	for path: String in suites:
		var script: GDScript = load(path) as GDScript
		if script == null:
			failures.append("%s: could not load" % path)
			continue
		var suite_name: String = path.get_file()
		print("\n", suite_name)
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			total += 1
			var suite: WardKeepTest = script.new()
			suite.before_each()
			suite.call(method_name)
			suite.after_each()
			if suite.failures.is_empty():
				passed += 1
				print("  PASS  ", method_name)
			else:
				print("  FAIL  ", method_name)
				for failure: String in suite.failures:
					print("          ", failure)
					failures.append("%s::%s — %s" % [suite_name, method_name, failure])

	print("\n=======================================")
	print("WARDKEEP tests: %d/%d passed" % [passed, total])
	if not failures.is_empty():
		print("failures:")
		for failure: String in failures:
			print("  ", failure)
	print("=======================================")
	get_tree().quit(0 if failures.is_empty() else 1)
