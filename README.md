# Abducted: Escape the Mothership

2D action game: **Pac-Man maze + Tower Defense**, made with **Godot 4.3+ (GDScript)**.
You've been abducted. Survive the monster waves, grab the alien laser, and destroy the monster origin before the 3-minute timer runs out.

Full design: [docs/design.md](docs/design.md) · **Shared rules: [docs/contracts.md]**

## Run it

1. Install Godot **4.3 or newer** (standard version, not .NET).
2. Godot → *Import* → pick this folder's `project.godot`.
3. Press **F5** to play from the title screen, or open any scene and press **F6** to run just that scene.

## Who owns what

Ownership is **per file**, not per folder (a few folders have files from two people).
The file list below is the source of truth. **Only edit your own files.** If you need
something changed in someone else's file, ask them or use a signal in `autoload/events.gd`.
Every `.gd` file has its owner and TODO list in the comment at the top.

| Person | Responsible for |
|---|---|
| **Yang** | Player (movement, shooting, HP, bullet) and the whole laser sequence: laser manager (timer + spawning), laser pickup, aim mode. Also the story screen. |
| **Ploy** | All monsters and waves, the monster origin (Egg + Commander), the end screen. **Also the integrator:** reviews and merges PRs, approves changes to `events.gd`, `project.godot` and `docs/`. |
| **Kong** | `GameState` (3 min timer, win/lose, level flow), `game.gd` (builds a level and wires everyone's pieces together) and the HUD logic. |
| **Fah** | All art, animation, sound and fonts. The title screen. Also gives the others sprites, icons and sounds when they ask. |
| **Mew** | Level 1 and Level 2: maze, walls, enemy paths, spawn points, laser spots. |

## Project layout and who owns each file

```
abducted-escape-the-mothership/
├── project.godot                  # Ploy: only Ploy edits this (new input actions, autoloads)
├── README.md                      # Ploy
├── CREDITS.md                     # Ploy
├── autoload/
│   ├── events.gd                  # shared signals, ask Ploy before adding one
│   └── game_state.gd              # Kong: timer, win/lose, level flow
├── game/
│   ├── game.gd                    # Kong: builds a level and wires every system
│   ├── game.tscn                  # Kong
│   └── GUIDE.md                   # Kong (old, see note below)
├── levels/
│   ├── level.gd                   # Mew
│   ├── level_1.tscn               # Mew
│   ├── level_2.tscn               # Mew
│   ├── tiles/                     # Mew: tileset (techlab_tiles.png, techlab_tileset.tres)
│   └── GUIDE.md                   # Mew
├── player/
│   ├── player.gd                  # Yang: movement, attack, HP
│   ├── player.tscn                # Yang
│   ├── bullet.gd                  # Yang
│   ├── bullet.tscn                # Yang
│   └── GUIDE.md                   # Yang
├── laser/
│   ├── laser_manager.gd           # Yang: laser timer, spawn, pickup, hit/miss loop
│   ├── laser_pickup.gd            # Yang
│   ├── laser_pickup.tscn          # Yang
│   ├── aim_mode.gd                # Yang: pause + aim + fire
│   ├── GUIDE.md                   # Kong (old, see note below)
│   └── origins/
│       ├── origin.gd              # Ploy: base script, only the laser can hurt it
│       ├── egg.tscn               # Ploy: level 1 origin, stands still
│       ├── commander.gd           # Ploy: level 2 origin, walks a path
│       └── commander.tscn         # Ploy
├── enemies/
│   ├── enemy.gd                   # Ploy: shared monster script
│   ├── enemy_basic.tscn           # Ploy
│   ├── enemy_fast.tscn            # Ploy
│   ├── enemy_tank.tscn            # Ploy
│   ├── wave_manager.gd            # Ploy: what spawns and when
│   └── GUIDE.md                   # Ploy
├── ui/
│   ├── title_screen.gd/.tscn      # Fah: main menu (the game's main scene)
│   ├── story_screen.gd/.tscn      # Yang: intro / level 2 / ending pages
│   ├── hud.gd/.tscn               # Kong: hearts, timer, laser status (Fah gives the art)
│   ├── end_screen.gd/.tscn        # Ploy: you won / game over
│   └── GUIDE.md                   # Fah (old, see note below)
├── assets/                        # Fah
│   ├── sprites/                   # Fah: 24 in-game 64x64 PNGs (player, monsters, egg, laser, hearts...)
│   ├── home/                      # Fah: layered title screen art
│   ├── audio/                     # Fah: music and sounds (empty for now)
│   └── fonts/                     # Fah: pixel font (empty for now)
├── art_source/                    # Fah: Illustrator and hi-res source, Godot ignores it
├── tools/
│   └── convert_sprites.py         # Fah: turns big exports into 64x64 sprites
├── sandbox/                       # personal test scenes
│   ├── ploy_test.gd/.tscn         # Ploy: waves on level 1 paths, no player
│   └── yang_test.tscn             # Yang: walk around level 1 with the player
└── docs/                          # Ploy: design.md and contracts.md, ask before changing
```

`GUIDE.md` files inside `levels/`, `player/`, `laser/`, `game/` and `ui/` are older and still describe the
first split of work. If one disagrees with this README, follow this README.

## How the pieces connect

```
title_screen ──START──► story_screen ──► game.tscn ──► (win) story ──► game (L2) ──► story(ending) ──► end_screen
                                            │
       game.gd builds:  Level (Mew) ─ Player (Yang) ─ WaveManager (Ploy) ─ LaserManager (Yang) ─ Origin (Ploy) ─ HUD (Kong)
       they talk only through  Events.*  signals  +  GameState
```

## Git workflow (short version)

```bash
git checkout main && git pull
git checkout -b yourname/feature-name
# ...work, press F5 to check it runs...
git add . && git commit -m "Short description"
git push -u origin yourname/feature-name   # then open a Pull Request on GitHub
```

## Schedule

| Date | Milestone |
|---|---|
| Nov 11 | Movement, Level 1 map, basic enemy spawning |
| Nov 12 | Laser pickup, sprites in game |
| Nov 13 | Combat, waves, aim/shoot. **Integration day: merge everything into main and play it** |
| Nov 14 | Level 2, moving origin, effects |
| Nov 15 | Win/lose, screens, polish, bug fixing |
