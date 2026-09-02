extends Control
## User Flow §3.3 — "Resume / Settings / Forfeit Run". Settings are inline
## rather than a scene change, so opening them never costs the player the run.

signal resume_pressed()
signal forfeit_pressed()

@onready var _resume_button: Button = %ResumeButton
@onready var _forfeit_button: Button = %ForfeitButton
@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _reduced_motion: CheckButton = %ReducedMotion
@onready var _forfeit_note: Label = %ForfeitNote

func _ready() -> void:
	# The device may put a punch-hole over the top of this screen and a
	# gesture bar under the bottom of it.
	UiKit.pad_for_safe_area($Root)
	get_viewport().size_changed.connect(func() -> void:
		UiKit.pad_for_safe_area($Root))
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resume_button.pressed.connect(func() -> void:
		AudioBus.click()
		resume_pressed.emit())
	_forfeit_button.pressed.connect(func() -> void:
		AudioBus.click()
		forfeit_pressed.emit())
	_music_slider.value_changed.connect(func(value: float) -> void:
		SaveManager.set_setting("music_volume", value)
		AudioBus.apply_settings())
	_sfx_slider.value_changed.connect(func(value: float) -> void:
		SaveManager.set_setting("sfx_volume", value)
		AudioBus.apply_settings())
	_reduced_motion.toggled.connect(func(pressed: bool) -> void:
		SaveManager.set_setting("reduced_motion", pressed))
	hide()

## `between_waves` is true once a wave has cleared, when Bank & Retreat is the
## better exit than forfeiting (Feature Spec §2.6: 100% vs 75%).
func open(between_waves: bool) -> void:
	_music_slider.set_value_no_signal(float(SaveManager.get_setting("music_volume", 0.8)))
	_sfx_slider.set_value_no_signal(float(SaveManager.get_setting("sfx_volume", 1.0)))
	_reduced_motion.set_pressed_no_signal(bool(SaveManager.get_setting("reduced_motion", false)))
	_forfeit_note.visible = between_waves
	show()

func close() -> void:
	hide()
