extends Resource
class_name WaveTable
## Technical Architecture §4.2: the authored curve. Wave index has no upper
## bound — past the last authored row WaveDirector extrapolates with the same
## §2.1/§2.4 formulas, so a run never hard-stops for balance-table reasons.

@export var rows: Array[WaveRow] = []

func has_row(wave: int) -> bool:
	return wave >= 1 and wave <= rows.size()

func row_for(wave: int) -> WaveRow:
	if has_row(wave):
		return rows[wave - 1]
	return null

func authored_length() -> int:
	return rows.size()
