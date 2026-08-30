extends Node2D
class_name Vfx
## Pooled one-shot effect. Technical Architecture §6 forbids per-frame
## instantiate/free of high-frequency nodes, so the Arena recycles these.

signal finished(effect: Vfx)

@onready var _sprite: Sprite2D = $Sprite

var _frames: Array = []
var _fps: float = 18.0
var _elapsed: float = 0.0
var _fade: bool = false
var _duration: float = 0.4
var active: bool = false

## Plays a frame sequence (the Explosion Pack sheets).
func play_frames(frames: Array, at: Vector2, effect_scale: float, tint: Color, fps: float = 18.0) -> void:
	_frames = frames
	_fps = fps
	_fade = false
	_elapsed = 0.0
	_duration = float(frames.size()) / fps if fps > 0.0 else 0.4
	_start(at, effect_scale, tint)

## Plays a single texture that scales up and fades out (Particle Pack pieces).
func play_puff(texture: Texture2D, at: Vector2, effect_scale: float, tint: Color, duration: float = 0.35) -> void:
	_frames = [texture]
	_fade = true
	_elapsed = 0.0
	_duration = duration
	_start(at, effect_scale, tint)

func _start(at: Vector2, effect_scale: float, tint: Color) -> void:
	global_position = at
	_sprite.texture = _frames[0] if not _frames.is_empty() else null
	_sprite.scale = Vector2.ONE * effect_scale
	_sprite.modulate = tint
	active = true
	show()
	set_process(true)

func _process(delta: float) -> void:
	if not active:
		return
	_elapsed += delta
	if _elapsed >= _duration:
		_stop()
		return
	var ratio: float = _elapsed / _duration
	if _fade:
		_sprite.modulate.a = 1.0 - ratio
		_sprite.scale = _sprite.scale.lerp(_sprite.scale * 1.02, 0.5)
	else:
		var index: int = clampi(int(_elapsed * _fps), 0, _frames.size() - 1)
		_sprite.texture = _frames[index]

func _stop() -> void:
	active = false
	set_process(false)
	hide()
	finished.emit(self)

func despawn() -> void:
	_stop()
