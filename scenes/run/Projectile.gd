extends Node2D
class_name Projectile
## Pooled shot fired by a ranged tower. Technical Architecture §6 requires
## pooling for projectiles, so this never frees itself — it reports back to the
## Arena, which returns it to the pool.

signal finished(projectile: Projectile)

const SPEED: float = 720.0
## A shot that outlives its target still resolves at the last known position,
## so damage is never silently lost when an enemy dies in flight.
const MAX_LIFETIME: float = 3.0

@onready var _sprite: Sprite2D = $Sprite

var _tower: Tower = null
var _target: Enemy = null
var _target_position: Vector2 = Vector2.ZERO
var _lifetime: float = 0.0
var active: bool = false

func launch(tower: Tower, target: Enemy, tint: Color, texture: Texture2D) -> void:
	_tower = tower
	_target = target
	_target_position = target.global_position
	_lifetime = 0.0
	active = true
	global_position = tower.global_position
	_sprite.texture = texture
	_sprite.modulate = tint
	show()
	set_process(true)

func _process(delta: float) -> void:
	if not active:
		return
	_lifetime += delta
	if is_instance_valid(_target) and _target.alive:
		_target_position = _target.global_position
	var to_target: Vector2 = _target_position - global_position
	var step: float = SPEED * delta
	if to_target.length() <= step or _lifetime >= MAX_LIFETIME:
		global_position = _target_position
		_impact()
		return
	global_position += to_target.normalized() * step
	rotation = to_target.angle()

func _impact() -> void:
	active = false
	set_process(false)
	if is_instance_valid(_tower):
		_tower.on_projectile_hit(_target, global_position)
	finished.emit(self)

func despawn() -> void:
	active = false
	set_process(false)
	hide()
