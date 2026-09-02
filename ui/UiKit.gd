extends RefCounted
class_name UiKit
## Small shared helpers over the UI Pack - Adventure assets, so every screen
## picks the same chrome (User Flow §3).

const UI_DIR: String = "res://assets/sprites/ui/adventure_pack/Default/"
const RANK_DIR: String = "res://assets/sprites/ui/ranks/"
const MEDAL_DIR: String = "res://assets/sprites/ui/medals/"
const TOUCH_DIR: String = "res://assets/sprites/ui/input_prompts_touch/Default/"
const BORDER_DIR: String = "res://assets/sprites/ui/fantasy_borders/"
## 48x48 source with a 16px ornate corner, so the frame scales without the
## corners smearing.
const BORDER_CORNER: int = 16

## Feature Spec §8 — rank badges at account levels 5/10/15/20/25/30.
const MEDAL_LEVELS: Array[int] = [5, 10, 15, 20, 25, 30]

## Chrome is never flush against the physical edge of the screen even where the
## device reports no cutout: a top bar hard against the top of the glass reads
## as clipped, and a control on the very bottom edge competes with the system
## gesture bar. In viewport units.
const MIN_TOP_INSET: float = 18.0
const MIN_BOTTOM_INSET: float = 22.0

## Space at the top and bottom of the viewport that the device's own furniture
## occupies — a punch-hole or notch above, a gesture bar below.
##
## get_display_safe_area() answers in physical screen pixels while the UI is
## laid out in viewport units, and the two differ by whatever the stretch
## settings resolved to on this device, so the insets are converted before use.
## Desktop reports the whole screen as safe, which leaves the minimums above.
static func safe_insets(viewport: Viewport) -> Vector2:
	var minimums := Vector2(MIN_TOP_INSET, MIN_BOTTOM_INSET)
	if viewport == null:
		return minimums
	var window: Vector2 = Vector2(DisplayServer.window_get_size())
	var visible: Vector2 = viewport.get_visible_rect().size
	if window.y <= 0.0 or visible.y <= 0.0:
		return minimums
	var to_viewport: float = visible.y / window.y
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	# A display server with no notion of a safe area returns an empty or
	# oversized rect; either way the minimums are the sane answer.
	if safe.size.y <= 0 or safe.size.y > int(window.y):
		return minimums
	return Vector2(
		maxf(minimums.x, float(safe.position.y) * to_viewport),
		maxf(minimums.y, float(int(window.y) - safe.end.y) * to_viewport))

## Pushes a full-screen layout in past whatever the device puts over the top
## and bottom of the glass, keeping whatever padding the scene already had.
## Every screen calls this, so no screen has to know what a punch-hole is.
static func pad_for_safe_area(root: Control) -> void:
	if root == null or not root.is_inside_tree():
		return
	if root.has_meta(&"safe_area_padding"):
		# Re-applied on rotation, so start from the scene's own offsets rather
		# than from the last inset added to them.
		var base: Vector2 = root.get_meta(&"safe_area_padding")
		root.offset_top = base.x
		root.offset_bottom = base.y
	else:
		root.set_meta(&"safe_area_padding", Vector2(root.offset_top, root.offset_bottom))
	var insets: Vector2 = safe_insets(root.get_viewport())
	root.offset_top += insets.x
	root.offset_bottom -= insets.y

static func ui_texture(file_name: String) -> Texture2D:
	return load(UI_DIR + file_name) as Texture2D

## Ranks Pack tier for an account level (also the §6.4 skin palette source).
## The Ranks pack ships 832x384 tilesheets of military insignia, not single
## badges. This used to hand the whole sheet to a 64px TextureRect, which drew
## every chevron in the pack squeezed into a thumbnail — a smear where an icon
## should be. One 64px cell is sliced out instead, and the insignia escalate
## with the tier so the badge says something beyond its colour.
const RANK_CELL: int = 64
const RANK_TIERS: Array[Dictionary] = [
	{"level": 25, "tier": "gold", "cell": Vector2i(4, 4)},     # chevrons and a diamond
	{"level": 15, "tier": "silver", "cell": Vector2i(2, 1)},   # chevron, two stars
	{"level": 5, "tier": "bronze", "cell": Vector2i(0, 1)},    # a single chevron
	{"level": 0, "tier": "black", "cell": Vector2i(0, 0)},     # a plain bar
]

static func rank_texture(account_level: int) -> Texture2D:
	for tier: Dictionary in RANK_TIERS:
		if account_level >= int(tier["level"]):
			return SpriteAtlas.cell(RANK_DIR + "default_%s.png" % tier["tier"],
				tier["cell"].x, tier["cell"].y, RANK_CELL, 0)
	return null

## Iron's plate is near-black on a near-black menu, so it is lifted to a dark
## steel that reads against the background.
static func rank_tint(account_level: int) -> Color:
	return Color(1.9, 1.95, 2.2) if account_level < 5 else Color.WHITE

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

## Fantasy UI Borders are drawn white so they can be tinted. A draft card's
## frame is its rarity colour (Feature Spec §5.2), which is far more legible
## than a flat one-pixel outline.
static func border_stylebox(tint: Color, variant: String = "006", filled: bool = true) -> StyleBoxTexture:
	var folder: String = "Transparent center" if filled else "Border"
	var prefix: String = "panel-transparent-center" if filled else "panel-border"
	var path: String = "%s%s/%s-%s.png" % [BORDER_DIR, folder, prefix, variant]
	var box := StyleBoxTexture.new()
	box.texture = load(path) as Texture2D
	box.texture_margin_left = BORDER_CORNER
	box.texture_margin_right = BORDER_CORNER
	box.texture_margin_top = BORDER_CORNER
	box.texture_margin_bottom = BORDER_CORNER
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	box.modulate_color = tint
	return box

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
