extends Control
## User Flow §3.2 — read-only roster, one Begin button. Towers are still not
## picked before a run: every unlocked one is available in-run via gold. The
## board is, because the map is the one thing that makes two runs of an endless
## game feel different before the first wave lands.

## Five boards fit the portrait width without scrolling at this size.
const THUMB_SIZE: Vector2 = Vector2(128, 196)

@onready var _roster: GridContainer = %Roster
@onready var _map_row: HBoxContainer = %MapRow
@onready var _map_blurb: Label = %MapBlurb
@onready var _begin_button: Button = %BeginButton
@onready var _back_button: Button = %BackButton
@onready var _hint: Label = %Hint
@onready var _heading: Label = %TowerHeading

var _thumbs: Array[MapThumb] = []
var _cards: Dictionary = {}          ## StringName -> Button
var _required: int = 3

func _ready() -> void:
	# The device may put a punch-hole over the top of this screen and a
	# gesture bar under the bottom of it.
	UiKit.pad_for_safe_area($Root)
	get_viewport().size_changed.connect(func() -> void:
		UiKit.pad_for_safe_area($Root))
	_begin_button.pressed.connect(_on_begin)
	_back_button.pressed.connect(_on_back)
	_populate_maps()
	_populate()

func _populate_maps() -> void:
	var boards: Array[ArenaMap] = Registry.maps()
	if boards.is_empty():
		return
	# Nothing chosen yet on a fresh install, and a board from an older build may
	# be gone, so resolve through the Registry rather than trusting the id.
	var chosen: ArenaMap = Registry.map(GameState.pending_map_id)
	for board: ArenaMap in boards:
		var thumb := MapThumb.new()
		thumb.custom_minimum_size = THUMB_SIZE
		thumb.toggle_mode = true
		thumb.bind(board)
		thumb.pressed.connect(_on_map_chosen.bind(board))
		_map_row.add_child(thumb)
		_thumbs.append(thumb)
	_on_map_chosen(chosen)

func _on_map_chosen(board: ArenaMap) -> void:
	if board == null:
		return
	AudioBus.click()
	GameState.pending_map_id = board.id
	_map_blurb.text = board.blurb
	for thumb: MapThumb in _thumbs:
		thumb.button_pressed = thumb.map != null and thumb.map.id == board.id

## The opening draft. Every unlocked tower used to be buyable in every run,
## which made the roster a menu rather than a hand — nine towers, always the
## same nine. Three of an offer turns the opening into a decision, and a run is
## frost-heavy or blight-heavy before the first wave lands.
func _populate() -> void:
	for child: Node in _roster.get_children():
		child.queue_free()
	_cards.clear()
	GameState.ensure_tower_offer()
	var offer: Array[StringName] = GameState.pending_tower_offer
	_required = TowerDraft.picks_for(offer.size())
	for id: StringName in offer:
		var def: TowerDef = Registry.tower(id)
		if def == null:
			continue
		var card: Button = _make_card(def)
		_roster.add_child(card)
		_cards[id] = card
	# An account with only the starters is offered exactly those and asked for
	# all of them, so it takes them rather than making the player tap three
	# cards to reach the only possible answer.
	if offer.size() <= _required:
		GameState.pending_tower_ids = offer.duplicate()
	_refresh_selection()

## A row rather than a tile. A Button is not a Container, so a grid of them
## gave every card the width of its own text and the labels wrapped one letter
## per line; and the §4 role strings need a line to themselves anyway, which is
## the whole reason to show them here.
func _make_card(def: TowerDef) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(0, 116)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.toggle_mode = true
	card.pressed.connect(_on_card_pressed.bind(def.id))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var icon := TextureRect.new()
	icon.texture = def.texture()
	icon.custom_minimum_size = Vector2(68, 68)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = WK.element_tint(def.rune_element) * UiKit.skin_modulate(
		SaveManager.equipped_skin(String(def.id)))
	row.add_child(icon)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", 1)
	row.add_child(text)
	text.add_child(_card_label("%s  ·  %dg" % [def.display_name, def.purchase_cost()], 22))
	text.add_child(_card_label("%s — %s" % [WK.element_name(def.rune_element), def.role], 16))
	return card

func _card_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

## Taking one too many drops the oldest pick rather than refusing the tap: on a
## phone, a card that does nothing when pressed reads as a broken button.
func _on_card_pressed(id: StringName) -> void:
	AudioBus.click()
	var chosen: Array[StringName] = GameState.pending_tower_ids
	if id in chosen:
		chosen.erase(id)
	else:
		chosen.append(id)
		while chosen.size() > _required:
			chosen.remove_at(0)
	_refresh_selection()

func _refresh_selection() -> void:
	var chosen: Array[StringName] = GameState.pending_tower_ids
	for id: StringName in _cards:
		_cards[id].button_pressed = id in chosen
	_heading.text = "Choose %d towers  ·  %d picked" % [_required, chosen.size()]
	var locked: int = Registry.towers().size() - RunManager.unlocked_towers().size()
	_hint.text = "Only what you take can be built this run. %d still locked in the Keep Hub." % locked
	_begin_button.disabled = chosen.size() != _required

func _on_begin() -> void:
	AudioBus.click()
	GameState.goto_scene(GameState.SCENE_ARENA)

func _on_back() -> void:
	AudioBus.click()
	GameState.goto_scene(GameState.SCENE_MAIN_MENU)
