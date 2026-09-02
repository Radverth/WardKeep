extends Control
## User Flow §3.1.

const XP_BAR_FILL: Color = Color(0.55, 0.78, 0.44)
const XP_BAR_TRACK: Color = Color(0.20, 0.19, 0.20)

@onready var _rank_icon: TextureRect = %RankIcon
@onready var _medal_icon: TextureRect = %MedalIcon
@onready var _level_label: Label = %LevelLabel
@onready var _xp_bar: ProgressBar = %XpBar
@onready var _runestone_label: Label = %RunestoneLabel
@onready var _start_button: Button = %StartButton
@onready var _daily_button: Button = %DailyButton
@onready var _daily_detail: Label = %DailyDetail
@onready var _keep_button: Button = %KeepButton
@onready var _settings_button: Button = %SettingsButton
@onready var _best_wave_label: Label = %BestWaveLabel

func _ready() -> void:
	# The device may put a punch-hole over the top of this screen and a
	# gesture bar under the bottom of it.
	UiKit.pad_for_safe_area($Root)
	get_viewport().size_changed.connect(func() -> void:
		UiKit.pad_for_safe_area($Root))
	GameState.return_scene = GameState.SCENE_MAIN_MENU
	_start_button.pressed.connect(_on_start)
	_daily_button.pressed.connect(_on_daily)
	_keep_button.pressed.connect(_on_keep)
	_settings_button.pressed.connect(_on_settings)
	_refresh()
	AudioBus.play_stinger(AudioBus.STINGER_MENU)

## The theme dresses every ProgressBar as the Ward Stone's health bar. A
## full-width red one under the player's rank reads as an alarm rather than as
## progress, and tinting the red art green only made it brown — so this bar
## gets flat styleboxes of its own instead.
func _style_xp_bar() -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = XP_BAR_FILL
	fill.set_corner_radius_all(4)
	var track := StyleBoxFlat.new()
	track.bg_color = XP_BAR_TRACK
	track.set_corner_radius_all(4)
	_xp_bar.add_theme_stylebox_override("fill", fill)
	_xp_bar.add_theme_stylebox_override("background", track)

func _refresh() -> void:
	var level: int = SaveManager.account_level()
	_rank_icon.texture = UiKit.rank_texture(level)
	_rank_icon.modulate = UiKit.rank_tint(level)
	var medal: Texture2D = UiKit.medal_texture(level)
	_medal_icon.texture = medal
	_medal_icon.visible = medal != null
	_level_label.text = "%s  ·  Level %d" % [UiKit.rank_name(level), level]
	_style_xp_bar()
	_xp_bar.value = Balance.level_progress(SaveManager.account_xp()) * 100.0
	_runestone_label.text = "%d Runestones" % SaveManager.runestones()

	var best: int = int(SaveManager.get_stat("best_wave", 0))
	_best_wave_label.text = "Best wave: %d" % best if best > 0 else "No runs yet"

	var streak: int = int(SaveManager.get_value("daily_challenge_streak", 0))
	if RunManager.daily_played_today():
		_daily_button.text = "Completed — back tomorrow"
		_daily_detail.text = "Today: wave %d  ·  streak %d" % [
			int(SaveManager.get_value("daily_challenge_best_wave", 0)), streak]
	else:
		_daily_button.text = "Daily Challenge"
		_daily_detail.text = "Streak %d" % streak

func _on_start() -> void:
	AudioBus.click()
	GameState.pending_run_mode = WK.RunMode.STANDARD
	GameState.goto_scene(GameState.SCENE_RUN_SETUP)

## User Flow §5 — an already-played Daily reopens today's result read-only
## rather than replaying it.
func _on_daily() -> void:
	AudioBus.click()
	if RunManager.daily_played_today():
		GameState.last_run_result = {
			"mode": int(WK.RunMode.DAILY),
			"waves_survived": int(SaveManager.get_value("daily_challenge_best_wave", 0)),
			"read_only": true,
			"banked": true,
			"runestones_earned": 0,
			"daily_bonus": 0,
			"xp_earned": 0,
			"enemies_killed": 0,
			"new_best_wave": false,
			"best_wave": int(SaveManager.get_stat("best_wave", 0)),
			"levels_gained": 0,
			"account_level": SaveManager.account_level(),
		}
		GameState.goto_scene(GameState.SCENE_RUN_SUMMARY)
		return
	GameState.pending_run_mode = WK.RunMode.DAILY
	GameState.goto_scene(GameState.SCENE_ARENA)

func _on_keep() -> void:
	AudioBus.click()
	GameState.goto_scene(GameState.SCENE_KEEP_HUB)

func _on_settings() -> void:
	AudioBus.click()
	GameState.goto_scene(GameState.SCENE_SETTINGS)
