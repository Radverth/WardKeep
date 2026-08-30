extends Control
## User Flow §1 — Boot to Main Menu. Autoloads have already run their _ready
## by the time this scene exists, so the save is loaded; this screen just
## holds the splash long enough not to flash, then hands over.

const SPLASH_SECONDS: float = 0.8

@onready var _version_label: Label = %VersionLabel

func _ready() -> void:
	_version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.0.0")
	# Touching SaveManager here surfaces a corrupt-save repair before any
	# screen reads from it.
	SaveManager.load_save()
	await get_tree().create_timer(SPLASH_SECONDS).timeout
	GameState.goto_scene(GameState.SCENE_MAIN_MENU)
