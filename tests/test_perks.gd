extends WardKeepTest
## Keep Hub perks. PROVISIONAL (SPEC_GAPS.md #10 — Feature Spec §6 has no perk
## table), so these guard the shape rather than the values: costs must climb, a
## rank must be worth something, and no perk may be strong enough to decide a
## run on its own.

## Stands in for SaveManager so the maths can be exercised at ranks nobody has
## bought. Perks reads ranks through an injected source for exactly this reason.
class StubRanks extends Object:
	var ranks: Dictionary = {}
	func perk_rank(id: String) -> int:
		return int(ranks.get(id, 0))

var _stub: StubRanks = null

func before_each() -> void:
	_stub = StubRanks.new()
	Perks.bind(_stub)

func after_each() -> void:
	super.after_each()
	# Static state: leaving the stub bound would break every later suite.
	Perks.bind(SaveManager)
	if _stub != null:
		_stub.free()
		_stub = null

func _max_out() -> void:
	for perk: PerkDef in Registry.perks():
		_stub.ranks[String(perk.id)] = perk.max_rank()

func test_every_perk_is_buyable_and_worth_something() -> void:
	var perks: Array[PerkDef] = Registry.perks()
	assert_gt(float(perks.size()), 0.0, "there are perks to buy")
	for perk: PerkDef in perks:
		assert_gt(float(perk.max_rank()), 0.0, "%s has at least one rank" % perk.id)
		assert_gt(absf(perk.per_rank), 0.0, "%s does something per rank" % perk.id)
		assert_true(perk.display_name != "" and perk.description != "",
			"%s is presentable in the Keep Hub" % perk.id)

func test_each_rank_costs_more_than_the_last() -> void:
	for perk: PerkDef in Registry.perks():
		for rank: int in range(1, perk.max_rank()):
			assert_gt(float(perk.cost_for_next(rank)), float(perk.cost_for_next(rank - 1)),
				"%s rank %d costs more than rank %d" % [perk.id, rank + 1, rank])

func test_an_unbought_perk_is_worth_nothing() -> void:
	for effect: StringName in [Perks.STARTING_GOLD, Perks.WARD_STONE_HP,
			Perks.GOLD_PER_KILL, Perks.UPGRADE_DISCOUNT, Perks.RUNESTONE_BONUS,
			Perks.WAVE_REPAIR]:
		assert_almost_eq(Perks.value(effect), 0.0, 0.001, "%s starts at zero" % effect)
	assert_almost_eq(Perks.runestone_multiplier(), 1.0, 0.001, "and banks the base rate")

func test_buying_ranks_moves_the_numbers() -> void:
	_max_out()
	assert_gt(float(Perks.starting_gold_bonus()), 0.0, "gold to start with")
	assert_gt(float(Perks.ward_stone_bonus()), 0.0, "a sturdier Ward Stone")
	assert_gt(Perks.runestone_multiplier(), 1.0, "a better tithe")

## A meta upgrade that visibly wins a run by itself turns the early waves into a
## formality for a returning player and a wall for a new one, and this game has
## no separate difficulty setting to absorb that.
func test_a_fully_bought_keep_does_not_decide_the_run() -> void:
	_max_out()
	var base_gold: int = Balance.config().starting_gold
	assert_true(float(Perks.starting_gold_bonus()) <= float(base_gold) * 0.75,
		"starting gold bonus %d against a base of %d" % [
			Perks.starting_gold_bonus(), base_gold])
	var base_ward: int = Balance.config().ward_stone_hp
	assert_true(float(Perks.ward_stone_bonus()) <= float(base_ward) * 0.5,
		"Ward Stone bonus %d against a base of %d" % [
			Perks.ward_stone_bonus(), base_ward])
	assert_true(Perks.upgrade_discount() <= 0.5, "upgrades are never free")

## Every effect a perk names has to be one Perks actually reads, or the perk is
## sold to the player and then quietly does nothing.
func test_no_perk_turns_a_knob_nobody_reads() -> void:
	var known: Array[StringName] = [Perks.STARTING_GOLD, Perks.WARD_STONE_HP,
		Perks.GOLD_PER_KILL, Perks.UPGRADE_DISCOUNT, Perks.RUNESTONE_BONUS,
		Perks.WAVE_REPAIR]
	for perk: PerkDef in Registry.perks():
		assert_true(known.has(perk.effect),
			"%s turns '%s', which nothing reads" % [perk.id, perk.effect])
