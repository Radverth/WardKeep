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
static func offer(rng: RandomNumberGenerator, unlocked: Array[TowerDef]) -> Array[StringName]:
	var pool: Array[TowerDef] = unlocked.duplicate()
	var out: Array[StringName] = []
	var wanted: int = mini(Balance.config().tower_offer_size, pool.size())
	while out.size() < wanted and not pool.is_empty():
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)).id)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out

## How many of the offer the player takes. Never more than the offer itself, so
## an early account with three unlocks is not asked for an impossible fourth.
static func picks_for(offer_size: int) -> int:
	return mini(Balance.config().tower_draft_picks, offer_size)
