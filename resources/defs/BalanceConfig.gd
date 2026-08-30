extends Resource
class_name BalanceConfig
## Every tuning number the Feature Spec states as a formula constant.
##
## Per the Claude Code Brief §4, gameplay numbers live in resources, not in
## .gd files — Balance.gd only implements the arithmetic, this resource holds
## the values. Fields whose source is a spec gap rather than a spec table are
## marked PROVISIONAL and listed in SPEC_GAPS.md.

## Feature Spec §2.1 — wave budget bands, in ascending wave order.
@export var wave_bands: Array[WaveBand] = []

## Feature Spec §2.2 — multiplier = 1 + stat_scale_per_wave x (wave - 1).
@export var stat_scale_per_wave: float = 0.09

## Feature Spec §2.3 — elite waves.
@export var elite_every: int = 5
@export var elite_budget_multiplier: float = 1.4
@export var elite_hp_multiplier: float = 2.0
@export var elite_gold_multiplier: float = 1.5

## Feature Spec §2.5 — boss waves (10, 20, 30, then cycling every 10).
@export var first_boss_wave: int = 10
@export var boss_wave_interval: int = 10

## Feature Spec §3 — in-run gold.
@export var starting_gold: int = 40
@export var gold_kill_base: int = 2
@export var gold_kill_wave_divisor: int = 3
@export var gold_boss_base: int = 50
@export var gold_boss_per_wave: int = 5
@export var gold_wave_clear_base: int = 5
@export var gold_wave_clear_per_wave: int = 1
@export var sell_refund_ratio: float = 0.6

## Feature Spec §6.1 / §6.3 — meta-progression.
@export var runestones_per_wave: int = 3
@export var bank_rate_retreat: float = 1.0
@export var bank_rate_loss: float = 0.75
@export var xp_per_wave: int = 5
@export var xp_level_coefficient: int = 100
@export var max_account_level: int = 30

## Feature Spec §5.2 — draft rarity weights (must sum to 100).
@export var draft_card_count: int = 3
@export var draft_weight_common: int = 60
@export var draft_weight_rare: int = 30
@export var draft_weight_epic: int = 10

## Feature Spec §7 — Daily Challenge.
@export var daily_completion_bonus: int = 25

## Pipeline/Integration Spec §4 — interstitial frequency cap.
@export var interstitial_every_n_run_ends: int = 3

## PROVISIONAL — the Feature Spec never states a Ward Stone HP pool.
## See SPEC_GAPS.md #1.
@export var ward_stone_hp: int = 20

## Feature Spec §4 names the element matchups ("strong vs", "weak vs") but
## gives no magnitudes. PROVISIONAL — see SPEC_GAPS.md #5.
@export var element_strong_multiplier: float = 1.25
@export var element_weak_multiplier: float = 0.75
