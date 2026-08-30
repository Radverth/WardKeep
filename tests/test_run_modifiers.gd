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
