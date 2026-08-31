# WARDKEEP

Endless roguelite tower defense for Android. Godot 4.3, GDScript, portrait
768×1280.

Built from the seven-document spec suite in [`docs/`](docs/). Where those
documents disagree, the precedence is the one they set themselves: Feature
Spec wins on mechanics and numbers, Technical Architecture on structure and
data model, Claude Code Brief on build order.

**Read [`SPEC_GAPS.md`](SPEC_GAPS.md) before tuning anything.** Nine things the
suite leaves undefined — Ward Stone HP, the entire enemy table, tier 2/3
stats, boss stat lines — are running on provisional values. They are all
isolated in `.tres` resources so replacing them is a data edit.

## Running it

```bash
godot --headless --path . --import          # first time, builds the import cache
godot --path . res://scenes/boot/Boot.tscn  # or just open the project and press F5
```

## Tests

```bash
godot --headless --path . res://tests/Tests.tscn                 # unit suites
godot --headless --path . res://tests/Playtest.tscn -- --waves 12  # headless smoke run
```

The unit suites cover the Feature Spec formulas verbatim (wave budgets, stat
scaling, gold, Runestone bank rates, XP thresholds, element matchups), the
save schema and its migration path, seeded draft and wave reproducibility for
the Daily Challenge, and a content audit that fails if any tower or enemy id
loses its resource or scene.

The playtest boots a real Arena, drives it with `AutoPlayer` and fails unless
the run reaches the target wave — the fastest way to catch a regression that
only shows up once enemies are actually walking. It runs the wave-10 Bulwark
fight on the default target.

## Layout

| Path | What |
|---|---|
| `autoload/` | The six singletons from Technical Architecture §4 |
| `scripts/` | Stateless helpers — `Balance` (every spec formula), `WK` (enums), `Registry`, `SpriteAtlas`, `DraftPool`, `RunModifiers` |
| `resources/defs/` | Resource *scripts* — the shape of a TowerDef, EnemyDef, WaveTable… |
| `resources/` | Generated `.tres` **data** — towers, enemies, waves, draft cards, balance, arena |
| `scenes/` | Boot, menus, the Arena, and one scene+script per tower and enemy |
| `tools/` | Build-time generators (never shipped) |
| `tests/` | Unit suites, the runner, and the headless playtest |
| `assets/` | Trimmed art/audio, arranged exactly as `MAPPING.md` describes |

## Data, not code

Per Claude Code Brief §4, no gameplay tuning number lives in a `.gd` file.
Every one is in a `.tres`, and those are generated from the spec tables by:

```bash
godot --headless --path . --script res://tools/gen_resources.gd
```

Editing a number means editing the table in `tools/gen_resources.gd` and
re-running that — the generator is the transcription of the Feature Spec, and
re-running it is how a balance change lands. It also bakes each pack's
spritesheet `.xml` into an `AtlasFrames` resource, so the shipped game never
parses XML at runtime.

The three boss composites are likewise built once, not assembled at runtime
(per `MAPPING.md`):

```bash
godot --headless --path . --script res://tools/build_boss_composites.gd
```

## Build phases

Built in the order the Claude Code Brief §3 sets out. Phase status:

| Phase | State |
|---|---|
| 0 — Skeleton | Done — Boot → Main Menu → Run Setup → Arena → Run Summary, save schema live |
| 1 — Core combat | Done — path following, targeting, projectiles, splash, DoT, slows, Ward Stone leaks |
| 2 — Wave system | Done — `WaveDirector` off `WaveTable.tres`, gold economy, 3-card draft |
| 3 — Full roster | Done — 9 towers × 3 tiers, 12 enemies, all three element matchups |
| 4 — Bosses & elites | Done — elite modifier, three boss patterns, cycling past wave 40 |
| 5 — Meta-progression | Done — Keep Hub tabs, unlocks, skins, XP/levels, persistence |
| 6 — Daily & retention | Done — date-seeded runs, streak, best-wave celebration, medals |
| 7 — Monetization | Scaffolded — `AdsManager` with the full call surface; **no AdMob plugin is vendored**, so every ad path degrades to "no fill". Wiring the plugin is an Android export step, not a code change here |
| 8 — Polish & store | Partial — audio wired, CI in place. **Store listing assets are not generated**: the Brief requires screenshots from real gameplay captures, which needs a device or emulator run |

## CI

`.github/workflows/android-build.yml` builds a debug APK on every push to
`main` and attaches it to a pre-release, then waits on the `play-release`
environment's approval before building the signed AAB. One-time setup —
environment, secrets, keystore — is in [`CI_SETUP.md`](CI_SETUP.md).

`version/code` in `export_presets.cfg` must be bumped by hand before any build
intended for Play Console. There are two presets: `Android` (the release
`.aab`) and `Android Test` (the sideloadable `.apk`); keep the version and
package fields in sync across both.

### Art direction

The arena floor and the enemies are **16px pixel art** (Tiny Town and
Roguelike Characters), drawn at whole-number scales onto the 64px grid. The
towers are still RTS Medieval, which is flat vector — small enough on screen
to pass, but it is a genuine style mix and worth deciding on before adding
more tower art. See `MAPPING.md`.

Android requires ETC2/ASTC-compressed textures, so `project.godot` sets
`rendering/textures/vram_compression/import_etc2_astc=true`. Do not remove it:
without it the export fails validation on any host that does not itself prefer
that texture format, and Godot 4.3 reports that particular failure with an
empty error message.
