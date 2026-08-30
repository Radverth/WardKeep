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
func apply(card: DraftCardDef) -> void:
	ranks[card.id] = rank_of(card.id) + 1
	match String(card.effect_key):
		"damage_all_pct":
			damage_mult += card.magnitude
		"damage_element_pct":
			var element: int = card.element_filter
			element_damage_mult[element] = float(element_damage_mult.get(element, 1.0)) + card.magnitude
		"fire_rate_all_pct":
			fire_rate_mult += card.magnitude
		"range_all_pct":
			range_mult += card.magnitude
		"splash_radius_flat":
			splash_bonus += card.magnitude
		"slow_power_pct":
			slow_power_mult += card.magnitude
		"dot_damage_pct":
			dot_mult += card.magnitude
		"gold_per_kill_flat":
			gold_per_kill += int(card.magnitude)
		"wave_clear_bonus_pct":
			wave_clear_mult += card.magnitude
		"sell_refund_flat":
			sell_refund_bonus += card.magnitude
		"upgrade_discount_pct":
			upgrade_discount = minf(0.75, upgrade_discount + card.magnitude)
		"frost_slow_damage":
			frost_slow_dps += card.magnitude
		"universal_dot":
			universal_dps += card.magnitude
		"overcharge":
			damage_mult += card.magnitude
			fire_rate_mult += card.magnitude
		"ward_stone_max_flat":
			ward_stone_max_bonus += int(card.magnitude)
		"ward_stone_repair", "unlock_extra_tower":
			pass   # handled by RunManager — they change run state, not tower maths
		_:
			push_warning("WARDKEEP: draft card %s has unknown effect_key %s." % [card.id, card.effect_key])
