extends Node
class_name BossPattern
## One boss's attack pattern (Feature Spec §2.5). Attached to the Boss node at
## spawn time from EnemyDef.boss_pattern_script.

var boss: Boss = null

func setup(owner_boss: Boss) -> void:
	boss = owner_boss

## Called every frame while the boss is alive.
func tick(_delta: float) -> void:
	pass

func on_damaged(_hp_before: float, _hp_after: float) -> void:
	pass

func on_death() -> void:
	pass
