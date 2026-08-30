extends BossPattern
class_name HollowKingPattern
## Feature Spec §2.5, wave 30 — "Splits into 2 half-HP copies once at 50% HP
## remaining; each copy retains full damage."

const COPIES: int = 2
const SPLIT_THRESHOLD: float = 0.5
## Copies step apart so they are separately targetable rather than stacked.
const COPY_SPACING: float = 40.0

var can_split: bool = true

func on_damaged(hp_before: float, hp_after: float) -> void:
	if not can_split:
		return
	var threshold: float = boss.max_hp * SPLIT_THRESHOLD
	if hp_before <= threshold or hp_after > threshold:
		return
	can_split = false
	var arena: Node = Arena.current
	if arena == null:
		return
	var copy_hp: float = boss.max_hp * SPLIT_THRESHOLD
	for index: int in COPIES:
		var copy: Enemy = arena.spawn_extra(boss.def.id, boss.wave, false,
			maxf(0.0, boss.path_progress - COPY_SPACING * float(index)))
		if copy == null:
			continue
		copy.max_hp = copy_hp
		copy.hp = copy_hp
		# Each copy keeps full damage (§2.5) but must not split again.
		if copy is Boss and (copy as Boss).pattern is HollowKingPattern:
			((copy as Boss).pattern as HollowKingPattern).can_split = false
	# The original is consumed by the split.
	boss.hp = 0.0
	boss.take_damage(0.0, WK.RuneElement.PHYSICAL, true)
