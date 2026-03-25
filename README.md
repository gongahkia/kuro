# Kuro

Kuro is a Love2D/Lua first-person survival-horror game built around light pressure, sanity collapse, procedural descent, and anchor-lighting boss objectives.

## Requirements

- Love 11.x for the playable build
- Lua 5.5+ for headless tests

## Run

```console
make run
```

If `love` is not installed locally, `make run` prints the expected command instead of failing silently.

## Test

```console
make test
```

## Controls

- `Enter`: confirm title, menus, and replays
- `Up`, `Down`: move through title and replay menus
- `Left`, `Right`: adjust title options
- `Enter` on `Practice Target`: open the practice target browser
- `N`: roll a new seed, or advance the selected Sprint seed
- `Z`, `X`, `C`: toggle `Embers`, `Echoes`, `Onslaught` on the title screen
- `B`, `I`: toggle unlocked `Blacklight` and `Ironman` mutators on the title screen
- `W`, `S`: move forward and backward
- `A`, `D`: strafe left and right
- `Left`/`Right` or `K`/`L`: turn camera
- `E`: interact
- `Space`: jump
- `F`: emit light
- `Shift`: charge burst
- `G`: throw flare
- `1`, `2`, `3`: use consumables from the belt
- `Tab`: toggle automap
- `Esc`: pause, resume, or back out of menus
- Hold `R`: restart the current run from active play
- `V` or `S`: save a replay from pause or result screens
- `R`: retry after death or victory
- `P`: open progression from the result screen
- `V`: open replay browser from the result screen
- `1`, `2`, `3` on the result screen: jump into Sprint floor practice
- `D` on the Sprint result screen: open the practice target browser
- `G` on the Sprint result screen: play the current PB replay

## Modes

- `Classic`: standard seeded descent with selectable loadout, flame color, and mutators
- `Daily Challenge`: fixed date-seeded `stalker` run with a locked daily profile
- `Time Attack`: seeded descent with escalating pressure every 30 seconds
- `Sprint Official`: curated race seed packs, split timing, medals, PB records, ghost comparison, and exported local finish summaries
- `Sprint Practice`: the same authored route surfaces with floor starts, drill starts, optional auto-restart, and no PB/medal recording

## Systems

- `Sanity`: the only non-HP pressure track; low sanity distorts vision, weakens automap clarity, and reduces light recovery
- `Consumable belt`: `Calming Tonic`, `Speed Tonic`, and `Ward Charge` live in 3 quick-use slots
- `Sprint`: three official seed packs, authored minimum-torch lines, dark lanes, flare checkpoints, burn gates, soft pillar-route guidance, gold splits, projected finish readouts, PB ghosts, floor practice, and drill practice
- `Progression`: unlocks opt-in mutators, the `Scout` loadout, and cosmetic flame colors
- `Replays`: record runs, save them locally, auto-save every official Sprint finish plus Sprint PB mirrors, export paired text and JSON official summaries, and replay them from the title screen
- `Speed tech`: `Burn Dash` converts charged burst releases into movement, and `Flare Boost` rewards routing through freshly thrown flares on authored route lines

## Asset Packs

- [Pixel Texture Pack](https://jestan.itch.io/pixel-texture-pack) by Jestan — wall and floor textures
- [Skeletons Pack](https://monopixelart.itch.io/skeletons-pack) by MonoPixelArt — skeleton enemy sprites
- [Forest Monsters](https://monopixelart.itch.io/forest-monsters-pixel-art) by MonoPixelArt — mushroom enemy sprites
- [Flying Forest Enemies](https://monopixelart.itch.io/flying-enemies) by MonoPixelArt — flying enemy and boss sprites
- [Crafting Materials](https://beast-pixels.itch.io/crafting-materials) by Beast Pixels — item resource sprites
- [Pixel Mart](https://ghostpixxells.itch.io/pixel-mart) by GhostPixxells — mart item sprites
- [Pixel Art Vending Machines](https://karsiori.itch.io/pixel-art-vending-machines) by Karsiori — vending machine sprites
- [Sci-Fi Lab Pick-Ups](https://foozlecc.itch.io/sci-fi-lab-pick-ups) by Foozle — pickup item sprites

## Structure

- [`docs/mechanics.md`](/Users/gongahkia/Desktop/coding/projects/kuro/docs/mechanics.md): legacy mechanic reference
- [`main.lua`](/Users/gongahkia/Desktop/coding/projects/kuro/main.lua): Love entrypoint
- [`src/app.lua`](/Users/gongahkia/Desktop/coding/projects/kuro/src/app.lua): app state and screen flow
- [`src/game/run.lua`](/Users/gongahkia/Desktop/coding/projects/kuro/src/game/run.lua): run orchestration
- [`src/game/sprint.lua`](/Users/gongahkia/Desktop/coding/projects/kuro/src/game/sprint.lua): Sprint seed packs, medals, and record helpers
- [`src/game/sanity.lua`](/Users/gongahkia/Desktop/coding/projects/kuro/src/game/sanity.lua): sanity pressure model
- [`src/game/replay.lua`](/Users/gongahkia/Desktop/coding/projects/kuro/src/game/replay.lua): replay recording and playback
- [`src/world/generator.lua`](/Users/gongahkia/Desktop/coding/projects/kuro/src/world/generator.lua): deterministic floor generation
- [`src/render/renderer.lua`](/Users/gongahkia/Desktop/coding/projects/kuro/src/render/renderer.lua): first-person renderer
