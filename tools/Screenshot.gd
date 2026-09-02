extends Node
## Build tool — renders a scene headlessly and writes a PNG, so a visual change
## can be checked without a device. Excluded from exports along with the rest
## of tools/.
##
##   xvfb-run godot --rendering-driver opengl3 --path . --resolution 768x1280 \
##       tools/Screenshot.tscn -- --scene=res://scenes/run/Arena.tscn \
##       --out=/tmp/arena.png --frames=120
##
## --boss= takes any enemy id, or several separated by commas.
## Also takes --showcase (one funded tower of every archetype), --boss=<id>
## (or --boss=all) and --play (hand the board to the smoke-test driver).

func _ready() -> void:
	var scene_path: String = "res://scenes/run/Arena.tscn"
	var out_path: String = "user://screenshot.png"
	var frames: int = 60
	var auto_play: bool = false
	var showcase: bool = false
	var boss_id: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--scene="):
			scene_path = argument.trim_prefix("--scene=")
		elif argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
		elif argument.begins_with("--frames="):
			frames = int(argument.trim_prefix("--frames="))
		elif argument == "--play":
			auto_play = true
		elif argument == "--showcase":
			showcase = true
		elif argument.begins_with("--map="):
			GameState.pending_map_id = StringName(argument.trim_prefix("--map="))
		elif argument.begins_with("--boss="):
			boss_id = argument.trim_prefix("--boss=")
	# The first-run tutorial dims the whole board, which is exactly what a
	# screenshot of the board must not have over it.
	SaveManager.set_stat("onboarding_complete", true)
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("Screenshot: cannot load %s" % scene_path)
		get_tree().quit(1)
		return
	var scene: Node = packed.instantiate()
	get_tree().root.add_child.call_deferred(scene)
	if showcase:
		# One of every archetype on the board, funded outright, so a shot shows
		# the whole tower roster instead of whatever the economy afforded.
		await get_tree().process_frame
		await get_tree().process_frame
		RunManager.gold = 100000
		var slots: Array = (scene.get("_slots") as Dictionary).values()
		slots.sort_custom(func(a: Node, b: Node) -> bool:
			return a.grid_cell.y * 100 + a.grid_cell.x < b.grid_cell.y * 100 + b.grid_cell.x)
		var defs: Array = Registry.towers()
		for index: int in mini(slots.size(), defs.size() * 2):
			var def: Resource = defs[index % defs.size()]
			scene.set("_armed_def", def)
			scene.call("_try_place", slots[index].grid_cell)
			if index >= defs.size():
				var tower: Node = slots[index].tower
				if tower != null:
					tower.call("upgrade")
					tower.call("upgrade")
		scene.set("_armed_def", null)
	if boss_id != "":
		await get_tree().process_frame
		await get_tree().process_frame
		# Any enemy id, not only bosses — the supports need a shot too.
		var wanted: Array = (boss_id.split(",") if boss_id != "all" else
			["the_bulwark", "frostmaw", "the_hollow_king"])
		for index: int in wanted.size():
			var boss: Resource = Registry.enemy(StringName(wanted[index]))
			if boss != null:
				scene.call("_spawn", boss, false,
					0.30 + 0.22 * float(index), 30)
	if auto_play:
		# Let the smoke-test driver buy and upgrade, so the shot shows a board
		# with towers on it rather than an empty field.
		await get_tree().process_frame
		var driver: Node = (load("res://tests/AutoPlayer.gd") as Script).new()
		driver.set("arena", scene)
		driver.set("verbose", false)
		get_tree().root.add_child(driver)
	for _frame: int in frames:
		await get_tree().process_frame
	print("Screenshot: towers=%d wave=%d gold=%d" % [
		RunManager.placed_towers.size(), RunManager.wave, RunManager.gold])
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var error: int = image.save_png(out_path)
	print("Screenshot: %s -> %s (%d)" % [scene_path, out_path, error])
	get_tree().quit(0 if error == OK else 1)
