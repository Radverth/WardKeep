extends Node
## Technical Architecture §4.2 — resolves a wave index to a concrete spawn
## list and the stat multipliers to apply to it.
##
## Reads the authored curve from WaveTable.tres; past the last authored row it
## keeps going on the Feature Spec §2.1/§2.4 formulas, so a run never
## hard-stops for balance-table reasons. All randomness comes from a
## run-seeded RNG so the Daily Challenge reproduces exactly (§7).

var rng := RandomNumberGenerator.new()
var _run_seed: int = 0

func begin_run(run_seed: int) -> void:
	_run_seed = run_seed
	rng = RandomNumberGenerator.new()
	rng.seed = run_seed

## Same wave index always resolves the same way within a run, whatever else
## has consumed the run RNG in between.
func _wave_rng(wave: int) -> RandomNumberGenerator:
	var wave_rng := RandomNumberGenerator.new()
	wave_rng.seed = _run_seed ^ (wave * 2654435761)
	return wave_rng

## The authored row, or an extrapolated one past the table (§2.4).
func row_for(wave: int) -> WaveRow:
	var table: WaveTable = Registry.wave_table()
	if table != null and table.has_row(wave):
		return table.row_for(wave)
	var row := WaveRow.new()
	row.wave = wave
	row.enemy_budget = Balance.enemy_budget(wave)
	row.spawn_interval = Balance.spawn_interval(wave)
	row.is_elite = Balance.is_elite_wave(wave)
	row.is_boss = Balance.is_boss_wave(wave)
	if row.is_boss:
		var bosses: Array[EnemyDef] = Registry.bosses()
		var index: int = Balance.boss_index_for_wave(wave)
		if index >= 0 and index < bosses.size():
			row.boss_id = bosses[index].id
	return row

## Feature Spec §2.1 — spend the wave's budget on archetypes weighted by their
## unlock wave, then spawn the result in a shuffled order at a fixed interval.
##
## Returns { "wave", "interval", "multiplier", "is_elite", "elite_id",
##           "boss_id", "spawns": [ { "id", "elite", "boss" } ] }
func plan_for_wave(wave: int) -> Dictionary:
	var row: WaveRow = row_for(wave)
	var wave_rng: RandomNumberGenerator = _wave_rng(wave)
	var eligible: Array[EnemyDef] = []
	for def: EnemyDef in Registry.spawnable_enemies():
		if def.unlock_wave <= wave:
			eligible.append(def)

	var picks: Array[StringName] = []
	var budget: float = row.enemy_budget
	if not eligible.is_empty():
		var cheapest: int = eligible[0].budget_cost
		for def: EnemyDef in eligible:
			cheapest = mini(cheapest, def.budget_cost)
		while budget >= float(cheapest):
			var affordable: Array[EnemyDef] = []
			for def: EnemyDef in eligible:
				if float(def.budget_cost) <= budget:
					affordable.append(def)
			if affordable.is_empty():
				break
			var chosen: EnemyDef = _weighted_pick(wave_rng, affordable)
			picks.append(chosen.id)
			budget -= float(chosen.budget_cost)

	# §2.3 — one random non-boss archetype in an elite wave is upgraded.
	var elite_id: StringName = &""
	if row.is_elite and not picks.is_empty():
		var distinct: Array[StringName] = []
		for id: StringName in picks:
			if id not in distinct:
				distinct.append(id)
		elite_id = distinct[wave_rng.randi_range(0, distinct.size() - 1)]

	_shuffle(wave_rng, picks)

	var spawns: Array[Dictionary] = []
	if row.is_boss and row.boss_id != &"":
		spawns.append({"id": row.boss_id, "elite": false, "boss": true})
	for id: StringName in picks:
		spawns.append({"id": id, "elite": id == elite_id, "boss": false})

	return {
		"wave": wave,
		"interval": row.spawn_interval,
		"multiplier": Balance.stat_multiplier(wave),
		"is_elite": row.is_elite,
		"is_boss": row.is_boss,
		"elite_id": elite_id,
		"boss_id": row.boss_id,
		"spawns": spawns,
	}

## Feature Spec §2.2 — HP and damage scale, speed never does. §2.3 doubles an
## Elite's HP on top.
func scaled_stats(def: EnemyDef, wave: int, is_elite: bool) -> Dictionary:
	var multiplier: float = Balance.stat_multiplier(wave)
	var hp: float = def.base_hp * multiplier
	if is_elite:
		hp *= Balance.config().elite_hp_multiplier
	return {
		"hp": hp,
		"damage": def.base_damage * multiplier,
		"speed": def.base_speed,
	}

## Weight = the archetype's unlock wave, so the mix drifts toward the newer,
## heavier archetypes as a run goes on. See SPEC_GAPS.md #7 — §2.1 says
## "weighted by their unlock wave" without giving the function.
func _weighted_pick(wave_rng: RandomNumberGenerator, pool: Array[EnemyDef]) -> EnemyDef:
	var total: int = 0
	for def: EnemyDef in pool:
		total += maxi(1, def.unlock_wave)
	var roll: int = wave_rng.randi_range(0, total - 1)
	for def: EnemyDef in pool:
		roll -= maxi(1, def.unlock_wave)
		if roll < 0:
			return def
	return pool[pool.size() - 1]

func _shuffle(wave_rng: RandomNumberGenerator, items: Array) -> void:
	for index: int in range(items.size() - 1, 0, -1):
		var swap: int = wave_rng.randi_range(0, index)
		var temporary: Variant = items[index]
		items[index] = items[swap]
		items[swap] = temporary
