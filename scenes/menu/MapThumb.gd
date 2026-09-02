extends Button
class_name MapThumb
## One board in the Run Setup picker, drawn from its own legend rather than
## from a baked image — a new board in tools/gen_resources.gd shows up here with
## no art to author, and the thumbnail can never disagree with what gets played.

## Board colours, close enough to Toen's palette that the thumbnail reads as the
## arena in miniature without pretending to be a screenshot.
const GRASS: Color = Color(0.40, 0.72, 0.28)
const LANE: Color = Color(0.94, 0.90, 0.76)
const BUILD: Color = Color(0.30, 0.55, 0.22)
const KEEP: Color = Color(0.78, 0.74, 0.62)
const SELECTED_EDGE: Color = Color(1.0, 0.86, 0.34)
const EDGE_WIDTH: float = 3.0
## Room under the board for the name label, which is a child so it draws over
## the board rather than under it.
const LABEL_HEIGHT: float = 44.0

var map: ArenaMap = null

var _name_label: Label = null

func bind(arena_map: ArenaMap) -> void:
	map = arena_map
	if _name_label == null:
		_name_label = Label.new()
		_name_label.add_theme_font_size_override("font_size", 14)
		_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_name_label.offset_top = -LABEL_HEIGHT
		_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_name_label)
	_name_label.text = arena_map.display_name
	queue_redraw()

func _draw() -> void:
	if map == null:
		return
	var board := Vector2(size.x, size.y - LABEL_HEIGHT)
	var cell: float = minf(board.x / float(map.columns), board.y / float(map.rows))
	var span: Vector2 = Vector2(map.columns, map.rows) * cell
	var origin: Vector2 = Vector2((size.x - span.x) * 0.5, 0.0)
	draw_rect(Rect2(origin, span), GRASS, true)
	for row: int in map.rows:
		for column: int in map.columns:
			var colour: Color
			match map.cell(column, row):
				"#": colour = LANE
				"B": colour = BUILD
				"W": colour = KEEP
				_: continue
			draw_rect(Rect2(origin + Vector2(column, row) * cell, Vector2(cell, cell)), colour, true)
	# The button's own pressed styling is behind this fill, so the chosen board
	# draws its own frame or nothing on screen says which one is armed.
	if button_pressed:
		draw_rect(Rect2(origin, span), SELECTED_EDGE, false, EDGE_WIDTH)
