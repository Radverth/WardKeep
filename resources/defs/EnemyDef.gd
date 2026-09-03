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

@export var sprite_atlas_path: String = ""
## Column,row in that sheet, or (-1, -1) when the whole file is one sprite.
@export var sprite_cell: Vector2i = Vector2i(-1, -1)
@export var sprite_cell_size: int = 16
@export var sprite_cell_margin: int = 0
## True when the artwork is drawn facing left. Enemy flips the sprite to match
## the direction of travel, and it has to know which way the source faces to do
## that: Toen's soldiers face right, Frostmaw faces left.
@export var sprite_faces_left: bool = false
## Front-on portrait art has no left or right to turn, so flipping it only
## mirrors detail for no gain. True for the Battlers drawn head-on.
@export var sprite_faces_camera: bool = false
@export var tint: Color = Color.WHITE
@export var scale_factor: float = 4.0

## --- archetype behaviour (all PROVISIONAL, SPEC_GAPS.md #3) --------------
## The document suite has no enemy table, so what each archetype *does* is a
## design decision rather than a transcription. Every field below is inert at
## its default, so an archetype with no behaviour needs nothing set.

## Enemies spawned together for one entry in the wave plan. budget_cost covers
## the whole pack, so a pack does not buy extra enemies out of the wave budget.
@export var pack_size: int = 1

## Radius of whatever this archetype projects onto its neighbours, in tiles.
@export var aura_radius_tiles: float = 0.0
## Fraction of incoming damage nearby enemies shrug off.
@export var aura_damage_reduction: float = 0.0
## Fraction of base speed added to nearby enemies.
@export var aura_speed_bonus: float = 0.0
## HP per second restored to nearby damaged enemies.
@export var aura_heal_per_second: float = 0.0

## Seconds spent targetable, then untargetable, on a repeating cycle. Zero for
## anything that is always a legal target.
@export var phase_visible_seconds: float = 0.0
@export var phase_hidden_seconds: float = 0.0

@export var is_boss: bool = false
@export var boss_pattern_script: Script = null
@export var scene_path: String = ""

## --- animation sheets ---------------------------------------------------
## A sheet of non-square frames, read as an animation rather than as a single
## cell. Frames run left to right and wrap at `sprite_sheet_columns`, so a
## cycle drawn across two rows plays as one loop. Zero frames means the sprite
## is a still, which is what every 16px pack enemy is.
@export var sprite_frame_size: Vector2i = Vector2i.ZERO
@export var sprite_sheet_columns: int = 1
@export var sprite_frames: int = 0
@export var sprite_fps: float = 8.0

func is_animated() -> bool:
	return sprite_frames > 1 and sprite_frame_size.x > 0 and sprite_frame_size.y > 0

## The sprite at rest: frame zero when animated, the still otherwise.
func texture() -> Texture2D:
	if is_animated():
		return frame_texture(0)
	if sprite_cell.x < 0:
		return SpriteAtlas.whole(sprite_atlas_path)
	return SpriteAtlas.cell(sprite_atlas_path, sprite_cell.x, sprite_cell.y,
		sprite_cell_size, sprite_cell_margin)

## Frame `index` of the cycle, counted from the sheet cell the def starts at.
func frame_texture(index: int) -> Texture2D:
	var start: int = maxi(0, sprite_cell.y) * maxi(1, sprite_sheet_columns) + maxi(0, sprite_cell.x)
	return SpriteAtlas.frame_cell(sprite_atlas_path,
		start + posmod(index, maxi(1, sprite_frames)),
		sprite_frame_size, sprite_sheet_columns)

## True where a value in this resource is provisional rather than transcribed
## from a Feature Spec table. See SPEC_GAPS.md.
@export var provisional: bool = false
