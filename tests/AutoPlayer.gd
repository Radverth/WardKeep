extends Node
class_name AutoPlayer
## Headless smoke-test driver: plays the Arena without a human, so CI can
## prove a run reaches a target wave without errors. Not shipped in a build —
## it lives under res://tests/ and is only instantiated by the harness.

signal report_ready(report: Dictionary)

## Stop once this wave is reached, so the harness always terminates.
@export var target_wave: int = 12
@export var max_seconds: float = 3600.0
@export var verbose: bool = true

var arena: Arena = null
var _elapsed: float = 0.0
var _buy_timer: float = 0.0
var _finished: bool = false
var _debug_timer: float = 0.0

func _ready() -> void:
	RunManager.wave_cleared.connect(_on_wave_cleared)
	RunManager.draft_offered.connect(_on_draft_offered)
	RunManager.run_ended.connect(_on_run_ended)

func _process(delta: float) -> void:
	if _finished or arena == null:
		return
	_elapsed += delta
	if _elapsed > max_seconds:
		_finish("timeout")
		return
	if verbose:
		_debug_timer -= delta
		if _debug_timer <= 0.0:
			_debug_timer = 5.0
			print("  t=%.0fs wave=%d enemies=%d towers=%d gold=%d ward=%d" % [
				_elapsed, RunManager.wave, arena.active_enemies.size(),
				RunManager.placed_towers.size(), RunManager.gold, RunManager.ward_stone_hp])
	_buy_timer -= delta
	if _buy_timer <= 0.0:
		_buy_timer = 0.4
		_buy_or_upgrade()

## A stand-in for a competent player rather than a hoarder: build a working
## line first, then put gold into upgrades, which are more gold-efficient than
## a tenth tier-1 tower. Falls back to placing when nothing can be upgraded.
const SOFT_TOWER_CAP: int = 12

func _buy_or_upgrade() -> void:
	var towers: int = RunManager.placed_towers.size()
	if towers < SOFT_TOWER_CAP and _place_best():
		return
	if _upgrade_cheapest():
		return
	_place_best()

func _place_best() -> bool:
	var affordable: Array[TowerDef] = []
	for def: TowerDef in RunManager.available_towers():
		if RunManager.can_afford(def.purchase_cost()):
			affordable.append(def)
	if affordable.is_empty():
		return false
	affordable.sort_custom(func(a: TowerDef, b: TowerDef) -> bool:
		return a.purchase_cost() > b.purchase_cost())
	var slot: TowerSlot = _free_slot()
	if slot == null:
		return false
	arena._armed_def = affordable[0]
	arena._try_place(slot.grid_cell)
	return true

func _upgrade_cheapest() -> bool:
	var best: Tower = null
	for tower: Node in RunManager.placed_towers:
		if not (tower is Tower):
			continue
		var candidate: Tower = tower as Tower
		if not candidate.can_upgrade() or not RunManager.can_afford(candidate.upgrade_cost()):
			continue
		if best == null or candidate.upgrade_cost() < best.upgrade_cost():
			best = candidate
	if best == null:
		return false
	best.upgrade()
	return true

func _free_slot() -> TowerSlot:
	for slot: TowerSlot in arena._slots.values():
		if slot.is_free():
			return slot
	return null

## The wave-cleared signal is the only reliable stopping point: the Arena
## moves straight from CLEARED into DRAFT in the same frame.
func _on_wave_cleared(wave: int) -> void:
	if wave >= target_wave:
		_finish("target_reached")

func _on_draft_offered(cards: Array) -> void:
	if cards.is_empty():
		return
	# Resolve on the next frame so the overlay's own show path runs first.
	call_deferred("_take_card", _pick_card(cards))

## Prefers a card with no price. A card like Blood Price trades Ward Stone for
## damage, which is a real decision for a player and pure self-harm for a bot
## with no strategy to make the trade pay off — taking whatever came first made
## this smoke test fail about one run in three at random.
func _pick_card(cards: Array) -> DraftCardDef:
	for card: DraftCardDef in cards:
		if not card.has_cost():
			return card
	return cards[0]

func _take_card(card: DraftCardDef) -> void:
	if _finished:
		return
	arena._on_draft_card_chosen(card)

func _on_run_ended(_banked: bool, _waves: int, _runestones: int) -> void:
	_finish("run_ended")

func _finish(reason: String) -> void:
	if _finished:
		return
	_finished = true
	var tiers: Array[int] = [0, 0, 0]
	for tower: Node in RunManager.placed_towers:
		if tower is Tower:
			tiers[(tower as Tower).tier_index] += 1
	report_ready.emit({
		"reason": reason,
		"wave": RunManager.wave,
		"tiers_1_2_3": tiers,
		"ward_stone_hp": RunManager.ward_stone_hp,
		"gold": RunManager.gold,
		"towers": RunManager.placed_towers.size(),
		"enemies_killed": RunManager.enemies_killed,
		"seconds": _elapsed,
	})
