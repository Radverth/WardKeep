extends Resource
class_name TowerDef
## Technical Architecture §3.1. One per tower archetype (9 total).

@export var id: StringName = &""
@export var display_name: String = ""
@export var role: String = ""                ## the §4 table's "Role" column
@export var rune_element: WK.RuneElement = WK.RuneElement.PHYSICAL
@export var tiers: Array[TowerTierData] = []
@export var sprite_atlas_path: String = ""
## Column,row in that sheet, and its grid. Towers are stamped from the terrain
## pack's own keep and siege tiles, so the board is one artist's work.
@export var sprite_cell: Vector2i = Vector2i.ZERO
@export var sprite_cell_size: int = 16
@export var sprite_cell_margin: int = 0
@export var projectile_scene: PackedScene = null   ## null for melee/aura towers
@export var scene_path: String = ""

## Feature Spec §6.2 — Keep Hub unlock.
@export var unlock_cost: int = 0
@export var required_account_level: int = 1

func texture() -> Texture2D:
	return SpriteAtlas.cell(sprite_atlas_path, sprite_cell.x, sprite_cell.y,
		sprite_cell_size, sprite_cell_margin)

func tier(index: int) -> TowerTierData:
	return tiers[clampi(index, 0, tiers.size() - 1)]

func max_tier_index() -> int:
	return tiers.size() - 1

func purchase_cost() -> int:
	return tiers[0].cost if not tiers.is_empty() else 0

func is_starter() -> bool:
	return unlock_cost <= 0
