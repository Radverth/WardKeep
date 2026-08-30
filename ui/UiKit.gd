extends RefCounted
class_name UiKit
## Small shared helpers over the UI Pack - Adventure assets, so every screen
## picks the same chrome (User Flow §3).

const UI_DIR: String = "res://assets/sprites/ui/adventure_pack/Default/"
const RANK_DIR: String = "res://assets/sprites/ui/ranks/"
const MEDAL_DIR: String = "res://assets/sprites/ui/medals/"
const TOUCH_DIR: String = "res://assets/sprites/ui/input_prompts_touch/Default/"

## Feature Spec §8 — rank badges at account levels 5/10/15/20/25/30.
const MEDAL_LEVELS: Array[int] = [5, 10, 15, 20, 25, 30]

static func ui_texture(file_name: String) -> Texture2D:
	return load(UI_DIR + file_name) as Texture2D

## Ranks Pack tier for an account level (also the §6.4 skin palette source).
static func rank_texture(account_level: int) -> Texture2D:
	var tier: String = "black"
	if account_level >= 25:
		tier = "gold"
	elif account_level >= 15:
		tier = "silver"
	elif account_level >= 5:
		tier = "bronze"
	return load(RANK_DIR + "default_%s.png" % tier) as Texture2D

static func rank_name(account_level: int) -> String:
	if account_level >= 25:
		return "Gold"
	if account_level >= 15:
		return "Silver"
	if account_level >= 5:
		return "Bronze"
	return "Iron"

## Highest milestone medal earned, or null below level 5.
static func medal_texture(account_level: int) -> Texture2D:
	var earned: int = 0
	for index: int in MEDAL_LEVELS.size():
		if account_level >= MEDAL_LEVELS[index]:
			earned = index + 1
	if earned == 0:
		return null
	return load(MEDAL_DIR + "flat_medal%d.png" % earned) as Texture2D

static func touch_texture(file_name: String) -> Texture2D:
	var path: String = TOUCH_DIR + file_name
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

## A label styled for headings rather than body copy.
static func heading(text: String, size: int = 44) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

static func spacer(height: int) -> Control:
	var control := Control.new()
	control.custom_minimum_size = Vector2(0, height)
	return control

## Feature Spec §6.4 — Veteran/Legendary are palette swaps of the same sprite.
static func skin_modulate(skin_id: String) -> Color:
	match skin_id:
		"veteran": return Color(0.80, 0.85, 0.95)
		"legendary": return Color(1.25, 1.12, 0.65)
	return Color.WHITE

static func skin_display_name(skin_id: String) -> String:
	match skin_id:
		"veteran": return "Veteran"
		"legendary": return "Legendary"
	return "Default"
