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

var _thumbs: Array[MapThumb] = []

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

func _populate() -> void:
	for child: Node in _roster.get_children():
		child.queue_free()
	var available: Array[TowerDef] = RunManager.available_towers()
	for def: TowerDef in available:
		_roster.add_child(_make_card(def))
	var locked: int = Registry.towers().size() - available.size()
	_hint.text = "%d towers ready · %d still locked in the Keep Hub" % [available.size(), locked]

func _make_card(def: TowerDef) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 150)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)

	var icon := TextureRect.new()
	icon.texture = def.texture()
	icon.custom_minimum_size = Vector2(0, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = WK.element_tint(def.rune_element) * UiKit.skin_modulate(
		SaveManager.equipped_skin(String(def.id)))
	box.add_child(icon)

	var name_label := Label.new()
	name_label.text = def.display_name
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(name_label)

	var cost_label := Label.new()
	cost_label.text = "%s · %dg" % [WK.element_name(def.rune_element), def.purchase_cost()]
	cost_label.add_theme_font_size_override("font_size", 17)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(cost_label)
	return panel

func _on_begin() -> void:
	AudioBus.click()
	GameState.goto_scene(GameState.SCENE_ARENA)

func _on_back() -> void:
	AudioBus.click()
	GameState.goto_scene(GameState.SCENE_MAIN_MENU)
