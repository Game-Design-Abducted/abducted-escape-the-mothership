# enemies/: Ploy (Enemy + Wave Programmer **and Integrator**)

**You own:** `enemy.gd`, `enemy_basic/fast/tank.tscn`, `wave_manager.gd`, `sandbox/ploy_*.tscn`
**As integrator you also gatekeep:** `project.godot`, `autoload/events.gd`, `docs/contracts.md`, merging into `main`
**Others depend on:** `take_damage(amount)` on the enemy root, group `"enemies"`, `Hitbox` on layer 3.

## Already working (starter code)
- Monsters walk Mew's paths, take damage from bullets, hurt the player on contact, and play their hit/dead sprites.
- They **hatch**: for `spawn_protection` seconds (0.7) a new monster is small and see-through, can't be hurt and can't hurt. This stops kill-farming on top of the egg and unfair hits from a monster that just appeared.
- They bob as they walk, pop when hit, and float up and fade when killed. When the origin is destroyed they all dissolve (`vanish()`).
- Wave manager spawns waves from the `WAVES` table and loops the last wave, faster each time. It waits `start_delay` (2 s) before the first monster and never has more than `max_alive` (40) on the map.

## Enemy tasks
| Deadline | Task |
|---|---|
| **Nov 11** | Basic spawning + movement ✅ (starter). Check it on Mew's real paths |
| **Nov 13** | 3 monster types feel different + a real Level 1 wave table |
| **Nov 14** | Level 2 enemy difficulty and movement |
| **Nov 15** | Testing (yours for the whole team) and bug fixes |

## Testing: all yours
You own **all the testing** for the team. The others only build their part and open a PR. See "Testing (all Ploy)" in the README. In short:
- run `tools/smoke_test.gd` before every merge (it must end with **ALL PASSED**)
- play the full game by hand after each merge
- keep the bug list in the chat, with an owner for each bug, and re-check fixes
- update `tools/smoke_test.gd` when a PR changes a rule on purpose

## Integrator tasks
| When | Task |
|---|---|
| Every day | Review & merge PRs into `main`. Check that the project opens and **F5** runs after each merge |
| Every day | Post in the chat: "main is updated, everyone pull" |
| On request | Add input actions / autoloads / signals (you're the only one who edits `project.godot` and `events.gd`) |
| **Nov 13** | **Integration Day**: merge every branch, play the full game (title → L1 → L2 → ending), post a bug list with an owner for each bug |
| **Nov 15** | Final playtest, export the build (Project → Export), tag the release: `git tag v1.0` |

### Merge checklist
1. Did the PR only touch the author's own folder? If not, ask why.
2. Pull the branch and run the smoke test (about 15 seconds, plays the whole loop by itself):
   `godot --headless --path . -s tools/smoke_test.gd` → it must end with **ALL PASSED**.
   If a check fails because the PR changed a rule on purpose, the PR should update `tools/smoke_test.gd` too.
3. Open Godot, press **F5**, play for 1 minute.
4. Check the Debugger → Errors tab for red errors.
5. Merge. If two people changed the same `.tscn`, don't hand-merge it. Keep one version and ask the other person to redo their change.

## Test
- `tools/playtest_bot.gd`: a scripted player plays a whole level a few times, to check balance after you change waves or monsters (see the README, Testing).
- `sandbox/ploy_test.tscn` → **F6**: Level 1 paths + waves, no player.
