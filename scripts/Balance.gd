extends RefCounted
class_name Balance
## Pure arithmetic for every Feature Spec formula. No state, no side effects —
## this is the layer the GUT suites in res://tests/ exercise directly.
##
## Values come from res://resources/balance/Balance.tres (BalanceConfig); this
## file holds only the shape of the formulas, never the numbers.

const CONFIG_PATH: String = "res://resources/balance/Balance.tres"

## Feature Spec §6.2 — the three starter towers, one per rune element.
const STARTER_TOWERS: Array[String] = ["watchtower", "rime_spire", "rot_censer"]

static var _config: BalanceConfig = null

static func config() -> BalanceConfig:
	if _config == null:
		_config = load(CONFIG_PATH) as BalanceConfig
		assert(_config != null, "WARDKEEP: Balance.tres missing or unreadable.")
	return _config

## Test seam: lets a suite swap in a config without touching the shipped one.
static func set_config(override: BalanceConfig) -> void:
	_config = override

## --- wave curve (Feature Spec §2) ---------------------------------------

## Feature Spec §2.1. Elite waves multiply the result by §2.3's 1.4.
## Past the authored table the last band's formula continues unbounded (§2.4).
static func enemy_budget(wave: int) -> float:
	var cfg: BalanceConfig = config()
	var budget: float = 0.0
	for band: WaveBand in cfg.wave_bands:
		if band.contains(wave):
			budget = band.budget_for(wave)
			break
	if is_elite_wave(wave):
		budget *= cfg.elite_budget_multiplier
	return budget

static func spawn_interval(wave: int) -> float:
	for band: WaveBand in config().wave_bands:
		if band.contains(wave):
			return band.spawn_interval
	return 0.7

## Feature Spec §2.2 — HP and damage only; speed is deliberately never scaled.
static func stat_multiplier(wave: int) -> float:
	return 1.0 + config().stat_scale_per_wave * float(wave - 1)

## Feature Spec §2.5 — waves 10, 20, 30, then every 10 indefinitely.
static func is_boss_wave(wave: int) -> bool:
	var cfg: BalanceConfig = config()
	return wave >= cfg.first_boss_wave and wave % cfg.boss_wave_interval == 0

## Feature Spec §2.3 — every 5th wave, excluding boss waves.
static func is_elite_wave(wave: int) -> bool:
	return wave > 0 and wave % config().elite_every == 0 and not is_boss_wave(wave)

## 0 = The Bulwark, 1 = Frostmaw, 2 = The Hollow King, then cycling (§2.5).
static func boss_index_for_wave(wave: int) -> int:
	if not is_boss_wave(wave):
		return -1
	return ((wave / config().boss_wave_interval) - 1) % 3

## --- economy (Feature Spec §3) ------------------------------------------

static func gold_for_kill(wave: int, is_elite: bool = false, is_boss: bool = false) -> int:
	var cfg: BalanceConfig = config()
	if is_boss:
		return cfg.gold_boss_base + cfg.gold_boss_per_wave * wave
	var base: int = cfg.gold_kill_base + int(floor(float(wave) / float(cfg.gold_kill_wave_divisor)))
	if is_elite:
		return int(floor(float(base) * cfg.elite_gold_multiplier))
	return base

static func wave_clear_bonus(wave: int) -> int:
	var cfg: BalanceConfig = config()
	return cfg.gold_wave_clear_base + cfg.gold_wave_clear_per_wave * wave

static func sell_refund(gold_spent: int) -> int:
	return int(floor(float(gold_spent) * config().sell_refund_ratio))

## --- meta-progression (Feature Spec §6) ---------------------------------

## bank_rate is 1.0 for Bank & Retreat, 0.75 for a Ward Stone loss (§2.6).
static func runestones_for_run(waves_survived: int, banked: bool) -> int:
	var cfg: BalanceConfig = config()
	var rate: float = cfg.bank_rate_retreat if banked else cfg.bank_rate_loss
	return int(floor(float(waves_survived) * float(cfg.runestones_per_wave) * rate))

static func xp_for_run(waves_survived: int) -> int:
	return waves_survived * config().xp_per_wave

## Cumulative XP needed to hold `level` — 100 x level^2 (§6.3).
static func xp_for_level(level: int) -> int:
	return config().xp_level_coefficient * level * level

static func level_for_xp(xp: int) -> int:
	var cfg: BalanceConfig = config()
	var level: int = 1
	while level < cfg.max_account_level and xp >= xp_for_level(level + 1):
		level += 1
	return level

## Progress towards the next level, 0.0-1.0. Returns 1.0 at the level cap.
static func level_progress(xp: int) -> float:
	var cfg: BalanceConfig = config()
	var level: int = level_for_xp(xp)
	if level >= cfg.max_account_level:
		return 1.0
	var floor_xp: int = xp_for_level(level) if level > 1 else 0
	var next_xp: int = xp_for_level(level + 1)
	return clampf(float(xp - floor_xp) / float(next_xp - floor_xp), 0.0, 1.0)

## --- element matchups (Feature Spec §4) ---------------------------------

## Frost is strong vs HEAVY and weak vs ETHEREAL; Blight is strong vs
## ETHEREAL and neutral vs HEAVY; Physical is neutral against everything.
static func element_multiplier(element: WK.RuneElement, armor: WK.ArmorType) -> float:
	var cfg: BalanceConfig = config()
	match element:
		WK.RuneElement.FROST:
			if armor == WK.ArmorType.HEAVY:
				return cfg.element_strong_multiplier
			if armor == WK.ArmorType.ETHEREAL:
				return cfg.element_weak_multiplier
		WK.RuneElement.BLIGHT:
			if armor == WK.ArmorType.ETHEREAL:
				return cfg.element_strong_multiplier
	return 1.0
