extends RefCounted
class_name Registry
## Loads the generated .tres definition sets once and hands them out by id.

const TOWER_DIR: String = "res://resources/towers/"
const ENEMY_DIR: String = "res://resources/enemies/"
const ARENA_DIR: String = "res://resources/arena/"
const WAVE_TABLE_PATH: String = "res://resources/waves/WaveTable.tres"

static var _towers: Dictionary = {}      ## StringName -> TowerDef
static var _enemies: Dictionary = {}     ## StringName -> EnemyDef
static var _tower_order: Array[StringName] = []
static var _enemy_order: Array[StringName] = []
static var _maps: Dictionary = {}        ## StringName -> ArenaMap
static var _map_order: Array[StringName] = []
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

static func _ensure_maps() -> void:
	if not _maps.is_empty():
		return
	var loaded: Array[ArenaMap] = []
	for file_name: String in _file_names(ARENA_DIR):
		var map: ArenaMap = load(ARENA_DIR + file_name) as ArenaMap
		if map == null:
			continue
		loaded.append(map)
	loaded.sort_custom(func(a: ArenaMap, b: ArenaMap) -> bool:
		return a.order < b.order if a.order != b.order else String(a.id) < String(b.id))
	for map: ArenaMap in loaded:
		_maps[map.id] = map
		_map_order.append(map.id)

## Every board, in a stable order — the map picker and the Daily's deterministic
## pick both index into this, so the order must not depend on load timing.
static func maps() -> Array[ArenaMap]:
	_ensure_maps()
	var out: Array[ArenaMap] = []
	for id: StringName in _map_order:
		out.append(_maps[id])
	return out

## The named board, or the first one when the id is unknown or empty — a save
## naming a board that a later build removed must not strand the player.
static func map(id: StringName) -> ArenaMap:
	_ensure_maps()
	if _maps.has(id):
		return _maps[id]
	return _maps[_map_order[0]] if not _map_order.is_empty() else null

static func wave_table() -> WaveTable:
	if _wave_table == null:
		_wave_table = load(WAVE_TABLE_PATH) as WaveTable
	return _wave_table

static func clear() -> void:
	_towers.clear()
	_enemies.clear()
	_tower_order.clear()
	_enemy_order.clear()
	_maps.clear()
	_map_order.clear()
	_wave_table = null
