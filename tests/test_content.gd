extends WardKeepTest
## Claude Code Brief Phase 3 acceptance: "every tower id and enemy id in the
## Feature Spec tables exists as a working resource + scene."

const EXPECTED_TOWERS: Array[String] = [
	"watchtower", "ballista", "palisade_ram",
	"rime_spire", "glacier_well", "icicle_battery",
	"rot_censer", "plague_caster", "bone_turret",
]
const EXPECTED_BOSSES: Array[String] = ["the_bulwark", "frostmaw", "the_hollow_king"]
const EXPECTED_ENEMY_COUNT: int = 12

func test_all_nine_towers_exist_with_three_tiers() -> void:
	assert_eq(Registry.towers().size(), EXPECTED_TOWERS.size(), "nine towers")
	for id: String in EXPECTED_TOWERS:
		var def: TowerDef = Registry.tower(StringName(id))
		assert_not_null(def, "%s resource exists" % id)
		if def == null:
			continue
		assert_eq(def.tiers.size(), 3, "%s has three tiers" % id)
		assert_true(ResourceLoader.exists(def.scene_path), "%s scene exists" % id)

func test_tower_costs_match_the_feature_spec_tables() -> void:
	# §4.1 / §4.2 / §4.3, tier 1 cost / tier 2 cost / tier 3 cost.
	var expected: Dictionary = {
		"watchtower": [20, 35, 60], "ballista": [30, 50, 90], "palisade_ram": [25, 40, 70],
		"rime_spire": [25, 40, 75], "glacier_well": [30, 50, 85], "icicle_battery": [35, 55, 95],
		"rot_censer": [25, 40, 70], "plague_caster": [30, 50, 85], "bone_turret": [30, 50, 90],
	}
	for id: String in expected:
		var def: TowerDef = Registry.tower(StringName(id))
		for tier: int in 3:
			assert_eq(def.tier(tier).cost, int(expected[id][tier]), "%s tier %d cost" % [id, tier + 1])

func test_tier_one_damage_and_rate_match_the_tables() -> void:
	assert_almost_eq(Registry.tower(&"watchtower").tier(0).damage, 4.0, 0.001, "watchtower damage")
	assert_almost_eq(Registry.tower(&"watchtower").tier(0).fire_rate, 1.4, 0.001, "watchtower rate")
	assert_almost_eq(Registry.tower(&"ballista").tier(0).damage, 10.0, 0.001, "ballista damage")
	assert_almost_eq(Registry.tower(&"ballista").tier(0).range_tiles, 4.0, 0.001, "ballista range")
	assert_almost_eq(Registry.tower(&"rime_spire").tier(0).slow_amount, 0.20, 0.001, "rime spire slow")
	assert_almost_eq(Registry.tower(&"rime_spire").tier(0).slow_duration, 4.0, 0.001, "rime spire slow duration")
	assert_almost_eq(Registry.tower(&"glacier_well").tier(0).slow_amount, 0.35, 0.001, "glacier well slow")
	assert_true(Registry.tower(&"glacier_well").tier(0).is_aura, "glacier well is an aura")
	assert_almost_eq(Registry.tower(&"icicle_battery").tier(0).bonus_vs_slowed, 0.5, 0.001, "icicle bonus")
	assert_almost_eq(Registry.tower(&"bone_turret").tier(0).bonus_vs_ethereal, 1.0, 0.001, "bone turret bonus")
	assert_true(Registry.tower(&"ballista").tier(0).ignores_armor_matchup, "ballista is armour-piercing")

func test_unlock_costs_match_the_keep_hub_table() -> void:
	# Feature Spec §6.2.
	for id: String in Balance.STARTER_TOWERS:
		var starter: TowerDef = Registry.tower(StringName(id))
		assert_eq(starter.unlock_cost, 0, "%s is free" % id)
		assert_eq(starter.required_account_level, 1, "%s needs level 1" % id)
	for id: String in ["ballista", "glacier_well", "plague_caster"]:
		assert_eq(Registry.tower(StringName(id)).unlock_cost, 150, "%s costs 150" % id)
		assert_eq(Registry.tower(StringName(id)).required_account_level, 3, "%s needs level 3" % id)
	for id: String in ["palisade_ram", "icicle_battery", "bone_turret"]:
		assert_eq(Registry.tower(StringName(id)).unlock_cost, 300, "%s costs 300" % id)
		assert_eq(Registry.tower(StringName(id)).required_account_level, 6, "%s needs level 6" % id)

func test_twelve_enemy_archetypes_plus_three_bosses() -> void:
	assert_eq(Registry.spawnable_enemies().size(), EXPECTED_ENEMY_COUNT, "twelve archetypes")
	assert_eq(Registry.bosses().size(), EXPECTED_BOSSES.size(), "three bosses")
	for def: EnemyDef in Registry.spawnable_enemies():
		assert_true(ResourceLoader.exists(def.scene_path), "%s scene exists" % def.id)
	for id: String in EXPECTED_BOSSES:
		var boss: EnemyDef = Registry.enemy(StringName(id))
		assert_not_null(boss, "%s resource exists" % id)
		if boss == null:
			continue
		assert_true(boss.is_boss, "%s is flagged as a boss" % id)
		assert_not_null(boss.boss_pattern_script, "%s has an attack pattern" % id)
		assert_true(ResourceLoader.exists(boss.scene_path), "%s scene exists" % id)

func test_all_three_armour_types_are_represented() -> void:
	# The §4 matchup rules only mean something if every armour type ships.
	var seen: Array = []
	for def: EnemyDef in Registry.spawnable_enemies():
		if def.armor_type not in seen:
			seen.append(def.armor_type)
	assert_eq(seen.size(), 3, "unarmoured, heavy and ethereal all present")

## §1 fixes the geometry, and every alternate board is cut to the same rules —
## so this runs over all of them, not just the spec's own.
func test_every_arena_matches_the_feature_spec_geometry() -> void:
	var boards: Array[ArenaMap] = Registry.maps()
	assert_gt(float(boards.size()), 1.0, "more than one board to choose from")
	for map: ArenaMap in boards:
		assert_eq(map.columns, 12, "%s: 12 columns" % map.id)
		assert_eq(map.rows, 20, "%s: 20 rows" % map.id)
		assert_eq(map.legend.size(), 20, "%s: one legend row per grid row" % map.id)
		assert_eq(map.build_tiles().size(), 34, "%s: 34 build tiles" % map.id)
		assert_gt(float(map.waypoints.size()), 3.0, "%s: the path has switchbacks" % map.id)
		assert_true(String(map.id) != "" and map.display_name != "",
			"%s: named for the picker" % map.id)
		for waypoint: Vector2i in map.waypoints:
			assert_true(waypoint.x >= 0 and waypoint.x < map.columns,
				"%s: waypoint inside the grid" % map.id)
			assert_true(waypoint.y >= 0 and waypoint.y < map.rows,
				"%s: waypoint inside the grid" % map.id)

## A tower on a longer lane gets more seconds of fire, so a board far longer
## than the spec's own would quietly be an easier difficulty setting.
func test_every_lane_is_comparable_in_length() -> void:
	var shortest: int = 9999
	var longest: int = 0
	for map: ArenaMap in Registry.maps():
		shortest = mini(shortest, map.lane_length())
		longest = maxi(longest, map.lane_length())
	assert_gt(float(shortest), 30.0, "no board is a sprint")
	assert_true(float(longest) <= float(shortest) * 1.25,
		"longest lane %d is within a quarter of the shortest %d" % [longest, shortest])

## The lane is one tile wide everywhere: the road tiler composites from a
## nine-slice ring and has no junction piece to draw.
func test_no_board_branches_its_lane() -> void:
	for map: ArenaMap in Registry.maps():
		for row: int in map.rows:
			for column: int in map.columns:
				if not map.is_path_tile(column, row):
					continue
				var neighbours: int = 0
				for offset: Vector2i in [Vector2i(0, -1), Vector2i(1, 0),
						Vector2i(0, 1), Vector2i(-1, 0)]:
					if map.is_path_tile(column + offset.x, row + offset.y) \
							or map.is_ward_stone(column + offset.x, row + offset.y):
						neighbours += 1
				assert_true(neighbours <= 2,
					"%s: lane branches at %d,%d" % [map.id, column, row])

func test_wave_table_is_authored_to_sixty() -> void:
	var table: WaveTable = Registry.wave_table()
	assert_eq(table.authored_length(), 60, "60 authored waves")
	for wave: int in [1, 10, 30, 60]:
		var row: WaveRow = table.row_for(wave)
		assert_almost_eq(row.enemy_budget, Balance.enemy_budget(wave), 0.001, "wave %d budget" % wave)

## The run-clock toggle multiplies whatever the host set rather than assigning
## over it — the headless playtest runs the clock at 8x, and an Arena that
## assigned 1x on _ready would silently slow every CI run to real time.
func test_speed_steps_start_at_real_time_and_climb() -> void:
	assert_gt(float(WK.SPEED_STEPS.size()), 1.0, "there is something to toggle")
	assert_almost_eq(WK.SPEED_STEPS[0], 1.0, 0.001, "the first step is real time")
	for index: int in range(1, WK.SPEED_STEPS.size()):
		assert_gt(WK.SPEED_STEPS[index], WK.SPEED_STEPS[index - 1],
			"step %d is faster than the one before" % index)

## The matchup hints the player is shown are derived from Balance rather than
## written down, so they cannot start lying the first time the multipliers move.
func test_matchup_hints_follow_the_balance_table() -> void:
	for armor: int in [WK.ArmorType.NONE, WK.ArmorType.HEAVY, WK.ArmorType.ETHEREAL]:
		var matchup: Dictionary = Balance.armor_matchup(armor)
		for name: String in matchup["strong"]:
			assert_true(name != "Unknown", "%s names a real element" % WK.armor_name(armor))
		assert_true(Balance.armor_matchup_line(armor).length() > 0,
			"%s has something to say" % WK.armor_name(armor))
	for element: int in [WK.RuneElement.PHYSICAL, WK.RuneElement.FROST, WK.RuneElement.BLIGHT]:
		assert_true(Balance.element_matchup_line(element).length() > 0,
			"%s has something to say" % WK.element_name(element))
	# §4: "Frost is strong vs HEAVY and weak vs ETHEREAL; Blight is strong vs
	# ETHEREAL". If a tuning pass breaks that, the hints follow it silently —
	# so the spec's own shape is asserted here too.
	assert_true(Balance.armor_matchup(WK.ArmorType.HEAVY)["strong"].has("Frost"),
		"Frost cuts through Heavy")
	assert_true(Balance.armor_matchup(WK.ArmorType.ETHEREAL)["weak"].has("Frost"),
		"Frost slides off Ethereal")
	assert_true(Balance.armor_matchup(WK.ArmorType.ETHEREAL)["strong"].has("Blight"),
		"Blight cuts through Ethereal")
