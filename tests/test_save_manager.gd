extends WardKeepTest
## Technical Architecture §5 — the save schema and its migration path.

func test_default_data_has_every_documented_key() -> void:
	var data: Dictionary = SaveManager.default_data()
	for key: String in ["schema_version", "runestones", "account_level", "account_xp",
			"unlocked_towers", "unlocked_skins", "equipped_skins", "daily_challenge_date",
			"daily_challenge_best_wave", "settings", "stats_lifetime"]:
		assert_true(data.has(key), "schema key %s present" % key)
	assert_eq(int(data["schema_version"]), SaveManager.CURRENT_SCHEMA_VERSION, "schema version")
	assert_eq(int(data["account_level"]), 1, "new accounts start at level 1")

func test_starter_towers_are_unlocked_from_the_start() -> void:
	# Feature Spec §6.2 — one starter per rune element, free at level 1.
	var unlocked: Array = SaveManager.default_data()["unlocked_towers"]
	assert_eq(unlocked.size(), 3, "three starters")
	for id: String in Balance.STARTER_TOWERS:
		assert_true(id in unlocked, "%s unlocked by default" % id)

func test_migration_fills_keys_missing_from_an_older_save() -> void:
	var old_save: Dictionary = {"schema_version": 1, "runestones": 120}
	var migrated: Dictionary = SaveManager.migrate(old_save)
	assert_eq(int(migrated["runestones"]), 120, "existing values survive")
	assert_true(migrated.has("stats_lifetime"), "missing top-level key added")
	assert_true((migrated["settings"] as Dictionary).has("reduced_motion"), "missing nested key added")

func test_migration_repairs_a_versionless_save() -> void:
	var broken: Dictionary = {"runestones": 5}
	var migrated: Dictionary = SaveManager.migrate(broken)
	assert_eq(int(migrated["schema_version"]), SaveManager.CURRENT_SCHEMA_VERSION, "version stamped")
	assert_eq(int(migrated["account_level"]), 1, "defaults filled in")

func test_migration_does_not_clobber_nested_values() -> void:
	var save: Dictionary = {"schema_version": 1, "settings": {"music_volume": 0.2}}
	var migrated: Dictionary = SaveManager.migrate(save)
	assert_almost_eq(float(migrated["settings"]["music_volume"]), 0.2, 0.001, "player's volume kept")
	assert_true((migrated["settings"] as Dictionary).has("sfx_volume"), "sibling default added")

## --- run-end histogram ---------------------------------------------------
##
## These exercise the live singleton because the histogram is instance state,
## not a pure function. record_run_end deliberately does not write to disk —
## RunManager saves once at the end of a run — so this stays in memory, and
## the player's real save is put back afterwards regardless.

var _saved_data: Dictionary = {}

func before_each() -> void:
	_saved_data = SaveManager.data.duplicate(true)
	SaveManager.data = SaveManager.default_data()

func after_each() -> void:
	super.after_each()
	SaveManager.data = _saved_data

func test_the_histogram_counts_where_runs_ended() -> void:
	for wave: int in [4, 9, 9, 12, 30]:
		SaveManager.record_run_end(wave)
	var histogram: Dictionary = SaveManager.run_end_histogram()
	assert_eq(int(histogram.get("9", 0)), 2, "two runs ended on wave 9")
	assert_eq(int(histogram.get("30", 0)), 1, "one reached wave 30")

## The median rather than the mean: one lucky run to wave 60 should not move the
## number that says where the wall is.
func test_the_median_ignores_one_lucky_run() -> void:
	for _repeat: int in 9:
		SaveManager.record_run_end(8)
	SaveManager.record_run_end(60)
	assert_eq(SaveManager.median_run_end(), 8, "nine runs at wave 8 outweigh one at 60")

func test_an_empty_histogram_has_no_median() -> void:
	assert_eq(SaveManager.median_run_end(), 0, "nothing recorded yet")
