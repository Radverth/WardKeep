extends Node2D
class_name Arena
## The in-run screen. Owns the board, the pools and the wave-loop state
## machine from User Flow §2; the numbers behind it all come from
## RunManager / WaveDirector / Balance, never from here.

## Set on _ready so towers, enemies and boss patterns can reach the board
## without threading a reference through every constructor.
static var current: Arena = null

enum Phase { INTRO, ACTIVE, CLEARED, DRAFT, ENDED }

## The board is drawn from Toen's Medieval Strategy Sprite Pack; the tile
## indices, the lane compositing and the prop bag all live in Terrain.
## Everything on the board is 16px art shown on a 64px grid, so ground sprites
## are drawn at WK.PIXEL_ZOOM and the project filters textures nearest.

## Gap between the members of a pack, in pixels along the lane.
const PACK_SPACING: float = float(WK.TILE_SIZE) * 0.7

const WAVE_INTRO_SECONDS: float = 1.5
## The HUD's top bar and tower tray sit over the board. The board is exactly
## 12x20 tiles, so without framing, the Ward Stone platform on rows 17-18 ends
## up underneath the tray.
const HUD_TOP_INSET: float = 104.0
const HUD_BOTTOM_INSET: float = 148.0


@onready var _ground: Node2D = $Ground
@onready var _slot_layer: Node2D = $SlotLayer
@onready var _tower_layer: Node2D = $TowerLayer
@onready var _enemy_layer: Node2D = $EnemyLayer
@onready var _projectile_layer: Node2D = $ProjectileLayer
@onready var _vfx_layer: Node2D = $VfxLayer
@onready var _ward_stone: Sprite2D = $WardStone
@onready var _hud: Control = %HUD
@onready var _draft_overlay: Control = %DraftOverlay
@onready var _tower_panel: Control = %TowerPanel
@onready var _pause_menu: Control = %PauseMenu
@onready var _onboarding: Control = %Onboarding
@onready var _ghost: Sprite2D = $Ghost
@onready var _range_indicator: RangeIndicator = $RangeIndicator
@onready var _camera: Camera2D = $Camera

var map: ArenaMap = null
var phase: Phase = Phase.INTRO
var active_enemies: Array[Enemy] = []

var _path_points: PackedVector2Array = PackedVector2Array()
var _slots: Dictionary = {}                ## Vector2i -> TowerSlot
var _spawn_queue: Array[Dictionary] = []
var _spawn_timer: float = 0.0
var _spawn_interval: float = 1.0
var _armed_def: TowerDef = null
var _selected_tower: Tower = null
var _shake_time: float = 0.0
## Whatever the host had the clock set to when the Arena came up. The headless
## playtest runs at 8x, so the speed toggle multiplies this rather than
## assigning over it, and _exit_tree puts it back.
var _base_time_scale: float = 1.0
var _speed_step: int = 0

var _enemy_pools: Dictionary = {}          ## StringName -> Array[Enemy]
var _projectile_pool: Array[Projectile] = []
var _vfx_pool: Array[Vfx] = []
var _explosion_frames: Dictionary = {}     ## atlas name -> Array[AtlasTexture]

func _ready() -> void:
	current = self
	_base_time_scale = Engine.time_scale
	map = GameState.resolve_arena_map()
	_build_ground()
	_build_path_points()
	_build_slots()
	_place_ward_stone()
	_cache_explosion_frames()
	_frame_board()

	RunManager.ward_stone_damaged.connect(_on_ward_stone_damaged)
	RunManager.run_ended.connect(_on_run_ended)
	RunManager.draft_offered.connect(_on_draft_offered)
	_draft_overlay.card_chosen.connect(_on_draft_card_chosen)
	_hud.tower_armed.connect(_on_tower_armed)
	_hud.speed_pressed.connect(_on_speed_pressed)
	_hud.pause_pressed.connect(_open_pause)
	_hud.bank_pressed.connect(_on_bank_pressed)
	_pause_menu.resume_pressed.connect(_close_pause)
	_pause_menu.forfeit_pressed.connect(_on_forfeit)
	_tower_panel.upgrade_pressed.connect(_on_upgrade_tower)
	_tower_panel.sell_pressed.connect(_on_sell_tower)

	RunManager.start_run(GameState.pending_run_mode)
	_hud.bind()
	_apply_speed(int(SaveManager.get_setting("game_speed_step", 0)))
	AudioBus.play_music(AudioBus.MUSIC_GAMEPLAY)
	_maybe_run_onboarding()
	_start_next_wave()

func _exit_tree() -> void:
	if current == self:
		current = null
	get_tree().paused = false
	Engine.time_scale = _base_time_scale

## --- board construction -------------------------------------------------

## No z_index here: it applies across the whole canvas layer, so a ground
## sprite raised above 0 would draw over the towers and enemies. Everything in
## this node stacks by insertion order instead, and the node itself sits below
## the tower layer in the scene.
func _ground_sprite(texture: Texture2D, at: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = at
	sprite.scale = Vector2.ONE * WK.PIXEL_ZOOM
	_ground.add_child(sprite)
	return sprite

## The lane's open sides, as the bitmask Terrain.road() takes.
func _lane_mask(column: int, row: int) -> int:
	var mask: int = 0
	if _is_lane(column, row - 1):
		mask |= Terrain.OPEN_NORTH
	if _is_lane(column + 1, row):
		mask |= Terrain.OPEN_EAST
	if _is_lane(column, row + 1):
		mask |= Terrain.OPEN_SOUTH
	if _is_lane(column - 1, row):
		mask |= Terrain.OPEN_WEST
	return mask

## The Ward Stone platform is walked onto, so it counts as lane for edging —
## otherwise the road would draw a grass border against the keep.
func _is_lane(column: int, row: int) -> bool:
	return map.is_path_tile(column, row) or map.is_ward_stone(column, row)

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * float(WK.TILE_SIZE) + Vector2.ONE * (float(WK.TILE_SIZE) * 0.5)

func world_to_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / float(WK.TILE_SIZE)), floori(position.y / float(WK.TILE_SIZE)))

func _build_ground() -> void:
	# Deterministic, so the field looks the same every run rather than
	# shimmering between loads.
	var ground_rng := RandomNumberGenerator.new()
	ground_rng.seed = 0x57A11
	for row: int in range(-Terrain.BLEED_TILES, map.rows + Terrain.BLEED_TILES):
		for column: int in range(-Terrain.BLEED_TILES, map.columns + Terrain.BLEED_TILES):
			var grass: int = Terrain.GRASS_TUFT if ground_rng.randf() < Terrain.GRASS_TUFT_CHANCE \
				else Terrain.GRASS_BASE
			_ground_sprite(Terrain.tile(grass), cell_to_world(Vector2i(column, row)))
	_scatter_ground_detail(ground_rng)
	for row: int in map.rows:
		for column: int in map.columns:
			if not _is_lane(column, row):
				continue
			_ground_sprite(Terrain.road(_lane_mask(column, row)),
				cell_to_world(Vector2i(column, row)))
	_scatter_props(ground_rng)

## Moss and long grass under the lane and the props, nudged off the grid so the
## field reads as ground cover rather than as a second set of tiles.
func _scatter_ground_detail(detail_rng: RandomNumberGenerator) -> void:
	var jitter: float = float(Terrain.GROUND_DETAIL_JITTER) * WK.PIXEL_ZOOM
	for row: int in range(-Terrain.BLEED_TILES, map.rows + Terrain.BLEED_TILES):
		for column: int in range(-Terrain.BLEED_TILES, map.columns + Terrain.BLEED_TILES):
			if _is_lane(column, row) or detail_rng.randf() > Terrain.GROUND_DETAIL_CHANCE:
				continue
			var offset := Vector2(detail_rng.randf_range(-jitter, jitter),
				detail_rng.randf_range(-jitter, jitter))
			var index: int = Terrain.GROUND_DETAIL[
				detail_rng.randi_range(0, Terrain.GROUND_DETAIL.size() - 1)]
			_ground_sprite(Terrain.tile(index), cell_to_world(Vector2i(column, row)) + offset)

## Trees, boulders and camps on the open field only — never on the lane or a
## build tile, so scenery can never be mistaken for something placeable.
func _scatter_props(prop_rng: RandomNumberGenerator) -> void:
	var bag: Array[int] = []
	for entry: Vector2i in Terrain.PROPS:
		for _repeat: int in entry.y:
			bag.append(entry.x)
	var jitter: float = float(Terrain.PROP_JITTER) * WK.PIXEL_ZOOM
	for row: int in range(-Terrain.BLEED_TILES, map.rows + Terrain.BLEED_TILES):
		for column: int in range(-Terrain.BLEED_TILES, map.columns + Terrain.BLEED_TILES):
			if map.cell(column, row) != "." or prop_rng.randf() > Terrain.PROP_CHANCE:
				continue
			var offset := Vector2(prop_rng.randf_range(-jitter, jitter),
				prop_rng.randf_range(-jitter, jitter))
			_ground_sprite(Terrain.tile(bag[prop_rng.randi_range(0, bag.size() - 1)]),
				cell_to_world(Vector2i(column, row)) + offset)

func _build_path_points() -> void:
	_path_points = PackedVector2Array()
	for waypoint: Vector2i in map.waypoints:
		_path_points.append(cell_to_world(waypoint))

func _build_slots() -> void:
	var slot_scene: PackedScene = load("res://scenes/run/TowerSlot.tscn")
	for cell: Vector2i in map.build_tiles():
		var slot: TowerSlot = slot_scene.instantiate()
		slot.position = cell_to_world(cell)
		_slot_layer.add_child(slot)
		slot.setup(cell)
		_slots[cell] = slot

func _place_ward_stone() -> void:
	var centre: Vector2 = map.ward_stone_center()
	_ward_stone.texture = Terrain.keep()
	_ward_stone.scale = Vector2.ONE * WK.PIXEL_ZOOM
	_ward_stone.visible = true
	_ward_stone.position = (centre + Vector2(0.5, 0.5)) * float(WK.TILE_SIZE)

func _cache_explosion_frames() -> void:
	for entry: Array in [
			["explosion_pixel", "pixelExplosion"],
			["explosion_simple", "simpleExplosion"],
			["explosion_ground", "groundExplosion"],
			["explosion_regular", "regularExplosion"],
			["explosion_sonic", "sonicExplosion"]]:
		var frames: Array = []
		for index: int in 9:
			var texture: AtlasTexture = SpriteAtlas.frame(entry[0], "%s%02d.png" % [entry[1], index])
			if texture != null:
				frames.append(texture)
		_explosion_frames[entry[0]] = frames

## Fits the whole board into the strip of screen the HUD leaves free, so no
## part of the arena is ever hidden behind the chrome.
func _frame_board() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var board: Vector2 = Vector2(map.columns, map.rows) * float(WK.TILE_SIZE)
	var free_height: float = maxf(1.0, viewport_size.y - HUD_TOP_INSET - HUD_BOTTOM_INSET)
	var fit: float = minf(viewport_size.x / board.x, free_height / board.y)
	var free_centre_y: float = HUD_TOP_INSET + free_height * 0.5
	_camera.zoom = Vector2.ONE * fit
	_camera.position = Vector2(
		board.x * 0.5,
		board.y * 0.5 - (free_centre_y - viewport_size.y * 0.5) / fit)
	_camera.make_current()

## Input arrives in screen space; the camera means that is no longer the same
## as world space.
func _to_world(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position

## --- wave loop (User Flow §2) -------------------------------------------

func _start_next_wave() -> void:
	if phase == Phase.ENDED:
		return
	phase = Phase.INTRO
	RunManager.begin_wave()
	var plan: Dictionary = WaveDirector.plan_for_wave(RunManager.wave)
	_spawn_queue = (plan["spawns"] as Array).duplicate()
	_spawn_interval = float(plan["interval"])
	_spawn_timer = 0.0
	_hud.show_wave_banner(RunManager.wave, bool(plan["is_elite"]), StringName(plan["boss_id"]))
	if bool(plan["is_boss"]):
		AudioBus.play_music(AudioBus.MUSIC_BOSS)
	elif AudioBus.current_music() != AudioBus.MUSIC_GAMEPLAY:
		AudioBus.play_music(AudioBus.MUSIC_GAMEPLAY)
	await get_tree().create_timer(WAVE_INTRO_SECONDS).timeout
	if phase == Phase.INTRO:
		phase = Phase.ACTIVE

func _process(delta: float) -> void:
	_tick_shake(delta)
	if phase != Phase.ACTIVE:
		return
	if not _spawn_queue.is_empty():
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = _spawn_interval
			_spawn_next()
	elif active_enemies.is_empty():
		_on_wave_cleared()

## User Flow §2 exception: a boss wave cannot end early — the boss is an
## active enemy, so the same "queue empty and board empty" test covers it.
func _on_wave_cleared() -> void:
	phase = Phase.CLEARED
	_hud.set_bank_available(true)
	RunManager.complete_wave()

func _spawn_next() -> void:
	var entry: Dictionary = _spawn_queue.pop_front()
	var def: EnemyDef = Registry.enemy(StringName(entry["id"]))
	if def == null:
		push_warning("WARDKEEP: wave plan referenced unknown enemy %s" % entry["id"])
		return
	# A pack archetype spends one plan entry on several bodies. They are strung
	# out along the lane rather than stacked on the spawn point, or they would
	# read as one enemy and every splash would hit the whole pack at once.
	for index: int in maxi(1, def.pack_size):
		_spawn(def, bool(entry["elite"]), float(index) * PACK_SPACING)

func spawn_extra(enemy_id: StringName, wave: int, elite: bool, at_progress: float) -> Enemy:
	var def: EnemyDef = Registry.enemy(enemy_id)
	if def == null:
		return null
	return _spawn(def, elite, at_progress, wave)

func _spawn(def: EnemyDef, elite: bool, at_progress: float, wave_override: int = -1) -> Enemy:
	var enemy: Enemy = _take_enemy(def)
	if enemy == null:
		return null
	var wave: int = RunManager.wave if wave_override < 0 else wave_override
	enemy.setup(def, wave, elite, _path_points)
	if at_progress > 0.0:
		enemy.seek_to(at_progress)
	active_enemies.append(enemy)
	return enemy

func _take_enemy(def: EnemyDef) -> Enemy:
	var pool: Array = _enemy_pools.get(def.id, [])
	while not pool.is_empty():
		var recycled: Enemy = pool.pop_back()
		if is_instance_valid(recycled):
			return recycled
	var path: String = def.scene_path
	if not ResourceLoader.exists(path):
		push_error("WARDKEEP: enemy scene missing at %s" % path)
		return null
	var enemy: Enemy = (load(path) as PackedScene).instantiate()
	_enemy_layer.add_child(enemy)
	enemy.died.connect(_on_enemy_died)
	enemy.leaked.connect(_on_enemy_leaked)
	enemy.struck_ward_stone.connect(_on_ward_stone_struck)
	return enemy

func _release_enemy(enemy: Enemy) -> void:
	active_enemies.erase(enemy)
	enemy.despawn()
	var pool: Array = _enemy_pools.get(enemy.def.id, [])
	pool.append(enemy)
	_enemy_pools[enemy.def.id] = pool

func _on_enemy_died(enemy: Enemy) -> void:
	RunManager.on_enemy_killed(enemy.def, enemy.is_elite)
	if enemy.def.is_boss:
		play_vfx("boss_death", enemy.global_position)
		AudioBus.play_sfx(AudioBus.SFX_BOSS_DEATH)
	else:
		play_vfx("death", enemy.global_position)
		AudioBus.play_random_sfx(AudioBus.SFX_ENEMY_DEATH)
	_release_enemy(enemy)

## A boss hitting the stone, rather than an enemy getting through it. The
## enemy stays on the board, so nothing is released here.
func _on_ward_stone_struck(_enemy: Enemy, amount: int) -> void:
	RunManager.damage_ward_stone(amount)

func _on_enemy_leaked(enemy: Enemy) -> void:
	RunManager.damage_ward_stone(maxi(1, int(round(enemy.damage))))
	_release_enemy(enemy)

## --- pools --------------------------------------------------------------

func spawn_projectile() -> Projectile:
	while not _projectile_pool.is_empty():
		var recycled: Projectile = _projectile_pool.pop_back()
		if is_instance_valid(recycled):
			return recycled
	var projectile: Projectile = (load("res://scenes/run/Projectile.tscn") as PackedScene).instantiate()
	_projectile_layer.add_child(projectile)
	projectile.finished.connect(_on_projectile_finished)
	return projectile

func _on_projectile_finished(projectile: Projectile) -> void:
	projectile.despawn()
	_projectile_pool.append(projectile)

func _take_vfx() -> Vfx:
	while not _vfx_pool.is_empty():
		var recycled: Vfx = _vfx_pool.pop_back()
		if is_instance_valid(recycled):
			return recycled
	var effect: Vfx = (load("res://scenes/vfx/Vfx.tscn") as PackedScene).instantiate()
	_vfx_layer.add_child(effect)
	effect.finished.connect(_on_vfx_finished)
	return effect

func _on_vfx_finished(effect: Vfx) -> void:
	_vfx_pool.append(effect)

## Pipeline §2.4 maps each effect to a pack. Reduced motion (User Flow §3.7)
## drops everything except the two explosion beats that read as feedback.
func play_vfx(kind: String, at: Vector2) -> void:
	var reduced: bool = bool(SaveManager.get_setting("reduced_motion", false))
	match kind:
		"death":
			var effect: Vfx = _take_vfx()
			effect.play_frames(_explosion_frames["explosion_pixel"], at, 0.5, Color.WHITE, 20.0)
		"boss_death":
			var effect: Vfx = _take_vfx()
			effect.play_frames(_explosion_frames["explosion_regular"], at, 1.3, Color.WHITE, 16.0)
			_shake(0.5)
		"ward_hit":
			var effect: Vfx = _take_vfx()
			effect.play_frames(_explosion_frames["explosion_ground"], at, 0.9, Color.WHITE, 18.0)
		"frost_field":
			if reduced:
				return
			var effect: Vfx = _take_vfx()
			effect.play_frames(_explosion_frames["explosion_sonic"], at, 1.6,
				Color(0.65, 0.88, 1.0), 14.0)
		_:
			if reduced:
				return
			_play_small_effect(kind, at)

func _play_small_effect(kind: String, at: Vector2) -> void:
	var element: int = int(kind.get_slice("_", 1)) if kind.contains("_") else 0
	var texture_path: String = "res://assets/sprites/vfx/particle_magic_light/light_02.png"
	match element:
		int(WK.RuneElement.FROST):
			texture_path = "res://assets/sprites/vfx/particle_magic_light/magic_02.png"
		int(WK.RuneElement.BLIGHT):
			texture_path = "res://assets/sprites/vfx/particle_smoke/smoke_02.png"
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		return
	var tint: Color = WK.element_tint(element)
	_take_vfx().play_puff(texture, at, 0.6 if kind.begins_with("muzzle") else 0.9, tint, 0.28)

## --- queries used by towers and boss patterns ---------------------------

func enemies_in_radius(at: Vector2, radius: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	var radius_squared: float = radius * radius
	for enemy: Enemy in active_enemies:
		if enemy.alive and enemy.global_position.distance_squared_to(at) <= radius_squared:
			out.append(enemy)
	return out

func towers_in_radius(at: Vector2, radius: float) -> Array[Tower]:
	var out: Array[Tower] = []
	var radius_squared: float = radius * radius
	for tower: Node in RunManager.placed_towers:
		if tower is Tower and tower.global_position.distance_squared_to(at) <= radius_squared:
			out.append(tower)
	return out

## --- placement (User Flow §3.3) -----------------------------------------

func _on_tower_armed(def: TowerDef) -> void:
	_armed_def = def
	_close_tower_panel()
	_ghost.texture = def.texture()
	_ghost.scale = Vector2.ONE * WK.PIXEL_ZOOM
	_ghost.modulate = WK.element_tint(def.rune_element)
	_ghost.modulate.a = 0.7
	_ghost.visible = true
	_show_placement_hints(true)
	# Tier 1 reach, so the player can judge coverage before paying for it.
	_range_indicator.show_range(_ghost.global_position,
		def.tier(0).range_tiles * RunManager.modifiers.range_mult * float(WK.TILE_SIZE),
		WK.element_tint(def.rune_element))

func _clear_armed() -> void:
	_armed_def = null
	_ghost.visible = false
	_range_indicator.hide_range()
	_show_placement_hints(false)
	_hud.clear_armed()

## Every build tile reports its state while placing — a pad where the tower
## can go, a cross where one already stands.
func _show_placement_hints(visible: bool) -> void:
	for slot: TowerSlot in _slots.values():
		if visible:
			slot.show_placement_hint(slot.is_free())
		else:
			slot.clear_hint()

func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.ENDED:
		return
	if event is InputEventMouseMotion and _armed_def != null:
		_move_ghost(_to_world((event as InputEventMouseMotion).position))
	elif event is InputEventScreenDrag and _armed_def != null:
		_move_ghost(_to_world((event as InputEventScreenDrag).position))
	elif event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		_resolve_tap(_to_world((event as InputEventMouseButton).position))
	elif event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed:
		_resolve_tap(_to_world((event as InputEventScreenTouch).position))

## Snaps to the build tile under the finger so the preview sits where the
## tower actually would, not under the fingertip.
func _move_ghost(at: Vector2) -> void:
	var cell: Vector2i = world_to_cell(at)
	var slot: TowerSlot = _slots.get(cell, null)
	var target: Vector2 = cell_to_world(cell) if slot != null else at
	_ghost.global_position = target
	_range_indicator.move_to(target)

func _resolve_tap(at: Vector2) -> void:
	var cell: Vector2i = world_to_cell(at)
	if _armed_def != null:
		_try_place(cell)
		return
	var slot: TowerSlot = _slots.get(cell, null)
	if slot != null and slot.tower != null:
		_select_tower(slot.tower)
	else:
		_close_tower_panel()

func _try_place(cell: Vector2i) -> void:
	var slot: TowerSlot = _slots.get(cell, null)
	if slot == null or not slot.is_free():
		_hud.flash_message("Place on a highlighted build tile.")
		_clear_armed()
		return
	var cost: int = _armed_def.purchase_cost()
	if not RunManager.spend_gold(cost):
		_hud.flash_message("Not enough gold.")
		_clear_armed()
		return
	var scene_path: String = _armed_def.scene_path
	if not ResourceLoader.exists(scene_path):
		push_error("WARDKEEP: tower scene missing at %s" % scene_path)
		RunManager.add_gold(cost)
		_clear_armed()
		return
	var tower: Tower = (load(scene_path) as PackedScene).instantiate()
	_tower_layer.add_child(tower)
	tower.position = cell_to_world(cell)
	tower.setup(_armed_def, cell)
	slot.tower = tower
	RunManager.register_tower(tower)
	AudioBus.select()
	_clear_armed()

func _select_tower(tower: Tower) -> void:
	_selected_tower = tower
	for slot: TowerSlot in _slots.values():
		slot.clear_hint()
	var slot: TowerSlot = _slots.get(tower.grid_cell, null)
	if slot != null:
		slot.show_selected()
	_range_indicator.show_range(tower.global_position, tower.effective_range(),
		WK.element_tint(tower.def.rune_element))
	_tower_panel.open(tower)

func _close_tower_panel() -> void:
	_selected_tower = null
	_range_indicator.hide_range()
	_tower_panel.close()
	for slot: TowerSlot in _slots.values():
		slot.clear_hint()

func _on_upgrade_tower(tower: Tower) -> void:
	if tower.upgrade():
		AudioBus.select()
		_range_indicator.show_range(tower.global_position, tower.effective_range(),
			WK.element_tint(tower.def.rune_element))
		_tower_panel.open(tower)
	else:
		_hud.flash_message("Not enough gold.")

func _on_sell_tower(tower: Tower) -> void:
	RunManager.add_gold(tower.sell_value())
	var slot: TowerSlot = _slots.get(tower.grid_cell, null)
	if slot != null:
		slot.tower = null
	RunManager.unregister_tower(tower)
	tower.queue_free()
	AudioBus.click()
	_close_tower_panel()

## --- draft, pause, ending -----------------------------------------------

func _on_draft_offered(cards: Array) -> void:
	phase = Phase.DRAFT
	get_tree().paused = true
	_draft_overlay.show_cards(cards)

func _on_draft_card_chosen(card: DraftCardDef) -> void:
	RunManager.take_draft_card(card)
	AudioBus.select()
	get_tree().paused = false
	_hud.set_bank_available(false)
	_hud.refresh_tray()
	_start_next_wave()

## Cycles the run clock. An endless game asks the player to watch wave 40 play
## out, and at 1x that is a chore rather than a decision.
func _on_speed_pressed() -> void:
	AudioBus.click()
	_apply_speed(_speed_step + 1)

func _apply_speed(step: int) -> void:
	_speed_step = posmod(step, WK.SPEED_STEPS.size())
	SaveManager.set_setting("game_speed_step", _speed_step)
	Engine.time_scale = _base_time_scale * WK.SPEED_STEPS[_speed_step]
	_hud.set_speed_label(WK.SPEED_STEPS[_speed_step])

func _open_pause() -> void:
	if phase == Phase.ENDED:
		return
	get_tree().paused = true
	_pause_menu.open(phase != Phase.ACTIVE)

func _close_pause() -> void:
	_pause_menu.close()
	if phase != Phase.DRAFT:
		get_tree().paused = false

func _on_forfeit() -> void:
	get_tree().paused = false
	RunManager.end_run(false)

## Feature Spec §2.6 — banks at 100% instead of the 75% a loss pays.
func _on_bank_pressed() -> void:
	get_tree().paused = false
	RunManager.bank_and_retreat()

func _on_ward_stone_damaged(hp: int, max_hp: int) -> void:
	AudioBus.play_sfx(AudioBus.SFX_WARD_STONE_HIT)
	play_vfx("boss_death" if hp <= 0 else "ward_hit", _ward_stone.global_position)
	_shake(0.35)
	if hp < max_hp:
		_ward_stone.modulate = Color(1.0, 0.75, 0.7)

func _on_run_ended(_victory: bool, _waves: int, _runestones: int) -> void:
	phase = Phase.ENDED
	get_tree().paused = false
	GameState.goto_scene(GameState.SCENE_RUN_SUMMARY)

## --- screen shake -------------------------------------------------------

func _shake(duration: float) -> void:
	if bool(SaveManager.get_setting("reduced_motion", false)):
		return
	_shake_time = maxf(_shake_time, duration)

func _tick_shake(delta: float) -> void:
	if _shake_time <= 0.0:
		if position != Vector2.ZERO:
			position = Vector2.ZERO
		return
	_shake_time -= delta
	var strength: float = clampf(_shake_time * 18.0, 0.0, 7.0)
	position = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))

## --- onboarding (User Flow §4) ------------------------------------------

func _maybe_run_onboarding() -> void:
	if bool(SaveManager.get_stat("onboarding_complete", false)):
		_onboarding.hide()
		return
	_onboarding.begin()
	SaveManager.set_stat("onboarding_complete", true)
	SaveManager.write_save()
