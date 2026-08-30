extends SceneTree
## Build tool — assembles the three Feature Spec §2.5 bosses once from the
## Monster Builder Pack's modular parts and writes each out as a single static
## PNG, per MAPPING.md ("build each boss once as a static composite at import
## time, don't runtime-assemble"). Run with:
##
##   godot --headless --path . --script res://tools/build_boss_composites.gd

const PARTS := "res://assets/sprites/enemies/monster_builder_bosses/"
const OUT_DIR := "res://assets/sprites/enemies/bosses_composite/"
const CANVAS := 340

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	# The Bulwark — heavy, stone-grey, horned: sustained single-target DPS check.
	_compose("the_bulwark", {
		"body": "body_darkF.png", "arms": "arm_darkD.png", "legs": "leg_darkC.png",
		"eyes": "eye_angry_red.png", "mouth": "mouth_closed_fangs.png",
		"horns": "detail_dark_horn_large.png", "body_scale": 1.0,
	})
	# Frostmaw — ethereal, blue, immune to Frost slows.
	_compose("frostmaw", {
		"body": "body_blueE.png", "arms": "arm_blueC.png", "legs": "leg_blueB.png",
		"eyes": "eye_angry_blue.png", "mouth": "mouthE.png",
		"horns": "detail_blue_horn_large.png", "body_scale": 0.95,
	})
	# The Hollow King — splits at 50%; pale, crowned.
	_compose("the_hollow_king", {
		"body": "body_whiteD.png", "arms": "arm_whiteB.png", "legs": "leg_whiteA.png",
		"eyes": "eye_psycho_dark.png", "mouth": "mouthI.png",
		"horns": "detail_white_horn_large.png", "body_scale": 0.9,
	})
	print("WARDKEEP: boss composites written to ", OUT_DIR)
	quit()

func _load_part(file_name: String) -> Image:
	var path: String = PARTS + file_name
	if not FileAccess.file_exists(path):
		push_warning("WARDKEEP: boss part missing, skipped: %s" % file_name)
		return null
	return Image.load_from_file(path)

## Alpha-blends `part` onto `canvas` with its centre at `center`.
func _stamp(canvas: Image, part: Image, center: Vector2i, flip_h: bool = false) -> void:
	if part == null:
		return
	var image: Image = part.duplicate()
	image.convert(Image.FORMAT_RGBA8)
	if flip_h:
		image.flip_x()
	var top_left := Vector2i(center.x - image.get_width() / 2, center.y - image.get_height() / 2)
	canvas.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), top_left)

func _compose(boss_id: String, parts: Dictionary) -> void:
	var canvas: Image = Image.create(CANVAS, CANVAS, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	var body: Image = _load_part(parts["body"])
	if body == null:
		push_error("WARDKEEP: %s has no body part; composite skipped." % boss_id)
		return
	body = body.duplicate()
	body.convert(Image.FORMAT_RGBA8)
	var scale: float = float(parts.get("body_scale", 1.0))
	var target: Vector2i = Vector2i(int(body.get_width() * scale), int(body.get_height() * scale))
	target.x = mini(target.x, CANVAS - 160)
	target.y = mini(target.y, CANVAS - 160)
	body.resize(target.x, target.y, Image.INTERPOLATE_LANCZOS)

	var centre := Vector2i(CANVAS / 2, CANVAS / 2)
	var half := Vector2i(body.get_width() / 2, body.get_height() / 2)

	# Back-to-front: legs, arms, body, then face and horns on top.
	var legs: Image = _load_part(parts["legs"])
	_stamp(canvas, legs, Vector2i(centre.x - half.x / 2, centre.y + half.y))
	_stamp(canvas, legs, Vector2i(centre.x + half.x / 2, centre.y + half.y), true)
	var arms: Image = _load_part(parts["arms"])
	_stamp(canvas, arms, Vector2i(centre.x - half.x - 4, centre.y + half.y / 4))
	_stamp(canvas, arms, Vector2i(centre.x + half.x + 4, centre.y + half.y / 4), true)
	_stamp(canvas, _load_part(parts["horns"]), Vector2i(centre.x - half.x / 2, centre.y - half.y - 4))
	_stamp(canvas, _load_part(parts["horns"]), Vector2i(centre.x + half.x / 2, centre.y - half.y - 4), true)
	_stamp(canvas, body, centre)
	var eyes: Image = _load_part(parts["eyes"])
	_stamp(canvas, eyes, Vector2i(centre.x - half.x / 3, centre.y - half.y / 3))
	_stamp(canvas, eyes, Vector2i(centre.x + half.x / 3, centre.y - half.y / 3), true)
	_stamp(canvas, _load_part(parts["mouth"]), Vector2i(centre.x, centre.y + half.y / 4))

	var used: Rect2i = canvas.get_used_rect()
	if used.size.x > 0 and used.size.y > 0:
		canvas = canvas.get_region(used)
	var err: int = canvas.save_png(OUT_DIR + boss_id + ".png")
	if err != OK:
		push_error("WARDKEEP: could not write %s composite (%d)" % [boss_id, err])
	else:
		print("  wrote ", OUT_DIR, boss_id, ".png (", canvas.get_width(), "x", canvas.get_height(), ")")
