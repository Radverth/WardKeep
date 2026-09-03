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
	var inspect_id: String = ""
	var tab_index: int = -1
	var arm_flare: bool = false
	var arm_tower: bool = false
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
		elif argument == "--arm":
			arm_tower = true
		elif argument == "--flare":
			arm_flare = true
		elif argument.begins_with("--roster="):
			for id: String in argument.trim_prefix("--roster=").split(","):
				GameState.pending_tower_ids.append(StringName(id))
		elif argument == "--unlock-all":
			for def: Resource in Registry.towers():
				SaveManager.unlock_tower(String(def.id))
		elif argument == "--seed-history":
			for wave: int in [6, 8, 8, 9, 11, 12, 12, 13, 14, 17, 19, 22, 28]:
				SaveManager.record_run_end(wave)
		elif argument.begins_with("--tab="):
			tab_index = int(argument.trim_prefix("--tab="))
		elif argument.begins_with("--inspect="):
			inspect_id = argument.trim_prefix("--inspect=")
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
		# Open the panel on one of them, so a shot covers the tower readout too.
		var first: Node = slots[0].tower
		if first != null:
			scene.call("_select_tower", first)
	if boss_id != "":
		await get_tree().process_frame
		await get_tree().process_frame
		# Any enemy id, not only bosses — the supports need a shot too.
		var wanted: Array = (boss_id.split(",") if boss_id != "all" else
			["the_bulwark", "frostmaw", "the_hollow_king"])
		for index: int in wanted.size():
			var boss: Resource = Registry.enemy(StringName(wanted[index]))
			if boss == null:
				print("Screenshot: no enemy named %s" % wanted[index])
				continue
			var spawned: Node = scene.call("_spawn", boss, false,
				0.30 + 0.22 * float(index), 30)
			# Say what actually landed on the board. A sprite that silently
			# fails to draw is otherwise indistinguishable from one that never
			# spawned, and both look like an empty screenshot.
			if spawned == null:
				print("Screenshot: %s did not spawn" % wanted[index])
			else:
				var sprite: Sprite2D = spawned.get_node_or_null("Sprite")
				print("Screenshot: spawned %s visible=%s pos=%s sprite=%s scale=%s tex=%s"
					% [wanted[index], spawned.visible, spawned.global_position,
					   "-" if sprite == null else str(sprite.visible),
					   "-" if sprite == null else str(sprite.scale),
					   "-" if sprite == null or sprite.texture == null
						   else str(sprite.texture.get_size())])
	if auto_play:
		# Let the smoke-test driver buy and upgrade, so the shot shows a board
		# with towers on it rather than an empty field.
		await get_tree().process_frame
		var driver: Node = (load("res://tests/AutoPlayer.gd") as Script).new()
		driver.set("arena", scene)
		driver.set("verbose", false)
		get_tree().root.add_child(driver)
	if arm_tower:
		await get_tree().process_frame
		await get_tree().process_frame
		scene.call("_on_tower_armed", Registry.towers()[0])
	if arm_flare:
		await get_tree().process_frame
		await get_tree().process_frame
		scene.call("_on_ability_pressed")
	if tab_index >= 0:
		await get_tree().process_frame
		var tabs: Node = scene.find_child("Tabs", true, false)
		if tabs != null:
			tabs.set("current_tab", tab_index)
	if inspect_id != "":
		await get_tree().process_frame
		await get_tree().process_frame
		scene.get_node("UI/EnemyPanel").call("open", Registry.enemy(StringName(inspect_id)))
	for _frame: int in frames:
		await get_tree().process_frame
	print("Screenshot: towers=%d wave=%d gold=%d" % [
		RunManager.placed_towers.size(), RunManager.wave, RunManager.gold])
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var error: int = image.save_png(out_path)
	print("Screenshot: %s -> %s (%d)" % [scene_path, out_path, error])
	get_tree().quit(0 if error == OK else 1)
