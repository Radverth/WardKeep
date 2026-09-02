extends RefCounted
class_name Terrain
## The board's art, sourced from Toen's Medieval Strategy Sprite Pack
## (Andre Mari Coppola, CC-BY 4.0 — see the pack's LICENSE.txt).
##
## The sheet is 7 columns of 16px tiles with no margin, so a tile is addressed
## by a single index: row * COLUMNS + column.
##
## The pack has no road *fill* tiles. What it has is a nine-slice ring — a
## sand band with grass on the outside and nothing in the middle — meant to be
## laid around an area. WardKeep's lane is one tile wide, so almost every lane
## cell needs grass on two opposite sides at once, which no single tile in the
## ring provides. road() therefore composites each lane tile out of four 8px
## quadrants taken from the ring, choosing each quadrant from the two
## directions that touch it. That covers all sixteen open/closed combinations
## from nine source tiles, and the seams are invisible because every quadrant
## comes from the same ring.

const SHEET: String = "res://assets/sprites/environment/toen_medieval_strategy/toen_medieval_strategy.png"
const COLUMNS: int = 7
const SIZE: int = 16
const HALF: int = SIZE / 2

## Grass. GRASS_BASE is the flat green the road ring's own border is drawn
## against, so only this shade may sit next to a lane; GRASS_TUFT is the same
## green with blades on it. The pack's other two grass tiles are a slightly
## darker green and tile visibly against these, so they are left out.
const GRASS_BASE: int = 1
const GRASS_TUFT: int = 3
const GRASS_TUFT_CHANCE: float = 0.35

## The nine-slice ring the lane tiles are cut from.
const RING_TOP_LEFT: int = 175
const RING_TOP: int = 176
const RING_TOP_RIGHT: int = 177
const RING_LEFT: int = 182
const RING_RIGHT: int = 184
const RING_BOTTOM_LEFT: int = 189
const RING_BOTTOM: int = 190
const RING_BOTTOM_RIGHT: int = 191
## The innermost colour of the ring's band, used where a quadrant is fully
## surrounded by lane and so has no edge to draw.
const ROAD_FILL: Color = Color(0.97255, 0.93333, 0.78039)

## Neighbour bits, in the order road() expects them.
const OPEN_NORTH: int = 1
const OPEN_EAST: int = 2
const OPEN_SOUTH: int = 4
const OPEN_WEST: int = 8

## Scenery for the open field. The weight is how many times a prop enters the
## draw bag, so pines and shrubs carry the field and the landmarks stay rare.
const PROPS: Array[Vector2i] = [
	Vector2i(4, 7), Vector2i(5, 7), Vector2i(6, 5),      # pine clumps
	Vector2i(13, 4), Vector2i(27, 4),                     # shrubs
	Vector2i(10, 3), Vector2i(11, 3), Vector2i(12, 2),    # boulders
	Vector2i(238, 2), Vector2i(239, 2),                   # fallen rubble
	Vector2i(18, 1), Vector2i(19, 1),                     # puddles
	Vector2i(40, 1), Vector2i(41, 1), Vector2i(35, 1),    # campfire, crate, bones
	Vector2i(36, 1), Vector2i(37, 1), Vector2i(38, 1), Vector2i(39, 1),
]
const PROP_CHANCE: float = 0.22
## Props are nudged off the tile centre so the scenery does not read as a grid.
const PROP_JITTER: int = 3
## Low grass under everything else, at a lower density than the props. The
## pack's leaf-litter tile is deliberately left out: it is a dark mound, and
## sown across a field it reads as scattered holes rather than as ground cover.
const GROUND_DETAIL: Array[int] = [306, 307]
const GROUND_DETAIL_CHANCE: float = 0.24
const GROUND_DETAIL_JITTER: int = 6

## The board is 12x20 tiles and a portrait screen is taller than that is wide,
## so fitting it by height leaves a bar down each side. The field is drawn this
## many tiles past the board on every side to fill them; nothing out there is
## interactive, it is only scenery so the arena reads as part of a countryside
## rather than as a card laid on a black table.
const BLEED_TILES: int = 3

## The Ward Stone: a walled keep with a gatehouse, four tiles laid 2x2.
const KEEP_TILES: Array[int] = [53, 54, 60, 61]

static var _road_cache: Dictionary = {}     ## mask -> ImageTexture
static var _sheet_image: Image = null

## One tile of the sheet, as an AtlasTexture over the shared texture.
static func tile(index: int) -> AtlasTexture:
	return SpriteAtlas.cell(SHEET, index % COLUMNS, index / COLUMNS, SIZE, 0)

static func _image() -> Image:
	if _sheet_image == null:
		_sheet_image = SpriteAtlas.texture(SHEET).get_image()
		if _sheet_image.is_compressed():
			# Nothing can be read out of a VRAM-compressed image. The sheet's
			# .import pins it to lossless for exactly this reason.
			_sheet_image.decompress()
	return _sheet_image

static func _quadrant_rect(index: int, quadrant_x: int, quadrant_y: int) -> Rect2i:
	return Rect2i((index % COLUMNS) * SIZE + quadrant_x * HALF,
		(index / COLUMNS) * SIZE + quadrant_y * HALF, HALF, HALF)

## Picks the ring tile whose quadrant belongs on a corner where `along` runs
## parallel to the band and `across` runs into it.
static func _quadrant_source(along_open: bool, across_open: bool,
		corner: int, along_edge: int, across_edge: int) -> int:
	if not along_open and not across_open:
		return corner
	return along_edge if not along_open else across_edge

## The lane tile for a set of open neighbours. `mask` is the OPEN_* bits.
static func road(mask: int) -> ImageTexture:
	if _road_cache.has(mask):
		return _road_cache[mask]
	var north: bool = (mask & OPEN_NORTH) != 0
	var east: bool = (mask & OPEN_EAST) != 0
	var south: bool = (mask & OPEN_SOUTH) != 0
	var west: bool = (mask & OPEN_WEST) != 0
	var sheet: Image = _image()
	var out := Image.create(SIZE, SIZE, false, sheet.get_format())
	var fill := Image.create(HALF, HALF, false, sheet.get_format())
	fill.fill(ROAD_FILL)
	var quadrants: Array = [
		# quadrant x, quadrant y, the two directions that touch it, sources
		[0, 0, north, west, RING_TOP_LEFT, RING_TOP, RING_LEFT],
		[1, 0, north, east, RING_TOP_RIGHT, RING_TOP, RING_RIGHT],
		[0, 1, south, west, RING_BOTTOM_LEFT, RING_BOTTOM, RING_LEFT],
		[1, 1, south, east, RING_BOTTOM_RIGHT, RING_BOTTOM, RING_RIGHT],
	]
	for quadrant: Array in quadrants:
		var at := Vector2i(int(quadrant[0]) * HALF, int(quadrant[1]) * HALF)
		if bool(quadrant[2]) and bool(quadrant[3]):
			out.blit_rect(fill, Rect2i(Vector2i.ZERO, Vector2i(HALF, HALF)), at)
			continue
		var source: int = _quadrant_source(bool(quadrant[2]), bool(quadrant[3]),
			int(quadrant[4]), int(quadrant[5]), int(quadrant[6]))
		out.blit_rect(sheet, _quadrant_rect(source, int(quadrant[0]), int(quadrant[1])), at)
	var texture: ImageTexture = ImageTexture.create_from_image(out)
	_road_cache[mask] = texture
	return texture

## The Ward Stone, composited from the pack's 2x2 walled keep so it can be one
## sprite on the board rather than four.
static var _keep_texture: ImageTexture = null

static func keep() -> ImageTexture:
	if _keep_texture != null:
		return _keep_texture
	var sheet: Image = _image()
	var out := Image.create(SIZE * 2, SIZE * 2, false, sheet.get_format())
	for slot: int in KEEP_TILES.size():
		var index: int = KEEP_TILES[slot]
		out.blit_rect(sheet,
			Rect2i((index % COLUMNS) * SIZE, (index / COLUMNS) * SIZE, SIZE, SIZE),
			Vector2i((slot % 2) * SIZE, (slot / 2) * SIZE))
	_keep_texture = ImageTexture.create_from_image(out)
	return _keep_texture

static func clear_cache() -> void:
	_road_cache.clear()
	_keep_texture = null
	_sheet_image = null
