extends RefCounted
class_name Perks
## Reads the permanent upgrades bought in the Keep Hub. Every getter answers in
## the unit the caller needs, so no caller has to know how a perk is stored.
##
## Runestones bought nine towers and then had nothing left to buy but skins,
## which is a meta currency that stops mattering exactly when a player has
## proved they intend to keep playing. PROVISIONAL — SPEC_GAPS.md #10.

const STARTING_GOLD: StringName = &"starting_gold"
const WARD_STONE_HP: StringName = &"ward_stone_hp"
const GOLD_PER_KILL: StringName = &"gold_per_kill"
const UPGRADE_DISCOUNT: StringName = &"upgrade_discount"
const RUNESTONE_BONUS: StringName = &"runestone_bonus"
const WAVE_REPAIR: StringName = &"wave_repair"

## Where ranks are read from, handed over by SaveManager on startup.
##
## Injected rather than reached for by name: an autoload is not registered while
## the project is being scanned, so a class_name script that names one fails to
## compile during --import and buries a real error in the noise. It also makes
## the perk maths testable against a stub.
static var _ranks: Object = null

static func bind(source: Object) -> void:
	_ranks = source

static func rank(id: StringName) -> int:
	return int(_ranks.perk_rank(String(id))) if _ranks != null else 0

## Total value bought against one effect, across every perk that turns it.
static func value(effect: StringName) -> float:
	var total: float = 0.0
	for perk: PerkDef in Registry.perks():
		if perk.effect == effect:
			total += perk.per_rank * float(rank(perk.id))
	return total

static func starting_gold_bonus() -> int:
	return int(round(value(STARTING_GOLD)))

static func ward_stone_bonus() -> int:
	return int(round(value(WARD_STONE_HP)))

static func gold_per_kill_bonus() -> int:
	return int(round(value(GOLD_PER_KILL)))

## Capped for the same reason the draft's own discount is: a run where upgrades
## are free is a run with no economy.
static func upgrade_discount() -> float:
	return clampf(value(UPGRADE_DISCOUNT), 0.0, 0.5)

static func runestone_multiplier() -> float:
	return 1.0 + value(RUNESTONE_BONUS)

static func repair_per_wave() -> int:
	return int(round(value(WAVE_REPAIR)))
