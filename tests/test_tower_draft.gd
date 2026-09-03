extends WardKeepTest
## The opening tower draft. PROVISIONAL (SPEC_GAPS.md #15) — Feature Spec §3.2
## says every unlocked tower is available in-run, and this deliberately
## narrows that, so these guard the shape rather than the numbers.

var _saved_data: Dictionary = {}

func before_each() -> void:
	_saved_data = SaveManager.data.duplicate(true)
	SaveManager.data = SaveManager.default_data()
	RunManager.run_roster.clear()
	RunManager.run_unlocked_towers.clear()

func after_each() -> void:
	super.after_each()
	SaveManager.data = _saved_data
	RunManager.run_roster.clear()
	RunManager.run_unlocked_towers.clear()

func _unlock_everything() -> void:
	for def: TowerDef in Registry.towers():
		SaveManager.unlock_tower(String(def.id))

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func test_the_offer_is_drawn_from_what_the_keep_hub_unlocked() -> void:
	_unlock_everything()
	var offer: Array[StringName] = TowerDraft.offer(_rng(7), RunManager.unlocked_towers())
	assert_eq(offer.size(), Balance.config().tower_offer_size, "a full offer")
	for id: StringName in offer:
		assert_true(SaveManager.is_tower_unlocked(String(id)), "%s is unlocked" % id)

func test_the_offer_never_repeats_a_tower() -> void:
	_unlock_everything()
	var offer: Array[StringName] = TowerDraft.offer(_rng(11), RunManager.unlocked_towers())
	var seen: Array[StringName] = []
	for id: StringName in offer:
		assert_true(id not in seen, "%s offered once" % id)
		seen.append(id)

## A fresh account has three starters. It must be offered exactly those and
## asked for all of them, rather than for an impossible fourth.
func test_a_new_account_is_never_asked_for_more_than_it_has() -> void:
	var unlocked: Array[TowerDef] = RunManager.unlocked_towers()
	assert_gt(float(unlocked.size()), 0.0, "the starters are unlocked")
	var offer: Array[StringName] = TowerDraft.offer(_rng(3), unlocked)
	assert_eq(offer.size(), unlocked.size(), "everything it owns is offered")
	assert_true(TowerDraft.picks_for(offer.size()) <= offer.size(),
		"it is not asked to pick more than it was offered")

## The Daily is the same run for everyone on a given day (Feature Spec §7), and
## the hand it is dealt is part of that.
func test_the_same_seed_deals_the_same_hand() -> void:
	_unlock_everything()
	var first: Array[StringName] = TowerDraft.offer(_rng(4242), RunManager.unlocked_towers())
	var second: Array[StringName] = TowerDraft.offer(_rng(4242), RunManager.unlocked_towers())
	assert_eq(first, second, "one seed, one offer")

func test_only_the_drafted_towers_can_be_built() -> void:
	_unlock_everything()
	var roster: Array[StringName] = [&"watchtower", &"ballista"]
	RunManager.run_roster = roster.duplicate()
	assert_true(RunManager.is_tower_available(&"watchtower"), "a drafted tower is available")
	assert_false(RunManager.is_tower_available(&"rot_censer"),
		"an unlocked tower that was not drafted is not")
	assert_eq(RunManager.available_towers().size(), roster.size(), "the tray holds the draft")

## A Hollow Charter now opens a tower left out of the draft, not only one the
## Keep Hub has never bought — which is what makes it worth taking.
func test_a_run_unlock_beats_the_draft() -> void:
	_unlock_everything()
	RunManager.run_roster = [&"watchtower"]
	assert_false(RunManager.is_tower_available(&"rot_censer"), "not drafted")
	RunManager.run_unlocked_towers.append(&"rot_censer")
	assert_true(RunManager.is_tower_available(&"rot_censer"), "until a charter opens it")

## A save from before the draft existed, or any run that starts without one,
## must not land in the Arena with an empty tray.
func test_no_draft_falls_back_to_every_unlock() -> void:
	_unlock_everything()
	RunManager.run_roster.clear()
	assert_eq(RunManager.available_towers().size(), Registry.towers().size(),
		"everything unlocked is buildable when nothing was drafted")

## A hand of nothing but slow fields has no way to end a wave, and a player who
## drafted one lost the run at the setup screen with nothing on the board to
## show them why. Support towers stay in the pool; they cannot be all of it.
func test_the_offer_always_deals_enough_damage_to_fill_a_hand() -> void:
	_unlock_everything()
	var picks: int = Balance.config().tower_draft_picks
	for seed_value: int in range(0, 200):
		var offer: Array[StringName] = TowerDraft.offer(
			_rng(seed_value), RunManager.unlocked_towers())
		var damage: int = 0
		for id: StringName in offer:
			if Registry.tower(id).deals_damage():
				damage += 1
		assert_true(damage >= picks,
			"seed %d offers %d damage towers for a hand of %d" % [seed_value, damage, picks])

func test_support_towers_are_still_offered() -> void:
	_unlock_everything()
	var seen_support: bool = false
	for seed_value: int in range(0, 200):
		for id: StringName in TowerDraft.offer(_rng(seed_value), RunManager.unlocked_towers()):
			if not Registry.tower(id).deals_damage():
				seen_support = true
	assert_true(seen_support, "guaranteeing damage did not push support out of the pool")
