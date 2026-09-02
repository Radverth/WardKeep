extends Node
## Headless smoke-test entry point. Run it as a scene so the autoloads come up
## exactly as they do in a real build:
##
##   godot --headless --fixed-fps 60 --path . res://tests/Playtest.tscn -- --waves 12
##
## Exits non-zero unless the run reaches the target wave.

const DEFAULT_TARGET: int = 12
## Fixed so CI runs the same waves every time. Override with --seed to sample
## the balance across different runs.
const DEFAULT_SEED: int = 20260902
## Must be run with --fixed-fps, which reports a constant delta and disables
## real-time synchronisation: frames then run flat out and the simulation is
## reproducible. Without it the run integrates over whatever delta the machine
## happened to produce, so a tower fires just before or just after an enemy
## moves depending on CI load — which made this test fail about half the time
## on a fixed seed, and looked like a balance problem rather than a timing one.

func _ready() -> void:
	var target: int = DEFAULT_TARGET
	var run_seed: int = DEFAULT_SEED
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in args.size():
		if args[index] == "--waves" and index + 1 < args.size():
			target = int(args[index + 1])
		elif args[index] == "--seed" and index + 1 < args.size():
			run_seed = int(args[index + 1])
	RunManager.seed_override = run_seed
	print("WARDKEEP playtest: seed ", run_seed)

	_furnish_keep()
	# Draft a roster the way Run Setup does, so the smoke test exercises the
	# opening draft rather than the no-draft fallback.
	GameState.ensure_tower_offer()
	GameState.pending_tower_ids = GameState.pending_tower_offer.slice(
		0, TowerDraft.picks_for(GameState.pending_tower_offer.size()))
	if Engine.max_fps != 0:
		push_warning("WARDKEEP playtest: run with --fixed-fps for a reproducible result.")
	var arena: Arena = (load("res://scenes/run/Arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	var player := AutoPlayer.new()
	player.target_wave = target
	player.arena = arena
	player.report_ready.connect(_on_report)
	add_child(player)
	print("WARDKEEP playtest: target wave ", target)

## Gives the bot the Keep Hub a player would actually have by the time they are
## pushing past wave 10 — every tower unlocked and the perks bought.
##
## Without it this ran on a fresh account, where the Ward Stone bleeds across
## waves 1-9 and arrives at the first boss on single digits: the run then either
## scraped through or died on wave 10, roughly a coin flip, which made a
## deliberately mediocre bot's luck the thing CI was measuring. It also means
## the test covers the perk maths and a full five-card tower draft rather than
## the three-unlock degenerate case.
func _furnish_keep() -> void:
	SaveManager.add_runestones(5000)
	for def: TowerDef in Registry.towers():
		SaveManager.unlock_tower(String(def.id))
	for perk: PerkDef in Registry.perks():
		for rank: int in perk.max_rank():
			SaveManager.buy_perk_rank(String(perk.id), perk.cost_for_next(rank))

func _on_report(report: Dictionary) -> void:
	print("--- playtest report ---")
	for key: String in report:
		print("  ", key, ": ", report[key])
	var ok: bool = String(report.get("reason", "")) == "target_reached"
	print("RESULT: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
