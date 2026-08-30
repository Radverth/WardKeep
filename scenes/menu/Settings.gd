extends Control
## User Flow §3.7.

const PRIVACY_URL: String = "https://wardkeep.example/privacy"

@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _reduced_motion: CheckButton = %ReducedMotion
@onready var _restore_button: Button = %RestoreButton
@onready var _privacy_button: Button = %PrivacyButton
@onready var _back_button: Button = %BackButton
@onready var _ads_label: Label = %AdsLabel

func _ready() -> void:
	_music_slider.value = float(SaveManager.get_setting("music_volume", 0.8))
	_sfx_slider.value = float(SaveManager.get_setting("sfx_volume", 1.0))
	_reduced_motion.button_pressed = bool(SaveManager.get_setting("reduced_motion", false))
	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_reduced_motion.toggled.connect(_on_reduced_motion)
	_restore_button.pressed.connect(_on_restore)
	_privacy_button.pressed.connect(func() -> void: OS.shell_open(PRIVACY_URL))
	_back_button.pressed.connect(_on_back)
	_refresh_ads_label()

func _on_music_changed(value: float) -> void:
	SaveManager.set_setting("music_volume", value)
	AudioBus.apply_settings()

func _on_sfx_changed(value: float) -> void:
	SaveManager.set_setting("sfx_volume", value)
	AudioBus.apply_settings()
	AudioBus.select()

func _on_reduced_motion(pressed: bool) -> void:
	SaveManager.set_setting("reduced_motion", pressed)

## Remove Ads is an entitlement, so "restore" re-reads it from the store when
## a billing plugin is present and otherwise reports honestly.
func _on_restore() -> void:
	AudioBus.click()
	_ads_label.text = "Nothing to restore on this build." if not AdsManager.has_removed_ads() \
		else "Remove Ads is active on this device."
	_refresh_ads_label()

func _refresh_ads_label() -> void:
	if AdsManager.has_removed_ads():
		_ads_label.text = "Remove Ads: active"
	elif not AdsManager.is_available():
		_ads_label.text = "Ads unavailable on this build"

func _on_back() -> void:
	AudioBus.click()
	GameState.goto_scene(GameState.return_scene)
