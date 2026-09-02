extends Node2D
class_name Tower
## Base class for every tower archetype (Claude Code Brief §4: one scene and
## one script per archetype, inheriting this — never a switch over ids).
##
## All tuning comes from the TowerDef resource; this class only implements the
## rules. Run-local draft effects are read from RunManager.modifiers on every
## shot, so a card taken mid-wave applies immediately (Feature Spec §5.3).

const PROJECTILE_TEXTURES: Dictionary = {
	WK.RuneElement.PHYSICAL: "res://assets/sprites/vfx/particle_magic_light/light_01.png",
	WK.RuneElement.FROST: "res://assets/sprites/vfx/particle_magic_light/magic_04.png",
	WK.RuneElement.BLIGHT: "res://assets/sprites/vfx/particle_smoke/smoke_04.png",
}
## An aura re-applies on this cadence rather than every frame.
const AURA_TICK: float = 0.5

## The element marker is a planted banner from the terrain pack, so the tower,
## the field it stands on and its rune all come from one artist.
const ELEMENT_BANNER: Dictionary = {
	WK.RuneElement.PHYSICAL: 44,
	WK.RuneElement.FROST: 46,
	WK.RuneElement.BLIGHT: 45,
}


@onready var _sprite: Sprite2D = $Sprite
@onready var _rune: Sprite2D = $Rune

var def: TowerDef = null
var tier_index: int = 0
var grid_cell: Vector2i = Vector2i.ZERO
var gold_spent: int = 0

var _cooldown: float = 0.0
var _aura_timer: float = 0.0
var _fire_rate_penalty: float = 0.0
var _penalty_remaining: float = 0.0
var _pending_hit_damage: float = 0.0

func setup(tower_def: TowerDef, cell: Vector2i) -> void:
	def = tower_def
	grid_cell = cell
	tier_index = 0
	gold_spent = tower_def.purchase_cost()
	_cooldown = 0.0
	_aura_timer = 0.0
	_fire_rate_penalty = 0.0
	_penalty_remaining = 0.0
	_apply_sprite()
	set_process(true)

func _apply_sprite() -> void:
	_sprite.texture = def.texture()
	var skin: String = SaveManager.equipped_skin(String(def.id))
	# Pixel art carries its own palette; a full element tint flattens it, so
	# the element is read off the banner below and the body is left alone.
	_sprite.modulate = WK.element_tint(def.rune_element).lerp(Color.WHITE, 0.72) \
		* UiKit.skin_modulate(skin)
	# Tier is read at a glance from the tower's footprint.
	_sprite.scale = Vector2.ONE * WK.PIXEL_ZOOM * (1.0 + 0.08 * float(tier_index))
	_rune.texture = _rune_texture()
	_rune.scale = Vector2.ONE * WK.PIXEL_ZOOM * 0.75
	_rune.modulate.a = 0.85 + 0.05 * float(tier_index)

func _rune_texture() -> Texture2D:
	return Terrain.tile(ELEMENT_BANNER.get(def.rune_element, 44))

func element() -> int:
	return int(def.rune_element)

func tier() -> TowerTierData:
	return def.tier(tier_index)

## --- effective stats (tier + run modifiers) -----------------------------

func _modifiers() -> RunModifiers:
	return RunManager.modifiers

func effective_damage() -> float:
	return tier().damage * _modifiers().damage_multiplier(def.rune_element)

func effective_range() -> float:
	return tier().range_tiles * _modifiers().range_mult * float(WK.TILE_SIZE)

func effective_fire_rate() -> float:
	var penalty: float = _fire_rate_penalty if _penalty_remaining > 0.0 else 0.0
	return tier().fire_rate * _modifiers().fire_rate_mult * (1.0 - penalty)

func effective_splash() -> float:
	var radius: float = tier().splash_radius
	if radius <= 0.0:
		return 0.0
	return (radius + _modifiers().splash_bonus) * float(WK.TILE_SIZE)

func effective_slow() -> float:
	return clampf(tier().slow_amount * _modifiers().slow_power_mult, 0.0, 0.9)

func effective_slow_duration() -> float:
	return tier().slow_duration * _modifiers().slow_power_mult

func effective_dot() -> float:
	return tier().dot_damage * _modifiers().dot_mult

## Feature Spec §2.5 — Frostmaw's field slows tower fire rate for a while.
func apply_fire_rate_penalty(amount: float, duration: float) -> void:
	_fire_rate_penalty = maxf(_fire_rate_penalty, amount)
	_penalty_remaining = maxf(_penalty_remaining, duration)

## --- upgrade / sell (Feature Spec §3, §4) -------------------------------

func can_upgrade() -> bool:
	return tier_index < def.max_tier_index()

func upgrade_cost() -> int:
	if not can_upgrade():
		return 0
	var base: int = def.tier(tier_index + 1).cost
	# The run's own discount and the Keep Hub perk are separate ledgers — each
	# is capped on its own, and the combined floor keeps an upgrade from ever
	# being free no matter how the two stack.
	var discount: float = clampf(_modifiers().upgrade_discount + Perks.upgrade_discount(), 0.0, 0.85)
	return maxi(1, int(round(float(base) * (1.0 - discount))))

func upgrade() -> bool:
	if not can_upgrade():
		return false
	var cost: int = upgrade_cost()
	if not RunManager.spend_gold(cost):
		return false
	gold_spent += cost
	tier_index += 1
	_apply_sprite()
	return true

## Feature Spec §3 — sell refunds 60% of everything spent on the tower.
func sell_value() -> int:
	var ratio: float = Balance.config().sell_refund_ratio + _modifiers().sell_refund_bonus
	return int(floor(float(gold_spent) * clampf(ratio, 0.0, 1.0)))

## --- firing -------------------------------------------------------------

func _process(delta: float) -> void:
	if _penalty_remaining > 0.0:
		_penalty_remaining -= delta
	if tier().is_aura:
		_process_aura(delta)
		return
	var rate: float = effective_fire_rate()
	if rate <= 0.0:
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var target: Enemy = acquire_target()
	if target == null:
		return
	_cooldown = 1.0 / rate
	fire_at(target)

## Standard tower-defence targeting: whichever enemy in range is furthest
## along the path, so leaks are prevented rather than merely averaged.
func acquire_target() -> Enemy:
	var arena: Node = Arena.current
	if arena == null:
		return null
	var best: Enemy = null
	var range_squared: float = effective_range() * effective_range()
	for enemy: Enemy in arena.active_enemies:
		# is_targetable rather than alive: a phased Shade is still walking and
		# still takes splash, but no tower may acquire it.
		if not enemy.is_targetable():
			continue
		if enemy.global_position.distance_squared_to(global_position) > range_squared:
			continue
		if best == null or enemy.path_progress > best.path_progress:
			best = enemy
	return best

func fire_at(target: Enemy) -> void:
	var arena: Node = Arena.current
	_pending_hit_damage = damage_against(target)
	if def.projectile_scene != null and arena != null:
		var projectile: Projectile = arena.spawn_projectile()
		if projectile != null:
			projectile.launch(self, target, WK.element_tint(def.rune_element), _projectile_texture())
			_muzzle_flash()
			return
	# Melee towers (and any shot with no projectile available) resolve now.
	on_projectile_hit(target, target.global_position)

func _projectile_texture() -> Texture2D:
	var path: String = PROJECTILE_TEXTURES.get(def.rune_element, "")
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

## Pipeline §2.4 — Frost/Blight muzzle flashes use the Particle Pack.
func _muzzle_flash() -> void:
	if def.rune_element == WK.RuneElement.PHYSICAL:
		return
	var arena: Node = Arena.current
	if arena != null:
		arena.play_vfx("muzzle_%d" % int(def.rune_element), global_position)

## Feature Spec §4 — conditional bonuses, then the element matchup, which
## Enemy.take_damage applies (or skips, for the armour-piercing Ballista).
func damage_against(target: Enemy) -> float:
	var amount: float = effective_damage()
	var tier_data: TowerTierData = tier()
	if tier_data.bonus_vs_slowed > 0.0 and target.is_slowed():
		amount *= 1.0 + tier_data.bonus_vs_slowed
	# "Frostbite" — every tower hits harder into a slowed target, which is what
	# makes a Frost line worth building behind rather than instead of damage.
	if _modifiers().slowed_damage_bonus > 0.0 and target.is_slowed():
		amount *= 1.0 + _modifiers().slowed_damage_bonus
	# "Executioner" — finishing blows land harder, so chip damage on a big
	# target is worth something instead of being outrun by the health bar.
	if _modifiers().execute_bonus > 0.0 and target.max_hp > 0.0 \
			and target.hp / target.max_hp <= RunModifiers.EXECUTE_THRESHOLD:
		amount *= 1.0 + _modifiers().execute_bonus
	if tier_data.bonus_vs_ethereal > 0.0 and target.def.armor_type == WK.ArmorType.ETHEREAL:
		amount *= 1.0 + tier_data.bonus_vs_ethereal
	return amount

func on_projectile_hit(target: Enemy, at_position: Vector2) -> void:
	var arena: Node = Arena.current
	var tier_data: TowerTierData = tier()
	var splash: float = effective_splash()
	var damage: float = _pending_hit_damage if _pending_hit_damage > 0.0 else effective_damage()

	if splash > 0.0 and arena != null:
		for enemy: Enemy in arena.enemies_in_radius(at_position, splash):
			_hit(enemy, damage_against(enemy), tier_data)
	elif is_instance_valid(target) and target.alive:
		_hit(target, damage, tier_data)

	if arena != null:
		arena.play_vfx("impact_%d" % int(def.rune_element), at_position)
	AudioBus.play_random_sfx(AudioBus.SFX_TOWER_HITS)

func _hit(enemy: Enemy, damage: float, tier_data: TowerTierData) -> void:
	if not enemy.alive:
		return
	var modifiers: RunModifiers = _modifiers()
	if effective_slow() > 0.0:
		enemy.apply_slow(effective_slow(), effective_slow_duration())
		# "Bitter Frost" — Frost slows also tick damage (Feature Spec §5.2).
		if modifiers.frost_slow_dps > 0.0 and def.rune_element == WK.RuneElement.FROST:
			enemy.apply_dot(modifiers.frost_slow_dps, effective_slow_duration())
	if effective_dot() > 0.0:
		enemy.apply_dot(effective_dot(), tier_data.dot_duration)
	if modifiers.universal_dps > 0.0:
		enemy.apply_dot(modifiers.universal_dps, 2.0)
	if damage > 0.0:
		enemy.take_damage(damage, def.rune_element, tier_data.ignores_armor_matchup)
	# Feature Spec §4.3 — Plague Caster spreads its DoT when a victim dies.
	# "Contagion" extends that to every tower that has any blight to spread.
	var spreads: bool = tier_data.spreads_dot_on_death or modifiers.dot_spreads_always
	if spreads and not enemy.alive and effective_dot() > 0.0:
		_spread_dot(enemy.global_position, tier_data)

func _spread_dot(at_position: Vector2, tier_data: TowerTierData) -> void:
	var arena: Node = Arena.current
	if arena == null:
		return
	var radius: float = maxf(effective_splash(), float(WK.TILE_SIZE))
	for enemy: Enemy in arena.enemies_in_radius(at_position, radius):
		enemy.apply_dot(effective_dot(), tier_data.dot_duration)

## --- auras (Glacier Well, Rot Censer) -----------------------------------

func _process_aura(delta: float) -> void:
	_aura_timer -= delta
	if _aura_timer > 0.0:
		return
	_aura_timer = AURA_TICK
	var arena: Node = Arena.current
	if arena == null:
		return
	var tier_data: TowerTierData = tier()
	var radius: float = maxf(effective_range(), effective_splash())
	for enemy: Enemy in arena.enemies_in_radius(global_position, radius):
		if effective_slow() > 0.0:
			# Field slows persist only while the enemy stays inside it.
			enemy.refresh_slow(effective_slow(), AURA_TICK * 1.5)
			if _modifiers().frost_slow_dps > 0.0 and def.rune_element == WK.RuneElement.FROST:
				enemy.apply_dot(_modifiers().frost_slow_dps, AURA_TICK * 1.5)
		if effective_dot() > 0.0:
			enemy.apply_dot(effective_dot(), tier_data.dot_duration)
		if effective_damage() > 0.0:
			enemy.take_damage(effective_damage() * AURA_TICK, def.rune_element, tier_data.ignores_armor_matchup)
