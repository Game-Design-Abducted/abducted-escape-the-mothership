# game/: Ploy

**You own:** `game.gd` and `game.tscn`. They build one level and connect everyone's systems.
**Others depend on:** the node names and signals in [docs/contracts.md](../docs/contracts.md). Keep them as they are.

## What game.gd does
In order (the list at the top of `game.gd` is the source of truth):
1. loads Mew's level for `GameState.current_level`
2. puts Yang's player at `PlayerStart`
3. puts your origin (egg or commander) in the level
4. starts your wave manager on the level's paths
5. starts Yang's laser manager
6. Kong's HUD is already inside `game.tscn` and just listens to `Events`
7. tells `GameState` (Kong) to start the 3 minute timer
8. plays the level music (Level 1 `bgm_level`, Level 2 `bgm_boss`) and every in-level sound (laser, shooting, monsters, player hurt / death, timer tick), by listening to `Events`
9. adds the screen feel: fade in, screen shake (a camera, so nothing in the level moves), hit and laser flashes, music that dips while aiming, the glowing spawn mark in Level 2 (`spawn_marker.gd`), and monsters that dissolve when the level is won

When two systems need to talk, wire them up here or with a signal in `autoload/events.gd`. Don't let them reach into each other's code.

**Rule for everyone else:** don't edit `game.tscn` / `game.gd`. If your system needs to be connected to something, ask Ploy.

## Test
- `game/game.tscn` → **F6** = play the current level. Set `debug_start_level = 2` in the Inspector to jump to Level 2.
- `tools/smoke_test.gd` plays the whole loop (load level, monsters, laser, win, level 2, timeout) and runs in CI.
- Your tasks and deadlines are in [enemies/GUIDE.md](../enemies/GUIDE.md).
