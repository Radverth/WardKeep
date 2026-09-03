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

## Timed effects one enemy projects onto another. Auras are re-applied on a
## cadence rather than tracked as a live list of sources, so a support dying
## mid-pulse simply stops refreshing and its effect lapses.
const AURA_WARD: StringName = &"ward"
const AURA_HASTE: StringName = &"haste"
## How often a support re-applies, and how long one application lasts. The
## lifetime is the longer of the two so the effect does not strobe between
## pulses.
const AURA_PULSE: float = 0.4
const AURA_LIFETIME: float = 0.7
## Alpha the sprite drops to while an archetype is phased out.
const PHASED_ALPHA: float = 0.28

## Walk bob: without it everything on the lane slides rather than walks, which
## is most obvious on the bosses, whose art is too big to read as anything but
## a shape being moved. Height in pixels and cycles per second.
const BOB_HEIGHT: float = 3.0
const BOB_SPEED: float = 5.0

const AURA_RING_ALPHA: float = 0.42
const AURA_RING_WIDTH: float = 1.5

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
var _auras: Dictionary = {}            ## kind -> { amount, remaining }

## Untargetable but still walking — see Shade.
var phased: bool = false
var _phase_timer: float = 0.0
var _aura_timer: float = 0.0
## Which way the enemy last travelled horizontally, so it keeps facing that way
## through a vertical leg rather than snapping back to the artwork's default.
var _facing_left: bool = false
var _bob_phase: float = 0.0
var _frame_time: float = 0.0
var _frame: int = 0

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
	_auras.clear()
	phased = false
	_phase_timer = def.phase_visible_seconds
	_aura_timer = 0.0
	_facing_left = false
	# Staggered per enemy, or a whole wave bobs in lockstep like a chorus line.
	_bob_phase = randf() * TAU
	alive = true
	global_position = path[0] if path.size() > 0 else Vector2.ZERO
	_apply_sprite()
	show()
	set_process(true)
	_refresh_health_bar()

func _apply_sprite() -> void:
	_frame_time = 0.0
	_frame = 0
	_sprite.texture = def.texture()
	_sprite.scale = Vector2.ONE * def.scale_factor
	_sprite.flip_h = false if def.sprite_faces_camera else (_facing_left != def.sprite_faces_left)
	# §2.3 — an Elite is the same archetype with a glow tint over it.
	_sprite.modulate = def.tint * (Color(1.35, 1.15, 0.75) if is_elite else Color.WHITE)
	if phased:
		_sprite.modulate.a *= PHASED_ALPHA
	queue_redraw()

func _process(delta: float) -> void:
	if not alive:
		return
	_tick_animation(delta)
	_tick_effects(delta)
	if not alive:
		return
	_tick_phase(delta)
	_tick_aura(delta)
	_tick_bob(delta)
	on_tick(delta)
	if not alive or reached_ward_stone:
		return
	_advance(delta * current_speed() * float(WK.TILE_SIZE))

func current_speed() -> float:
	var strongest: float = 0.0
	for slow: Dictionary in _slows:
		strongest = maxf(strongest, float(slow["amount"]))
	return base_speed * (1.0 - clampf(strongest, 0.0, 0.9)) * (1.0 + aura(AURA_HASTE))

## Towers only shoot what they can see. A phased archetype keeps walking and
## keeps taking splash it happens to sit in, but cannot be acquired.
func is_targetable() -> bool:
	return alive and not phased

func is_slowed() -> bool:
	return not _slows.is_empty()

func _tick_effects(delta: float) -> void:
	for index: int in range(_slows.size() - 1, -1, -1):
		_slows[index]["remaining"] = float(_slows[index]["remaining"]) - delta
		if float(_slows[index]["remaining"]) <= 0.0:
			_slows.remove_at(index)
	for kind: StringName in _auras.keys():
		var entry: Dictionary = _auras[kind]
		entry["remaining"] = float(entry["remaining"]) - delta
		if float(entry["remaining"]) <= 0.0:
			_auras.erase(kind)
	for index: int in range(_dots.size() - 1, -1, -1):
		var dot: Dictionary = _dots[index]
		take_damage(float(dot["dps"]) * delta, WK.RuneElement.BLIGHT, true)
		dot["remaining"] = float(dot["remaining"]) - delta
		if float(dot["remaining"]) <= 0.0:
			_dots.remove_at(index)
		if not alive:
			return

## Bobs the sprite rather than the node: the node's position is the enemy's
## place on the lane, which targeting, splash and the tap-to-inspect radius all
## measure against, and none of them should wobble.
## Advances an animated sheet. Driven off the same delta as everything else,
## so the game-speed control slows and hurries the animation with the rest of
## the board rather than letting a boss flail at 3x while it walks at 1x.
func _tick_animation(delta: float) -> void:
	if def == null or not def.is_animated():
		return
	_frame_time += delta * maxf(0.0, def.sprite_fps)
	var advanced: int = int(_frame_time)
	if advanced <= 0:
		return
	_frame_time -= float(advanced)
	_frame = posmod(_frame + advanced, def.sprite_frames)
	_sprite.texture = def.frame_texture(_frame)

func _tick_bob(delta: float) -> void:
	if reached_ward_stone:
		return
	_bob_phase += delta * BOB_SPEED * maxf(0.2, current_speed())
	_sprite.position.y = -absf(sin(_bob_phase)) * BOB_HEIGHT

func _advance(distance: float) -> void:
	while distance > 0.0 and _segment < _path.size() - 1:
		var target: Vector2 = _path[_segment + 1]
		var to_target: Vector2 = target - global_position
		_face_along(to_target)
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

## Turns to face the way it is walking. A lane that runs right to left had
## every soldier moonwalking down it, because the artwork all faces one way.
## Vertical legs keep the last horizontal facing rather than snapping.
func _face_along(direction: Vector2) -> void:
	if def == null or def.sprite_faces_camera or absf(direction.x) < 0.01:
		return
	var moving_left: bool = direction.x < 0.0
	if moving_left == _facing_left:
		return
	_facing_left = moving_left
	_sprite.flip_h = moving_left != def.sprite_faces_left

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
	amount *= 1.0 - clampf(aura(AURA_WARD), 0.0, 0.9)
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

## Called every frame while alive, after effects and before movement.
func on_tick(_delta: float) -> void:
	pass

## --- auras and phasing --------------------------------------------------

## Strength of a projected effect currently on this enemy, 0.0 when none.
func aura(kind: StringName) -> float:
	return float(_auras[kind]["amount"]) if _auras.has(kind) else 0.0

## Latest application wins on strength but never shortens the timer, so two
## supports overlapping do not fight each other.
func refresh_aura(kind: StringName, amount: float, duration: float) -> void:
	if not alive or amount <= 0.0:
		return
	if _auras.has(kind):
		var entry: Dictionary = _auras[kind]
		entry["amount"] = maxf(float(entry["amount"]), amount)
		entry["remaining"] = maxf(float(entry["remaining"]), duration)
		return
	_auras[kind] = {"amount": amount, "remaining": duration}

func heal(amount: float) -> void:
	if not alive or amount <= 0.0 or hp >= max_hp:
		return
	hp = minf(max_hp, hp + amount)
	_refresh_health_bar()

## Every living enemy within this archetype's aura radius, itself included —
## a support that cannot benefit from its own ward would have to be handled
## as a special case everywhere it is read.
func aura_neighbours() -> Array[Enemy]:
	var out: Array[Enemy] = []
	var arena: Node = Arena.current
	if arena == null or def == null or def.aura_radius_tiles <= 0.0:
		return out
	var radius: float = def.aura_radius_tiles * float(WK.TILE_SIZE)
	var radius_squared: float = radius * radius
	for other: Enemy in arena.active_enemies:
		if other.alive and other.global_position.distance_squared_to(global_position) <= radius_squared:
			out.append(other)
	return out

## Runs the archetype's aura on a cadence rather than every frame: an aura is a
## sweep over every live enemy, and at 1.0s spawn intervals a wave can hold
## dozens of them.
func _tick_aura(delta: float) -> void:
	if def == null or def.aura_radius_tiles <= 0.0:
		return
	_aura_timer -= delta
	if _aura_timer > 0.0:
		return
	_aura_timer = AURA_PULSE
	on_aura_pulse()

## What a support projects. Overridden by the archetypes that have one.
func on_aura_pulse() -> void:
	pass

func _tick_phase(delta: float) -> void:
	if def == null or def.phase_hidden_seconds <= 0.0:
		return
	_phase_timer -= delta
	if _phase_timer > 0.0:
		return
	phased = not phased
	_phase_timer = def.phase_hidden_seconds if phased else def.phase_visible_seconds
	_apply_sprite()

func despawn() -> void:
	alive = false
	set_process(false)
	hide()

## --- health bar ---------------------------------------------------------

func _ready() -> void:
	_health_bar.draw.connect(_draw_health_bar)

## The ring a support projects, drawn on the enemy itself so it sits under the
## sprite. Without it a player has no way to see why a pack is not dying, and
## "kill the support first" is not a decision they can make.
func _draw() -> void:
	if not alive or def == null or def.aura_radius_tiles <= 0.0:
		return
	# Outline only, and thin. Supports arrive in groups, and a filled disc each
	# turned four Shieldbearers walking together into a wash of overlapping
	# circles that read as a rendering fault rather than as information.
	var radius: float = def.aura_radius_tiles * float(WK.TILE_SIZE)
	var colour: Color = aura_ring_color()
	colour.a = AURA_RING_ALPHA
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, colour, AURA_RING_WIDTH, true)

## Overridden by each support so its ring reads as its own effect.
func aura_ring_color() -> Color:
	return Color(1, 1, 1, 0.5)

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
