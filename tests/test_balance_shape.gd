extends WardKeepTest
## Guards the two balance decisions recorded in SPEC_GAPS.md #1 and #2. The
## Feature Spec fixes the tower *costs* and the §2.2 scaling, but not these
## shapes — so they are asserted here rather than left to be re-broken by a
## later tuning pass.

## Feature Spec §1: "the constraint is gold, not space". That only holds if
## upgrading is worth more per gold than another tier-1 tower — otherwise the
## right play is to spam the cheapest tower until the build tiles run out, and
## tiers 2 and 3 are dead content.
func test_upgrading_beats_buying_another_tower() -> void:
	for def: TowerDef in Registry.towers():
		if def.tier(0).is_aura or def.tier(0).damage <= 0.0:
			continue   # auras trade damage for utility; the ratio says nothing
		var spent: int = 0
		var tier_one_ratio: float = 0.0
		for index: int in 3:
			var tier: TowerTierData = def.tier(index)
			spent += tier.cost
			var ratio: float = tier.damage * tier.fire_rate / float(spent)
			if index == 0:
				tier_one_ratio = ratio
			else:
				assert_true(ratio >= tier_one_ratio,
					"%s tier %d returns %.3f dps/gold, tier 1 returns %.3f" % [
						def.id, index + 1, ratio, tier_one_ratio])

func test_tier_damage_climbs_every_step() -> void:
	for def: TowerDef in Registry.towers():
		if def.tier(0).damage <= 0.0:
			continue
		for index: int in 2:
			assert_gt(def.tier(index + 1).damage, def.tier(index).damage,
				"%s tier %d out-damages tier %d" % [def.id, index + 2, index + 1])

## Leak damage scales with the wave (§2.2) while the Ward Stone pool does not,
## so without a floor the heaviest enemy eventually one-shots a full Ward Stone
## and the run ends on a single mistake rather than on attrition.
func test_no_enemy_one_shots_a_full_ward_stone() -> void:
	var pool: int = Balance.config().ward_stone_hp
	var worst: EnemyDef = null
	for def: EnemyDef in Registry.spawnable_enemies():
		if worst == null or def.base_damage > worst.base_damage:
			worst = def
	for wave: int in [20, 30, 40]:
		var leak: float = worst.base_damage * Balance.stat_multiplier(wave)
		assert_true(leak < float(pool) * 0.5,
			"a wave %d %s leak costs %.1f of a %d pool" % [wave, worst.id, leak, pool])

## A leak should barely register early and hurt late — that gradient is the
## difficulty curve doing its job.
func test_leak_cost_grows_with_the_wave() -> void:
	var pool: float = float(Balance.config().ward_stone_hp)
	var grunt: EnemyDef = Registry.enemy(&"grunt")
	var early: float = grunt.base_damage * Balance.stat_multiplier(1) / pool
	var late: float = grunt.base_damage * Balance.stat_multiplier(30) / pool
	assert_true(early < 0.05, "an opening leak costs %.1f%%" % (early * 100.0))
	assert_gt(late, early * 2.0, "a late leak should cost materially more")


## Feature Spec §2.5 — a boss that reaches the Ward Stone hits it repeatedly
## rather than leaking through. That makes its damage a rate, not a one-off, so
## a single blow must leave the player a window to kill it.
func test_a_boss_blow_leaves_a_window() -> void:
	var pool: float = float(Balance.config().ward_stone_hp)
	for pair: Array in [["the_bulwark", 10], ["frostmaw", 20], ["the_hollow_king", 30]]:
		var boss: EnemyDef = Registry.enemy(StringName(pair[0]))
		assert_not_null(boss, "%s exists" % pair[0])
		if boss == null:
			continue
		var blow: float = boss.base_damage * Balance.stat_multiplier(int(pair[1]))
		assert_true(blow < pool * 0.5,
			"a wave %d %s blow costs %.1f of a %.0f pool" % [int(pair[1]), boss.id, blow, pool])

## The whole point of the change: a boss must outlive its arrival, or it is
## still just a leak with extra steps.
func test_bosses_carry_a_siege_pattern_not_a_leak() -> void:
	for boss: EnemyDef in Registry.bosses():
		assert_true(boss.is_boss, "%s is flagged as a boss" % boss.id)
		var scene: PackedScene = load(boss.scene_path) as PackedScene
		assert_not_null(scene, "%s scene loads" % boss.id)
		if scene == null:
			continue
		var instance: Node = scene.instantiate()
		assert_true(instance is Boss, "%s instantiates as a Boss" % boss.id)
		instance.free()
