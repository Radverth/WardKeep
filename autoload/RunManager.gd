extends Node
## Technical Architecture §4.1 — owns current-run state and nothing else.
## Reset clean on every new run; persistence is SaveManager's job.

signal run_started(mode: int)
signal wave_started(wave: int)
signal wave_cleared(wave: int)
signal ward_stone_damaged(hp: int, max_hp: int)
signal gold_changed(gold: int)
signal draft_offered(cards: Array)
signal draft_resolved()
signal run_ended(victory: bool, waves: int, runestones_earned: int)
signal run_unlocks_changed()

var mode: WK.RunMode = WK.RunMode.STANDARD
var seed_value: int = 0
var rng := RandomNumberGenerator.new()

var wave: int = 0
var gold: int = 0
var ward_stone_hp: int = 0
var ward_stone_max_hp: int = 0
var enemies_killed: int = 0
var run_active: bool = false
var revive_used: bool = false

var modifiers: RunModifiers = null
var draft_pool: DraftPool = null
var pending_draft: Array[DraftCardDef] = []

## Towers currently on the board, registered by the Arena as it places them.
var placed_towers: Array = []
## Tower ids unlocked for this run only (Feature Spec §5.2 "Hollow Charter").
var run_unlocked_towers: Array[StringName] = []
## The towers drafted into this run at Run Setup.
var run_roster: Array[StringName] = []

func _ready() -> void:
	modifiers = RunModifiers.new()

## --- lifecycle ----------------------------------------------------------

func start_run(run_mode: WK.RunMode = WK.RunMode.STANDARD) -> void:
	mode = run_mode
	seed_value = _seed_for(run_mode)
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	wave = 0
	enemies_killed = 0
	revive_used = false
	run_active = true
	modifiers = RunModifiers.new()
	draft_pool = DraftPool.new()
	pending_draft.clear()
	placed_towers.clear()
	run_unlocked_towers.clear()
	run_roster = GameState.pending_tower_ids.duplicate()
	GameState.consume_tower_offer()
	# Keep Hub perks are permanent and apply before the first wave, so they are
	# folded into the starting values rather than treated as run modifiers.
	ward_stone_max_hp = Balance.config().ward_stone_hp + Perks.ward_stone_bonus()
	ward_stone_hp = ward_stone_max_hp
	gold = Balance.config().starting_gold + Perks.starting_gold_bonus()
	WaveDirector.begin_run(seed_value)
	run_started.emit(int(mode))
	gold_changed.emit(gold)
	ward_stone_damaged.emit(ward_stone_hp, ward_stone_max_hp)

## Set by the headless playtest so CI runs the same wave order every time. A
## smoke test on a random seed is a flaky test by construction: it samples the
## balance distribution instead of proving the game runs.
var seed_override: int = -1

## Feature Spec §7 — the Daily Challenge seed is the UTC date, so every player
## sees the same waves and the same draft offers on a given day.
func _seed_for(run_mode: WK.RunMode) -> int:
	if seed_override >= 0:
		return seed_override
	if run_mode == WK.RunMode.DAILY:
		return daily_seed()
	return int(Time.get_unix_time_from_system() * 1000.0) ^ randi()

static func daily_seed(date_string: String = "") -> int:
	if date_string.is_empty():
		date_string = Time.get_date_string_from_system(true)   # UTC, YYYY-MM-DD
	var compact: String = date_string.replace("-", "")
	return int(hash(compact))

static func today_utc() -> String:
	return Time.get_date_string_from_system(true)

## --- gold (Feature Spec §3) ---------------------------------------------

func add_gold(amount: int) -> void:
	gold = maxi(0, gold + amount)
	gold_changed.emit(gold)

func can_afford(amount: int) -> bool:
	return gold >= amount

func spend_gold(amount: int) -> bool:
	if not can_afford(amount):
		return false
	add_gold(-amount)
	return true

func on_enemy_killed(def: EnemyDef, is_elite: bool) -> void:
	enemies_killed += 1
	var reward: int = Balance.gold_for_kill(wave, is_elite, def.is_boss)
	if not def.is_boss:
		reward += modifiers.gold_per_kill + Perks.gold_per_kill_bonus()
	add_gold(reward)

## --- ward stone ---------------------------------------------------------

func damage_ward_stone(amount: int) -> void:
	if not run_active:
		return
	ward_stone_hp = maxi(0, ward_stone_hp - amount)
	ward_stone_damaged.emit(ward_stone_hp, ward_stone_max_hp)
	if ward_stone_hp <= 0:
		end_run(false)

func repair_ward_stone(amount: int) -> void:
	ward_stone_hp = mini(ward_stone_max_hp, ward_stone_hp + amount)
	ward_stone_damaged.emit(ward_stone_hp, ward_stone_max_hp)

## Raising the ceiling also fully repairs, which is what the Reinforced Ward
## card says on its face. Cards may now lower it too ("Blood Price"); that only
## trims the ceiling, and never below 1 — a run that ends the instant a card is
## taken is not a trade the player agreed to.
func raise_ward_stone_max(amount: int) -> void:
	ward_stone_max_hp = maxi(1, ward_stone_max_hp + amount)
	if amount >= 0:
		ward_stone_hp = ward_stone_max_hp
	else:
		ward_stone_hp = clampi(ward_stone_hp, 1, ward_stone_max_hp)
	ward_stone_damaged.emit(ward_stone_hp, ward_stone_max_hp)

## Rewarded-ad revive (Pipeline §4) — once per run, restores the Ward Stone.
func can_revive() -> bool:
	return not revive_used

func revive() -> void:
	revive_used = true
	run_active = true
	ward_stone_hp = maxi(1, int(round(float(ward_stone_max_hp) * 0.5)))
	ward_stone_damaged.emit(ward_stone_hp, ward_stone_max_hp)

## --- waves --------------------------------------------------------------

func begin_wave() -> void:
	wave += 1
	wave_started.emit(wave)

func complete_wave() -> void:
	add_gold(int(round(float(Balance.wave_clear_bonus(wave)) * modifiers.wave_clear_mult)))
	repair_ward_stone(Perks.repair_per_wave())
	wave_cleared.emit(wave)
	offer_draft()

## --- draft (Feature Spec §5) --------------------------------------------

func offer_draft() -> void:
	var elements: Array = elements_in_play()
	pending_draft = draft_pool.draw(rng, modifiers, elements)
	draft_offered.emit(pending_draft)

func elements_in_play() -> Array:
	var out: Array = []
	for tower: Node in placed_towers:
		if is_instance_valid(tower) and tower.has_method("element"):
			var element: int = tower.call("element")
			if element not in out:
				out.append(element)
	return out

func take_draft_card(card: DraftCardDef) -> void:
	modifiers.apply(card)
	# A card's price can be a Ward Stone cost, and that is run state rather than
	# tower maths, so it is resolved here alongside the boon.
	if card.has_cost() and String(card.cost_effect_key) == "ward_stone_max_flat":
		raise_ward_stone_max(int(card.cost_magnitude))
	match String(card.effect_key):
		"ward_stone_repair":
			repair_ward_stone(int(card.magnitude))
		"ward_stone_max_flat":
			raise_ward_stone_max(int(card.magnitude))
		"unlock_extra_tower":
			_unlock_random_locked_tower()
	pending_draft.clear()
	draft_resolved.emit()

func _unlock_random_locked_tower() -> void:
	var locked: Array[StringName] = []
	for def: TowerDef in Registry.towers():
		if not is_tower_available(def.id):
			locked.append(def.id)
	if locked.is_empty():
		return
	run_unlocked_towers.append(locked[rng.randi_range(0, locked.size() - 1)])
	run_unlocks_changed.emit()

## Everything the Keep Hub has bought, which is the pool the opening draft is
## dealt from — not the same thing as what this run may build.
func unlocked_towers() -> Array[TowerDef]:
	var out: Array[TowerDef] = []
	for def: TowerDef in Registry.towers():
		if SaveManager.is_tower_unlocked(String(def.id)):
			out.append(def)
	return out

## What this run may build: the three drafted at Run Setup, plus anything a
## Hollow Charter opened mid-run. A run with no draft recorded — the smoke test,
## or a save from before the draft existed — falls back to every unlock, so the
## Arena is never left with an empty tray.
func is_tower_available(tower_id: StringName) -> bool:
	if tower_id in run_unlocked_towers:
		return true
	if run_roster.is_empty():
		return SaveManager.is_tower_unlocked(String(tower_id))
	return tower_id in run_roster

func available_towers() -> Array[TowerDef]:
	var out: Array[TowerDef] = []
	for def: TowerDef in Registry.towers():
		if is_tower_available(def.id):
			out.append(def)
	return out

## --- tower registry -----------------------------------------------------

func register_tower(tower: Node) -> void:
	if tower not in placed_towers:
		placed_towers.append(tower)

func unregister_tower(tower: Node) -> void:
	placed_towers.erase(tower)

## --- ending the run -----------------------------------------------------

## Feature Spec §2.6 — Bank & Retreat banks at 100%, a Ward Stone loss at 75%.
func bank_and_retreat() -> void:
	end_run(true)

func end_run(banked: bool) -> void:
	if not run_active:
		return
	run_active = false
	var waves_survived: int = maxi(0, wave - 1) if ward_stone_hp <= 0 else wave
	var runestones: int = int(round(float(Balance.runestones_for_run(waves_survived, banked))
		* Perks.runestone_multiplier()))
	var daily_bonus: int = 0
	if mode == WK.RunMode.DAILY:
		daily_bonus = Balance.config().daily_completion_bonus
		runestones += daily_bonus
	var xp: int = Balance.xp_for_run(waves_survived)

	var level_before: int = SaveManager.account_level()
	SaveManager.add_runestones(runestones)
	SaveManager.add_account_xp(xp)
	SaveManager.add_stat("total_runs", 1)
	SaveManager.record_run_end(waves_survived)
	SaveManager.add_stat("total_enemies_killed", enemies_killed)
	var best_before: int = int(SaveManager.get_stat("best_wave", 0))
	var new_best: bool = waves_survived > best_before
	if new_best:
		SaveManager.set_stat("best_wave", waves_survived)
	if mode == WK.RunMode.DAILY:
		_record_daily_result(waves_survived)
	SaveManager.write_save()

	GameState.last_run_result = {
		"mode": int(mode),
		"waves_survived": waves_survived,
		"banked": banked,
		"runestones_earned": runestones,
		"daily_bonus": daily_bonus,
		"xp_earned": xp,
		"enemies_killed": enemies_killed,
		"new_best_wave": new_best,
		"best_wave": int(SaveManager.get_stat("best_wave", 0)),
		"levels_gained": SaveManager.account_level() - level_before,
		"account_level": SaveManager.account_level(),
	}
	run_ended.emit(banked, waves_survived, runestones)

## Feature Spec §8 — streak advances on a new day, resets when a day is missed.
func _record_daily_result(waves_survived: int) -> void:
	var today: String = today_utc()
	var last: String = str(SaveManager.get_value("daily_challenge_date", ""))
	if last != today:
		var streak: int = int(SaveManager.get_value("daily_challenge_streak", 0))
		SaveManager.set_value("daily_challenge_streak", streak + 1 if _is_yesterday(last, today) else 1)
		SaveManager.set_value("daily_challenge_date", today)
		SaveManager.set_value("daily_challenge_best_wave", waves_survived)
	elif waves_survived > int(SaveManager.get_value("daily_challenge_best_wave", 0)):
		SaveManager.set_value("daily_challenge_best_wave", waves_survived)

static func _is_yesterday(candidate: String, today: String) -> bool:
	if candidate.is_empty():
		return false
	var today_unix: int = int(Time.get_unix_time_from_datetime_string(today + "T00:00:00"))
	var candidate_unix: int = int(Time.get_unix_time_from_datetime_string(candidate + "T00:00:00"))
	return today_unix - candidate_unix == 86400

func daily_played_today() -> bool:
	return str(SaveManager.get_value("daily_challenge_date", "")) == today_utc()
