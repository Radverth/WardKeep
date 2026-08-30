# WARDKEEP Asset Mapping

This zip contains only the asset subset WARDKEEP actually uses, already trimmed
from the full source pack and arranged to match the `res://assets/` folder
structure described in Technical Architecture §2 and Pipeline/Integration Spec §2.

To use: unzip this into your Godot project root so the top-level `assets/`
folder here becomes `res://assets/` in the project. No further reorganizing
should be needed — the folder names below ARE the intended `res://` paths.

Each folder below also contains the original pack's `License.txt` where one
existed, carried over verbatim. Confirm license terms before shipping (see
Pipeline/Integration Spec §6) — this manifest doesn't replace reading them.

| res:// path | Source pack | Used for | Spec reference |
|---|---|---|---|
| `assets/sprites/environment/tower_defense_tilesheet/` | Tower Defense (Tilesheet) | Path tiles, build-tile highlight overlay | Feature Spec §1; Pipeline §2.1 |
| `assets/sprites/environment/roguelike_dungeon/` | Roguelike Dungeon Pack (Spritesheet) | Floor texture variation, decorative props | Feature Spec §1; Pipeline §2.1 |
| `assets/sprites/towers/rts_medieval_base/` | RTS Medieval (Spritesheet) | Base tower structures — shared across all 3 rune elements | Feature Spec §4; Pipeline §2.2 |
| `assets/sprites/towers/rune_overlays/grey/` | Rune Pack — Grey | Physical-element tint overlay + Default cosmetic tier | Feature Spec §4.1, §6.4; Pipeline §2.2 |
| `assets/sprites/towers/rune_overlays/blue/` | Rune Pack — Blue | Frost-element tint overlay + Default cosmetic tier | Feature Spec §4.2, §6.4; Pipeline §2.2 |
| `assets/sprites/towers/rune_overlays/black/` | Rune Pack — Black | Blight-element tint overlay + Default cosmetic tier | Feature Spec §4.3, §6.4; Pipeline §2.2 |
| `assets/sprites/enemies/roguelike_characters/` | Roguelike Characters Pack (Spritesheet) | Standard + Elite enemy archetypes (Feature Spec §4 enemy table — not the tower table) | Feature Spec §2.3; Pipeline §2.3 |
| `assets/sprites/enemies/monster_builder_bosses/` | Monster Builder Pack (Spritesheet + PNG/Default parts) | Boss composite sprites: The Bulwark, Frostmaw, The Hollow King — build each boss once as a static composite at import time, don't runtime-assemble | Feature Spec §2.5; Pipeline §2.3 |
| `assets/sprites/vfx/explosion_pixel/` | Explosion Pack — pixelExplosion spritesheet | Physical tower hits, standard enemy death | Pipeline §2.4 |
| `assets/sprites/vfx/explosion_simple/` | Explosion Pack — simpleExplosion spritesheet | Boss death, Ward-Stone-hit shake accompaniment | Pipeline §2.4 |
| `assets/sprites/vfx/particle_magic_light/` | Particle Pack — magic_*, light_* | Frost/Blight tower muzzle flashes | Pipeline §2.4 |
| `assets/sprites/vfx/particle_smoke/` | Particle Pack — smoke_* | Blight DoT lingering effect | Pipeline §2.4 |
| `assets/sprites/vfx/particle_star/` | Particle Pack — star_* | Best-wave-ever celebration burst | Feature Spec §8; Pipeline §2.4 |
| `assets/sprites/ui/adventure_pack/` | UI Pack – Adventure (PNG, Default + Double) | All buttons, panels, progress bars, HUD chrome | User Flow §3; Pipeline §2.5 |
| `assets/sprites/ui/medals/` | Medals (PNG) | Rank-milestone badges (levels 5/10/15/20/25/30) | Feature Spec §8; Pipeline §2.5 |
| `assets/sprites/ui/ranks/` | Ranks Pack (Tilesheet) | Account-level rank icon + source palette for Veteran/Legendary skin recolors | Feature Spec §6.4; Pipeline §2.5 |
| `assets/sprites/ui/input_prompts_touch/` | Input Prompts — Touch | First-run onboarding tooltip icons | User Flow §4; Pipeline §2.5 |
| `assets/audio/music/Infinite Descent.ogg` | Music Loops | Main gameplay loop track | Pipeline §2.6 |
| `assets/audio/music/Mission Plausible.ogg` | Music Loops | Boss-wave alternate track | Pipeline §2.6 |
| `assets/audio/music/Serious ident.ogg` | Music Loops (Idents) | Main Menu stinger | Pipeline §2.6 |
| `assets/audio/sfx_impact/` | Impact Sounds — impactMetal_*, impactBell_heavy_* | Physical tower hits, Ward Stone damage cue | Pipeline §2.6 |
| `assets/audio/sfx_ui/` | UI Audio — click2.ogg, switch1.ogg | Button press, draft-card select | Pipeline §2.6 |
| `assets/fonts/` | Kenney fonts (Mini + Bold) | All UI text — pick one at Phase 0, don't mix without a reason | Pipeline §2.7 |

## Notes for import (see Pipeline/Integration Spec §3 for full detail)

- Spritesheets that ship with an `.xml` (RTS Medieval, Explosion Pack, Rune
  Pack has none but the others do where present) should be imported as
  AtlasTexture sets driven by that XML, not re-sliced by hand.
- `rune_overlays/{grey,blue,black}` are meant to be layered on top of
  `rts_medieval_base` sprites (tint/overlay), not swapped in as full
  replacements — see Feature Spec §4 for which tower uses which element.
- `monster_builder_bosses/` includes both the pre-built spritesheet and the
  raw modular PNG parts from `PNG/Default/`. Use whichever gets you to the
  three boss composites in Feature Spec §2.5 fastest; the raw parts are there
  in case the pre-built spritesheet doesn't include a needed limb/pose.
- Only the files actually copied here were trimmed from each pack — e.g.
  `Particle Pack` originally has ~10 effect categories; only magic/light,
  smoke, and star were pulled, matching the 3 VFX uses in Feature Spec.
  If a later feature needs another particle type, go back to the source pack
  rather than trying to repurpose what's here.
