extends RefCounted
class_name DraftPool
## Feature Spec §5.1 — after every wave clear, three cards drawn without
## replacement from the effects not already at max rank, weighted by rarity.
## If fewer than three remain eligible the pool refills, so the overlay always
## shows three cards.
##
## All draws come from an injected RandomNumberGenerator so the Daily
## Challenge (§7) reproduces exactly from its date seed.

const DRAFT_DIR: String = "res://resources/draft/"

var cards: Array[DraftCardDef] = []

func _init() -> void:
	load_cards()

func load_cards() -> void:
	cards.clear()
	var dir: DirAccess = DirAccess.open(DRAFT_DIR)
	if dir == null:
		push_error("WARDKEEP: draft pool directory missing.")
		return
	var names: Array[String] = []
	for file_name: String in dir.get_files():
		# Exported projects see .tres as .remap; strip either suffix.
		if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
			names.append(file_name.trim_suffix(".remap"))
	names.sort()   # stable order, so a seed always means the same draw
	for file_name: String in names:
		var card: DraftCardDef = load(DRAFT_DIR + file_name) as DraftCardDef
		if card != null:
			cards.append(card)

## A card is eligible when it is below max rank and, for element-scoped cards,
## the player actually has a tower of that element in play.
func eligible(modifiers: RunModifiers, elements_in_play: Array) -> Array[DraftCardDef]:
	var out: Array[DraftCardDef] = []
	for card: DraftCardDef in cards:
		if modifiers.rank_of(card.id) >= card.max_rank:
			continue
		if card.element_filter >= 0 and card.element_filter not in elements_in_play:
			continue
		out.append(card)
	return out

func _weight_for(rarity: WK.Rarity) -> int:
	var cfg: BalanceConfig = Balance.config()
	match rarity:
		WK.Rarity.COMMON: return cfg.draft_weight_common
		WK.Rarity.RARE: return cfg.draft_weight_rare
		WK.Rarity.EPIC: return cfg.draft_weight_epic
	return 0

## Draws `count` distinct cards, weighted by the §5.2 rarity weights.
func draw(rng: RandomNumberGenerator, modifiers: RunModifiers, elements_in_play: Array, count: int = -1) -> Array[DraftCardDef]:
	if count < 0:
		count = Balance.config().draft_card_count
	var picked: Array[DraftCardDef] = []
	var available: Array[DraftCardDef] = eligible(modifiers, elements_in_play)
	if available.is_empty():
		available = cards.duplicate()
	while picked.size() < count:
		if available.is_empty():
			# §5.1: refill rather than show fewer than three cards.
			available = eligible(modifiers, elements_in_play)
			if available.is_empty():
				available = cards.duplicate()
			if available.is_empty():
				break
		var card: DraftCardDef = _weighted_pick(rng, available)
		picked.append(card)
		available.erase(card)
	return picked

func _weighted_pick(rng: RandomNumberGenerator, pool: Array[DraftCardDef]) -> DraftCardDef:
	var total: int = 0
	for card: DraftCardDef in pool:
		total += _weight_for(card.rarity)
	if total <= 0:
		return pool[rng.randi_range(0, pool.size() - 1)]
	var roll: int = rng.randi_range(0, total - 1)
	for card: DraftCardDef in pool:
		roll -= _weight_for(card.rarity)
		if roll < 0:
			return card
	return pool[pool.size() - 1]
