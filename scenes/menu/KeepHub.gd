extends Control
## User Flow §3.6 — Towers (permanent unlocks), Cosmetics (skins) and Account
## (level, medals, lifetime stats). Costs come from Feature Spec §6.
##
## Perks is a fourth tab and an addition: §6 sells unlocks and cosmetics only,
## so once nine towers were bought Runestones had nothing left to buy but skins
## — a meta currency that stops mattering exactly when a player has proved they
## intend to keep playing. PROVISIONAL, SPEC_GAPS.md #10.

## Feature Spec §6.4 — Veteran needs account level 10; Legendary is the IAP
## bundle or 800 Runestones.
const SKIN_TIERS: Array[Dictionary] = [
	{"id": "default", "cost": 0, "level": 1},
	{"id": "veteran", "cost": 200, "level": 10},
	{"id": "legendary", "cost": 800, "level": 1},
]

@onready var _balance_label: Label = %BalanceLabel
@onready var _towers_list: VBoxContainer = %TowersList
## Runs are bucketed this many waves wide in the where-runs-end chart.
const CHART_BUCKET: int = 5
const CHART_BAR: Color = Color(0.85, 0.72, 0.36)
const CHART_TRACK: Color = Color(0.22, 0.20, 0.20)

@onready var _perks_list: VBoxContainer = %PerksList
@onready var _cosmetics_list: VBoxContainer = %CosmeticsList
@onready var _account_list: VBoxContainer = %AccountList
@onready var _medal_row: HBoxContainer = %MedalRow
@onready var _back_button: Button = %BackButton
@onready var _toast: Label = %Toast

func _ready() -> void:
	_back_button.pressed.connect(_on_back)
	SaveManager.runestones_changed.connect(func(_balance: int) -> void: _refresh())
	_refresh()

func _refresh() -> void:
	_balance_label.text = "%d Runestones" % SaveManager.runestones()
	_build_towers()
	_build_perks()
	_build_cosmetics()
	_build_account()

func _clear(container: Node) -> void:
	for child: Node in container.get_children():
		child.queue_free()

## --- perks tab ----------------------------------------------------------

func _build_perks() -> void:
	_clear(_perks_list)
	for perk: PerkDef in Registry.perks():
		_perks_list.add_child(_perk_row(perk))

func _perk_row(perk: PerkDef) -> Control:
	var row := PanelContainer.new()
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	row.add_child(box)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(text)

	var rank: int = SaveManager.perk_rank(String(perk.id))
	var title := Label.new()
	title.text = "%s   %s" % [perk.display_name, _pips(rank, perk.max_rank())]
	title.add_theme_font_size_override("font_size", 24)
	text.add_child(title)

	var subtitle := Label.new()
	subtitle.text = perk.description
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(subtitle)

	var action := Button.new()
	action.custom_minimum_size = Vector2(190, 72)
	if rank >= perk.max_rank():
		action.text = "Maxed"
		action.disabled = true
	else:
		var cost: int = perk.cost_for_next(rank)
		action.text = "%d ◆" % cost
		action.disabled = SaveManager.runestones() < cost
		action.pressed.connect(func() -> void:
			# Re-read the rank on press: the row was built before the player
			# could have bought anything else, and the cost climbs per rank.
			var current: int = SaveManager.perk_rank(String(perk.id))
			if current >= perk.max_rank():
				return
			if not SaveManager.buy_perk_rank(String(perk.id), perk.cost_for_next(current)):
				_show_toast("Not enough Runestones.")
				return
			AudioBus.select()
			_show_toast("%s is now rank %d." % [perk.display_name, current + 1])
			_refresh())
	box.add_child(action)
	return row

## Ranks as filled and empty pips, so the tab reads at a glance.
func _pips(rank: int, maximum: int) -> String:
	var out: String = ""
	for index: int in maximum:
		out += "●" if index < rank else "○"
	return out

## --- towers tab (Feature Spec §6.2) -------------------------------------

func _build_towers() -> void:
	_clear(_towers_list)
	var level: int = SaveManager.account_level()
	for def: TowerDef in Registry.towers():
		var row := PanelContainer.new()
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 14)
		row.add_child(box)

		var icon := TextureRect.new()
		icon.texture = def.texture()
		icon.custom_minimum_size = Vector2(72, 72)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = WK.element_tint(def.rune_element)
		box.add_child(icon)

		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(text)
		var title := Label.new()
		title.text = def.display_name
		title.add_theme_font_size_override("font_size", 24)
		text.add_child(title)
		var subtitle := Label.new()
		subtitle.text = "%s · %s" % [WK.element_name(def.rune_element), def.role]
		subtitle.add_theme_font_size_override("font_size", 17)
		subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(subtitle)

		var action := Button.new()
		action.custom_minimum_size = Vector2(190, 72)
		if SaveManager.is_tower_unlocked(String(def.id)):
			action.text = "Unlocked"
			action.disabled = true
		elif level < def.required_account_level:
			action.text = "Level %d" % def.required_account_level
			action.disabled = true
		else:
			action.text = "%d" % def.unlock_cost
			action.disabled = SaveManager.runestones() < def.unlock_cost
			action.pressed.connect(_on_unlock_tower.bind(def))
		box.add_child(action)
		_towers_list.add_child(row)

func _on_unlock_tower(def: TowerDef) -> void:
	if not SaveManager.spend_runestones(def.unlock_cost):
		_show_toast("Not enough Runestones.")
		return
	SaveManager.unlock_tower(String(def.id))
	AudioBus.select()
	_show_toast("%s unlocked." % def.display_name)
	_refresh()

## --- cosmetics tab (Feature Spec §6.4) ----------------------------------

func _build_cosmetics() -> void:
	_clear(_cosmetics_list)
	var level: int = SaveManager.account_level()
	for def: TowerDef in Registry.towers():
		if not SaveManager.is_tower_unlocked(String(def.id)):
			continue
		var row := PanelContainer.new()
		var box := VBoxContainer.new()
		row.add_child(box)
		var title := Label.new()
		title.text = def.display_name
		title.add_theme_font_size_override("font_size", 24)
		box.add_child(title)

		var options := HBoxContainer.new()
		options.add_theme_constant_override("separation", 10)
		box.add_child(options)
		for tier: Dictionary in SKIN_TIERS:
			options.add_child(_skin_button(def, tier, level))
		_cosmetics_list.add_child(row)
	if _cosmetics_list.get_child_count() == 0:
		var empty := Label.new()
		empty.text = "Unlock a tower to customise it."
		_cosmetics_list.add_child(empty)

func _skin_button(def: TowerDef, tier: Dictionary, level: int) -> Button:
	var skin_id: String = tier["id"]
	var full_id: String = "%s_%s" % [def.id, skin_id]
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 84)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var owned: bool = skin_id == "default" or SaveManager.is_skin_unlocked(full_id)
	var equipped: bool = SaveManager.equipped_skin(String(def.id)) == skin_id
	if equipped:
		button.text = "%s ✓" % UiKit.skin_display_name(skin_id)
		button.disabled = true
	elif owned:
		button.text = "Equip %s" % UiKit.skin_display_name(skin_id)
		button.pressed.connect(func() -> void:
			SaveManager.equip_skin(String(def.id), skin_id)
			AudioBus.select()
			_refresh())
	elif level < int(tier["level"]):
		button.text = "%s · Lv%d" % [UiKit.skin_display_name(skin_id), int(tier["level"])]
		button.disabled = true
	else:
		button.text = "%s · %d" % [UiKit.skin_display_name(skin_id), int(tier["cost"])]
		button.disabled = SaveManager.runestones() < int(tier["cost"])
		button.pressed.connect(func() -> void:
			if not SaveManager.spend_runestones(int(tier["cost"])):
				_show_toast("Not enough Runestones.")
				return
			SaveManager.unlock_skin(full_id)
			SaveManager.equip_skin(String(def.id), skin_id)
			AudioBus.select()
			_refresh())
	return button

## --- account tab (Feature Spec §6.3, §8) --------------------------------

func _build_account() -> void:
	_clear(_account_list)
	_clear(_medal_row)
	var level: int = SaveManager.account_level()
	var xp: int = SaveManager.account_xp()
	_add_stat("Rank", "%s · Level %d" % [UiKit.rank_name(level), level])
	if level < Balance.config().max_account_level:
		_add_stat("XP", "%d / %d" % [xp, Balance.xp_for_level(level + 1)])
	else:
		_add_stat("XP", "%d (max level)" % xp)
	_add_stat("Best wave", str(int(SaveManager.get_stat("best_wave", 0))))
	_add_stat("Runs played", str(int(SaveManager.get_stat("total_runs", 0))))
	_add_stat("Enemies killed", str(int(SaveManager.get_stat("total_enemies_killed", 0))))
	_add_stat("Runestones earned", str(int(SaveManager.get_stat("total_runestones_earned", 0))))
	_add_stat("Daily streak", str(int(SaveManager.get_value("daily_challenge_streak", 0))))
	var median: int = SaveManager.median_run_end()
	if median > 0:
		_add_stat("Runs usually end at", "Wave %d" % median)
	_build_run_end_chart()

	for index: int in UiKit.MEDAL_LEVELS.size():
		var milestone: int = UiKit.MEDAL_LEVELS[index]
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(78, 78)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = load("res://assets/sprites/ui/medals/flat_medal%d.png" % (index + 1))
		icon.modulate = Color.WHITE if level >= milestone else Color(0.3, 0.3, 0.3, 0.55)
		icon.tooltip_text = "Level %d" % milestone
		_medal_row.add_child(icon)

## Where runs actually end, bucketed in fives. Tuning an endless game's later
## waves needs to know where the wall is, and the smoke-test bot is not a
## player. Local only — nothing here leaves the device.
func _build_run_end_chart() -> void:
	var histogram: Dictionary = SaveManager.run_end_histogram()
	if histogram.is_empty():
		return
	var buckets: Dictionary = {}
	var tallest: int = 0
	for key: String in histogram:
		var bucket: int = (int(key) / CHART_BUCKET) * CHART_BUCKET
		buckets[bucket] = int(buckets.get(bucket, 0)) + int(histogram[key])
		tallest = maxi(tallest, int(buckets[bucket]))
	var edges: Array[int] = []
	for bucket: int in buckets:
		edges.append(bucket)
	edges.sort()
	var heading := Label.new()
	heading.text = "Where runs end"
	heading.add_theme_font_size_override("font_size", 22)
	_account_list.add_child(heading)
	for edge: int in edges:
		var count: int = int(buckets[edge])
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%d-%d" % [edge, edge + CHART_BUCKET - 1]
		label.custom_minimum_size = Vector2(120, 0)
		label.add_theme_font_size_override("font_size", 18)
		row.add_child(label)
		# Two stretched rectangles rather than a ProgressBar: the theme styles
		# the bar for the Ward Stone, where fill and track are both red, and a
		# histogram drawn in it reads as full at every height.
		var bar := HBoxContainer.new()
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size = Vector2(0, 26)
		bar.add_theme_constant_override("separation", 0)
		var filled := ColorRect.new()
		filled.color = CHART_BAR
		filled.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		filled.size_flags_stretch_ratio = maxf(0.001, float(count))
		bar.add_child(filled)
		var empty := ColorRect.new()
		empty.color = CHART_TRACK
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.size_flags_stretch_ratio = maxf(0.001, float(tallest - count))
		bar.add_child(empty)
		row.add_child(bar)
		var tally := Label.new()
		tally.text = str(count)
		tally.custom_minimum_size = Vector2(56, 0)
		tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tally.add_theme_font_size_override("font_size", 18)
		row.add_child(tally)
		_account_list.add_child(row)

func _add_stat(name: String, value: String) -> void:
	var row := HBoxContainer.new()
	var key := Label.new()
	key.text = name
	key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(key)
	var val := Label.new()
	val.text = value
	row.add_child(val)
	_account_list.add_child(row)

func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.show()
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(_toast):
		_toast.hide()

func _on_back() -> void:
	AudioBus.click()
	GameState.goto_scene(GameState.SCENE_MAIN_MENU)
