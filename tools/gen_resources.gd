extends SceneTree
## Build tool — transcribes the Feature Spec tables into the .tres resources
## the game loads at runtime. Run with:
##
##   godot --headless --path . --script res://tools/gen_resources.gd
##
## Gameplay code never reads this file; it only reads the generated .tres.
## Edit a number here and re-run to regenerate. Values that are NOT in a
## Feature Spec table are marked PROVISIONAL and listed in SPEC_GAPS.md.

const OUT_BALANCE := "res://resources/balance/Balance.tres"
const OUT_ARENA := "res://resources/arena/ArenaMap.tres"
const OUT_WAVES := "res://resources/waves/WaveTable.tres"
const TOWER_DIR := "res://resources/towers/"
const ENEMY_DIR := "res://resources/enemies/"
const DRAFT_DIR := "res://resources/draft/"

const AUTHORED_WAVES: int = 60   ## Technical Architecture §4.2
const PROJECTILE_SCENE := "res://scenes/run/Projectile.tscn"

func _initialize() -> void:
	_ensure_dirs()
	var cfg: BalanceConfig = _build_balance()
	_save(cfg, OUT_BALANCE)
	Balance.set_config(cfg)
	_save(_build_arena(), OUT_ARENA)
	_build_atlases()
	_build_towers()
	_build_enemies()
	_build_waves()
	_build_draft()
	_build_theme()
	print("WARDKEEP: resource generation complete.")
	quit()

func _ensure_dirs() -> void:
	for dir: String in ["res://resources/balance", "res://resources/arena", "res://resources/waves",
			TOWER_DIR, ENEMY_DIR, DRAFT_DIR]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))

func _save(res: Resource, path: String) -> void:
	var err: int = ResourceSaver.save(res, path)
	if err != OK:
		push_error("WARDKEEP: failed saving %s (%d)" % [path, err])
	else:
		print("  wrote ", path)

## --- balance (Feature Spec §2.1, §2.2, §2.3, §3, §6) --------------------

func _build_balance() -> BalanceConfig:
	var cfg := BalanceConfig.new()
	var bands: Array[WaveBand] = []
	# Feature Spec §2.1, verbatim.
	bands.append(_band(1, 5, 10.0, 6.0, 1.2))
	bands.append(_band(6, 10, 40.0, 9.0, 1.0))
	bands.append(_band(11, 30, 80.0, 12.0, 0.85))
	bands.append(_band(31, -1, 308.0, 15.0, 0.7))
	cfg.wave_bands = bands
	return cfg

func _band(from_wave: int, to_wave: int, base: float, step: float, interval: float) -> WaveBand:
	var band := WaveBand.new()
	band.from_wave = from_wave
	band.to_wave = to_wave
	band.base = base
	band.step = step
	band.spawn_interval = interval
	return band

## --- arena (Feature Spec §1) --------------------------------------------

func _build_arena() -> ArenaMap:
	var map := ArenaMap.new()
	map.columns = WK.GRID_COLUMNS
	map.rows = WK.GRID_ROWS
	map.legend = PackedStringArray([
		"....B#B.....",
		"....B#......",
		"....B#......",
		".....#####B.",
		".....B.BB#B.",
		"........B#..",
		"........B#..",
		".B########..",
		".B#BBBBB.B..",
		".B#.........",
		".B#.........",
		"..#######B..",
		"..B.BBBB#B..",
		".......B#...",
		".......B#...",
		"....B####...",
		"....B#B.B...",
		".....WW.....",
		".....WW.....",
		"............",
	])
	map.waypoints = [
		Vector2i(5, 0), Vector2i(5, 3), Vector2i(9, 3), Vector2i(9, 7),
		Vector2i(2, 7), Vector2i(2, 11), Vector2i(8, 11), Vector2i(8, 15),
		Vector2i(5, 15), Vector2i(5, 17),
	]
	return map

## --- towers (Feature Spec §4) -------------------------------------------

## Tier 1 comes straight from the §4 tables. The spec gives only *costs* for
## tiers 2 and 3, so their stats follow one documented progression rule
## (SPEC_GAPS.md #2): damage x2.5 / x6, range +0.5 / +1.0 tiles, fire rate
## x1.15 / x1.32, splash +0.25 / +0.5, slow +5 / +10 percentage points.
##
## The damage multipliers are set so upgrading beats buying another tower.
## At x2/x4 a Watchtower returned 0.280 damage-per-second per gold at tier 1
## and only 0.234 / 0.257 at tiers 2 and 3 — so while any build tile was free,
## a new tier-1 tower was always the better buy and two thirds of the tower
## roster was dead content. It also made space the binding constraint rather
## than gold, which Feature Spec §1 explicitly does not want. At x2.5/x6 the
## figures are 0.280 / 0.293 / 0.386, so going tall is the rational play once
## a line is established.
const TIER_DAMAGE_SCALE := [1.0, 2.5, 6.0]
const TIER_RANGE_BONUS := [0.0, 0.5, 1.0]
const TIER_RATE_SCALE := [1.0, 1.15, 1.32]
const TIER_SPLASH_BONUS := [0.0, 0.25, 0.5]
const TIER_SLOW_BONUS := [0.0, 0.05, 0.10]
const TIER_SLOW_DURATION_BONUS := [0.0, 1.0, 2.0]

func _build_towers() -> void:
	var towers: Array = [
		# id, name, role, element, [t1 cost, dmg, range, rate], t2 cost, t3 cost, sprite, extras
		{
			"id": "watchtower", "name": "Watchtower", "role": "Single-target, high rate",
			"element": WK.RuneElement.PHYSICAL, "t1": [20, 4.0, 3.0, 1.4], "t2": 35, "t3": 60,
			"sprite": "medievalStructure_16.png", "unlock": 0, "level": 1, "extras": {},
		},
		{
			"id": "ballista", "name": "Ballista", "role": "Single-target, armour-piercing",
			"element": WK.RuneElement.PHYSICAL, "t1": [30, 10.0, 4.0, 0.6], "t2": 50, "t3": 90,
			"sprite": "medievalStructure_17.png", "unlock": 150, "level": 3,
			"extras": {"ignores_armor_matchup": true},
		},
		{
			"id": "palisade_ram", "name": "Palisade Ram", "role": "Melee AoE, short range",
			"element": WK.RuneElement.PHYSICAL, "t1": [25, 3.0, 1.0, 1.0], "t2": 40, "t3": 70,
			"sprite": "medievalStructure_23.png", "unlock": 300, "level": 6,
			"extras": {"splash_radius": 1.0},
		},
		{
			"id": "rime_spire", "name": "Rime Spire", "role": "Slow single-target + 20% slow debuff (4s)",
			"element": WK.RuneElement.FROST, "t1": [25, 3.0, 3.0, 1.0], "t2": 40, "t3": 75,
			"sprite": "medievalStructure_19.png", "unlock": 0, "level": 1,
			"extras": {"slow_amount": 0.20, "slow_duration": 4.0},
		},
		{
			"id": "glacier_well", "name": "Glacier Well", "role": "AoE slow field, no damage",
			"element": WK.RuneElement.FROST, "t1": [30, 0.0, 2.0, 0.0], "t2": 50, "t3": 85,
			"sprite": "medievalStructure_13.png", "unlock": 150, "level": 3,
			"extras": {"slow_amount": 0.35, "is_aura": true, "splash_radius": 2.0},
		},
		{
			"id": "icicle_battery", "name": "Icicle Battery", "role": "Burst single-target, bonus vs slowed",
			"element": WK.RuneElement.FROST, "t1": [35, 6.0, 3.0, 0.9], "t2": 55, "t3": 95,
			"sprite": "medievalStructure_18.png", "unlock": 300, "level": 6,
			"extras": {"bonus_vs_slowed": 0.5},
		},
		{
			"id": "rot_censer", "name": "Rot Censer", "role": "Damage-over-time AoE",
			"element": WK.RuneElement.BLIGHT, "t1": [25, 0.0, 2.0, 1.0], "t2": 40, "t3": 70,
			"sprite": "medievalStructure_08.png", "unlock": 0, "level": 1,
			"extras": {"is_aura": true, "splash_radius": 1.5, "dot_damage": 2.0, "dot_duration": 3.0},
		},
		{
			"id": "plague_caster", "name": "Plague Caster", "role": "Single-target, spreads DoT on splash death",
			"element": WK.RuneElement.BLIGHT, "t1": [30, 4.0, 3.0, 1.1], "t2": 50, "t3": 85,
			"sprite": "medievalStructure_12.png", "unlock": 150, "level": 3,
			"extras": {"dot_damage": 2.0, "dot_duration": 3.0, "spreads_dot_on_death": true, "splash_radius": 1.0},
		},
		{
			"id": "bone_turret", "name": "Bone Turret", "role": "Anti-ethereal specialist",
			"element": WK.RuneElement.BLIGHT, "t1": [30, 5.0, 3.0, 1.0], "t2": 50, "t3": 90,
			"sprite": "medievalStructure_22.png", "unlock": 300, "level": 6,
			"extras": {"bonus_vs_ethereal": 1.0},
		},
	]
	for entry: Dictionary in towers:
		var def := TowerDef.new()
		def.id = StringName(entry["id"])
		def.display_name = entry["name"]
		def.role = entry["role"]
		def.rune_element = entry["element"]
		def.sprite_frame = entry["sprite"]
		def.unlock_cost = entry["unlock"]
		def.required_account_level = entry["level"]
		def.scene_path = "res://scenes/towers/%s.tscn" % _pascal(entry["id"])
		# Melee and aura towers stay null here, per Technical Architecture §3.1.
		if not entry["extras"].get("is_aura", false) and float(entry["t1"][2]) > 1.5:
			def.projectile_scene = load(PROJECTILE_SCENE)
		var costs: Array = [entry["t1"][0], entry["t2"], entry["t3"]]
		var tiers: Array[TowerTierData] = []
		for index: int in 3:
			tiers.append(_tier(index, costs[index], entry["t1"], entry["extras"]))
		def.tiers = tiers
		_save(def, TOWER_DIR + entry["id"] + ".tres")

func _tier(index: int, cost: int, t1: Array, extras: Dictionary) -> TowerTierData:
	var tier := TowerTierData.new()
	tier.cost = cost
	tier.damage = snappedf(float(t1[1]) * TIER_DAMAGE_SCALE[index], 0.1)
	tier.range_tiles = float(t1[2]) + TIER_RANGE_BONUS[index]
	tier.fire_rate = snappedf(float(t1[3]) * TIER_RATE_SCALE[index], 0.01)
	tier.is_aura = extras.get("is_aura", false)
	tier.splash_radius = float(extras.get("splash_radius", 0.0))
	if tier.splash_radius > 0.0:
		tier.splash_radius += TIER_SPLASH_BONUS[index]
	tier.slow_amount = float(extras.get("slow_amount", 0.0))
	if tier.slow_amount > 0.0:
		tier.slow_amount = snappedf(tier.slow_amount + TIER_SLOW_BONUS[index], 0.01)
	tier.slow_duration = float(extras.get("slow_duration", 0.0))
	if tier.slow_duration > 0.0:
		tier.slow_duration += TIER_SLOW_DURATION_BONUS[index]
	tier.dot_damage = snappedf(float(extras.get("dot_damage", 0.0)) * TIER_DAMAGE_SCALE[index], 0.1)
	tier.dot_duration = float(extras.get("dot_duration", 0.0))
	tier.spreads_dot_on_death = extras.get("spreads_dot_on_death", false)
	tier.bonus_vs_slowed = float(extras.get("bonus_vs_slowed", 0.0))
	tier.bonus_vs_ethereal = float(extras.get("bonus_vs_ethereal", 0.0))
	tier.ignores_armor_matchup = extras.get("ignores_armor_matchup", false)
	return tier

## --- enemies -------------------------------------------------------------

## PROVISIONAL, all of it. The Feature Spec references "the §4 enemy table"
## but §4 is the tower roster — there is no enemy table anywhere in the suite.
## See SPEC_GAPS.md #3. Shapes chosen to exercise the three armour types the
## §4 matchup rules and the §2.5 boss roster depend on.
func _build_enemies() -> void:
	# Sprite, armour and role are matched deliberately: shelled creatures carry
	# HEAVY, spectral ones ETHEREAL, so a player can read an enemy's matchup
	# off its silhouette instead of memorising a table.
	var enemies: Array = [
		{"id": "grunt", "name": "Grunt", "hp": 12.0, "speed": 1.6, "dmg": 1.0,
			"armor": WK.ArmorType.NONE, "cost": 4, "wave": 1, "art": "slimeGreen", "scale": 0.75},
		{"id": "swarmling", "name": "Swarmling", "hp": 6.0, "speed": 2.4, "dmg": 1.0,
			"armor": WK.ArmorType.NONE, "cost": 3, "wave": 1, "art": "fly", "scale": 0.6},
		{"id": "skirmisher", "name": "Skirmisher", "hp": 18.0, "speed": 1.9, "dmg": 1.0,
			"armor": WK.ArmorType.NONE, "cost": 6, "wave": 3, "art": "spider", "scale": 0.75},
		{"id": "shieldbearer", "name": "Shieldbearer", "hp": 34.0, "speed": 1.1, "dmg": 2.0,
			"armor": WK.ArmorType.HEAVY, "cost": 10, "wave": 5, "art": "snail", "scale": 0.8},
		{"id": "wraith", "name": "Wraith", "hp": 20.0, "speed": 1.8, "dmg": 2.0,
			"armor": WK.ArmorType.ETHEREAL, "cost": 9, "wave": 7, "art": "ghost",
			"tint": Color(1, 1, 1, 0.8), "scale": 0.75},
		{"id": "brute", "name": "Brute", "hp": 55.0, "speed": 0.9, "dmg": 2.0,
			"armor": WK.ArmorType.HEAVY, "cost": 15, "wave": 9, "art": "frog", "scale": 0.95},
		{"id": "hexer", "name": "Hexer", "hp": 26.0, "speed": 1.5, "dmg": 2.0,
			"armor": WK.ArmorType.NONE, "cost": 11, "wave": 11, "art": "bee", "scale": 0.75},
		{"id": "revenant", "name": "Revenant", "hp": 44.0, "speed": 1.4, "dmg": 3.0,
			"armor": WK.ArmorType.ETHEREAL, "cost": 16, "wave": 13, "art": "ghost",
			"tint": Color(0.62, 0.85, 1.0, 0.8), "scale": 0.95},
		{"id": "ironclad", "name": "Ironclad", "hp": 90.0, "speed": 0.8, "dmg": 3.0,
			"armor": WK.ArmorType.HEAVY, "cost": 24, "wave": 16, "art": "barnacle", "scale": 0.9},
		{"id": "shade", "name": "Shade", "hp": 30.0, "speed": 2.6, "dmg": 2.0,
			"armor": WK.ArmorType.ETHEREAL, "cost": 18, "wave": 19, "art": "bat",
			"tint": Color(0.75, 0.75, 0.95, 0.85), "scale": 0.7},
		{"id": "ogre", "name": "Ogre", "hp": 140.0, "speed": 0.7, "dmg": 4.0,
			"armor": WK.ArmorType.HEAVY, "cost": 34, "wave": 22, "art": "slimeBlock", "scale": 1.05},
		{"id": "warlord", "name": "Warlord", "hp": 110.0, "speed": 1.3, "dmg": 3.0,
			"armor": WK.ArmorType.NONE, "cost": 30, "wave": 25, "art": "snakeLava", "scale": 0.95},
	]
	for entry: Dictionary in enemies:
		var def := EnemyDef.new()
		def.id = StringName(entry["id"])
		def.display_name = entry["name"]
		def.base_hp = entry["hp"]
		def.base_speed = entry["speed"]
		def.base_damage = entry["dmg"]
		def.armor_type = entry["armor"]
		def.budget_cost = entry["cost"]
		def.unlock_wave = entry["wave"]
		# One PNG per creature rather than a cell in a sheet, so sprite_cell
		# is the whole-image marker the boss composites already use.
		def.sprite_atlas_path = "res://assets/sprites/enemies/creatures/%s.png" % entry["art"]
		def.sprite_cell = Vector2i(-1, -1)
		def.tint = entry.get("tint", Color.WHITE)
		def.scale_factor = float(entry.get("scale", 0.8))
		def.provisional = true
		def.scene_path = "res://scenes/enemies/%s.tscn" % _pascal(entry["id"])
		_save(def, ENEMY_DIR + entry["id"] + ".tres")

	# Feature Spec §2.5 names the three bosses, their armour types and their
	# patterns, but no stat line for any of them. PROVISIONAL — SPEC_GAPS.md #4.
	var bosses: Array = [
		{"id": "the_bulwark", "name": "The Bulwark", "hp": 450.0, "speed": 0.5, "dmg": 10.0,
			"armor": WK.ArmorType.HEAVY, "script": "res://scenes/enemies/bosses/BulwarkPattern.gd"},
		{"id": "frostmaw", "name": "Frostmaw", "hp": 700.0, "speed": 0.7, "dmg": 12.0,
			"armor": WK.ArmorType.ETHEREAL, "script": "res://scenes/enemies/bosses/FrostmawPattern.gd"},
		{"id": "the_hollow_king", "name": "The Hollow King", "hp": 1000.0, "speed": 0.9, "dmg": 15.0,
			"armor": WK.ArmorType.NONE, "script": "res://scenes/enemies/bosses/HollowKingPattern.gd"},
	]
	for entry: Dictionary in bosses:
		var def := EnemyDef.new()
		def.id = StringName(entry["id"])
		def.display_name = entry["name"]
		def.base_hp = entry["hp"]
		def.base_speed = entry["speed"]
		def.base_damage = entry["dmg"]
		def.armor_type = entry["armor"]
		def.budget_cost = 0
		def.unlock_wave = 10
		def.is_boss = true
		def.provisional = true
		def.sprite_atlas_path = "res://assets/sprites/enemies/bosses_composite/%s.png" % entry["id"]
		def.sprite_cell = Vector2i(-1, -1)   # whole-image sprite, not a sheet cell
		def.scale_factor = 1.0
		def.boss_pattern_script = load(entry["script"]) if ResourceLoader.exists(entry["script"]) else null
		def.scene_path = "res://scenes/enemies/bosses/%s.tscn" % _pascal(entry["id"])
		_save(def, ENEMY_DIR + entry["id"] + ".tres")

## --- wave table (Feature Spec §2) ---------------------------------------

func _build_waves() -> void:
	var table := WaveTable.new()
	var rows: Array[WaveRow] = []
	var boss_ids: Array[String] = ["the_bulwark", "frostmaw", "the_hollow_king"]
	for wave: int in range(1, AUTHORED_WAVES + 1):
		var row := WaveRow.new()
		row.wave = wave
		row.enemy_budget = Balance.enemy_budget(wave)
		row.spawn_interval = Balance.spawn_interval(wave)
		row.is_elite = Balance.is_elite_wave(wave)
		row.is_boss = Balance.is_boss_wave(wave)
		if row.is_boss:
			row.boss_id = StringName(boss_ids[Balance.boss_index_for_wave(wave)])
		rows.append(row)
	table.rows = rows
	_save(table, OUT_WAVES)

## --- draft pool (Feature Spec §5) ---------------------------------------

## §5.2 fixes the rarity weights and gives one example effect per rarity; the
## rest of the pool is PROVISIONAL — SPEC_GAPS.md #6.
func _build_draft() -> void:
	var cards: Array = [
		{"id": "keen_edge", "title": "Keen Edge", "desc": "+10% damage for all towers.",
			"rarity": WK.Rarity.COMMON, "effect": "damage_all_pct", "mag": 0.10, "rank": 3},
		{"id": "iron_discipline", "title": "Iron Discipline", "desc": "+8% fire rate for all towers.",
			"rarity": WK.Rarity.COMMON, "effect": "fire_rate_all_pct", "mag": 0.08, "rank": 3},
		{"id": "far_sight", "title": "Far Sight", "desc": "+10% range for all towers.",
			"rarity": WK.Rarity.COMMON, "effect": "range_all_pct", "mag": 0.10, "rank": 3},
		{"id": "war_tithe", "title": "War Tithe", "desc": "+1 gold from every kill.",
			"rarity": WK.Rarity.COMMON, "effect": "gold_per_kill_flat", "mag": 1.0, "rank": 3},
		{"id": "levy", "title": "Levy", "desc": "+25% wave-clear gold bonus.",
			"rarity": WK.Rarity.COMMON, "effect": "wave_clear_bonus_pct", "mag": 0.25, "rank": 3},
		{"id": "grey_rites", "title": "Grey Rites", "desc": "+15% damage for Physical towers.",
			"rarity": WK.Rarity.COMMON, "effect": "damage_element_pct", "mag": 0.15, "rank": 3,
			"element": WK.RuneElement.PHYSICAL},
		{"id": "blue_rites", "title": "Blue Rites", "desc": "+15% damage for Frost towers.",
			"rarity": WK.Rarity.COMMON, "effect": "damage_element_pct", "mag": 0.15, "rank": 3,
			"element": WK.RuneElement.FROST},
		{"id": "black_rites", "title": "Black Rites", "desc": "+15% damage for Blight towers.",
			"rarity": WK.Rarity.COMMON, "effect": "damage_element_pct", "mag": 0.15, "rank": 3,
			"element": WK.RuneElement.BLIGHT},
		{"id": "masonry", "title": "Masonry", "desc": "Repair 2 Ward Stone health.",
			"rarity": WK.Rarity.COMMON, "effect": "ward_stone_repair", "mag": 2.0, "rank": 3},
		{"id": "wide_blast", "title": "Wide Blast", "desc": "+1 tile splash radius on all AoE towers.",
			"rarity": WK.Rarity.RARE, "effect": "splash_radius_flat", "mag": 1.0, "rank": 2},
		{"id": "deep_chill", "title": "Deep Chill", "desc": "+25% slow strength and duration.",
			"rarity": WK.Rarity.RARE, "effect": "slow_power_pct", "mag": 0.25, "rank": 2},
		{"id": "virulence", "title": "Virulence", "desc": "+30% damage-over-time damage.",
			"rarity": WK.Rarity.RARE, "effect": "dot_damage_pct", "mag": 0.30, "rank": 2},
		{"id": "salvage_rights", "title": "Salvage Rights", "desc": "Selling refunds 20% more.",
			"rarity": WK.Rarity.RARE, "effect": "sell_refund_flat", "mag": 0.20, "rank": 2},
		{"id": "guild_favour", "title": "Guild Favour", "desc": "Tower upgrades cost 15% less.",
			"rarity": WK.Rarity.RARE, "effect": "upgrade_discount_pct", "mag": 0.15, "rank": 2},
		{"id": "reinforced_ward", "title": "Reinforced Ward", "desc": "+5 maximum Ward Stone health, fully repaired.",
			"rarity": WK.Rarity.RARE, "effect": "ward_stone_max_flat", "mag": 5.0, "rank": 2},
		{"id": "bitter_frost", "title": "Bitter Frost", "desc": "Frost slows also deal 1 damage per second.",
			"rarity": WK.Rarity.EPIC, "effect": "frost_slow_damage", "mag": 1.0, "rank": 1},
		{"id": "hollow_charter", "title": "Hollow Charter", "desc": "Unlock one locked tower for the rest of this run.",
			"rarity": WK.Rarity.EPIC, "effect": "unlock_extra_tower", "mag": 1.0, "rank": 1},
		{"id": "overcharge", "title": "Overcharge", "desc": "+25% damage and +25% fire rate for all towers.",
			"rarity": WK.Rarity.EPIC, "effect": "overcharge", "mag": 0.25, "rank": 1},
		{"id": "creeping_rot", "title": "Creeping Rot", "desc": "Every tower applies 1 damage per second of Blight.",
			"rarity": WK.Rarity.EPIC, "effect": "universal_dot", "mag": 1.0, "rank": 1},
	]
	for entry: Dictionary in cards:
		var card := DraftCardDef.new()
		card.id = StringName(entry["id"])
		card.title = entry["title"]
		card.description = entry["desc"]
		card.rarity = entry["rarity"]
		card.effect_key = StringName(entry["effect"])
		card.magnitude = entry["mag"]
		card.max_rank = entry["rank"]
		card.element_filter = entry.get("element", -1)
		_save(card, DRAFT_DIR + entry["id"] + ".tres")

## --- atlases (Pipeline/Integration Spec §3) -----------------------------

## Bakes each pack's spritesheet .xml into an AtlasFrames resource so the
## shipped game never has to parse XML (and the .xml files never have to be
## added to the export filter).
func _build_atlases() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://resources/atlas"))
	var sheets: Dictionary = {
		"medievalRTS": "res://assets/sprites/towers/rts_medieval_base/medievalRTS_spritesheet",
		"explosion_pixel": "res://assets/sprites/vfx/explosion_pixel/spritesheet_pixelExplosion",
		"explosion_simple": "res://assets/sprites/vfx/explosion_simple/spritesheet_simpleExplosion",
		"explosion_ground": "res://assets/sprites/vfx/explosion_ground/spritesheet_groundExplosion",
		"explosion_regular": "res://assets/sprites/vfx/explosion_regular/spritesheet_regularExplosion",
		"explosion_sonic": "res://assets/sprites/vfx/explosion_sonic/spritesheet_sonicExplosion",
	}
	for atlas_name: String in sheets:
		var base: String = sheets[atlas_name]
		var frames := AtlasFrames.new()
		frames.texture_path = base + ".png"
		frames.frames = _parse_atlas_xml(base + ".xml")
		if frames.frames.is_empty():
			push_warning("WARDKEEP: no frames parsed for %s" % atlas_name)
		_save(frames, "res://resources/atlas/%s.tres" % atlas_name)

func _parse_atlas_xml(path: String) -> Dictionary:
	var out: Dictionary = {}
	var parser := XMLParser.new()
	if parser.open(path) != OK:
		push_error("WARDKEEP: cannot open %s" % path)
		return out
	while parser.read() == OK:
		if parser.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		if parser.get_node_name() != "SubTexture":
			continue
		var name: String = parser.get_named_attribute_value_safe("name")
		if name.is_empty():
			continue
		out[name] = Rect2i(
			int(parser.get_named_attribute_value_safe("x")),
			int(parser.get_named_attribute_value_safe("y")),
			int(parser.get_named_attribute_value_safe("width")),
			int(parser.get_named_attribute_value_safe("height")))
	return out

## --- UI theme (User Flow §3, Pipeline §2.5/§2.7) ------------------------

## One theme over the UI Pack - Adventure nine-patches and the Kenney font,
## so every screen picks up the same chrome without per-scene styling.
const UI_DIR := "res://assets/sprites/ui/adventure_pack/Default/"
const FONT_PATH := "res://assets/fonts/Kenney Bold.ttf"

func _build_theme() -> void:
	var theme := Theme.new()
	var font: FontFile = load(FONT_PATH) as FontFile
	if font != null:
		theme.default_font = font
	theme.default_font_size = 26

	theme.set_stylebox("normal", "Button", _nine_patch("button_brown.png"))
	theme.set_stylebox("hover", "Button", _nine_patch("button_brown.png", Color(1.12, 1.12, 1.12)))
	theme.set_stylebox("pressed", "Button", _nine_patch("button_brown.png", Color(0.85, 0.85, 0.85)))
	theme.set_stylebox("disabled", "Button", _nine_patch("button_grey.png", Color(0.7, 0.7, 0.7, 0.7)))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", Color(1, 0.97, 0.9))
	theme.set_color("font_disabled_color", "Button", Color(0.75, 0.75, 0.75))
	theme.set_constant("outline_size", "Button", 4)
	theme.set_color("font_outline_color", "Button", Color(0.16, 0.11, 0.08))

	theme.set_stylebox("panel", "PanelContainer", _nine_patch("panel_brown.png"))
	theme.set_stylebox("panel", "Panel", _nine_patch("panel_grey_bolts.png"))
	theme.set_color("font_color", "Label", Color(1, 0.97, 0.9))
	theme.set_constant("outline_size", "Label", 4)
	theme.set_color("font_outline_color", "Label", Color(0.16, 0.11, 0.08))

	theme.set_stylebox("background", "ProgressBar", _nine_patch("progress_red_border.png"))
	theme.set_stylebox("fill", "ProgressBar", _nine_patch("progress_red.png"))

	_save(theme, "res://ui/wardkeep_theme.tres")

func _nine_patch(file_name: String, tint: Color = Color.WHITE) -> StyleBox:
	var texture: Texture2D = load(UI_DIR + file_name) as Texture2D
	if texture == null:
		var fallback := StyleBoxFlat.new()
		fallback.bg_color = Color(0.2, 0.17, 0.14)
		fallback.set_corner_radius_all(8)
		return fallback
	var box := StyleBoxTexture.new()
	box.texture = texture
	# The Adventure pack's frames have a consistent ~16px decorated border.
	var inset: int = mini(16, int(min(texture.get_width(), texture.get_height()) / 3.0))
	box.texture_margin_left = inset
	box.texture_margin_right = inset
	box.texture_margin_top = inset
	box.texture_margin_bottom = inset
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 12
	box.content_margin_bottom = 16
	box.modulate_color = tint
	return box

func _pascal(id: String) -> String:
	var out: String = ""
	for part: String in id.split("_"):
		out += part.capitalize()
	return out
