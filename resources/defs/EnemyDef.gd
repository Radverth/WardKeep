extends Resource
class_name EnemyDef
## Technical Architecture §3.2. Base stats; WaveDirector scales HP and damage
## by the Feature Spec §2.2 wave multiplier at spawn time. Speed never scales.

@export var id: StringName = &""
@export var display_name: String = ""
@export var base_hp: float = 10.0
@export var base_speed: float = 1.6          ## tiles per second
@export var base_damage: float = 1.0         ## Ward Stone HP removed on leak
@export var armor_type: WK.ArmorType = WK.ArmorType.NONE

## Feature Spec §2.1 — what one of these costs out of the wave's enemy_budget,
## and the first wave it can appear on.
@export var budget_cost: int = 4
@export var unlock_wave: int = 1

@export var sprite_atlas_path: String = "res://assets/sprites/enemies/roguelike_characters/roguelikeChar_transparent.png"
@export var sprite_cell: Vector2i = Vector2i.ZERO   ## column,row in the 16px/1px-margin sheet
@export var tint: Color = Color.WHITE
@export var scale_factor: float = 2.5

@export var is_boss: bool = false
@export var boss_pattern_script: Script = null
@export var scene_path: String = ""

## True where a value in this resource is provisional rather than transcribed
## from a Feature Spec table. See SPEC_GAPS.md.
@export var provisional: bool = false
