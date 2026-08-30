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
@export var icon_path: String = ""
