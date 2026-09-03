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

## --- tower upkeep (PROVISIONAL, SPEC_GAPS.md #16) -----------------------
## Towers past this many cost one kill's worth of gold every wave. Feature Spec
## §1 wants gold to be the constraint rather than space, but with 34 build
## tiles and income that outruns costs, filling the board was strictly correct
## and nothing pushed back. Upkeep is charged per tower rather than per tier,
## so going tall stays the efficient play and going wide is what costs.
##
## Set to a working line rather than something smaller, so the opening is
## untaxed. Charging from the ninth tower took gold out of exactly the waves a
## fresh Keep spends assembling its first defence, which is not where filling
## the board was the problem.
@export var upkeep_free_towers: int = 12
## Gold of unpaid upkeep per point of Ward Stone lost. A tax the player can
## simply decline to pay changes nothing once the board is already built —
## towers stay bought and keep firing — so an unpaid garrison deserts and the
## keep suffers for it. That is what makes an oversized board actively bad
## rather than merely slower to assemble, and selling one is the answer.
@export var upkeep_desertion_gold: int = 20
## Every this many towers past the free allowance, each garrisoned tower's
## wages go up by another kill's worth. Flat upkeep only skimmed gold a wide
## board had nothing left to spend on: it made filling the map poorer without
## making it wrong. A rate that climbs with the size of the garrison is what
## turns "one more tower" into a decision instead of a formality.
@export var upkeep_step_towers: int = 8

## --- opening tower draft (PROVISIONAL, SPEC_GAPS.md #15) ----------------
## How many unlocked towers a run offers, and how many of them the player takes
## into it. Five of nine picking three gives ten possible hands at a full Keep
## Hub, and leaves two thirds of the roster out of any given run.
@export var tower_offer_size: int = 5
@export var tower_draft_picks: int = 3

## --- Ward Flare (PROVISIONAL, SPEC_GAPS.md #12) -------------------------
## The spec has no player ability: once towers are placed a wave plays itself
## out, and on a phone that is a lot of watching. Damage is multiplied by the
## §2.2 wave multiplier, exactly as enemy health is, so the flare stays worth
## the same at wave 40 as at wave 4 rather than fading into irrelevance.
@export var ability_cooldown: float = 24.0
@export var ability_radius_tiles: float = 1.6
@export var ability_base_damage: float = 30.0

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
##
## Sized against §2.2's scaling leak damage rather than picked round: at 20 a
## single wave-30 Ogre leak did 108% of the pool, so from roughly wave 22 the
## Ward Stone bar stopped meaning anything and one mistake ended the run. At
## 50, with the trimmed leak damages, an early leak costs a couple of percent
## and a late one about a third — forgiving to start, unforgiving to finish.
@export var ward_stone_hp: int = 50

## Feature Spec §4 names the element matchups ("strong vs", "weak vs") but
## gives no magnitudes. PROVISIONAL — see SPEC_GAPS.md #5.
@export var element_strong_multiplier: float = 1.25
@export var element_weak_multiplier: float = 0.75
