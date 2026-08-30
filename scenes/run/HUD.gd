extends Control
## User Flow §3.3 — top bar (wave, Ward Stone, gold), bottom tower tray,
## wave banner and the Bank & Retreat control.

signal tower_armed(def: TowerDef)
signal pause_pressed()
signal bank_pressed()

@onready var _wave_label: Label = %WaveLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _ward_bar: ProgressBar = %WardBar
@onready var _ward_label: Label = %WardLabel
@onready var _tray: HBoxContainer = %Tray
@onready var _banner: Label = %Banner
@onready var _message: Label = %Message
@onready var _pause_button: Button = %PauseButton
@onready var _bank_button: Button = %BankButton

var _buttons: Dictionary = {}    ## StringName -> Button

func _ready() -> void:
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	_bank_button.pressed.connect(func() -> void: bank_pressed.emit())
	_banner.hide()
	_message.hide()
	_bank_button.hide()

func bind() -> void:
	RunManager.gold_changed.connect(_on_gold_changed)
	RunManager.ward_stone_damaged.connect(_on_ward_changed)
	RunManager.wave_started.connect(_on_wave_started)
	RunManager.run_unlocks_changed.connect(refresh_tray)
	_on_gold_changed(RunManager.gold)
	_on_ward_changed(RunManager.ward_stone_hp, RunManager.ward_stone_max_hp)
	refresh_tray()

func _on_gold_changed(gold: int) -> void:
	_gold_label.text = "%d g" % gold
	_refresh_affordability()

func _on_ward_changed(hp: int, max_hp: int) -> void:
	_ward_bar.max_value = float(max_hp)
	_ward_bar.value = float(hp)
	_ward_label.text = "%d / %d" % [hp, max_hp]

func _on_wave_started(wave: int) -> void:
	_wave_label.text = "Wave %d" % wave

## --- tower tray ---------------------------------------------------------

func refresh_tray() -> void:
	for child: Node in _tray.get_children():
		child.queue_free()
	_buttons.clear()
	for def: TowerDef in RunManager.available_towers():
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 128)
		button.text = "%s\n%dg" % [def.display_name, def.purchase_cost()]
		button.add_theme_font_size_override("font_size", 18)
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
