extends Resource
class_name WaveBand
## One row of the Feature Spec §2.1 wave-composition table.
## enemy_budget = base + step x (wave - from_wave)

@export var from_wave: int = 1
@export var to_wave: int = 5      ## inclusive; -1 means "no upper bound"
@export var base: float = 10.0
@export var step: float = 6.0
@export var spawn_interval: float = 1.2

func contains(wave: int) -> bool:
	if wave < from_wave:
		return false
	return to_wave < 0 or wave <= to_wave

func budget_for(wave: int) -> float:
	return base + step * float(wave - from_wave)
