extends Enemy
class_name Boss
## Feature Spec §2.5. A boss is an Enemy whose behaviour comes from a pattern
## script named on its EnemyDef, so the three fights stay separate objects
## rather than branches inside one boss class.

## Feature Spec §2.5 — "Slow single-target melee hits on the Ward Stone if it
## reaches it". A boss that arrives does not leak through and vanish: it stops
## at the stone and keeps swinging until it is killed or the run is over. That
## also satisfies User Flow §4, which says a boss wave cannot end while the
## boss lives.
##
## PROVISIONAL: the spec says "slow" without giving an interval.
## See SPEC_GAPS.md #4.
const SIEGE_INTERVAL: float = 2.0

var pattern: BossPattern = null
var _siege_timer: float = 0.0

func setup(enemy_def: EnemyDef, wave_index: int, elite: bool, path: PackedVector2Array) -> void:
	_clear_pattern()
	_siege_timer = 0.0
	super(enemy_def, wave_index, elite, path)
	if enemy_def.boss_pattern_script != null:
		var instance: Object = enemy_def.boss_pattern_script.new()
		if instance is BossPattern:
			pattern = instance
			add_child(pattern)
			pattern.setup(self)

func _clear_pattern() -> void:
	if pattern != null and is_instance_valid(pattern):
		pattern.queue_free()
	pattern = null

func _process(delta: float) -> void:
	super(delta)
	if not alive:
		return
	if pattern != null:
		pattern.tick(delta)
	if reached_ward_stone:
		_tick_siege(delta)

## The boss stays alive, targetable and in the wave while it does this, so the
## player can still kill it — reaching the stone is a crisis, not a loss.
func _tick_siege(delta: float) -> void:
	_siege_timer -= delta
	if _siege_timer > 0.0:
		return
	_siege_timer = SIEGE_INTERVAL
	struck_ward_stone.emit(self, maxi(1, int(round(damage))))

## Arrival stops the advance but does not remove the boss; the first blow
## lands immediately rather than after a free interval.
func on_reach_ward_stone() -> void:
	_siege_timer = 0.0

func take_damage(raw: float, element: WK.RuneElement, ignore_matchup: bool = false) -> void:
	var before: float = hp
	super(raw, element, ignore_matchup)
	if pattern != null and alive and hp < before:
		pattern.on_damaged(before, hp)

func on_death() -> void:
	if pattern != null:
		pattern.on_death()
