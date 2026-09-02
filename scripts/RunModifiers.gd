extends RefCounted
class_name RunModifiers
## Accumulated draft-card effects for one run (Feature Spec §5.3 — run-local,
## discarded at run end). Towers read these multipliers every time they
## compute a shot, so a card picked mid-wave applies immediately.

var damage_mult: float = 1.0
var fire_rate_mult: float = 1.0
var range_mult: float = 1.0
var slow_power_mult: float = 1.0
var dot_mult: float = 1.0
var splash_bonus: float = 0.0
var gold_per_kill: int = 0
var wave_clear_mult: float = 1.0
var sell_refund_bonus: float = 0.0
var upgrade_discount: float = 0.0
var frost_slow_dps: float = 0.0
var universal_dps: float = 0.0
var ward_stone_max_bonus: int = 0
## Extra damage against an enemy already below execute_threshold health.
var execute_bonus: float = 0.0
## Extra damage from every tower against anything currently slowed.
var slowed_damage_bonus: float = 0.0
## Every tower spreads its blight on a kill, not just the Plague Caster.
var dot_spreads_always: bool = false

## Health fraction below which the execute bonus applies.
const EXECUTE_THRESHOLD: float = 0.3

## element -> extra damage multiplier, e.g. Grey Rites only helps Physical.
var element_damage_mult: Dictionary = {}

## card id -> how many times it has been taken (Feature Spec §5.1 max rank).
var ranks: Dictionary = {}

func rank_of(card_id: StringName) -> int:
	return int(ranks.get(card_id, 0))

func damage_multiplier(element: WK.RuneElement) -> float:
	return damage_mult * float(element_damage_mult.get(element, 1.0))

## Applies one card. Effects that change run state rather than tower maths
## (repairs, extra unlocks) are returned to RunManager rather than applied here.
## Applies one card: its boon, then its price. Both go through the same
## dispatcher, so a cost is only ever an effect with a negative magnitude and
## there is no second set of rules to keep in step.
func apply(card: DraftCardDef) -> void:
	ranks[card.id] = rank_of(card.id) + 1
	_apply_effect(card.effect_key, card.magnitude, card.element_filter, card.id)
	if card.has_cost():
		_apply_effect(card.cost_effect_key, card.cost_magnitude,
			card.cost_element_filter, card.id)

func _apply_effect(effect_key: StringName, magnitude: float, element_filter: int,
		card_id: StringName) -> void:
	match String(effect_key):
		"damage_all_pct":
			damage_mult += magnitude
		"damage_element_pct":
			element_damage_mult[element_filter] = float(
				element_damage_mult.get(element_filter, 1.0)) + magnitude
		"fire_rate_all_pct":
			fire_rate_mult += magnitude
		"range_all_pct":
			range_mult += magnitude
		"splash_radius_flat":
			splash_bonus += magnitude
		"slow_power_pct":
			slow_power_mult += magnitude
		"dot_damage_pct":
			dot_mult += magnitude
		"gold_per_kill_flat":
			gold_per_kill += int(magnitude)
		"wave_clear_bonus_pct":
			wave_clear_mult += magnitude
		"sell_refund_flat":
			sell_refund_bonus += magnitude
		"upgrade_discount_pct":
			upgrade_discount = minf(0.75, upgrade_discount + magnitude)
		"frost_slow_damage":
			frost_slow_dps += magnitude
		"universal_dot":
			universal_dps += magnitude
		"overcharge":
			damage_mult += magnitude
			fire_rate_mult += magnitude
		"execute_bonus_pct":
			execute_bonus += magnitude
		"slowed_damage_bonus_pct":
			slowed_damage_bonus += magnitude
		"dot_spreads_always":
			dot_spreads_always = true
		"ward_stone_max_flat":
			ward_stone_max_bonus += int(magnitude)
		"ward_stone_repair", "unlock_extra_tower":
			pass   # handled by RunManager — they change run state, not tower maths
		_:
			push_warning("WARDKEEP: draft card %s has unknown effect_key %s." % [
				card_id, effect_key])
	# A price may not turn a multiplier inside out: at zero a tower does
	# nothing, and below zero it heals what it shoots.
	damage_mult = maxf(0.1, damage_mult)
	fire_rate_mult = maxf(0.1, fire_rate_mult)
	range_mult = maxf(0.25, range_mult)
	wave_clear_mult = maxf(0.0, wave_clear_mult)
	for element: int in element_damage_mult:
		element_damage_mult[element] = maxf(0.1, float(element_damage_mult[element]))
