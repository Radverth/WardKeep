extends WardKeepTest
## Feature Spec §2 and §3 arithmetic, checked against the tables verbatim.

func test_wave_budget_matches_band_formulas() -> void:
	# §2.1: 1-5 => 10 + 6 x (wave-1)
	assert_almost_eq(Balance.enemy_budget(1), 10.0, 0.001, "wave 1 budget")
	assert_almost_eq(Balance.enemy_budget(4), 28.0, 0.001, "wave 4 budget")
	# §2.1: 6-10 => 40 + 9 x (wave-6)
	assert_almost_eq(Balance.enemy_budget(6), 40.0, 0.001, "wave 6 budget")
	assert_almost_eq(Balance.enemy_budget(9), 67.0, 0.001, "wave 9 budget")
	# §2.1: 11-30 => 80 + 12 x (wave-11)
	assert_almost_eq(Balance.enemy_budget(11), 80.0, 0.001, "wave 11 budget")
	assert_almost_eq(Balance.enemy_budget(30), 308.0, 0.001, "wave 30 budget")
	# §2.1: 31+ => 308 + 15 x (wave-31), continuous with the band above
	assert_almost_eq(Balance.enemy_budget(31), 308.0, 0.001, "wave 31 budget")
	assert_almost_eq(Balance.enemy_budget(60), 743.0, 0.001, "wave 60 budget")

func test_elite_waves_multiply_the_budget() -> void:
	# §2.3: every 5th wave, excluding boss waves, x1.4
	assert_true(Balance.is_elite_wave(5), "wave 5 is elite")
	assert_true(Balance.is_elite_wave(15), "wave 15 is elite")
	assert_false(Balance.is_elite_wave(10), "wave 10 is a boss wave, not elite")
	assert_false(Balance.is_elite_wave(20), "wave 20 is a boss wave, not elite")
	assert_almost_eq(Balance.enemy_budget(5), 34.0 * 1.4, 0.001, "elite budget")

func test_spawn_interval_floors_at_seven_tenths() -> void:
	assert_almost_eq(Balance.spawn_interval(1), 1.2, 0.001, "band 1")
	assert_almost_eq(Balance.spawn_interval(6), 1.0, 0.001, "band 2")
	assert_almost_eq(Balance.spawn_interval(11), 0.85, 0.001, "band 3")
	assert_almost_eq(Balance.spawn_interval(31), 0.7, 0.001, "band 4")
	assert_almost_eq(Balance.spawn_interval(400), 0.7, 0.001, "no cap past the table")

func test_stat_multiplier_has_no_ceiling() -> void:
	# §2.2: 1 + 0.09 x (wave-1), §2.4: never capped
	assert_almost_eq(Balance.stat_multiplier(1), 1.0, 0.001, "wave 1")
	assert_almost_eq(Balance.stat_multiplier(11), 1.9, 0.001, "wave 11")
	assert_gt(Balance.stat_multiplier(500), 45.0, "no cap on the curve")

func test_boss_waves_cycle_every_ten() -> void:
	# §2.5: 10/20/30, then the same three cycling
	assert_eq(Balance.boss_index_for_wave(10), 0, "Bulwark")
	assert_eq(Balance.boss_index_for_wave(20), 1, "Frostmaw")
	assert_eq(Balance.boss_index_for_wave(30), 2, "Hollow King")
	assert_eq(Balance.boss_index_for_wave(40), 0, "cycles back to Bulwark")
	assert_eq(Balance.boss_index_for_wave(70), 0, "still cycling at 70")
	assert_eq(Balance.boss_index_for_wave(11), -1, "not a boss wave")

func test_gold_rewards_match_the_economy_table() -> void:
	# §3: kill = 2 + floor(wave/3); elite = 1.5x; boss = 50 + 5 x wave
	assert_eq(Balance.gold_for_kill(1), 2, "wave 1 kill")
	assert_eq(Balance.gold_for_kill(9), 5, "wave 9 kill")
	assert_eq(Balance.gold_for_kill(9, true), 7, "wave 9 elite kill")
	assert_eq(Balance.gold_for_kill(10, false, true), 100, "wave 10 boss")
	# §3: wave-clear bonus = 5 + wave
	assert_eq(Balance.wave_clear_bonus(1), 6, "wave 1 clear bonus")
	assert_eq(Balance.wave_clear_bonus(30), 35, "wave 30 clear bonus")
	# §3: sell refunds 60%
	assert_eq(Balance.sell_refund(100), 60, "sell refund")

func test_runestone_bank_rates() -> void:
	# §6.1: floor(waves x 3 x rate), rate 1.0 banked / 0.75 on a loss
	assert_eq(Balance.runestones_for_run(10, true), 30, "banked")
	assert_eq(Balance.runestones_for_run(10, false), 22, "ward stone fell")
	assert_eq(Balance.runestones_for_run(0, true), 0, "no waves survived")

func test_account_level_thresholds() -> void:
	# §6.3: xp_required(level) = 100 x level^2, cumulative, cap 30
	assert_eq(Balance.xp_for_level(2), 400, "level 2 threshold")
	assert_eq(Balance.xp_for_level(3), 900, "level 3 threshold")
	assert_eq(Balance.xp_for_level(30), 90000, "level 30 threshold")
	assert_eq(Balance.level_for_xp(0), 1, "a new account is level 1")
	assert_eq(Balance.level_for_xp(399), 1, "just short of level 2")
	assert_eq(Balance.level_for_xp(400), 2, "exactly level 2")
	assert_eq(Balance.level_for_xp(1_000_000), 30, "capped at 30")
	# §6.3: xp per run = waves x 5
	assert_eq(Balance.xp_for_run(12), 60, "xp for a 12-wave run")

func test_element_matchups() -> void:
	# §4: Physical neutral; Frost strong vs HEAVY, weak vs ETHEREAL;
	# Blight strong vs ETHEREAL, neutral vs HEAVY.
	var cfg: BalanceConfig = Balance.config()
	assert_almost_eq(Balance.element_multiplier(WK.RuneElement.PHYSICAL, WK.ArmorType.HEAVY), 1.0, 0.001, "physical neutral")
	assert_almost_eq(Balance.element_multiplier(WK.RuneElement.FROST, WK.ArmorType.HEAVY),
		cfg.element_strong_multiplier, 0.001, "frost strong vs heavy")
	assert_almost_eq(Balance.element_multiplier(WK.RuneElement.FROST, WK.ArmorType.ETHEREAL),
		cfg.element_weak_multiplier, 0.001, "frost weak vs ethereal")
	assert_almost_eq(Balance.element_multiplier(WK.RuneElement.BLIGHT, WK.ArmorType.ETHEREAL),
		cfg.element_strong_multiplier, 0.001, "blight strong vs ethereal")
	assert_almost_eq(Balance.element_multiplier(WK.RuneElement.BLIGHT, WK.ArmorType.HEAVY), 1.0, 0.001, "blight neutral vs heavy")

## --- Ward Flare (PROVISIONAL, SPEC_GAPS.md #12) -------------------------

## Scaled by the same §2.2 multiplier that scales enemy health, so the flare is
## worth the same at wave 40 as at wave 4 rather than fading to a rounding
## error — which is what a flat number would do against 1 + 0.09 x (wave - 1).
func test_ward_flare_keeps_pace_with_enemy_health() -> void:
	var early: float = Balance.ability_damage(1)
	var late: float = Balance.ability_damage(40)
	assert_gt(early, 0.0, "the flare does something at wave 1")
	assert_almost_eq(late / early, Balance.stat_multiplier(40), 0.001,
		"the flare scales exactly as enemy health does")

func test_ward_flare_is_a_burst_not_a_tower() -> void:
	var cfg: BalanceConfig = Balance.config()
	assert_gt(cfg.ability_cooldown, 10.0,
		"a long enough cooldown that it is a decision, not a rotation")
	assert_gt(cfg.ability_radius_tiles, 0.0, "it covers ground")
	# A flare that one-shots the wave it lands on removes the towers' job.
	var grunt: EnemyDef = Registry.enemy(&"grunt")
	var wave: int = 20
	var flare: float = Balance.ability_damage(wave)
	var brute_hp: float = Registry.enemy(&"ogre").base_hp * Balance.stat_multiplier(wave)
	assert_true(flare < brute_hp, "the flare does not delete an Ogre outright")
	assert_gt(flare, grunt.base_hp * Balance.stat_multiplier(wave),
		"but it clears the fodder it lands on")

## --- tower upkeep (PROVISIONAL, SPEC_GAPS.md #16) -----------------------

## Feature Spec §1 wants gold to be the constraint. Filling the board was
## strictly correct until upkeep existed, so these guard the shape that makes
## going wide a decision: free up to a working line, then a bill that climbs
## faster than the board does.
func test_a_working_line_costs_nothing_to_hold() -> void:
	var free: int = Balance.config().upkeep_free_towers
	assert_eq(Balance.upkeep_for(10, free), 0, "the free allowance is free")
	assert_eq(Balance.upkeep_for(10, 1), 0, "an opening tower is free")
	assert_gt(Balance.upkeep_for(10, free + 1), 0, "one past it is not")

func test_wages_climb_faster_than_the_garrison() -> void:
	var free: int = Balance.config().upkeep_free_towers
	var small: int = Balance.upkeep_for(20, free + 4)
	var double: int = Balance.upkeep_for(20, free + 8)
	assert_gt(double, small * 2,
		"twice the excess costs more than twice as much, so widening compounds")

## Tied to the per-kill reward rather than a flat number, so it neither
## throttles wave 2 nor becomes a rounding error at wave 40.
func test_wages_keep_pace_with_the_economy() -> void:
	var towers: int = Balance.config().upkeep_free_towers + 6
	var early: int = Balance.upkeep_for(2, towers)
	var late: int = Balance.upkeep_for(40, towers)
	assert_gt(late, early, "the same board costs more when a kill is worth more")
	# Loose because the bill is floored to whole gold at both ends; what this
	# guards is that the two grow together, not that they round alike.
	var kill_growth: float = float(Balance.gold_for_kill(40)) / float(Balance.gold_for_kill(2))
	assert_almost_eq(float(late) / float(early), kill_growth, kill_growth * 0.1,
		"and it tracks the kill reward rather than drifting from it")

## A bill that jumped when one more tower crossed a boundary would put an
## invisible wall in front of a player who could see no reason for it.
func test_wages_have_no_cliff() -> void:
	var free: int = Balance.config().upkeep_free_towers
	var previous: int = 0
	var biggest_step: int = 0
	for towers: int in range(free, free + 20):
		var owed: int = Balance.upkeep_for(30, towers)
		assert_true(owed >= previous, "the bill never falls as the board grows")
		biggest_step = maxi(biggest_step, owed - previous)
		previous = owed
	assert_gt(float(Balance.upkeep_for(30, free + 20)) / 2.0, float(biggest_step),
		"no single tower more than doubles what the last one cost")
