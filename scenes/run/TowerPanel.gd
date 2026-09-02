extends Control
## User Flow §3.3 — the panel a tap on a placed tower opens: current tier,
## upgrade cost, sell refund.

signal upgrade_pressed(tower: Tower)
signal sell_pressed(tower: Tower)

@onready var _title: Label = %Title
@onready var _stats: Label = %Stats
@onready var _upgrade_button: Button = %UpgradeButton
@onready var _sell_button: Button = %SellButton
@onready var _close_button: Button = %CloseButton

var _tower: Tower = null

func _ready() -> void:
	_upgrade_button.pressed.connect(func() -> void:
		if _tower != null:
			upgrade_pressed.emit(_tower))
	_sell_button.pressed.connect(func() -> void:
		if _tower != null:
			sell_pressed.emit(_tower))
	_close_button.pressed.connect(close)
	hide()

func open(tower: Tower) -> void:
	_tower = tower
	var tier: TowerTierData = tower.tier()
	_title.text = "%s  ·  Tier %d" % [tower.def.display_name, tower.tier_index + 1]
	var lines: Array[String] = []
	# What the element is for, derived from the matchup table rather than
	# written down, so it cannot drift from the numbers it describes.
	lines.append("%s — %s" % [WK.element_name(tower.def.rune_element),
		Balance.element_matchup_line(tower.def.rune_element)])
	if tier.is_aura:
		lines.append("Aura, radius %.1f tiles" % maxf(tier.range_tiles, tier.splash_radius))
	else:
		lines.append("%.1f damage · %.1f/s · %.1f tiles" % [
			tower.effective_damage(), tower.effective_fire_rate(), tier.range_tiles])
	if tier.slow_amount > 0.0:
		lines.append("Slow %d%%" % int(round(tower.effective_slow() * 100.0)))
	if tier.dot_damage > 0.0:
		lines.append("%.1f blight damage/s" % tower.effective_dot())
	if tier.splash_radius > 0.0:
		lines.append("Splash %.2f tiles" % (tier.splash_radius + RunManager.modifiers.splash_bonus))
	_stats.text = "\n".join(lines)

	if tower.can_upgrade():
		_upgrade_button.text = "Upgrade  ·  %dg" % tower.upgrade_cost()
		_upgrade_button.disabled = not RunManager.can_afford(tower.upgrade_cost())
	else:
		_upgrade_button.text = "Max tier"
		_upgrade_button.disabled = true
	_sell_button.text = "Sell  ·  +%dg" % tower.sell_value()
	show()

func close() -> void:
	_tower = null
	hide()
