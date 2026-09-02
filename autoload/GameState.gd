extends Node
## Screen navigation and the handoff between screens.
##
## Nothing gameplay-stateful lives here — in-run state is RunManager's,
## persistent state is SaveManager's. Enums and shared constants are in
## WK (res://scripts/WK.gd). See Technical Architecture §4.

const SCENE_MAIN_MENU: String = "res://scenes/menu/MainMenu.tscn"
const SCENE_RUN_SETUP: String = "res://scenes/menu/RunSetup.tscn"
const SCENE_KEEP_HUB: String = "res://scenes/menu/KeepHub.tscn"
const SCENE_SETTINGS: String = "res://scenes/menu/Settings.tscn"
const SCENE_ARENA: String = "res://scenes/run/Arena.tscn"
const SCENE_RUN_SUMMARY: String = "res://scenes/menu/RunSummary.tscn"

## Set before entering the Arena; read by RunManager on run start.
var pending_run_mode: WK.RunMode = WK.RunMode.STANDARD

## The opening tower draft: what this run was offered, and what was taken.
## Held here rather than regenerated on every visit to Run Setup, or backing out
## and returning would reroll the offer until it was one the player liked.
var pending_tower_offer: Array[StringName] = []
var pending_tower_ids: Array[StringName] = []
var _offer_signature: String = ""

## Builds the offer once per (mode, day). The Daily's has to be the same for
## everyone — Feature Spec §7 — so it comes from the date's seed; a standard
## run's is rolled fresh each time the previous one is consumed.
func ensure_tower_offer() -> void:
	var signature: String = "%d/%s" % [int(pending_run_mode),
		Time.get_date_string_from_system(true) if pending_run_mode == WK.RunMode.DAILY else "run"]
	if signature == _offer_signature and not pending_tower_offer.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = RunManager.daily_seed() if pending_run_mode == WK.RunMode.DAILY \
		else int(Time.get_unix_time_from_system() * 1000.0) ^ randi()
	pending_tower_offer = TowerDraft.offer(rng, RunManager.unlocked_towers())
	pending_tower_ids.clear()
	_offer_signature = signature

## Called when a run actually begins, so the next standard run is offered a new
## hand rather than the one that was just played.
func consume_tower_offer() -> void:
	_offer_signature = ""

## The board picked at Run Setup. Empty falls back to the first map, so a save
## naming a board a later build removed still starts.
var pending_map_id: StringName = &""

## The board this run is played on. The Daily cannot let the player choose one:
## Feature Spec §7 wants every player on the same waves and the same offers on a
## given day, and the board is part of that, so it comes from the date's seed.
func resolve_arena_map() -> ArenaMap:
	var boards: Array[ArenaMap] = Registry.maps()
	if boards.is_empty():
		push_error("WARDKEEP: no arena maps generated.")
		return null
	if pending_run_mode == WK.RunMode.DAILY:
		return boards[absi(RunManager.daily_seed()) % boards.size()]
	return Registry.map(pending_map_id)

## Result of the last finished run, handed to RunSummary. See RunManager.end_run().
var last_run_result: Dictionary = {}

## Where Settings and Keep Hub return to when opened from somewhere other
## than the Main Menu.
var return_scene: String = SCENE_MAIN_MENU

## Deferred so callers can change scenes from inside signal handlers safely.
func goto_scene(path: String) -> void:
	get_tree().call_deferred("change_scene_to_file", path)
