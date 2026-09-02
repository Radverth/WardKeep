extends Control
## User Flow §3.5 — waves survived, Runestones earned, unlock thresholds newly
## met, and the Feature Spec §8 best-wave celebration. The interstitial ad
## opportunity is scheduled on the transition into this screen, never mid-run
## (Pipeline/Integration Spec §4).

const STAR_TEXTURE: String = "res://assets/sprites/vfx/particle_star/star_05.png"

@onready var _headline: Label = %Headline
@onready var _waves_label: Label = %WavesLabel
@onready var _detail: VBoxContainer = %Detail
@onready var _celebration: CPUParticles2D = %Celebration
@onready var _best_banner: Label = %BestBanner
@onready var _double_button: Button = %DoubleButton
@onready var _spend_button: Button = %SpendButton
@onready var _continue_button: Button = %ContinueButton

var _result: Dictionary = {}
var _doubled: bool = false

func _ready() -> void:
	# The device may put a punch-hole over the top of this screen and a
	# gesture bar under the bottom of it.
	UiKit.pad_for_safe_area($Root)
	get_viewport().size_changed.connect(func() -> void:
		UiKit.pad_for_safe_area($Root))
	_result = GameState.last_run_result
	_spend_button.pressed.connect(_on_spend)
	_continue_button.pressed.connect(_on_continue)
	_double_button.pressed.connect(_on_double)
	_celebration.texture = load(STAR_TEXTURE)
	_populate()
	if not bool(_result.get("read_only", false)):
		AdsManager.maybe_show_interstitial_on_run_end()

func _populate() -> void:
	var waves: int = int(_result.get("waves_survived", 0))
	var banked: bool = bool(_result.get("banked", false))
	var read_only: bool = bool(_result.get("read_only", false))

	if read_only:
		_headline.text = "Today's Daily Challenge"
	elif banked:
		_headline.text = "Banked & Retreated"
	else:
		_headline.text = "The Ward Stone Fell"
	_waves_label.text = "Wave %d" % waves

	for child: Node in _detail.get_children():
		child.queue_free()
	if read_only:
		_add_line("Come back tomorrow for a new seed.")
		_add_line("Streak: %d" % int(SaveManager.get_value("daily_challenge_streak", 0)))
		_double_button.hide()
	else:
		var bank_rate: String = "100%" if banked else "75%"
		_add_line("Runestones earned: %d  (banked at %s)" % [
			int(_result.get("runestones_earned", 0)), bank_rate])
		if int(_result.get("daily_bonus", 0)) > 0:
			_add_line("Daily Challenge bonus: +%d" % int(_result.get("daily_bonus", 0)))
		_add_line("Enemies killed: %d" % int(_result.get("enemies_killed", 0)))
		_add_line("Account XP: +%d" % int(_result.get("xp_earned", 0)))
		if int(_result.get("levels_gained", 0)) > 0:
			_add_line("Level up! Now level %d" % int(_result.get("account_level", 1)), Color(1, 0.85, 0.4))
		for line: String in _newly_affordable_lines():
			_add_line(line, Color(0.6, 0.9, 0.6))
		_double_button.visible = AdsManager.rewarded_ready() and int(_result.get("runestones_earned", 0)) > 0

	var new_best: bool = bool(_result.get("new_best_wave", false))
	_best_banner.visible = new_best
	if new_best and not bool(SaveManager.get_setting("reduced_motion", false)):
		_celebration.emitting = true

func _add_line(text: String, color: Color = Color(1, 0.97, 0.9)) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(label)

## Feature Spec §6.2 — highlight unlocks this run's Runestones just paid for.
func _newly_affordable_lines() -> Array[String]:
	var lines: Array[String] = []
	var balance: int = SaveManager.runestones()
	var earned: int = int(_result.get("runestones_earned", 0))
	var level: int = SaveManager.account_level()
	for def: TowerDef in Registry.towers():
		if def.is_starter() or SaveManager.is_tower_unlocked(String(def.id)):
			continue
		if def.required_account_level > level:
			continue
		if balance >= def.unlock_cost and balance - earned < def.unlock_cost:
			lines.append("%s is now affordable in the Keep Hub" % def.display_name)
	return lines

## Pipeline §4 rewarded video: doubles the run's Runestones, once, and only
## when an ad actually completed.
func _on_double() -> void:
	if _doubled:
		return
	AudioBus.click()
	_double_button.disabled = true
	AdsManager.show_rewarded(func(granted: bool) -> void:
		if granted:
			_doubled = true
			SaveManager.add_runestones(int(_result.get("runestones_earned", 0)))
			_add_line("Runestones doubled!", Color(1, 0.85, 0.4))
			_double_button.hide()
		else:
			_double_button.disabled = false
			_double_button.text = "Reward unavailable")

func _on_spend() -> void:
	AudioBus.click()
	GameState.return_scene = GameState.SCENE_MAIN_MENU
	GameState.goto_scene(GameState.SCENE_KEEP_HUB)

func _on_continue() -> void:
	AudioBus.click()
	GameState.goto_scene(GameState.SCENE_MAIN_MENU)
