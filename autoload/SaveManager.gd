extends Node
## Single versioned JSON save file at user://save.json.
## Schema is Technical Architecture §5 — every key there is written from day 1.

signal save_written()
signal runestones_changed(balance: int)
signal account_level_changed(level: int)

const SAVE_PATH: String = "user://save.json"
const CURRENT_SCHEMA_VERSION: int = 1

var data: Dictionary = {}

func _ready() -> void:
	load_save()
	# Perks reads ranks through this rather than naming the autoload, so it
	# still compiles when the project is scanned before autoloads exist.
	Perks.bind(self)

## --- schema -------------------------------------------------------------

func default_data() -> Dictionary:
	return {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"runestones": 0,
		## Keep Hub perk id -> ranks bought. See PerkDef / Perks.
		"perk_ranks": {},
		"account_level": 1,
		"account_xp": 0,
		"unlocked_towers": Balance.STARTER_TOWERS.duplicate(),
		"unlocked_skins": [],
		"equipped_skins": {},
		"daily_challenge_date": "",
		"daily_challenge_best_wave": 0,
		"daily_challenge_streak": 0,
		"settings": {
			"music_volume": 0.8,
			"sfx_volume": 1.0,
			"reduced_motion": false,
			## Index into WK.SPEED_STEPS — the run clock the player last chose.
			"game_speed_step": 0,
			"has_removed_ads": false,
		},
		"stats_lifetime": {
			"total_runs": 0,
			"best_wave": 0,
			"total_enemies_killed": 0,
			"total_runestones_earned": 0,
			"run_ends_since_interstitial": 0,
			"onboarding_complete": false,
			## Wave a run ended on -> how many runs ended there, as string keys
			## because JSON has no integer keys. See record_run_end.
			"run_end_waves": {},
		},
	}

## Adds any key introduced after a save file was first written, so an old
## install never reads a missing key. Recurses one level into the two
## dictionary-valued keys.
func _merge_defaults(loaded: Dictionary) -> Dictionary:
	var defaults: Dictionary = default_data()
	for key: String in defaults:
		if not loaded.has(key):
			loaded[key] = defaults[key]
		elif defaults[key] is Dictionary and loaded[key] is Dictionary:
			for sub_key: String in defaults[key]:
				if not loaded[key].has(sub_key):
					loaded[key][sub_key] = defaults[key][sub_key]
	return loaded

## Bring a save written by an older build up to CURRENT_SCHEMA_VERSION.
## Each step is one version bump so migrations chain.
func migrate(loaded: Dictionary) -> Dictionary:
	var version: int = int(loaded.get("schema_version", 0))
	# No shipped versions before 1 yet; a v0 file (or a corrupt one missing
	# the key) is treated as v1-shaped and repaired by _merge_defaults.
	if version < 1:
		version = 1
	loaded["schema_version"] = version
	return _merge_defaults(loaded)

## --- io -----------------------------------------------------------------

func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		data = default_data()
		write_save()
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("WARDKEEP: save unreadable (%s); starting fresh." % FileAccess.get_open_error())
		data = default_data()
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		data = migrate(parsed)
	else:
		push_warning("WARDKEEP: save corrupt; starting fresh.")
		data = default_data()

## Throws the ledger away and starts from the defaults. Used by the headless
## harness so a run measures the game rather than the machine's history.
func reset() -> void:
	data = default_data()
	write_save()

func write_save() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("WARDKEEP: could not write save (%s)." % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	save_written.emit()

## --- accessors ----------------------------------------------------------

func get_value(key: String, fallback: Variant = null) -> Variant:
	return data.get(key, fallback)

func set_value(key: String, value: Variant) -> void:
	data[key] = value

func get_setting(key: String, fallback: Variant = null) -> Variant:
	return (data.get("settings", {}) as Dictionary).get(key, fallback)

func set_setting(key: String, value: Variant) -> void:
	(data["settings"] as Dictionary)[key] = value
	write_save()

## --- run-end histogram ---------------------------------------------------

## Where runs actually end, which is the only way to tune an endless game's
## later waves on evidence rather than on how the smoke-test bot happened to
## do. Local only — nothing here is sent anywhere.
func record_run_end(wave: int) -> void:
	var histogram: Dictionary = data["stats_lifetime"].get("run_end_waves", {}) as Dictionary
	var key: String = str(maxi(0, wave))
	histogram[key] = int(histogram.get(key, 0)) + 1
	(data["stats_lifetime"] as Dictionary)["run_end_waves"] = histogram

func run_end_histogram() -> Dictionary:
	return (data.get("stats_lifetime", {}) as Dictionary).get("run_end_waves", {}) as Dictionary

## Median wave a run ends on, or 0 with nothing recorded. The median rather than
## the mean: one lucky run to wave 60 should not move the number that says where
## the wall is.
func median_run_end() -> int:
	var histogram: Dictionary = run_end_histogram()
	var total: int = 0
	for key: String in histogram:
		total += int(histogram[key])
	if total == 0:
		return 0
	var waves: Array[int] = []
	for key: String in histogram:
		waves.append(int(key))
	waves.sort()
	var seen: int = 0
	for wave: int in waves:
		seen += int(histogram[str(wave)])
		if seen * 2 >= total:
			return wave
	return waves[waves.size() - 1]

func get_stat(key: String, fallback: Variant = 0) -> Variant:
	return (data.get("stats_lifetime", {}) as Dictionary).get(key, fallback)

func set_stat(key: String, value: Variant) -> void:
	(data["stats_lifetime"] as Dictionary)[key] = value

func add_stat(key: String, amount: int) -> void:
	set_stat(key, int(get_stat(key, 0)) + amount)

## --- currency & progression --------------------------------------------

## --- perks ---------------------------------------------------------------

func perk_rank(id: String) -> int:
	return int((data.get("perk_ranks", {}) as Dictionary).get(id, 0))

## Buys one rank, or returns false and changes nothing. The cost is passed in
## rather than looked up so this stays a pure ledger operation — PerkDef owns
## what a rank costs, SaveManager owns whether it can be afforded.
func buy_perk_rank(id: String, cost: int) -> bool:
	if not spend_runestones(cost):
		return false
	var ranks: Dictionary = data["perk_ranks"] as Dictionary
	ranks[id] = perk_rank(id) + 1
	write_save()
	return true

func runestones() -> int:
	return int(data.get("runestones", 0))

func add_runestones(amount: int) -> void:
	data["runestones"] = maxi(0, runestones() + amount)
	if amount > 0:
		add_stat("total_runestones_earned", amount)
	write_save()
	runestones_changed.emit(runestones())

func spend_runestones(amount: int) -> bool:
	if amount > runestones():
		return false
	add_runestones(-amount)
	return true

func account_level() -> int:
	return int(data.get("account_level", 1))

func account_xp() -> int:
	return int(data.get("account_xp", 0))

## Feature Spec §6.3 — xp_required(level) = 100 x level^2, cumulative.
func add_account_xp(amount: int) -> int:
	var before: int = account_level()
	data["account_xp"] = account_xp() + amount
	data["account_level"] = Balance.level_for_xp(account_xp())
	write_save()
	if account_level() != before:
		account_level_changed.emit(account_level())
	return account_level() - before

func is_tower_unlocked(tower_id: String) -> bool:
	return tower_id in (data.get("unlocked_towers", []) as Array)

func unlock_tower(tower_id: String) -> void:
	var unlocked: Array = data.get("unlocked_towers", []) as Array
	if tower_id not in unlocked:
		unlocked.append(tower_id)
		write_save()

func is_skin_unlocked(skin_id: String) -> bool:
	return skin_id in (data.get("unlocked_skins", []) as Array)

func unlock_skin(skin_id: String) -> void:
	var unlocked: Array = data.get("unlocked_skins", []) as Array
	if skin_id not in unlocked:
		unlocked.append(skin_id)
		write_save()

func equipped_skin(tower_id: String) -> String:
	return str((data.get("equipped_skins", {}) as Dictionary).get(tower_id, "default"))

func equip_skin(tower_id: String, skin_id: String) -> void:
	(data["equipped_skins"] as Dictionary)[tower_id] = skin_id
	write_save()
