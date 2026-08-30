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
