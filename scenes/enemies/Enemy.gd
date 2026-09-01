extends Node2D
class_name Enemy
## Base class for every enemy archetype. One scene + one script per archetype
## inherits this (Claude Code Brief §4) — the subclasses carry archetype
## behaviour only, never a switch over ids.
##
## Enemies are pooled (Technical Architecture §6): setup() must fully restore
## a recycled instance, and nothing may be assumed about prior state.

signal died(enemy: Enemy)
signal leaked(enemy: Enemy)
## Raised by anything that reaches the Ward Stone and keeps hitting it rather
## than leaking through — see Boss (Feature Spec §2.5).
signal struck_ward_stone(enemy: Enemy, amount: int)

const HEALTH_BAR_SIZE := Vector2(46, 6)

@onready var _sprite: Sprite2D = $Sprite
@onready var _health_bar: Node2D = $HealthBar

var def: EnemyDef = null
var is_elite: bool = false
var wave: int = 1

var max_hp: float = 1.0
var hp: float = 1.0
var damage: float = 1.0
var base_speed: float = 1.0     ## tiles per second, never wave-scaled (§2.2)
var slow_immune: bool = false

var alive: bool = false
## Distance walked along the path, in pixels — towers target the enemy
## furthest along, so leaks are prevented rather than merely averaged.
var path_progress: float = 0.0

var _path: PackedVector2Array = PackedVector2Array()
var _segment: int = 0
var reached_ward_stone: bool = false
var _slows: Array[Dictionary] = []     ## [{ amount, remaining }]
var _dots: Array[Dictionary] = []      ## [{ dps, remaining }]

func setup(enemy_def: EnemyDef, wave_index: int, elite: bool, path: PackedVector2Array) -> void:
	def = enemy_def
	wave = wave_index
	is_elite = elite
	slow_immune = false
	var stats: Dictionary = WaveDirector.scaled_stats(enemy_def, wave_index, elite)
	max_hp = float(stats["hp"])
	hp = max_hp
	damage = float(stats["damage"])
	base_speed = float(stats["speed"])
	_path = path
	_segment = 0
	path_progress = 0.0
	reached_ward_stone = false
	_slows.clear()
	_dots.clear()
	alive = true
	global_position = path[0] if path.size() > 0 else Vector2.ZERO
	_apply_sprite()
	show()
	set_process(true)
	_refresh_health_bar()

func _apply_sprite() -> void:
	if def.sprite_cell.x < 0:
		_sprite.texture = SpriteAtlas.whole(def.sprite_atlas_path)
	else:
		_sprite.texture = SpriteAtlas.cell(def.sprite_atlas_path, def.sprite_cell.x, def.sprite_cell.y)
	_sprite.scale = Vector2.ONE * def.scale_factor
	# §2.3 — an Elite is the same archetype with a glow tint over it.
	_sprite.modulate = def.tint * (Color(1.35, 1.15, 0.75) if is_elite else Color.WHITE)

func _process(delta: float) -> void:
	if not alive:
		return
	_tick_effects(delta)
	if not alive or reached_ward_stone:
		return
	_advance(delta * current_speed() * float(WK.TILE_SIZE))

func current_speed() -> float:
	var strongest: float = 0.0
	for slow: Dictionary in _slows:
		strongest = maxf(strongest, float(slow["amount"]))
	return base_speed * (1.0 - clampf(strongest, 0.0, 0.9))

func is_slowed() -> bool:
	return not _slows.is_empty()

func _tick_effects(delta: float) -> void:
	for index: int in range(_slows.size() - 1, -1, -1):
		_slows[index]["remaining"] = float(_slows[index]["remaining"]) - delta
		if float(_slows[index]["remaining"]) <= 0.0:
			_slows.remove_at(index)
	for index: int in range(_dots.size() - 1, -1, -1):
		var dot: Dictionary = _dots[index]
		take_damage(float(dot["dps"]) * delta, WK.RuneElement.BLIGHT, true)
		dot["remaining"] = float(dot["remaining"]) - delta
		if float(dot["remaining"]) <= 0.0:
			_dots.remove_at(index)
		if not alive:
			return

func _advance(distance: float) -> void:
	while distance > 0.0 and _segment < _path.size() - 1:
		var target: Vector2 = _path[_segment + 1]
		var to_target: Vector2 = target - global_position
		var length: float = to_target.length()
		if length <= distance:
			global_position = target
			path_progress += length
			distance -= length
			_segment += 1
		else:
			global_position += to_target / length * distance
			path_progress += distance
			distance = 0.0
	if _segment >= _path.size() - 1 and not reached_ward_stone:
		reached_ward_stone = true
		on_reach_ward_stone()

## What happens on arrival. A regular enemy is through and gone; a boss stays
## and lays into the Ward Stone (Feature Spec §2.5), so Boss overrides this.
func on_reach_ward_stone() -> void:
	_leak()

## Places the enemy `distance` pixels along the path — used when something
## spawns mid-path (the Bulwark's summons, the Hollow King's split copies).
func seek_to(distance: float) -> void:
	_segment = 0
	path_progress = 0.0
	if _path.size() > 0:
		global_position = _path[0]
	_advance(distance)

## --- damage -------------------------------------------------------------

## `raw` is the tower's post-modifier damage; the element matchup is applied
## here so every damage source goes through the same rules (Feature Spec §4).
func take_damage(raw: float, element: WK.RuneElement, ignore_matchup: bool = false) -> void:
	if not alive:
		return
	var amount: float = raw
	if not ignore_matchup:
		amount *= Balance.element_multiplier(element, def.armor_type)
	hp -= amount
	_refresh_health_bar()
	if hp <= 0.0:
		_die()

func apply_slow(amount: float, duration: float) -> void:
	if not alive or slow_immune or amount <= 0.0:
		return
	_slows.append({"amount": amount, "remaining": duration})

## An aura re-applies every tick; refresh the existing stack instead of
## growing it without bound.
func refresh_slow(amount: float, duration: float) -> void:
	if not alive or slow_immune or amount <= 0.0:
		return
	for slow: Dictionary in _slows:
		if is_equal_approx(float(slow["amount"]), amount):
			slow["remaining"] = maxf(float(slow["remaining"]), duration)
			return
	_slows.append({"amount": amount, "remaining": duration})

func apply_dot(dps: float, duration: float) -> void:
	if not alive or dps <= 0.0:
		return
	for dot: Dictionary in _dots:
		if is_equal_approx(float(dot["dps"]), dps):
			dot["remaining"] = maxf(float(dot["remaining"]), duration)
			return
	_dots.append({"dps": dps, "remaining": duration})

func active_dot() -> Dictionary:
	return _dots[0] if not _dots.is_empty() else {}

func _die() -> void:
	if not alive:
		return
	alive = false
	set_process(false)
	on_death()
	died.emit(self)

func _leak() -> void:
	if not alive:
		return
	alive = false
	set_process(false)
	leaked.emit(self)

## Hooks for archetype subclasses and boss patterns.
func on_death() -> void:
	pass

func despawn() -> void:
	alive = false
	set_process(false)
	hide()

## --- health bar ---------------------------------------------------------

func _ready() -> void:
	_health_bar.draw.connect(_draw_health_bar)

func _draw_health_bar() -> void:
	if not alive or hp >= max_hp:
		return
	var size: Vector2 = HEALTH_BAR_SIZE * (1.6 if def != null and def.is_boss else 1.0)
	var origin := Vector2(-size.x * 0.5, -size.y * 0.5)
	_health_bar.draw_rect(Rect2(origin, size), Color(0.1, 0.08, 0.08, 0.85))
	var ratio: float = clampf(hp / max_hp, 0.0, 1.0)
	var fill: Color = Color(0.35, 0.75, 0.35) if ratio > 0.4 else Color(0.85, 0.35, 0.25)
	_health_bar.draw_rect(Rect2(origin, Vector2(size.x * ratio, size.y)), fill)

func _refresh_health_bar() -> void:
	if is_instance_valid(_health_bar):
		_health_bar.queue_redraw()
