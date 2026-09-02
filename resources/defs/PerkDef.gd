extends Resource
class_name PerkDef
## A permanent, runestone-bought upgrade that applies to every run.
##
## Feature Spec §6 has no perk table — the Keep Hub it describes sells tower
## unlocks and cosmetics only. These are an addition (SPEC_GAPS.md #10), so the
## whole set is PROVISIONAL.

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
## Which knob this perk turns. Perks.value() sums every rank bought against the
## same effect, so two perks may share one.
@export var effect: StringName = &""
## What one rank is worth. Read as gold, hit points or a fraction depending on
## the effect — see Perks for which.
@export var per_rank: float = 0.0
## Runestones for rank 1, rank 2, and so on. Its length is the maximum rank.
@export var costs: PackedInt32Array = PackedInt32Array()
@export var order: int = 0

func max_rank() -> int:
	return costs.size()

## Runestones to go from `rank` to `rank + 1`, or 0 when already maxed.
func cost_for_next(rank: int) -> int:
	return costs[rank] if rank >= 0 and rank < costs.size() else 0
