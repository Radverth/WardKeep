extends Resource
class_name TowerDef
## Technical Architecture §3.1. One per tower archetype (9 total).

@export var id: StringName = &""
@export var display_name: String = ""
@export var role: String = ""                ## the §4 table's "Role" column
@export var rune_element: WK.RuneElement = WK.RuneElement.PHYSICAL
@export var tiers: Array[TowerTierData] = []
@export var sprite_atlas_path: String = "res://assets/sprites/towers/rts_medieval_base/medievalRTS_spritesheet.png"
@export var sprite_frame: String = ""        ## SubTexture name inside that atlas' .xml
@export var projectile_scene: PackedScene = null   ## null for melee/aura towers
@export var scene_path: String = ""

## Feature Spec §6.2 — Keep Hub unlock.
@export var unlock_cost: int = 0
@export var required_account_level: int = 1

func tier(index: int) -> TowerTierData:
	return tiers[clampi(index, 0, tiers.size() - 1)]

func max_tier_index() -> int:
	return tiers.size() - 1

func purchase_cost() -> int:
	return tiers[0].cost if not tiers.is_empty() else 0

func is_starter() -> bool:
	return unlock_cost <= 0
