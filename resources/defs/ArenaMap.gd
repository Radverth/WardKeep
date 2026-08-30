extends Resource
class_name ArenaMap
## Feature Spec §1 — the single fixed v1.0 map.
## Legend: '#' path, 'B' build tile, 'W' Ward Stone platform, '.' empty floor.

@export var columns: int = 12
@export var rows: int = 20
@export var legend: PackedStringArray = PackedStringArray()
## Grid coordinates the enemies walk between, in order.
@export var waypoints: Array[Vector2i] = []

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
