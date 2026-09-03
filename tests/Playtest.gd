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
	var strategy: AutoPlayer.Strategy = AutoPlayer.Strategy.MEASURED
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in args.size():
		if args[index] == "--waves" and index + 1 < args.size():
			target = int(args[index + 1])
		elif args[index] == "--seed" and index + 1 < args.size():
			run_seed = int(args[index + 1])
		elif args[index] == "--greedy":
			strategy = AutoPlayer.Strategy.GREEDY
	RunManager.seed_override = run_seed
	print("WARDKEEP playtest: seed ", run_seed)

	_furnish_keep()
	# Draft a roster the way Run Setup does, so the smoke test exercises the
	# opening draft rather than the no-draft fallback.
	GameState.ensure_tower_offer()
	GameState.pending_tower_ids = _draft_hand()
	if Engine.max_fps != 0:
		push_warning("WARDKEEP playtest: run with --fixed-fps for a reproducible result.")
	var arena: Arena = (load("res://scenes/run/Arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	var player := AutoPlayer.new()
	player.target_wave = target
	player.strategy = strategy
	player.arena = arena
	player.report_ready.connect(_on_report)
	add_child(player)
	print("WARDKEEP playtest: target wave %d, strategy %s" % [
		target, "greedy" if strategy == AutoPlayer.Strategy.GREEDY else "measured"])

## Takes damage towers first, the way a player reads the offer. Slicing the
## offer as it came took whichever three sorted first by name, so the bot could
## walk into wave 10 holding two slow fields — a hand no player would pick, and
## a run the harness then reported as a balance failure.
func _draft_hand() -> Array[StringName]:
	var offer: Array[StringName] = GameState.pending_tower_offer
	var wanted: int = TowerDraft.picks_for(offer.size())
	var hand: Array[StringName] = []
	for want_damage: bool in [true, false]:
		for id: StringName in offer:
			var def: TowerDef = Registry.tower(id)
			if hand.size() < wanted and def != null and def.deals_damage() == want_damage \
					and not hand.has(id):
				hand.append(id)
	return hand

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
	# From a clean ledger every time. The save file outlives the process, so
	# without this each run inherits the last one's Keep and the numbers drift
	# upward run over run — which quietly turned a balance measurement into a
	# record of how many times the test had been run.
	SaveManager.reset()
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
