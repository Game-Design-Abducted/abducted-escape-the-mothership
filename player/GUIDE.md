# player/: Yang (Player + Combat Programmer)

**You own:** `player.gd/.tscn`, `bullet.gd/.tscn`, `sandbox/yang_*.tscn`
**Others depend on:** `take_damage(amount)`, group `"player"`, layer 2, the `Events.player_*` signals.

## Already working (starter code)
- Movement (WASD/arrows) with wall collision, shooting (Space/J), HP with invincibility frames, death signal.
- Read the comment at the top of `player.gd` for the full TODO list.

## Tasks
| Deadline | Task |
|---|---|
| **Nov 11** | Movement + wall collision feel good. Decide: free movement or Pac-Man grid movement |
| **Nov 13** | Attack tuning, enemy damage, player HP, hit/death visuals |
| **Nov 14** | Laser pickup works with your player (with Kong) + general combat polish |
| **Nov 15** | Fix the bugs Ploy assigns to you (Ploy does the testing) |

## Test
- `sandbox/yang_test.tscn` → **F6**: Level 1 + player, no enemies or timer.
- `game/game.tscn` → **F6**: the full game loop.

## Notes
- Don't edit enemy files to change how damage works. Use `take_damage()`. Need something else? Ask Ploy.
- Need a new input action? Ask Ploy (integrator). It's added in `project.godot`.
