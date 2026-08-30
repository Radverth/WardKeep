extends RefCounted
class_name SpriteAtlas
## Builds AtlasTextures over the packs' shared spritesheets and caches them,
## so a sheet's texture is loaded once no matter how many sprites use it
## (Technical Architecture §6, "one texture, an AtlasTexture per frame").

const ATLAS_DIR: String = "res://resources/atlas/"

static var _textures: Dictionary = {}       ## path -> Texture2D
static var _frame_sets: Dictionary = {}     ## atlas name -> AtlasFrames
static var _cache: Dictionary = {}          ## cache key -> AtlasTexture

static func texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) as Texture2D
	return _textures[path]

static func _frame_set(atlas_name: String) -> AtlasFrames:
	if not _frame_sets.has(atlas_name):
		var path: String = ATLAS_DIR + atlas_name + ".tres"
		_frame_sets[atlas_name] = load(path) as AtlasFrames if ResourceLoader.exists(path) else null
	return _frame_sets[atlas_name]

## A named frame from a baked .xml atlas (see AtlasFrames).
static func frame(atlas_name: String, frame_name: String) -> AtlasTexture:
	var key: String = atlas_name + "/" + frame_name
	if _cache.has(key):
		return _cache[key]
	var frames: AtlasFrames = _frame_set(atlas_name)
	if frames == null or not frames.has_frame(frame_name):
		push_warning("WARDKEEP: atlas frame %s missing." % key)
		return null
	var tex := AtlasTexture.new()
	tex.atlas = texture(frames.texture_path)
	tex.region = Rect2(frames.rect(frame_name))
	_cache[key] = tex
	return tex

## A cell from a uniform grid sheet — the roguelike packs are 16px tiles with
## a 1px margin (see each pack's Instructions.txt).
static func cell(sheet_path: String, column: int, row: int, size: int = 16, margin: int = 1) -> AtlasTexture:
	var key: String = "%s#%d,%d,%d,%d" % [sheet_path, column, row, size, margin]
	if _cache.has(key):
		return _cache[key]
	var tex := AtlasTexture.new()
	tex.atlas = texture(sheet_path)
	tex.region = Rect2(column * (size + margin), row * (size + margin), size, size)
	_cache[key] = tex
	return tex

## A whole image used as one sprite (the baked boss composites).
static func whole(path: String) -> Texture2D:
	return texture(path)

static func clear_cache() -> void:
	_textures.clear()
	_frame_sets.clear()
	_cache.clear()
