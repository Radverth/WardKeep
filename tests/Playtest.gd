extends Node
## Headless smoke-test entry point. Run it as a scene so the autoloads come up
## exactly as they do in a real build:
##
##   godot --headless --path . res://tests/Playtest.tscn -- --waves 12
##
## Exits non-zero unless the run reaches the target wave.

const DEFAULT_TARGET: int = 12
## Gameplay-accurate, but there is no reason to wait in real time for it.
const TIME_SCALE: float = 8.0

func _ready() -> void:
	var target: int = DEFAULT_TARGET
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in args.size():
		if args[index] == "--waves" and index + 1 < args.size():
			target = int(args[index + 1])

	Engine.max_fps = 0
	Engine.time_scale = TIME_SCALE
	var arena: Arena = (load("res://scenes/run/Arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	var player := AutoPlayer.new()
	player.target_wave = target
	player.arena = arena
	player.report_ready.connect(_on_report)
	add_child(player)
	print("WARDKEEP playtest: target wave ", target)

func _on_report(report: Dictionary) -> void:
	print("--- playtest report ---")
	for key: String in report:
		print("  ", key, ": ", report[key])
	var ok: bool = String(report.get("reason", "")) == "target_reached"
	print("RESULT: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
