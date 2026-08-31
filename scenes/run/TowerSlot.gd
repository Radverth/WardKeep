extends Node2D
class_name TowerSlot
## One build tile (Feature Spec §1 — 34 of them flank the path). Owns the
## placement marker and the tower standing on it, if any.
##
## The markers are the Tower Defense pack's own overlay tiles rather than
## flat colour rectangles, so placement feedback reads as part of the board.

const TILE_SHEET: String = "res://assets/sprites/environment/tower_defense_tilesheet/towerDefense_tilesheet.png"
## Cells in that sheet: a plain green pad, a grey cross, a green target ring.
const MARKER_VALID := Vector2i(15, 1)
const MARKER_INVALID := Vector2i(17, 3)
const MARKER_SELECTED := Vector2i(18, 1)

@onready var _marker: Sprite2D = $Marker

var grid_cell: Vector2i = Vector2i.ZERO
var tower: Tower = null

func setup(cell: Vector2i) -> void:
	grid_cell = cell
	clear_hint()

func is_free() -> bool:
	return tower == null

## Shown on every build tile while a tower is armed: a pad where it can go,
## a cross where it cannot.
func show_placement_hint(valid: bool) -> void:
	_set_marker(MARKER_VALID if valid else MARKER_INVALID, 0.85 if valid else 0.7)

func show_selected() -> void:
	_set_marker(MARKER_SELECTED, 1.0)

func clear_hint() -> void:
	if is_instance_valid(_marker):
		_marker.visible = false

func _set_marker(cell: Vector2i, alpha: float) -> void:
	_marker.texture = SpriteAtlas.cell(TILE_SHEET, cell.x, cell.y, WK.TILE_SIZE, 0)
	_marker.modulate.a = alpha
	_marker.visible = true
