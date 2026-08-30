extends WardKeepTest
## Feature Spec §5 — draft offers, and §7's requirement that a seed reproduces
## the same sequence for every player on a given date.

var pool: DraftPool = null

func before_each() -> void:
	pool = DraftPool.new()

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func test_pool_loads_the_generated_cards() -> void:
	assert_gt(float(pool.cards.size()), 0.0, "cards loaded")
	for card: DraftCardDef in pool.cards:
		assert_ne(String(card.effect_key), "", "card %s has an effect" % card.id)

func test_always_offers_three_cards() -> void:
	var offers: Array[DraftCardDef] = pool.draw(_rng(1), RunModifiers.new(), [])
	assert_eq(offers.size(), Balance.config().draft_card_count, "three cards")

func test_offers_are_distinct_within_one_draw() -> void:
	var offers: Array[DraftCardDef] = pool.draw(_rng(7), RunModifiers.new(), [])
	var ids: Array = []
	for card: DraftCardDef in offers:
		assert_false(card.id in ids, "no duplicate in one draw")
		ids.append(card.id)

func test_same_seed_reproduces_the_same_draw() -> void:
	var first: Array[DraftCardDef] = pool.draw(_rng(20260830), RunModifiers.new(), [])
	var second: Array[DraftCardDef] = pool.draw(_rng(20260830), RunModifiers.new(), [])
	for index: int in first.size():
		assert_eq(first[index].id, second[index].id, "card %d matches" % index)

func test_different_seeds_diverge() -> void:
	var first: Array[DraftCardDef] = pool.draw(_rng(1), RunModifiers.new(), [])
	var second: Array[DraftCardDef] = pool.draw(_rng(999), RunModifiers.new(), [])
	var same: bool = true
	for index: int in first.size():
		if first[index].id != second[index].id:
			same = false
	assert_false(same, "different seeds should not produce identical offers")

func test_max_rank_cards_stop_being_eligible() -> void:
	var modifiers := RunModifiers.new()
	var card: DraftCardDef = pool.cards[0]
	for index: int in card.max_rank:
		modifiers.apply(card)
	for eligible: DraftCardDef in pool.eligible(modifiers, []):
		assert_ne(eligible.id, card.id, "maxed card is no longer eligible")

func test_element_cards_need_that_element_in_play() -> void:
	var modifiers := RunModifiers.new()
	var scoped: Array[DraftCardDef] = pool.eligible(modifiers, [int(WK.RuneElement.FROST)])
	for card: DraftCardDef in scoped:
		if card.element_filter >= 0:
			assert_eq(card.element_filter, int(WK.RuneElement.FROST), "only Frost-scoped cards offered")

func test_daily_seed_is_stable_for_a_date() -> void:
	assert_eq(RunManager.daily_seed("2026-08-30"), RunManager.daily_seed("2026-08-30"), "same date, same seed")
	assert_ne(RunManager.daily_seed("2026-08-30"), RunManager.daily_seed("2026-08-31"), "different dates differ")
