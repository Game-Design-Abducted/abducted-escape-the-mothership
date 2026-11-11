# Contracts: the rules everyone codes against

These rules let five people build separate pieces that fit together on the first try.
**If you need to change something here, post in the group chat first.** Other people's code depends on it.
**Ploy (integrator)** approves changes to this file, `project.godot` and `autoload/events.gd`.

## 1. Screen & sizes

| Thing | Value |
|---|---|
| Godot version | **4.3 or newer** (renderer: GL Compatibility) |
| Viewport | 1280 × 720, stretch mode `canvas_items` |
| Tile size | **32 × 32 px** |
| Sprites | 64×64 PNGs in `assets/sprites/` (Fah's 32×32 pixel art, 2 px per art pixel). Scale **1** for characters, **2** for Egg/BigMonster, **0.5** for Bullet. Only use whole-number or ½ scales, or the pixels get uneven |
| Texture filter | **Nearest** (project default) for crisp pixel art. The big .jpg backgrounds override it with Linear |
| Corridors | at least **2 tiles (64 px)** wide. Characters are ~44 px |

## 2. Collision layers (already named in Project Settings)

| # | Name | Who is on it | Value (for code) |
|---|---|---|---|
| 1 | walls | Level `Walls` TileMapLayer | 1 |
| 2 | player | Player body | 2 |
| 3 | enemies | Enemy `Hitbox` Area2D | 4 |
| 4 | player_attack | Bullets | 8 |
| 5 | pickups | Laser pickup | 16 |
| 6 | origin | Egg / Commander | 32 |

Masks used:
- Player body → mask `walls`
- Enemy Hitbox → mask `player` (deals contact damage)
- Bullet → mask `walls` + `enemies`
- Laser pickup → mask `player`

## 3. Groups

| Group | Who |
|---|---|
| `"player"` | Player root |
| `"enemies"` | Every enemy root |
| `"origin"` | Egg / Commander root |

## 4. Damage interface

Anything that can be hurt has:

```gdscript
func take_damage(amount: int) -> void
```

- Bullets call it on `area.owner` (the root of the scene that the Hitbox belongs to).
- Enemies call it on the player body.
- **Origins do NOT have `take_damage`** (normal bullets can't hurt them). They have `take_laser_hit()` instead.

## 5. Level scene layout (Mew)

Every level scene **must** have these exact node names. `game.gd` finds them by name.

```
Level (Node2D, script: levels/level.gd)
├── Walls          TileMapLayer   — collision on physics layer 1
├── Paths          Node2D
│   ├── Path_A     Path2D         — enemy route (first point = where enemies spawn)
│   └── Path_B ... Path2D
├── PlayerStart    Marker2D
├── OriginSpot     Marker2D       — Level 1: where the Egg sits
├── OriginPath     Path2D         — Level 2: route the Commander walks (can be empty in L1)
├── LaserSpawns    Node2D
│   └── Spot1..N   Marker2D       — possible laser pickup positions
└── Entities       Node2D (y_sort) — player etc. get added here at runtime
```

## 6. Events (signals)

All shared signals live in `autoload/events.gd`. Emit and listen through `Events.<signal>`.
Don't `get_node()` into someone else's scene. Use a signal.

## 7. Input actions (already in Project Settings → Input Map)

| Action | Keys |
|---|---|
| `move_up/down/left/right` | WASD + arrow keys |
| `attack` | Space, J |
| `fire_laser` | Left mouse, K (`attack` also fires the laser while aiming) |

## 8. Pausing (laser aim mode)

- Aim mode sets `get_tree().paused = true`.
- Anything that must keep running while paused (aim line, HUD, menus) uses **Process Mode = Always**.
- Everything else (player, enemies, timer) uses the default (**Inherit**), so it freezes automatically.
- Exception: the Level 2 Commander uses **Always**, so it keeps walking while the player aims.

## 9. Git rules

1. **Never commit straight to `main`.** Branch: `yourname/what-you-do` (e.g. `ploy/wave-system`).
2. **Only edit files in your own folder** (see README). To use someone else's scene, *instance* it. Don't open it and change it.
3. Pull `main` every morning. Open a PR at least once a day, even if the work is small. **Ploy reviews and merges PRs.**
4. Before you commit: open the project and press **F5**. If it doesn't run, don't push.
5. Never commit the `.godot/` folder (already in `.gitignore`). **Do** commit the `.import` file Godot creates next to every new image or sound.
