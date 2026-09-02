# WARDKEEP — spec gaps

The Claude Code Brief §6 says: "If an implementation question comes up that
isn't answered by a value in that document, treat it as a spec bug to flag
rather than a judgment call to make silently."

These are the questions that came up. Each one is implemented with a
provisional value so the build is playable end to end, but **none of these
numbers came from a document in `/docs`** — they are placeholders waiting on a
decision. Every one of them lives in a `.tres` resource or a single named
constant, so changing them is a data edit, not a code change.

Sorted roughly by how much a wrong guess costs.

---

## 1. Ward Stone HP is never stated

**Where it bites:** Phase 1 cannot be built without it — the Ward Stone's
health pool is the entire fail condition.

**Searched:** Feature Spec §1 (arena), §2 (waves), §3 (economy); User Flow §2
and §3.3 (the HUD shows a "Ward Stone HP bar"); Technical Architecture §4.1
(RunManager "owns … Ward Stone HP"). Every document assumes the number
exists; none gives it.

**Provisional:** `50`, in `BalanceConfig.ward_stone_hp`
(`resources/balance/Balance.tres`).

Sized rather than guessed. Leak damage scales with the wave (§2.2) while the
pool does not, so the pool sets how long that scaling stays survivable. At the
original 20, one wave-30 Ogre leak cost 108% of a full bar — from about wave
22 the Ward Stone bar stopped meaning anything and a single mistake ended the
run outright. At 50, with the heaviest leak damages trimmed (see #3), one leak
costs:

| wave | grunt | ironclad | ogre |
|---|---|---|---|
| 1 | 2% | 6% | 8% |
| 20 | 5% | 16% | 22% |
| 30 | 7% | 22% | 29% |
| 40 | 9% | 27% | 36% |

Forgiving early, roughly three or four leaks from a loss late.
`tests/test_balance_shape.gd` asserts no enemy can take half a full pool in
one leak.

**Also unstated:** whether the pool ever regenerates between waves. Implemented
as: it does not, except via the "Masonry" draft card.

---

## 2. Tier 2 and tier 3 give costs but no stats

**Where it bites:** Feature Spec §4 fully specifies tier 1 for all nine
towers (cost / damage / range / rate) and then gives only "Tier 2 cost" and
"Tier 3 cost". Since §4 states that tiers are "cumulative replacements, not
additive bonuses", the missing values are the whole upgrade curve.

**Provisional progression rule**, applied uniformly in
`tools/gen_resources.gd` and baked into every `resources/towers/*.tres`:

| Stat | Tier 1 | Tier 2 | Tier 3 |
|---|---|---|---|
| damage (and DoT damage) | table value | ×2.5 | ×6 |
| range | table value | +0.5 tiles | +1.0 tiles |
| fire rate | table value | ×1.15 | ×1.32 |
| splash radius | table value | +0.25 tiles | +0.5 tiles |
| slow amount | table value | +5pp | +10pp |
| slow duration | table value | +1s | +2s |
| conditional bonuses (vs slowed / vs ethereal) | table value | unchanged | unchanged |

Costs are the spec's, untouched. The rule is deliberately uniform so it is
easy to replace one tower at a time once real numbers exist.

The damage multipliers are not arbitrary. The spec fixes the costs, so the
multipliers decide whether upgrading is ever worth doing. At the original
×2/×4 a Watchtower returned **0.280** damage-per-second per gold at tier 1 and
only **0.234** and **0.257** at tiers 2 and 3 — upgrading was strictly worse
than buying another tower while any build tile was free, which made two thirds
of the roster dead content and made *space* the binding constraint. Feature
Spec §1 explicitly wants the opposite: "more than enough for the full tower
roster at once so the constraint is gold, not space". At ×2.5/×6 the figures
are **0.280 / 0.293 / 0.386**, so a line of towers comes first and gold then
goes into height. `tests/test_balance_shape.gd` asserts this holds for every
damage-dealing tower.

---

## 3. There is no enemy table anywhere in the suite

**Where it bites:** Phase 3's acceptance criterion is "all 12 enemy
archetypes", and Phase 1's is a working "Grunt" — but no document lists them.

**Searched:** Feature Spec §2.3 says elite waves upgrade "one random non-boss
enemy archetype … (see §4 table)", and Pipeline §2.3 says the Roguelike
Characters pack covers "Standard + Elite enemy archetypes (§4 of Feature
Spec)". **Feature Spec §4 is the tower roster.** MAPPING.md notices the same
thing and annotates it "Feature Spec §4 enemy table — not the tower table",
which confirms an enemy table was intended and is missing. §2.1 also requires
a per-archetype **budget cost** and **unlock wave** to spend `enemy_budget`
against; neither exists for any enemy.

**Provisional:** twelve archetypes in `resources/enemies/*.tres`, every one
flagged `provisional = true`. Only the count (12), the three armour types the
§4 matchups need, and the name "Grunt" (from the Brief) come from the
documents. HP/speed/damage/cost/unlock-wave are all invented.

The **art** is no longer placeholder — each archetype now has a matching
creature sprite, with armour type matched to the silhouette (see MAPPING.md).
The **numbers** below are still guesses:

| id | armour | HP | speed | leak dmg | budget cost | unlock wave |
|---|---|---|---|---|---|---|
| grunt | none | 12 | 1.6 | 1 | 4 | 1 |
| swarmling | none | 6 | 2.4 | 1 | 3 | 1 |
| skirmisher | none | 18 | 1.9 | 1 | 6 | 3 |
| shieldbearer | heavy | 34 | 1.1 | 2 | 10 | 5 |
| wraith | ethereal | 20 | 1.8 | 2 | 9 | 7 |
| brute | heavy | 55 | 0.9 | 2 | 15 | 9 |
| hexer | none | 26 | 1.5 | 2 | 11 | 11 |
| revenant | ethereal | 44 | 1.4 | 3 | 16 | 13 |
| ironclad | heavy | 90 | 0.8 | 3 | 24 | 16 |
| shade | ethereal | 30 | 2.6 | 2 | 18 | 19 |
| ogre | heavy | 140 | 0.7 | 4 | 34 | 22 |
| warlord | none | 110 | 1.3 | 3 | 30 | 25 |

Speeds are in tiles/second. Note that §2.2 fixes speed per archetype forever,
so these particular numbers set the game's readability ceiling.

The leak-damage column was compressed (ogre 6→4, ironclad 4→3, warlord 5→3,
brute 3→2) as part of sizing the Ward Stone pool in #1 — the top of the
original range was what made a late leak lethal outright.

---

## 4. Boss stat lines and pattern timings

**Where it bites:** Feature Spec §2.5 names the three bosses, their armour
types and their behaviour in prose, but gives no HP, speed, damage or timing
for any of them.

**Provisional** (`resources/enemies/{the_bulwark,frostmaw,the_hollow_king}.tres`
and the three `BossPattern` scripts):

| boss | HP | speed | dmg per blow | pattern timing |
|---|---|---|---|---|
| The Bulwark | 450 | 0.5 | 5 | summons 2 Grunts every 7s |
| Frostmaw | 700 | 0.7 | 6 | every 8s, −40% fire rate for 4s within 3 tiles |
| The Hollow King | 1000 | 0.9 | 6 | splits once at 50% into 2 copies at half max HP |

Damage is **per blow, not per arrival**. §2.5 says a boss that reaches the
Ward Stone makes "slow single-target melee hits" on it, so a boss does not leak
through and vanish — it stops at the stone and keeps swinging until it is
killed. It stays targetable throughout, so arriving is a crisis rather than an
automatic loss, and User Flow §4's "a boss wave cannot end while the boss
lives" falls out of it naturally.

The blow interval is **2.0s** (`Boss.SIEGE_INTERVAL`) — the spec says "slow"
without giving a number. Against the 50-point pool that gives:

| boss | at wave | per blow | blows to fell a full Ward Stone |
|---|---|---|---|
| The Bulwark | 10 | 9.1 (18%) | 5.5, about 11s |
| Frostmaw | 20 | 16.3 (33%) | 3.1, about 6s |
| The Hollow King | 30 | 21.7 (43%) | 2.3, about 5s |

`tests/test_balance_shape.gd` asserts no single blow can take half a full pool,
so there is always a window to kill the boss.

§2.2's global multiplier applies on top, so wave 10's Bulwark is ~814
effective HP and wave 40's is ~1,880.

Specifically unstated and invented: the Bulwark's summon interval
("periodically"); the blow interval for all three ("slow"); Frostmaw's field
radius, penalty size and duration; and whether the Hollow King's original dies
on splitting (implemented: it does, consumed into the two copies).

---

## 5. Element matchup magnitudes

**Where it bites:** Feature Spec §4 says Frost is "strong vs HEAVY" and "weak
vs ETHEREAL", and Blight is "strong vs ETHEREAL" — with no numbers.

**Provisional:** strong = ×1.25, weak = ×0.75, in
`BalanceConfig.element_strong_multiplier` / `element_weak_multiplier`.

Related and unstated: what "armour-piercing" means for the Ballista (§4.1).
Implemented as: its shots skip the matchup multiplier entirely, so it is never
penalised and never rewarded by armour type.

---

## 6. The draft pool has three examples, not a pool

**Where it bites:** Feature Spec §5.2 fixes the rarity weights (60/30/10) and
the border colours, and gives one example effect per rarity. §5.1 requires
drawing from "the pool of upgrade effects" — which is never enumerated.

**Provisional:** 19 cards in `resources/draft/`, including all three of the
spec's examples. Max ranks are also invented: Common ×3, Rare ×2, Epic ×1.

§5.1's "not already at max rank **for the player's current towers**" is
ambiguous; implemented as: element-scoped cards are only offered once the
player has a tower of that element on the board.

---

## 7. "Weighted by their unlock wave" is not a function

**Where it bites:** Feature Spec §2.1 says the budget is spent on archetypes
"weighted by their unlock wave" without saying how.

**Provisional:** weight = the archetype's unlock wave, so the mix drifts
toward heavier archetypes as a run goes on (`WaveDirector._weighted_pick`).
An equally valid reading — weighting *down* by unlock wave, keeping fodder
dominant — produces a very different game.

---

## 8. Boss waves and the wave budget

**Where it bites:** §2.1 gives every wave an `enemy_budget` with no boss
exception, while §2.5 describes boss waves as single encounters.

**Implemented as:** a boss wave spawns the boss **and** spends the wave's full
budget on escorts. The reasoning: §2.3 explicitly carves boss waves out of the
*elite* rule, which shows the spec carves out boss waves when it means to, and
it does not do so for §2.1. Worth confirming — the alternative (boss alone)
makes waves 10/20/30 dramatically easier.

---

## 9. Smaller unstated items

- **Rot Censer's fire rate** is "n/a" in §4.3. Implemented as an aura that
  re-applies every 0.5s.
- **Targeting priority** is never specified. Implemented as "furthest along
  the path", the tower-defence default.
- **Interstitial cap** (Pipeline §4) is "once every 3 run-ends"; whether a
  Bank & Retreat counts as a run-end is unstated. Implemented as: it does.
- **Rewarded revive** (Brief Phase 7, "one revive per run") does not say how
  much Ward Stone HP a revive restores. Implemented as 50% of maximum.
- **Cosmetic skin ids** (§6.4) are not named; implemented as
  `<tower_id>_<default|veteran|legendary>`.
- **Legendary skins** are "IAP bundle only … or 800 Runestones" (§6.4) — the
  "or" makes the IAP path redundant. Implemented as: purchasable for 800
  Runestones, with no separate IAP bundle wired up.

---

## 10. The Keep Hub has nothing to sell a returning player

**Where it bites:** Feature Spec §6 sells tower unlocks (§6.2) and cosmetic
skins (§6.4) and nothing else. Nine towers cost 150-300 Runestones each, so a
player who keeps going runs out of unlocks and is left with skins — a meta
currency that stops mattering exactly when someone has proved they intend to
keep playing, in a game §2.4 says has "no designed ceiling".

**Implemented:** six permanent ranked perks, in a fourth Keep Hub tab
(`resources/perks/`, `PerkDef`, `Perks`). Starting gold, Ward Stone capacity,
gold per kill, upgrade discount, a repair after each wave cleared, and a
better tithe. Costs are sized against §6's own scale — a full board is a little
over 2000 against 800 for the Legendary skin.

Deliberately small: a meta upgrade that visibly wins a run turns the early
waves into a formality for a returning player and a wall for a new one, and
the game has no difficulty setting to absorb that. `tests/test_perks.gd` holds
the whole board to three quarters of starting gold and half the Ward Stone.

## 11. Fourteen of the nineteen draft cards are flat multipliers

**Where it bites:** §5.2's pool is mostly "+10% damage" and its kin, so a draft
is a pickup — take the biggest number — rather than the decision §5 describes.

**Implemented:** eight more cards. Four change how a run plays (Executioner,
Frostbite, Contagion, Blood Price) and four carry a price (Hair Trigger, Long
Watch, Scorched Earth, Press-Gang). `DraftCardDef` gained an optional cost
effect, dispatched through the same path as the boon, so a price is only ever
an effect with a negative magnitude.

## 12. The player has nothing to do during a wave

**Where it bites:** no document gives the player an in-wave action. Once towers
are placed a wave resolves itself, which on a phone is several minutes of
watching per run, and there is no skill expression between drafts.

**Implemented:** Ward Flare — a tapped burst of damage on a 24s cooldown
(`BalanceConfig.ability_*`). Its damage is multiplied by the §2.2 wave
multiplier, exactly as enemy health is, so it is worth the same at wave 40 as
at wave 4. Sized to clear the fodder it lands on without deleting an Ogre.

## 13. Five enemy archetypes had no behaviour

**Where it bites:** an extension of #3. With no enemy table, the twelve
archetypes differed only in armour type, health and speed, so the roster read
as one enemy at twelve sizes.

**Implemented:** Swarmling arrives as a pack, Shieldbearer wards, Hexer mends,
Shade phases out of reach, Warlord hastes. Every value is on `EnemyDef` and
inert at its default. Frostmaw keeps sole ownership of tower fire-rate
suppression (§2.5), so none of them touch towers.

## 14. One map for an endless game

**Where it bites:** §1 fixes a single map for v1.0 and says so deliberately.
That is a scope decision rather than an omission, but it leaves an endless
roguelite with one source of run-to-run variation.

**Implemented:** four alternate boards beside §1's own, cut to the same rules —
12x20, one-tile lane, 34 build tiles, comparable lane length — and picked at
Run Setup. The Daily derives its board from the date's seed, since §7 wants
every player on the same run. The Old Road remains the default and the board
the balance was measured against.

---

## Deviations from the documents that are not gaps

- **GUT** (Technical Architecture §7) is not vendored — it is a third-party
  addon and this build environment cannot fetch it. `res://tests/` uses the
  same `test_*` convention and the same assertion names behind a small local
  base class (`WardKeepTest`), so adopting GUT later means changing
  `extends WardKeepTest` to `extends GutTest` and deleting one file.
- **`res://scripts/`** is not in the Technical Architecture §2 tree. It holds
  stateless helpers that are not autoloads and not resources (`Balance`, `WK`,
  `Registry`, `SpriteAtlas`, `DraftPool`, `RunModifiers`).
- **`res://tools/`** likewise: build-time scripts that never ship in a build.
