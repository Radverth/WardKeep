extends BossPattern
class_name FrostmawPattern
## Feature Spec §2.5, wave 20 — "Casts a slow field that reduces nearby tower
## fire rate every 8s; immune to Frost-element slow effects."
##
## PROVISIONAL: field radius, strength and duration are not specified
## (SPEC_GAPS.md #4).

const CAST_INTERVAL: float = 8.0
const FIELD_RADIUS_TILES: float = 3.0
const FIRE_RATE_PENALTY: float = 0.4
const PENALTY_DURATION: float = 4.0

var _timer: float = 0.0

func setup(owner_boss: Boss) -> void:
	super(owner_boss)
	boss.slow_immune = true

func tick(delta: float) -> void:
	_timer += delta
	if _timer < CAST_INTERVAL:
		return
	_timer = 0.0
	var arena: Node = Arena.current
	if arena == null:
		return
	for tower: Tower in arena.towers_in_radius(boss.global_position, FIELD_RADIUS_TILES * float(WK.TILE_SIZE)):
		tower.apply_fire_rate_penalty(FIRE_RATE_PENALTY, PENALTY_DURATION)
	arena.play_vfx("frost_field", boss.global_position)
