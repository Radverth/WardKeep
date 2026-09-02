extends Enemy
class_name Shieldbearer
## Heavy support. Projects a ward that blunts incoming damage for everything
## marching near it, so a pack behind a Shieldbearer has to be broken by
## killing the Shieldbearer rather than by out-damaging the pack.
##
## Stats live in res://resources/enemies/shieldbearer.tres, not here. The whole
## enemy roster is PROVISIONAL — the document suite has no enemy table
## (SPEC_GAPS.md #3).

const DEF_PATH: String = "res://resources/enemies/shieldbearer.tres"
const RING_COLOR: Color = Color(0.62, 0.72, 0.92)

func on_aura_pulse() -> void:
	for other: Enemy in aura_neighbours():
		other.refresh_aura(AURA_WARD, def.aura_damage_reduction, AURA_LIFETIME)

func aura_ring_color() -> Color:
	return RING_COLOR
