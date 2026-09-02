extends Enemy
class_name Warlord
## Unarmoured support. Drives everything around it forward faster, which
## shortens the window every tower on the lane gets — the counter is to kill it
## early rather than to out-damage the wave it is leading.
##
## Stats live in res://resources/enemies/warlord.tres, not here. The whole enemy
## roster is PROVISIONAL — the document suite has no enemy table
## (SPEC_GAPS.md #3).

const DEF_PATH: String = "res://resources/enemies/warlord.tres"
const RING_COLOR: Color = Color(0.95, 0.72, 0.30)

func on_aura_pulse() -> void:
	for other: Enemy in aura_neighbours():
		other.refresh_aura(AURA_HASTE, def.aura_speed_bonus, AURA_LIFETIME)

func aura_ring_color() -> Color:
	return RING_COLOR
