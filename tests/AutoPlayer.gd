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
var _upgrade_timer: float = 0.0
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

## Buys the most expensive tower it can afford onto a free slot near the path,
## then spends leftover gold upgrading — a crude but consistent stand-in for a
## player, enough to keep the Ward Stone alive through the early curve.
func _buy_or_upgrade() -> void:
	var affordable: Array[TowerDef] = []
	for def: TowerDef in RunManager.available_towers():
		if RunManager.can_afford(def.purchase_cost()):
			affordable.append(def)
	if not affordable.is_empty():
		affordable.sort_custom(func(a: TowerDef, b: TowerDef) -> bool:
			return a.purchase_cost() > b.purchase_cost())
		var slot: TowerSlot = _free_slot()
		if slot != null:
			arena._armed_def = affordable[0]
			arena._try_place(slot.grid_cell)
			return
	_upgrade_timer -= 0.4
	if _upgrade_timer > 0.0:
		return
	_upgrade_timer = 2.0
	for tower: Node in RunManager.placed_towers:
		if tower is Tower and (tower as Tower).can_upgrade() \
				and RunManager.can_afford((tower as Tower).upgrade_cost()):
			(tower as Tower).upgrade()
			return

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
	call_deferred("_take_card", cards[0])

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
	report_ready.emit({
		"reason": reason,
		"wave": RunManager.wave,
		"ward_stone_hp": RunManager.ward_stone_hp,
		"gold": RunManager.gold,
		"towers": RunManager.placed_towers.size(),
		"enemies_killed": RunManager.enemies_killed,
		"seconds": _elapsed,
	})
