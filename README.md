# Kuro

Kuro is now a Love2D/Lua first-person survival-horror game built around light pressure, procedural descent, and anchor-lighting boss objectives.

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

- `Enter`: start run / confirm on title
- `1`, `2`, `3`: choose difficulty
- `W`, `S`: move forward and backward
- `A`, `D`: turn left and right
- `Q`, `E`: strafe
- `Space`: interact
- `F`: emit light
- `Shift`: charge burst
- `G`: throw flare
- `Tab`: toggle automap
- `R`: restart after death or victory

## Structure

- [`docs/mechanics.md`](/Users/gongahkia/Desktop/coding/projects/kuro/docs/mechanics.md): legacy mechanic reference
- [`main.lua`](/Users/gongahkia/Desktop/coding/projects/kuro/main.lua): Love entrypoint
- [`src/app.lua`](/Users/gongahkia/Desktop/coding/projects/kuro/src/app.lua): app state and screen flow
- [`src/game/run.lua`](/Users/gongahkia/Desktop/coding/projects/kuro/src/game/run.lua): run orchestration
- [`src/world/generator.lua`](/Users/gongahkia/Desktop/coding/projects/kuro/src/world/generator.lua): deterministic floor generation
- [`src/render/renderer.lua`](/Users/gongahkia/Desktop/coding/projects/kuro/src/render/renderer.lua): first-person renderer
