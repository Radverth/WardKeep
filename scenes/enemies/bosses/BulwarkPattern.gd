extends BossPattern
class_name BulwarkPattern
## Feature Spec §2.5, wave 10 — "Slow single-target melee hits on the Ward
## Stone if it reaches it; periodically spawns 2 Grunts. High HP, low speed."
##
## PROVISIONAL: the spec says "periodically" without an interval
## (SPEC_GAPS.md #4).

const SUMMON_INTERVAL: float = 7.0
const SUMMON_COUNT: int = 2
const SUMMON_ID: StringName = &"grunt"
## Summons appear just behind the boss so they don't skip path it has walked.
const SUMMON_TRAIL: float = 48.0

var _timer: float = 0.0

func tick(delta: float) -> void:
	_timer += delta
	if _timer < SUMMON_INTERVAL:
		return
	_timer = 0.0
	var arena: Node = Arena.current
	if arena == null:
		return
	for index: int in SUMMON_COUNT:
		arena.spawn_extra(SUMMON_ID, boss.wave, false,
			maxf(0.0, boss.path_progress - SUMMON_TRAIL * float(index + 1)))
