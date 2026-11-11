# laser/ + game/ + autoload/game_state.gd: Kong (Laser + Game Logic)

**You own:** `laser/` (pickup, aim mode, manager, origins), `game/` (game.tscn wiring), `autoload/game_state.gd` (timer, win/lose, scene flow)
**Others depend on:** `Events.laser_*`, `Events.origin_destroyed`, `Events.time_changed`, `Events.level_finished`, `GameState.*`

## Already working (starter code)
- Laser appears after `first_delay` s → pick it up → game freezes → red aim line to the mouse → click fires.
- Hit = origin destroyed = win. Miss = game resumes, next laser after `retry_delay` s.
- Egg stays at `OriginSpot` (L1). Commander walks `OriginPath` (L2).
- 3-minute timer, win/lose, and title → story → L1 → story → L2 → ending → end screen flow.
- Every file has a `TODO (Kong)` list in its header comment.

## Tasks
| Deadline | Task |
|---|---|
| **Nov 12** | Laser spawning + pickup sequence (tune `first_delay`, spawn spots with Mew) |
| **Nov 13** | Freeze / aim / shoot / hit-miss / retry: visuals, sound, feel |
| **Nov 14** | Level 1 stationary egg + Level 2 moving commander (make the commander hard but fair) |
| **Nov 15** | Win/lose conditions + level transitions polished |

## Open design questions (decide with the group)
- Does the 3-minute timer pause while aiming? (Now: **yes**)
- Does the commander keep moving while you aim? (Now: **no**, it freezes)
- Does the laser go through walls? (Now: **yes**)
- Does the laser appear after a fixed time, or after X kills?

## Test
- `game/game.tscn` → **F6** = play the current level. Set `debug_start_level = 2` in the Inspector to jump to Level 2.
- Temporarily set `first_delay` to 3 in the LaserManager node to test aiming quickly. **Set it back before committing!**
