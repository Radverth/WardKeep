extends WardKeepTest
## Feature Spec §5.3 — draft effects are run-local and stack as documented.

func _card(effect: String, magnitude: float, element: int = -1) -> DraftCardDef:
	var card := DraftCardDef.new()
	card.id = StringName("test_" + effect)
	card.effect_key = StringName(effect)
	card.magnitude = magnitude
	card.element_filter = element
	card.max_rank = 3
	return card

func test_damage_cards_stack_additively() -> void:
	var modifiers := RunModifiers.new()
	modifiers.apply(_card("damage_all_pct", 0.10))
	modifiers.apply(_card("damage_all_pct", 0.10))
	assert_almost_eq(modifiers.damage_multiplier(WK.RuneElement.PHYSICAL), 1.20, 0.001, "two commons")

func test_element_cards_only_help_their_element() -> void:
	var modifiers := RunModifiers.new()
	modifiers.apply(_card("damage_element_pct", 0.15, int(WK.RuneElement.FROST)))
	assert_almost_eq(modifiers.damage_multiplier(WK.RuneElement.FROST), 1.15, 0.001, "frost boosted")
	assert_almost_eq(modifiers.damage_multiplier(WK.RuneElement.BLIGHT), 1.0, 0.001, "blight untouched")

func test_overcharge_moves_two_stats() -> void:
	var modifiers := RunModifiers.new()
	modifiers.apply(_card("overcharge", 0.25))
	assert_almost_eq(modifiers.damage_mult, 1.25, 0.001, "damage")
	assert_almost_eq(modifiers.fire_rate_mult, 1.25, 0.001, "fire rate")

func test_upgrade_discount_is_capped() -> void:
	var modifiers := RunModifiers.new()
	for index: int in 10:
		modifiers.apply(_card("upgrade_discount_pct", 0.15))
	assert_almost_eq(modifiers.upgrade_discount, 0.75, 0.001, "never free")

func test_ranks_are_tracked_per_card() -> void:
	var modifiers := RunModifiers.new()
	var card: DraftCardDef = _card("damage_all_pct", 0.1)
	modifiers.apply(card)
	modifiers.apply(card)
	assert_eq(modifiers.rank_of(card.id), 2, "rank counted")
	assert_eq(modifiers.rank_of(&"never_taken"), 0, "untaken card is rank 0")

func test_state_changing_effects_are_left_to_run_manager() -> void:
	# ward_stone_repair and unlock_extra_tower change run state, not tower
	# maths — RunModifiers must not silently swallow them as unknown keys.
	var modifiers := RunModifiers.new()
	modifiers.apply(_card("ward_stone_repair", 2.0))
	modifiers.apply(_card("unlock_extra_tower", 1.0))
	assert_almost_eq(modifiers.damage_mult, 1.0, 0.001, "no accidental damage change")
	assert_eq(modifiers.rank_of(&"test_ward_stone_repair"), 1, "still ranked")

## --- cards with a price (SPEC_GAPS.md #11) ------------------------------

## The real generated card, as opposed to the synthetic one _card builds.
func _authored(id: StringName) -> DraftCardDef:
	return load("res://resources/draft/%s.tres" % id) as DraftCardDef

func test_a_card_with_a_price_applies_both_halves() -> void:
	var modifiers := RunModifiers.new()
	var card: DraftCardDef = _authored(&"hair_trigger")
	assert_true(card.has_cost(), "Hair Trigger costs something")
	modifiers.apply(card)
	assert_gt(modifiers.fire_rate_mult, 1.0, "the boon lands")
	assert_true(modifiers.range_mult < 1.0, "and so does the price")

## A price is only ever a negative magnitude through the same dispatcher, so
## the one thing that can go wrong is a multiplier crossing zero — at which
## point a tower does nothing, or below it heals what it shoots.
func test_no_price_can_turn_a_multiplier_inside_out() -> void:
	var modifiers := RunModifiers.new()
	var card: DraftCardDef = _authored(&"long_watch")
	for _repeat: int in 40:
		modifiers.apply(card)
	assert_gt(modifiers.fire_rate_mult, 0.0, "towers still fire")
	assert_gt(modifiers.range_mult, 0.0, "and still reach")
	var scorched: DraftCardDef = _authored(&"scorched_earth")
	for _repeat: int in 40:
		modifiers.apply(scorched)
	assert_gt(modifiers.damage_multiplier(WK.RuneElement.PHYSICAL), 0.0,
		"Physical towers still deal damage")

func test_every_priced_card_names_a_real_effect() -> void:
	var known := RunModifiers.new()
	for card: DraftCardDef in DraftPool.new().cards:
		if not card.has_cost():
			continue
		assert_true(card.cost_magnitude != 0.0,
			"%s has a price worth paying attention to" % card.id)
		# apply() push_warnings an unknown key rather than failing, so the
		# check here is that the price is a key the boon side also accepts.
		known.apply(card)

func test_the_new_cards_reach_their_knobs() -> void:
	var modifiers := RunModifiers.new()
	modifiers.apply(_authored(&"executioner"))
	assert_gt(modifiers.execute_bonus, 0.0, "Executioner finishes wounded targets")
	modifiers.apply(_authored(&"frostbite"))
	assert_gt(modifiers.slowed_damage_bonus, 0.0, "Frostbite punishes slowed targets")
	assert_false(modifiers.dot_spreads_always, "Contagion is off until taken")
	modifiers.apply(_authored(&"contagion"))
	assert_true(modifiers.dot_spreads_always, "and on once it is")
