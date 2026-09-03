extends Control
## User Flow §3.3 — top bar (wave, Ward Stone, gold), bottom tower tray,
## wave banner and the Bank & Retreat control.

signal tower_armed(def: TowerDef)
signal pause_pressed()
signal bank_pressed()
signal speed_pressed()
signal ability_pressed()
## The chrome's height changed, so the Arena can re-fit the board between them.
signal safe_area_changed(top: float, bottom: float)

@onready var _wave_label: Label = %WaveLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _upkeep_label: Label = %UpkeepLabel
@onready var _ward_bar: ProgressBar = %WardBar
@onready var _ward_label: Label = %WardLabel
@onready var _tray: HBoxContainer = %Tray
@onready var _banner: Label = %Banner
@onready var _message: Label = %Message
@onready var _top_bar: PanelContainer = $TopBar
@onready var _top_margin: MarginContainer = %TopMargin
@onready var _tray_panel: PanelContainer = $TrayPanel
@onready var _tray_margin: MarginContainer = %TrayMargin
@onready var _armed_info: PanelContainer = %ArmedInfo
@onready var _armed_title: Label = %ArmedTitle
@onready var _armed_stats: Label = %ArmedStats
@onready var _armed_matchup: Label = %ArmedMatchup
@onready var _ability_button: Button = %AbilityButton
@onready var _speed_button: Button = %SpeedButton
@onready var _pause_button: Button = %PauseButton
@onready var _bank_button: Button = %BankButton

var _buttons: Dictionary = {}    ## StringName -> Button

## Height of the bars before any device inset is added.
const TOP_BAR_HEIGHT: float = 104.0
const TRAY_HEIGHT: float = 148.0
## The card that says what an armed tower does. Sits above the tray so it
## covers as little board as possible at the moment the player is choosing
## where to put the thing.
## The Ward Flare sits above the tray on the thumb side rather than in it. It
## used to be the first cell of the tower row, where it competed with the towers
## for the same space and read as a fourth tower; and now that a run drafts
## exactly three towers, the tray has room for those three and nothing else.
const ABILITY_SIZE: Vector2 = Vector2(176, 168)
## Clear of the tray and the info card, on the right where a thumb rests.
const ABILITY_MARGIN: float = 20.0

## Three short lines inside the frame's own padding. The §4 role strings are
## far too long to sit next to a name — "Slow single-target + 20% slow debuff
## (4s)" wrapped the title on its own — so the numbers say what the role said.
const ARMED_INFO_HEIGHT: float = 124.0

func _ready() -> void:
	_style_ability_button()
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	_ability_button.pressed.connect(func() -> void: ability_pressed.emit())
	_speed_button.pressed.connect(func() -> void: speed_pressed.emit())
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	_bank_button.pressed.connect(func() -> void: bank_pressed.emit())
	_banner.hide()
	_message.hide()
	_bank_button.hide()
	_armed_info.hide()

## The flare is not a tower and must not look like one. The tray's chrome is
## the same cream panel for everything, so this gets its own red plate — it is
## the one control on the board that does something immediately when pressed.
const ABILITY_READY: Color = Color(0.70, 0.18, 0.16)
const ABILITY_COOLING: Color = Color(0.28, 0.22, 0.22)

func _style_ability_button() -> void:
	for state: String in ["normal", "hover", "focus"]:
		_ability_button.add_theme_stylebox_override(state, _ability_plate(ABILITY_READY))
	_ability_button.add_theme_stylebox_override("pressed", _ability_plate(ABILITY_READY.lightened(0.2)))
	_ability_button.add_theme_stylebox_override("disabled", _ability_plate(ABILITY_COOLING))
	_ability_button.add_theme_color_override("font_color", Color(1.0, 0.95, 0.88))
	_ability_button.add_theme_color_override("font_disabled_color", Color(0.72, 0.66, 0.64))

func _ability_plate(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(14)
	box.set_border_width_all(4)
	box.border_color = fill.lightened(0.35)
	return box

## Pushes the top bar below a punch-hole or notch and lifts the tray clear of
## the gesture bar. Both bars grow rather than move, so their contents stay
## centred in whatever room is left and nothing lands under the device's own
## furniture.
func _apply_safe_area() -> void:
	var insets: Vector2 = UiKit.safe_insets(get_viewport())
	# The panels grow to cover the inset so their backgrounds still run to the
	# edge of the glass; the margins inside push the controls clear of it.
	_top_bar.offset_bottom = TOP_BAR_HEIGHT + insets.x
	_top_margin.add_theme_constant_override("margin_top", int(insets.x))
	_tray_panel.offset_top = -(TRAY_HEIGHT + insets.y)
	_tray_margin.add_theme_constant_override("margin_bottom", int(insets.y))
	_armed_info.offset_bottom = -(TRAY_HEIGHT + insets.y)
	_armed_info.offset_top = _armed_info.offset_bottom - ARMED_INFO_HEIGHT
	_ability_button.offset_right = -ABILITY_MARGIN
	_ability_button.offset_left = _ability_button.offset_right - ABILITY_SIZE.x
	_ability_button.offset_bottom = _armed_info.offset_top - ABILITY_MARGIN
	_ability_button.offset_top = _ability_button.offset_bottom - ABILITY_SIZE.y
	safe_area_changed.emit(TOP_BAR_HEIGHT + insets.x, TRAY_HEIGHT + insets.y)

func board_insets() -> Vector2:
	var insets: Vector2 = UiKit.safe_insets(get_viewport())
	return Vector2(TOP_BAR_HEIGHT + insets.x, TRAY_HEIGHT + insets.y)

func bind() -> void:
	RunManager.gold_changed.connect(_on_gold_changed)
	RunManager.ward_stone_damaged.connect(_on_ward_changed)
	RunManager.wave_started.connect(_on_wave_started)
	RunManager.run_unlocks_changed.connect(refresh_tray)
	RunManager.wave_settled.connect(_on_wave_settled)
	RunManager.garrison_changed.connect(func(_count: int) -> void: _refresh_upkeep())
	_on_gold_changed(RunManager.gold)
	_refresh_upkeep()
	_on_ward_changed(RunManager.ward_stone_hp, RunManager.ward_stone_max_hp)
	refresh_tray()

func _on_gold_changed(gold: int) -> void:
	_gold_label.text = "%d g" % gold
	_refresh_upkeep()
	_refresh_affordability()

## Upkeep the player cannot see is a mysterious drain, so the running cost of
## the board sits under the gold count and updates the moment a tower is placed
## or sold — before the wave ends and it is charged.
func _refresh_upkeep() -> void:
	var owed: int = RunManager.upkeep_due()
	_upkeep_label.visible = owed > 0
	_upkeep_label.text = "-%d/wave" % owed

func _on_wave_settled(_wave: int, bonus: int, upkeep: int) -> void:
	_refresh_upkeep()
	if upkeep <= 0:
		flash_message("Wave held  ·  +%dg" % bonus)
	elif RunManager.gold <= 0 and upkeep > bonus:
		flash_message("Wave held  ·  the garrison went unpaid and men deserted")
	else:
		flash_message("Wave held  ·  +%dg  ·  -%dg garrison" % [bonus, upkeep])

func _on_ward_changed(hp: int, max_hp: int) -> void:
	_ward_bar.max_value = float(max_hp)
	_ward_bar.value = float(hp)
	_ward_label.text = "%d / %d" % [hp, max_hp]

func _on_wave_started(wave: int) -> void:
	_wave_label.text = "Wave %d" % wave

## `remaining` is seconds left on the cooldown; 0 means ready. `armed` is true
## between arming the flare and choosing where it lands.
func set_ability_state(remaining: float, armed: bool) -> void:
	var ready_now: bool = remaining <= 0.0
	_ability_button.disabled = not ready_now
	if not ready_now:
		_ability_button.text = "Ward Flare\n%ds" % int(ceil(remaining))
	elif armed:
		_ability_button.text = "Ward Flare\nPick a spot"
	else:
		_ability_button.text = "Ward Flare\nReady"

## What the tower being placed actually does. Until now nothing said, anywhere:
## the tray gave a name and a price, and the stats only appeared on the panel
## for a tower already bought and standing on the board.
func show_armed_info(def: TowerDef) -> void:
	if def == null:
		_armed_info.hide()
		return
	var tier: TowerTierData = def.tier(0)
	_armed_title.text = "%s  ·  %dg" % [def.display_name, def.purchase_cost()]
	var parts: Array[String] = []
	if tier.is_aura:
		parts.append("aura, %.1f tiles" % maxf(tier.range_tiles, tier.splash_radius))
	else:
		parts.append("%.0f damage" % tier.damage)
		parts.append("%.1f/s" % tier.fire_rate)
		parts.append("%.0f tiles" % tier.range_tiles)
	if tier.slow_amount > 0.0:
		parts.append("slows %d%%" % int(round(tier.slow_amount * 100.0)))
	if tier.dot_damage > 0.0:
		parts.append("%.0f blight/s" % tier.dot_damage)
	if tier.splash_radius > 0.0:
		parts.append("splash %.1f" % tier.splash_radius)
	_armed_stats.text = " · ".join(parts)
	_armed_matchup.text = "%s — %s" % [WK.element_name(def.rune_element),
		Balance.element_matchup_line(def.rune_element)]
	_armed_info.show()

func hide_armed_info() -> void:
	_armed_info.hide()

func set_speed_label(multiplier: float) -> void:
	_speed_button.text = "x%d" % int(round(multiplier))

## --- tower tray ---------------------------------------------------------

func refresh_tray() -> void:
	for child: Node in _tray.get_children():
		child.queue_free()
	_buttons.clear()
	for def: TowerDef in RunManager.available_towers():
		var button := Button.new()
		# A run drafts three towers, so the three share the tray's width evenly
		# and nothing has to be swiped. A Hollow Charter can add a fourth, and
		# the row still scrolls when it does.
		button.custom_minimum_size = Vector2(180, 128)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Name and price only. The element used to sit here too and clipped the
		# longer names at every width that still fit three towers on a phone;
		# arming one now shows a card that carries the element and the matchup,
		# which is a better place for it than a button this size.
		button.text = "%s\n%dg" % [def.display_name, def.purchase_cost()]
		button.add_theme_font_size_override("font_size", 15)
		button.clip_text = true
		button.pressed.connect(func() -> void:
			AudioBus.click()
			_set_armed(def.id)
			tower_armed.emit(def))
		_tray.add_child(button)
		_buttons[def.id] = button
	_refresh_affordability()

func _refresh_affordability() -> void:
	for id: StringName in _buttons:
		var def: TowerDef = Registry.tower(id)
		var button: Button = _buttons[id]
		if def != null and is_instance_valid(button):
			button.disabled = not RunManager.can_afford(def.purchase_cost())

func _set_armed(id: StringName) -> void:
	for other: StringName in _buttons:
		var button: Button = _buttons[other]
		if is_instance_valid(button):
			button.modulate = Color(1.25, 1.2, 0.9) if other == id else Color.WHITE

func clear_armed() -> void:
	_set_armed(&"")

## --- banners and messages ------------------------------------------------

func show_wave_banner(wave: int, is_elite: bool, boss_id: StringName) -> void:
	var text: String = "Wave %d" % wave
	if boss_id != &"":
		var boss: EnemyDef = Registry.enemy(boss_id)
		text = "%s\n%s" % [text, boss.display_name if boss != null else "Boss"]
	elif is_elite:
		text = "%s\nElite Wave" % text
	_banner.text = text
	_banner.modulate.a = 1.0
	_banner.show()
	var tween: Tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.4)
	tween.tween_callback(_banner.hide)

func flash_message(text: String) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	_message.show()
	var tween: Tween = create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(_message, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_message.hide)

## Feature Spec §2.6 — only offered once a wave has cleared.
func set_bank_available(available: bool) -> void:
	_bank_button.visible = available
