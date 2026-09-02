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

- Spritesheets that ship with an `.xml` (the Explosion Packs) are baked into
  `AtlasFrames` resources by `tools/gen_resources.gd`, so the shipped game
  never parses XML and the `.xml` files never need an export filter.
- Toen's sheet must stay on a **lossless** texture import. `Terrain` reads its
  pixels back to composite the lane tiles and the keep, and nothing can be
  read out of a VRAM-compressed image.
- Only the files actually copied here were trimmed from each pack — e.g.
  `Particle Pack` originally has ~10 effect categories; only magic/light,
  smoke, and star were pulled, matching the 3 VFX uses in Feature Spec.
  If a later feature needs another particle type, go back to the source pack
  rather than trying to repurpose what's here.


## Added after the original bundle

WARDKEEP's **board** is 16px pixel art (Toen's Medieval Strategy, plus the
Battlers for bosses); its **UI, VFX and audio** stay Kenney flat vector, which
is drawn near its native size and does not fight the board. Everything from
Kenney is CC0 with its `License.txt` kept in place; the two pixel packs are
CC-BY and credit-required respectively, so both carry a `LICENSE.txt` and both
are named in the credits below.

| res:// path | Pack | Used for |
|---|---|---|
| `assets/sprites/vfx/explosion_ground/` | Explosion Pack | Ward Stone impacts |
| `assets/sprites/vfx/explosion_regular/` | Explosion Pack | Boss deaths |
| `assets/sprites/vfx/explosion_sonic/` | Explosion Pack | Frostmaw's slow field |
| `assets/sprites/ui/fantasy_borders/` | Fantasy UI Borders | Draft card frames, tinted per rarity |

### The board

Everything standing on the board — grass, road, scenery, the Ward Stone,
towers and the whole enemy roster — is stamped from **one** sheet:

`assets/sprites/environment/toen_medieval_strategy/toen_medieval_strategy.png`
— Toen's Medieval Strategy Sprite Pack by Andre Mari Coppola, **CC-BY 4.0**
(see the folder's `LICENSE.txt`; attribution is required, unlike the CC0 packs
around it). 7 columns of 16px tiles, no margin, so a tile is `row * 7 + column`.

The board is 16px art on a 64px grid, so `WK.PIXEL_ZOOM` (4x) sizes every
sprite on it and `rendering/textures/canvas_textures/default_texture_filter`
is Nearest.

| use | tiles |
|---|---|
| grass | 1 flat, 3 tufted (0 and 2 are a slightly darker green and tile visibly against the road's own border — left out) |
| ground cover | 306, 307 (the leaf-litter tile 216 is a dark mound and sows as holes; left out) |
| scenery | pines 4-6, shrubs 13/27, boulders 10-12, rubble 238/239, puddles 18/19, campfire 40, crate 41, bones 35, sword 36, crystals 37-39 |
| Ward Stone | 53, 54, 60, 61 composited 2x2 into a walled keep |
| element banners | 44 Physical, 46 Frost, 45 Blight |

#### The lane

The pack has no road *fill* tiles. What it has is a nine-slice ring — a sand
band with grass outside and nothing in the middle — meant to be laid around an
area. WardKeep's lane is one tile wide, so almost every lane cell needs grass
on two opposite sides at once, which no single tile in the ring provides.

`Terrain.road()` therefore composites each lane tile out of four 8px
quadrants, choosing each quadrant from the two directions that touch it:

| | quadrant depends on | corner | along the band | across it |
|---|---|---|---|---|
| top-left | N, W | 175 | 176 | 182 |
| top-right | N, E | 177 | 176 | 184 |
| bottom-left | S, W | 189 | 190 | 182 |
| bottom-right | S, E | 191 | 190 | 184 |

A quadrant with both its directions open takes a flat fill in the band's
innermost colour. Sixteen tiles out of nine sources, and the seams are
invisible because every quadrant comes from the same ring.

#### Build tiles

Drawn, not stamped. The old cream pad tile put 34 bright squares on the field
at once and read as a checkerboard laid over the map; `TowerSlot._draw` puts
corner ticks over a barely-darkened square instead, and brightens them to a
lit pad (or a red one) only while a tower is armed.

#### The field bleeds past the board

A 12x20 board fitted by height into a portrait screen leaves a bar down each
side. `Terrain.BLEED_TILES` draws three more tiles of grass and scenery
outward on every side to fill them. Nothing out there is interactive.

### Enemy sprite to archetype

Armour type is matched to the silhouette, so a player can read a matchup
without memorising the table: shelled creatures are HEAVY, spectral ones
ETHEREAL.

The besieging host is Toen's **red** faction; the three ETHEREAL types are the
same soldiers drawn cold and half-transparent, and plate and siege engines
carry HEAVY.

| archetype | armour | tile |
|---|---|---|
| grunt | none | 252 levied villager |
| swarmling | none | 103 peasant |
| skirmisher | none | 119 archer |
| shieldbearer | heavy | 121 shielded knight |
| wraith | ethereal | 120 spearman, spectral |
| brute | heavy | 122 knight, mid-swing |
| hexer | none | 104 hooded hunter |
| revenant | ethereal | 128 knight, spectral |
| ironclad | heavy | 124 ballista |
| shade | ethereal | 112 archer, spectral |
| ogre | heavy | 123 catapult |
| warlord | none | 167 mounted rider |

### Tower sprite to archetype

Element is read off the planted banner rather than a full colour tint — a
strong modulate flattens pixel art's own palette.

| tower | element | tile |
|---|---|---|
| watchtower | physical | 22 stone tower |
| ballista | physical | 117 ballista |
| palisade_ram | physical | 116 catapult |
| rime_spire | frost | 25 blue-bannered tower |
| glacier_well | frost | 243 well |
| icicle_battery | frost | 124 ballista |
| rot_censer | blight | 40 brazier |
| plague_caster | blight | 24 green-bannered tower |
| bone_turret | blight | 35 bone pile |

### Packs supplied but not used

- **Tower Defense (sci-fi/modern)** — its terrain is the tilesheet already in
  use, so nothing to add. Its turrets, rockets, tanks and planes are wrong for
  a medieval keep defense and are deliberately unused.
- **The isometric bundle** (Medieval Town, Miniature Dungeon, Nature, Tower
  Defense, Vector Buildings) — WARDKEEP is a flat top-down 12x20 grid per
  Feature Spec §1. Adopting isometric would mean rebuilding the arena, path
  and placement maths.
- **Tiny Town** — 16px pixel art, superseded by Toen's.
- **Pack AH (16x16)** — real autotiles, but a four-tone Game Boy palette that
  sits beside nothing else here. No licence file in the archive either.
- **`gfx/` (Overworld, objects, character…)** — the richest terrain of the
  five, but the archive carries **no licence file at all**, so it cannot go
  into a commercial build on a guess.
- **Kenney Roguelike pack** — CC0 and complete, but flatter and more muted
  than Toen's; keeping two 16px sheets on one board would have cost the
  single-artist look that fixed the map.
- **Battlers `World04_*` (LaserDrone, ScoutMachine, Outlaw)** — sci-fi.
- **RTS Medieval, the Rune overlays, the Roguelike character and dungeon
  sheets, the Tower Defense tilesheet and the Kenney creature PNGs** — all
  replaced by Toen's and **deleted from the repo**, along with the Monster
  Builder boss composites. That is about 8 MB of art out of the APK.


### Bosses

The bosses are the one place the board leaves Toen's 16px sheet: a boss built
from the same soldier tiles as the wave it heads is just a bigger soldier.
They come from **JosephSeraph's Battlers** (`assets/sprites/enemies/battlers/`,
free to use and adapt with credit — see the folder's `LICENSE.txt`), drawn at
64-128px and shown at a smaller magnification than the rest of the board, so
they read as finer, more detailed creatures rather than as art from another
game.

| boss | sprite | shown at | tiles |
|---|---|---|---|
| The Bulwark | `World01_005_Shello` (64px) | 2.0x | 2x2 |
| Frostmaw | `Frostmaw_from_Salamander` (96x64) | 2.0x | 3x2 |
| The Hollow King | `World01_004_WailingPrince` (128px) | 1.5x | 3x3 |

Frostmaw is the pack's fire salamander with its warm hues rotated to glacier
blue and its saturation damped — an adaptation the Battlers licence allows.
The recolour maps every hue below 0.14 or above 0.92 to 0.55 at 0.72x
saturation and 1.06x value, and shifts every other hue by +0.42.

They were previously composites assembled from Kenney's Monster Builder kit by
a build script. Two problems: the kit is a modular googly-eye monster maker
and read as a cartoon toy rather than anything besieging a medieval keep, and
at 270px on a 64px grid each boss covered **four tiles square**. Both the
composites and the script that built them are gone.
