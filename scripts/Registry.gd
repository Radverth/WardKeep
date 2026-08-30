extends RefCounted
class_name Registry
## Loads the generated .tres definition sets once and hands them out by id.

const TOWER_DIR: String = "res://resources/towers/"
const ENEMY_DIR: String = "res://resources/enemies/"
const ARENA_MAP_PATH: String = "res://resources/arena/ArenaMap.tres"
const WAVE_TABLE_PATH: String = "res://resources/waves/WaveTable.tres"

static var _towers: Dictionary = {}      ## StringName -> TowerDef
static var _enemies: Dictionary = {}     ## StringName -> EnemyDef
static var _tower_order: Array[StringName] = []
static var _enemy_order: Array[StringName] = []
static var _arena_map: ArenaMap = null
static var _wave_table: WaveTable = null

static func _file_names(dir_path: String) -> Array[String]:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		push_error("WARDKEEP: missing resource directory %s" % dir_path)
		return []
	var names: Array[String] = []
	for file_name: String in dir.get_files():
		if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
			names.append(file_name.trim_suffix(".remap"))
	names.sort()
	return names

static func _ensure_towers() -> void:
	if not _towers.is_empty():
		return
	for file_name: String in _file_names(TOWER_DIR):
		var def: TowerDef = load(TOWER_DIR + file_name) as TowerDef
		if def != null:
			_towers[def.id] = def
	# Feature Spec order: the three starters first, then by unlock cost.
	_tower_order.assign(_towers.keys())
	_tower_order.sort_custom(func(a: StringName, b: StringName) -> bool:
		var left: TowerDef = _towers[a]
		var right: TowerDef = _towers[b]
		if left.unlock_cost != right.unlock_cost:
			return left.unlock_cost < right.unlock_cost
		return String(left.id) < String(right.id))

static func _ensure_enemies() -> void:
	if not _enemies.is_empty():
		return
	for file_name: String in _file_names(ENEMY_DIR):
		var def: EnemyDef = load(ENEMY_DIR + file_name) as EnemyDef
		if def != null:
			_enemies[def.id] = def
	_enemy_order.assign(_enemies.keys())
	_enemy_order.sort_custom(func(a: StringName, b: StringName) -> bool:
		return _enemies[a].unlock_wave < _enemies[b].unlock_wave)

static func tower(id: StringName) -> TowerDef:
	_ensure_towers()
	return _towers.get(id, null)

static func towers() -> Array[TowerDef]:
	_ensure_towers()
	var out: Array[TowerDef] = []
	for id: StringName in _tower_order:
		out.append(_towers[id])
	return out

static func enemy(id: StringName) -> EnemyDef:
	_ensure_enemies()
	return _enemies.get(id, null)

## Non-boss archetypes only — what WaveDirector spends a wave budget on.
static func spawnable_enemies() -> Array[EnemyDef]:
	_ensure_enemies()
	var out: Array[EnemyDef] = []
	for id: StringName in _enemy_order:
		var def: EnemyDef = _enemies[id]
		if not def.is_boss:
			out.append(def)
	return out

static func bosses() -> Array[EnemyDef]:
	_ensure_enemies()
	var out: Array[EnemyDef] = []
	for id: StringName in _enemy_order:
		if _enemies[id].is_boss:
			out.append(_enemies[id])
	return out

static func arena_map() -> ArenaMap:
	if _arena_map == null:
		_arena_map = load(ARENA_MAP_PATH) as ArenaMap
	return _arena_map

static func wave_table() -> WaveTable:
	if _wave_table == null:
		_wave_table = load(WAVE_TABLE_PATH) as WaveTable
	return _wave_table

static func clear() -> void:
	_towers.clear()
	_enemies.clear()
	_tower_order.clear()
	_enemy_order.clear()
	_arena_map = null
	_wave_table = null
