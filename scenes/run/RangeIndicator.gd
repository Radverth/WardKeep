extends Node2D
class_name RangeIndicator
## The reach of the tower being placed or inspected. A tower defense is
## unplayable without one — until now the player had no way to see how far a
## tower covered before spending the gold on it.

const FILL_ALPHA: float = 0.10
const EDGE_ALPHA: float = 0.75
const EDGE_WIDTH: float = 3.0
const SEGMENTS: int = 64

var radius: float = 0.0
var tint: Color = Color.WHITE

func _ready() -> void:
	hide_range()

func show_range(at: Vector2, radius_pixels: float, color: Color) -> void:
	global_position = at
	radius = radius_pixels
	tint = color
	visible = radius > 0.0
	queue_redraw()

func move_to(at: Vector2) -> void:
	if visible:
		global_position = at

func hide_range() -> void:
	visible = false
	radius = 0.0

func _draw() -> void:
	if radius <= 0.0:
		return
	draw_circle(Vector2.ZERO, radius, Color(tint.r, tint.g, tint.b, FILL_ALPHA))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, SEGMENTS,
		Color(tint.r, tint.g, tint.b, EDGE_ALPHA), EDGE_WIDTH, true)
