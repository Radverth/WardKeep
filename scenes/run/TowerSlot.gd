extends Node2D
class_name TowerSlot
## One build tile (Feature Spec §1 — 34 of them flank the path). Owns the
## placement marker and the tower standing on it, if any.
##
## The marker is drawn rather than stamped from a tileset. The old cream pad
## tile put 34 bright squares on the field at once, which read as a
## checkerboard laid over the map; corner ticks over a barely-darkened square
## say "you may build here" without competing with the terrain.

enum Marker { RESTING, VALID, TAKEN, SELECTED }

## One source pixel of the 16px art, so every edge lands on a pixel boundary.
const STROKE: float = float(WK.TILE_SIZE) / 12.0
const INSET: float = float(WK.TILE_SIZE) / 16.0
## How far along each edge the corner ticks run.
const TICK: float = float(WK.TILE_SIZE) * 0.24

## A free tile lights green while placing; a tile already built on does not
## light at all. It used to go red, which put a wall of alarm colour across
## every tower the player had bought — a tile being occupied is not an error,
## it is just not a target.
## Resting is quiet enough to sit under a whole board of towers without reading
## as a grid; armed is loud, because that is the one moment the player needs to
## see every tile they can build on. A green highlight was tried first and is
## useless here — the field is green, so it vanished into it.
const FILL_COLORS: Dictionary = {
	Marker.RESTING: Color(0.10, 0.20, 0.06, 0.10),
	Marker.VALID: Color(1.0, 0.97, 0.80, 0.40),
	Marker.TAKEN: Color(0.06, 0.10, 0.06, 0.22),
	Marker.SELECTED: Color(0.98, 0.82, 0.28, 0.26),
}
const EDGE_COLORS: Dictionary = {
	Marker.RESTING: Color(0.94, 0.92, 0.80, 0.26),
	Marker.VALID: Color(1.0, 0.95, 0.62, 0.95),
	Marker.TAKEN: Color(0.0, 0.0, 0.0, 0.0),
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

## Shown on every build tile while a tower is armed: a lit pad where the tower
## can go, and a tile that is merely dimmed where one already stands.
func show_placement_hint(valid: bool) -> void:
	_set_marker(Marker.VALID if valid else Marker.TAKEN)

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
	if edge.a <= 0.0:
		return
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var at := Vector2(corner.x * half, corner.y * half)
		# Horizontal arm, then vertical arm, both drawn inward from the corner.
		draw_rect(Rect2(minf(at.x, at.x + corner.x * -TICK),
			minf(at.y, at.y + corner.y * -STROKE), TICK, STROKE), edge, true)
		draw_rect(Rect2(minf(at.x, at.x + corner.x * -STROKE),
			minf(at.y, at.y + corner.y * -TICK), STROKE, TICK), edge, true)
