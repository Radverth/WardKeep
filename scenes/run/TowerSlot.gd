extends Node2D
class_name TowerSlot
## One build tile (Feature Spec §1 — 34 of them flank the path). Owns the
## highlight state and the tower standing on it, if any.

const HIGHLIGHT_VALID := Color(0.45, 0.95, 0.55, 0.55)
const HIGHLIGHT_BLOCKED := Color(0.95, 0.4, 0.35, 0.55)
const HIGHLIGHT_SELECTED := Color(1.0, 0.87, 0.45, 0.65)

@onready var _highlight: ColorRect = $Highlight

var grid_cell: Vector2i = Vector2i.ZERO
var tower: Tower = null

func setup(cell: Vector2i) -> void:
	grid_cell = cell
	_highlight.visible = false

func is_free() -> bool:
	return tower == null

func show_placement_hint(valid: bool) -> void:
	_highlight.color = HIGHLIGHT_VALID if valid else HIGHLIGHT_BLOCKED
	_highlight.visible = true

func show_selected() -> void:
	_highlight.color = HIGHLIGHT_SELECTED
	_highlight.visible = true

func clear_hint() -> void:
	_highlight.visible = false
