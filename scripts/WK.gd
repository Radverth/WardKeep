extends RefCounted
class_name WK
## Shared enums and constants.
##
## These live outside the GameState autoload because GDScript can't use an
## autoload's name as a static type — `WK.RuneElement` can appear in a
## function signature, `GameState.RuneElement` can't.

enum RuneElement { PHYSICAL, FROST, BLIGHT }
enum ArmorType { NONE, HEAVY, ETHEREAL }
enum RunMode { STANDARD, DAILY }
enum Rarity { COMMON, RARE, EPIC }

## Feature Spec §1 — arena grid.
const TILE_SIZE: int = 64
const GRID_COLUMNS: int = 12
const GRID_ROWS: int = 20

static func element_name(element: RuneElement) -> String:
	match element:
		RuneElement.PHYSICAL: return "Physical"
		RuneElement.FROST: return "Frost"
		RuneElement.BLIGHT: return "Blight"
	return "Unknown"

static func armor_name(armor: ArmorType) -> String:
	match armor:
		ArmorType.NONE: return "Unarmored"
		ArmorType.HEAVY: return "Heavy"
		ArmorType.ETHEREAL: return "Ethereal"
	return "Unknown"

static func rarity_name(rarity: Rarity) -> String:
	match rarity:
		Rarity.COMMON: return "Common"
		Rarity.RARE: return "Rare"
		Rarity.EPIC: return "Epic"
	return "Unknown"

## Feature Spec §5.2 — border colours: Common grey, Rare blue, Epic purple.
static func rarity_color(rarity: Rarity) -> Color:
	match rarity:
		Rarity.COMMON: return Color(0.62, 0.62, 0.62)
		Rarity.RARE: return Color(0.29, 0.53, 0.91)
		Rarity.EPIC: return Color(0.65, 0.35, 0.89)
	return Color.WHITE

## Rune Pack tint applied over the shared RTS Medieval base sprite (MAPPING.md).
static func element_tint(element: RuneElement) -> Color:
	match element:
		RuneElement.PHYSICAL: return Color(0.85, 0.85, 0.88)
		RuneElement.FROST: return Color(0.55, 0.78, 1.0)
		RuneElement.BLIGHT: return Color(0.55, 0.45, 0.62)
	return Color.WHITE
