extends Control
## What a tap on an enemy opens. The element/armour matchup is the core system
## of the game and the only place it was ever explained was a balance table in
## a design document — a player could reach wave 30 without learning that Frost
## slides off Ethereal. This is where they find out.

@onready var _icon: TextureRect = %Icon
@onready var _title: Label = %Title
@onready var _matchup: Label = %Matchup
@onready var _notes: Label = %Notes
@onready var _close_button: Button = %CloseButton

func _ready() -> void:
	_close_button.pressed.connect(close)
	hide()

func open(def: EnemyDef) -> void:
	if def == null:
		return
	_icon.texture = def.texture()
	_icon.modulate = def.tint
	_title.text = "%s  ·  %s" % [def.display_name, WK.armor_name(def.armor_type)]
	_matchup.text = Balance.armor_matchup_line(def.armor_type)
	_notes.text = "\n".join(_notes_for(def))
	show()

## Says what the archetype does beyond walking, in the same words the behaviour
## is written in. Anything inert at its default contributes no line, so an
## archetype with no behaviour simply has none.
func _notes_for(def: EnemyDef) -> Array[String]:
	var lines: Array[String] = []
	if def.pack_size > 1:
		lines.append("Arrives %d at a time." % def.pack_size)
	if def.aura_damage_reduction > 0.0:
		lines.append("Shields nearby enemies against %d%% of incoming damage." % int(
			round(def.aura_damage_reduction * 100.0)))
	if def.aura_heal_per_second > 0.0:
		lines.append("Mends nearby enemies for %.0f health a second." % def.aura_heal_per_second)
	if def.aura_speed_bonus > 0.0:
		lines.append("Drives nearby enemies %d%% faster." % int(
			round(def.aura_speed_bonus * 100.0)))
	if def.phase_hidden_seconds > 0.0:
		lines.append("Slips out of reach for %.1fs at a time — towers cannot target it." %
			def.phase_hidden_seconds)
	if def.is_boss:
		lines.append("Besieges the Ward Stone instead of leaking through it.")
	return lines

func close() -> void:
	hide()
