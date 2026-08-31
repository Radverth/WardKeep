extends Control
## User Flow §3.4 / Feature Spec §5 — three cards, rarity-coloured borders, no
## timer. The tree is paused while this is open, so it processes always.

signal card_chosen(card: DraftCardDef)

@onready var _cards_box: VBoxContainer = %CardsBox

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

func show_cards(cards: Array) -> void:
	for child: Node in _cards_box.get_children():
		child.queue_free()
	for card: DraftCardDef in cards:
		_cards_box.add_child(_build_card(card))
	show()

func _build_card(card: DraftCardDef) -> Control:
	# A dark plate behind the ornate frame: the Fantasy UI border is drawn to
	# be tinted, so on its own it would take the rarity colour across the whole
	# card and swallow the text.
	var plate := PanelContainer.new()
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.13, 0.11, 0.11, 0.97)
	backing.set_corner_radius_all(10)
	backing.set_content_margin_all(0)
	plate.add_theme_stylebox_override("panel", backing)

	var border := PanelContainer.new()
	border.add_theme_stylebox_override("panel",
		UiKit.border_stylebox(WK.rarity_color(card.rarity)))
	plate.add_child(border)

	var button := Button.new()
	button.flat = true
	button.custom_minimum_size = Vector2(0, 170)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void:
		hide()
		card_chosen.emit(card))
	border.add_child(button)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 8)
	button.add_child(box)

	var rarity_label := Label.new()
	rarity_label.text = WK.rarity_name(card.rarity).to_upper()
	rarity_label.add_theme_font_size_override("font_size", 18)
	rarity_label.add_theme_color_override("font_color", WK.rarity_color(card.rarity))
	box.add_child(rarity_label)

	var title := Label.new()
	title.text = card.title
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)

	var description := Label.new()
	description.text = card.description
	description.add_theme_font_size_override("font_size", 21)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(description)
	return plate
