extends Resource
class_name ArenaMap
## One board. Feature Spec §1 fixes the geometry — 12x20, one lane, 34 build
## tiles, a Ward Stone platform — and The Old Road is that map verbatim; the
## rest are alternates cut to the same rules so a run varies without the
## balance moving under it.
## Legend: '#' path, 'B' build tile, 'W' Ward Stone platform, '.' empty floor.

@export var id: StringName = &""
@export var display_name: String = ""
## One line for the map picker: what makes this board play differently.
@export var blurb: String = ""
## Picker order. The Old Road is 0: it is the Feature Spec's own board and the
## one the balance was measured against, so it must be the default rather than
## whichever filename happens to sort first.
@export var order: int = 0

@export var columns: int = 12
@export var rows: int = 20
@export var legend: PackedStringArray = PackedStringArray()
## Grid coordinates the enemies walk between, in order.
@export var waypoints: Array[Vector2i] = []

## Lane cells, Ward Stone platform excluded. Runs are longer on a longer lane
## because towers get more seconds of fire, so this is the number to compare
## when adding a board.
func lane_length() -> int:
	var count: int = 0
	for row: int in rows:
		for column: int in columns:
			if is_path_tile(column, row):
				count += 1
	return count

func cell(column: int, row: int) -> String:
	if row < 0 or row >= legend.size():
		return "."
	var line: String = legend[row]
	if column < 0 or column >= line.length():
		return "."
	return line[column]

func is_build_tile(column: int, row: int) -> bool:
	return cell(column, row) == "B"

func is_path_tile(column: int, row: int) -> bool:
	return cell(column, row) == "#"

func is_ward_stone(column: int, row: int) -> bool:
	return cell(column, row) == "W"

func build_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for row: int in rows:
		for column: int in columns:
			if is_build_tile(column, row):
				out.append(Vector2i(column, row))
	return out

## Centre of the Ward Stone platform, in grid coordinates (may be fractional).
func ward_stone_center() -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	var count: int = 0
	for row: int in rows:
		for column: int in columns:
			if is_ward_stone(column, row):
				sum += Vector2(column, row)
				count += 1
	return (sum / float(count)) if count > 0 else Vector2(columns / 2.0, rows - 2.0)
