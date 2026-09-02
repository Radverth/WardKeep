extends Node2D
class_name TowerSlot
## One build tile (Feature Spec §1 — 34 of them flank the path). Owns the
## placement marker and the tower standing on it, if any.
##
## The marker is drawn rather than stamped from a tileset. The old cream pad
## tile put 34 bright squares on the field at once, which read as a
## checkerboard laid over the map; corner ticks over a barely-darkened square
## say "you may build here" without competing with the terrain.

enum Marker { RESTING, VALID, INVALID, SELECTED }

## One source pixel of the 16px art, so every edge lands on a pixel boundary.
const STROKE: float = float(WK.TILE_SIZE) / 12.0
const INSET: float = float(WK.TILE_SIZE) / 16.0
## How far along each edge the corner ticks run.
const TICK: float = float(WK.TILE_SIZE) * 0.24

const FILL_COLORS: Dictionary = {
	Marker.RESTING: Color(0.10, 0.20, 0.06, 0.13),
	Marker.VALID: Color(0.42, 0.85, 0.28, 0.30),
	Marker.INVALID: Color(0.70, 0.12, 0.10, 0.30),
	Marker.SELECTED: Color(0.98, 0.82, 0.28, 0.24),
}
const EDGE_COLORS: Dictionary = {
	Marker.RESTING: Color(0.99, 0.96, 0.84, 0.34),
	Marker.VALID: Color(0.97, 0.99, 0.82, 0.95),
	Marker.INVALID: Color(0.95, 0.45, 0.40, 0.95),
	Marker.SELECTED: Color(1.0, 0.86, 0.34, 1.0),
}

var grid_cell: Vector2i = Vector2i.ZERO
var tower: Tower = null

var _marker: Marker = Marker.RESTING

func setup(cell: Vector2i) -> void:
	grid_cell = cell
	clear_hint()

func is_free() -> bool:
	return tower == null

## Shown on every build tile while a tower is armed: a lit pad where it can go,
## a red one where it cannot.
func show_placement_hint(valid: bool) -> void:
	_set_marker(Marker.VALID if valid else Marker.INVALID)

func show_selected() -> void:
	_set_marker(Marker.SELECTED)

## Back to the resting survey marks — never invisible, or a player has no way
## to see where the buildable ground is.
func clear_hint() -> void:
	_set_marker(Marker.RESTING)

func _set_marker(state: Marker) -> void:
	if _marker == state:
		return
	_marker = state
	queue_redraw()

func _draw() -> void:
	# An occupied tile is under a tower sprite; drawing a marker there only
	# outlines the thing already standing on it.
	if tower != null and _marker == Marker.RESTING:
		return
	var half: float = float(WK.TILE_SIZE) * 0.5 - INSET
	var box := Rect2(-half, -half, half * 2.0, half * 2.0)
	draw_rect(box, FILL_COLORS[_marker], true)
	var edge: Color = EDGE_COLORS[_marker]
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var at := Vector2(corner.x * half, corner.y * half)
		# Horizontal arm, then vertical arm, both drawn inward from the corner.
		draw_rect(Rect2(minf(at.x, at.x + corner.x * -TICK),
			minf(at.y, at.y + corner.y * -STROKE), TICK, STROKE), edge, true)
		draw_rect(Rect2(minf(at.x, at.x + corner.x * -STROKE),
			minf(at.y, at.y + corner.y * -TICK), STROKE, TICK), edge, true)
