extends Resource
class_name DraftCardDef
## Feature Spec §5. Run-local upgrade offered after a wave clear.

@export var id: StringName = &""
@export var title: String = ""
@export var description: String = ""
@export var rarity: WK.Rarity = WK.Rarity.COMMON
@export var effect_key: StringName = &""     ## key RunModifiers understands
@export var magnitude: float = 0.0
@export var max_rank: int = 3
@export var element_filter: int = -1         ## -1 = all elements, else WK.RuneElement

## What the card costs, applied through the same dispatcher as the boon. A
## card with a real price is a decision; a card that is only ever an
## improvement is a pickup. Empty for the cards that are pure gain.
@export var cost_effect_key: StringName = &""
@export var cost_magnitude: float = 0.0
## Which element the cost falls on, when the cost is element-scoped.
@export var cost_element_filter: int = -1

func has_cost() -> bool:
	return cost_effect_key != &""
@export var icon_path: String = ""
