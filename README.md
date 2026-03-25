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
- `N`: roll a new seed on the title screen
- `Z`, `X`, `C`: toggle `Embers`, `Echoes`, `Onslaught` on the title screen
- `B`, `I`: toggle unlocked `Blacklight` and `Ironman` mutators on the title screen
- `W`, `S`: move forward and backward
- `A`, `D`: turn left and right
- `Q`, `E`: strafe
- `Space`: interact
- `F`: emit light
- `Shift`: charge burst
- `G`: throw flare
- `1`, `2`, `3`: use consumables from the belt
- `Tab`: toggle automap
- `Esc`: pause, resume, or back out of menus
- `V` or `S`: save a replay from pause or result screens
- `R`: retry after death or victory
- `P`: open progression from the result screen
- `V`: open replay browser from the result screen

## Modes

- `Classic`: standard seeded descent with selectable loadout, flame color, and mutators
- `Daily Challenge`: fixed date-seeded `stalker` run with a locked daily profile
- `Time Attack`: seeded descent with escalating pressure every 30 seconds

## Systems

- `Sanity`: the only non-HP pressure track; low sanity distorts vision, weakens automap clarity, and reduces light recovery
- `Consumable belt`: `Calming Tonic`, `Speed Tonic`, and `Ward Charge` live in 3 quick-use slots
- `Progression`: unlocks opt-in mutators, the `Scout` loadout, and cosmetic flame colors
- `Replays`: record runs, save them locally, and replay them from the title screen

## Structure

- [`docs/mechanics.md`](/Users/gongahkia/Desktop/coding/projects/kuro/docs/mechanics.md): legacy mechanic reference
- [`main.lua`](/Users/gongahkia/Desktop/coding/projects/kuro/main.lua): Love entrypoint
- [`src/app.lua`](/Users/gongahkia/Desktop/coding/projects/kuro/src/app.lua): app state and screen flow
- [`src/game/run.lua`](/Users/gongahkia/Desktop/coding/projects/kuro/src/game/run.lua): run orchestration
- [`src/game/sanity.lua`](/Users/gongahkia/Desktop/coding/projects/kuro/src/game/sanity.lua): sanity pressure model
- [`src/game/replay.lua`](/Users/gongahkia/Desktop/coding/projects/kuro/src/game/replay.lua): replay recording and playback
- [`src/world/generator.lua`](/Users/gongahkia/Desktop/coding/projects/kuro/src/world/generator.lua): deterministic floor generation
- [`src/render/renderer.lua`](/Users/gongahkia/Desktop/coding/projects/kuro/src/render/renderer.lua): first-person renderer
