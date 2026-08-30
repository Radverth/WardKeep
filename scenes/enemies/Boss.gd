extends Enemy
class_name Boss
## Feature Spec §2.5. A boss is an Enemy whose behaviour comes from a pattern
## script named on its EnemyDef, so the three fights stay separate objects
## rather than branches inside one boss class.

var pattern: BossPattern = null

func setup(enemy_def: EnemyDef, wave_index: int, elite: bool, path: PackedVector2Array) -> void:
	_clear_pattern()
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
	if alive and pattern != null:
		pattern.tick(delta)

func take_damage(raw: float, element: WK.RuneElement, ignore_matchup: bool = false) -> void:
	var before: float = hp
	super(raw, element, ignore_matchup)
	if pattern != null and alive and hp < before:
		pattern.on_damaged(before, hp)

func on_death() -> void:
	if pattern != null:
		pattern.on_death()
