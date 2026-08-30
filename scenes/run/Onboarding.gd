extends Control
## User Flow §4 — one-time tooltip sequence on the very first run, using the
## Input Prompts (Touch) icons. The run itself is real; nothing is gated.

const STEPS: Array[Dictionary] = [
	{"icon": "touch_swipe_move.png", "text": "Drag to place a tower"},
	{"icon": "touch_tap.png", "text": "Tap a tower to upgrade it"},
	{"icon": "touch_tap_double.png", "text": "Waves get harder — that's the point."},
]

@onready var _icon: TextureRect = %Icon
@onready var _text: Label = %Text
@onready var _next_button: Button = %NextButton

var _step: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_next_button.pressed.connect(_advance)
	hide()

func begin() -> void:
	_step = 0
	_show_step()
	show()

func _show_step() -> void:
	var step: Dictionary = STEPS[_step]
	_icon.texture = UiKit.touch_texture(step["icon"])
	_text.text = step["text"]
	_next_button.text = "Got it" if _step == STEPS.size() - 1 else "Next"

func _advance() -> void:
	AudioBus.click()
	_step += 1
	if _step >= STEPS.size():
		hide()
		return
	_show_step()
