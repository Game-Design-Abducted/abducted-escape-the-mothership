# laser/ + game/ + autoload/game_state.gd: Kong (Laser + Game Logic)

**You own:** `laser/` (pickup, aim mode, manager, origins), `game/` (game.tscn wiring), `autoload/game_state.gd` (timer, win/lose, scene flow)
**Others depend on:** `Events.laser_*`, `Events.origin_destroyed`, `Events.time_changed`, `Events.level_finished`, `GameState.*`

## Already working (starter code)
- The laser **charges from kills**: after `first_kills` (10) kills it appears → pick it up → game freezes → a red aim line **sweeps around the player** → press Space / J / K / click at the right moment to fire.
- Hit = origin destroyed = win. Miss = game resumes, next laser after `retry_kills` (6) more kills.
- In Level 2 the Commander **keeps moving while you aim**.
- Egg stays at `OriginSpot` (L1). Commander walks `OriginPath` (L2).
- 3-minute timer, win/lose, and title → story → L1 → story → L2 → ending → end screen flow.
- Every file has a `TODO (Kong)` list in its header comment.

## Tasks
| Deadline | Task |
|---|---|
| **Nov 12** | Laser spawning + pickup sequence (tune `first_kills`, spawn spots with Mew) |
| **Nov 13** | Freeze / aim / shoot / hit-miss / retry: visuals, sound, feel |
| **Nov 14** | Level 1 stationary egg + Level 2 moving commander (make the commander hard but fair) |
| **Nov 15** | Win/lose conditions + level transitions polished |

## Open design questions (decide with the group)
- Does the 3-minute timer pause while aiming? (Now: **yes**)
- Does the commander keep moving while you aim? (Now: **yes**)
- Does the laser go through walls? (Now: **yes**)
- Laser charge: kills only (now), or kills + a minimum time? How many kills feels right?
- Aim sweep speed: 90°/s in Level 1, 120°/s in Level 2. Too easy / too hard?

## Test
- `game/game.tscn` → **F6** = play the current level. Set `debug_start_level = 2` in the Inspector to jump to Level 2.
- Temporarily set `first_kills` to 1 in the LaserManager node to test aiming quickly. **Set it back before committing!**
- Ploy runs the automatic test (`tools/smoke_test.gd`) and does all the testing. You only need to look at your own part.
