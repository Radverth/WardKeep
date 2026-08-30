extends Resource
class_name TowerTierData
## One tier of a tower. Feature Spec §4: "tier stats are cumulative
## replacements, not additive bonuses" — every field here is the tower's
## absolute value at that tier, never a delta.

@export var cost: int = 0                    ## gold to buy (tier 1) or upgrade to
@export var damage: float = 0.0
@export var range_tiles: float = 3.0
@export var fire_rate: float = 1.0           ## shots per second; 0 = aura, never fires
@export var splash_radius: float = 0.0       ## tiles; 0 = single target

## Frost towers (Feature Spec §4.2).
@export var slow_amount: float = 0.0         ## 0.0-1.0 speed reduction
@export var slow_duration: float = 0.0       ## seconds; 0 with an aura = while inside
@export var is_aura: bool = false            ## always-on field rather than a shot

## Blight towers (Feature Spec §4.3).
@export var dot_damage: float = 0.0          ## damage per second
@export var dot_duration: float = 0.0        ## seconds the application lasts
@export var spreads_dot_on_death: bool = false

## Conditional bonuses named in the §4 tables.
@export var bonus_vs_slowed: float = 0.0     ## Icicle Battery: +50% => 0.5
@export var bonus_vs_ethereal: float = 0.0   ## Bone Turret: +100% => 1.0
@export var ignores_armor_matchup: bool = false  ## Ballista, "armour-piercing"
