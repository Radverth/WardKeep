extends WardKeepTest
## Technical Architecture §4.2 — wave plans, scaling and reproducibility.

func _director_for(seed_value: int) -> void:
	WaveDirector.begin_run(seed_value)

func test_plan_spends_the_wave_budget() -> void:
	_director_for(42)
	var plan: Dictionary = WaveDirector.plan_for_wave(3)
	var spawns: Array = plan["spawns"]
	assert_gt(float(spawns.size()), 0.0, "wave 3 spawns something")
	var spent: int = 0
	for entry: Dictionary in spawns:
		spent += Registry.enemy(StringName(entry["id"])).budget_cost
	var budget: float = Balance.enemy_budget(3)
	assert_true(float(spent) <= budget, "never overspends the budget")
	# The leftover must be smaller than the cheapest archetype, or the
	# director stopped early.
	var cheapest: int = 999
	for def: EnemyDef in Registry.spawnable_enemies():
		if def.unlock_wave <= 3:
			cheapest = mini(cheapest, def.budget_cost)
	assert_true(budget - float(spent) < float(cheapest), "spends down to the remainder")

func test_only_unlocked_archetypes_appear() -> void:
	_director_for(9)
	for wave: int in [1, 3, 8]:
		for entry: Dictionary in (WaveDirector.plan_for_wave(wave)["spawns"] as Array):
			var def: EnemyDef = Registry.enemy(StringName(entry["id"]))
			if def.is_boss:
				continue
			assert_true(def.unlock_wave <= wave, "%s is unlocked by wave %d" % [def.id, wave])

func test_boss_waves_include_their_boss() -> void:
	_director_for(3)
	for pair: Array in [[10, "the_bulwark"], [20, "frostmaw"], [30, "the_hollow_king"], [40, "the_bulwark"]]:
		var plan: Dictionary = WaveDirector.plan_for_wave(int(pair[0]))
		assert_true(bool(plan["is_boss"]), "wave %d is a boss wave" % int(pair[0]))
		assert_eq(String(plan["boss_id"]), String(pair[1]), "wave %d boss" % int(pair[0]))
		var first: Dictionary = (plan["spawns"] as Array)[0]
		assert_true(bool(first["boss"]), "the boss leads the wave")

func test_elite_wave_marks_exactly_one_archetype() -> void:
	_director_for(11)
	var plan: Dictionary = WaveDirector.plan_for_wave(15)
	assert_true(bool(plan["is_elite"]), "wave 15 is elite")
	var elite_ids: Array = []
	for entry: Dictionary in (plan["spawns"] as Array):
		if bool(entry["elite"]) and entry["id"] not in elite_ids:
			elite_ids.append(entry["id"])
	assert_eq(elite_ids.size(), 1, "exactly one archetype is upgraded")
	assert_eq(String(elite_ids[0]), String(plan["elite_id"]), "matches the reported elite id")

func test_same_seed_reproduces_the_same_wave() -> void:
	_director_for(20260830)
	var first: Array = (WaveDirector.plan_for_wave(7)["spawns"] as Array).duplicate(true)
	_director_for(20260830)
	var second: Array = (WaveDirector.plan_for_wave(7)["spawns"] as Array).duplicate(true)
	assert_eq(first.size(), second.size(), "same spawn count")
	for index: int in first.size():
		assert_eq(String(first[index]["id"]), String(second[index]["id"]), "spawn %d matches" % index)

func test_wave_order_is_independent_of_other_rng_use() -> void:
	# A wave must resolve the same way regardless of what else consumed the
	# run RNG first — otherwise the Daily Challenge desyncs between players.
	_director_for(555)
	var expected: Array = (WaveDirector.plan_for_wave(9)["spawns"] as Array).duplicate(true)
	_director_for(555)
	WaveDirector.plan_for_wave(4)
	WaveDirector.plan_for_wave(5)
	var actual: Array = (WaveDirector.plan_for_wave(9)["spawns"] as Array).duplicate(true)
	for index: int in expected.size():
		assert_eq(String(expected[index]["id"]), String(actual[index]["id"]), "spawn %d matches" % index)

func test_hp_scales_but_speed_never_does() -> void:
	# Feature Spec §2.2 — HP and damage scale; speed is fixed per archetype.
	var grunt: EnemyDef = Registry.enemy(&"grunt")
	var early: Dictionary = WaveDirector.scaled_stats(grunt, 1, false)
	var late: Dictionary = WaveDirector.scaled_stats(grunt, 21, false)
	assert_almost_eq(float(early["hp"]), grunt.base_hp, 0.001, "wave 1 is unscaled")
	assert_almost_eq(float(late["hp"]), grunt.base_hp * 2.8, 0.01, "wave 21 multiplier")
	assert_almost_eq(float(late["speed"]), grunt.base_speed, 0.001, "speed never scales")

func test_elite_doubles_hp() -> void:
	var grunt: EnemyDef = Registry.enemy(&"grunt")
	var normal: Dictionary = WaveDirector.scaled_stats(grunt, 5, false)
	var elite: Dictionary = WaveDirector.scaled_stats(grunt, 5, true)
	assert_almost_eq(float(elite["hp"]), float(normal["hp"]) * 2.0, 0.001, "elite HP x2")

func test_extrapolates_past_the_authored_table() -> void:
	_director_for(1)
	var row: WaveRow = WaveDirector.row_for(500)
	assert_eq(row.wave, 500, "row built for an unauthored wave")
	assert_almost_eq(row.enemy_budget, Balance.enemy_budget(500), 0.001, "uses the §2.1 formula")
	assert_gt(float((WaveDirector.plan_for_wave(500)["spawns"] as Array).size()), 0.0, "still spawns")
