extends RefCounted
class_name TowerDraft
## Picks the towers a run is offered, and holds what the player chose.
##
## Every unlocked tower used to be buyable in every run, which made the roster a
## menu rather than a hand: nine towers, always the same nine, so two runs
## differed only in the cards that fell. Drafting three of an offer turns the
## opening into a decision and makes a run frost-heavy or blight-heavy before
## the first wave lands. PROVISIONAL — SPEC_GAPS.md #15.

## The offer is drawn from what the Keep Hub has unlocked, so buying a tower
## widens the pool rather than adding one more thing to the tray. A player with
## only the three starters is offered exactly those three and picks all of them,
## which is the same game they have now — the draft opens up as they unlock.
## Enough of the offer is guaranteed to deal damage that any three of it can
## still end a wave. Drawn purely at random, an offer could be mostly slow
## fields and support, and a player who took three of those had a run that was
## already lost at the setup screen with nothing on the board to show them why.
## Support towers stay in the pool; they just cannot be the whole of it.
const GUARANTEED_DAMAGE: int = 3

static func offer(rng: RandomNumberGenerator, unlocked: Array[TowerDef]) -> Array[StringName]:
	var damage_pool: Array[TowerDef] = []
	var support_pool: Array[TowerDef] = []
	for def: TowerDef in unlocked:
		if def.deals_damage():
			damage_pool.append(def)
		else:
			support_pool.append(def)
	var wanted: int = mini(Balance.config().tower_offer_size, unlocked.size())
	var out: Array[StringName] = []
	var guaranteed: int = mini(GUARANTEED_DAMAGE, mini(wanted, damage_pool.size()))
	for _index: int in guaranteed:
		out.append(_take(rng, damage_pool))
	var rest: Array[TowerDef] = damage_pool + support_pool
	while out.size() < wanted and not rest.is_empty():
		out.append(_take(rng, rest))
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out

static func _take(rng: RandomNumberGenerator, pool: Array[TowerDef]) -> StringName:
	return pool.pop_at(rng.randi_range(0, pool.size() - 1)).id

## How many of the offer the player takes. Never more than the offer itself, so
## an early account with three unlocks is not asked for an impossible fourth.
static func picks_for(offer_size: int) -> int:
	return mini(Balance.config().tower_draft_picks, offer_size)
