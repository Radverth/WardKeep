extends Enemy
class_name Hexer
## Unarmoured support. Mends the wounded around it, so damage that does not
## finish a target is wasted while a Hexer is alive.
##
## It restores rather than suppresses deliberately: Feature Spec §2.5 gives
## Frostmaw the tower fire-rate debuff, and a regular archetype doing the same
## thing would make the wave-20 boss's signature move unremarkable.
##
## Stats live in res://resources/enemies/hexer.tres, not here. The whole enemy
## roster is PROVISIONAL — the document suite has no enemy table
## (SPEC_GAPS.md #3).

const DEF_PATH: String = "res://resources/enemies/hexer.tres"
const RING_COLOR: Color = Color(0.65, 0.90, 0.55)

func on_aura_pulse() -> void:
	# Healing is a rate, and the pulse is the only place it is applied, so the
	# per-second figure has to be paid out one pulse at a time.
	var healed: float = def.aura_heal_per_second * AURA_PULSE
	for other: Enemy in aura_neighbours():
		other.heal(healed)

func aura_ring_color() -> Color:
	return RING_COLOR
