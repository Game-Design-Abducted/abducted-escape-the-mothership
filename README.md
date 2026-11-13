# Abducted: Escape the Mothership

2D action game: **Pac-Man maze + Tower Defense**, made with **Godot 4.3+ (GDScript)**.
You've been abducted by aliens. Survive the monster waves, grab the alien laser, and destroy the monster origin (Level 1: an egg, Level 2: the Alien Commander) before the 3-minute timer runs out.

Design doc: [docs/design.md](docs/design.md) · Shared rules (collision layers, node names, signals): [docs/contracts.md](docs/contracts.md)

## Run it

1. Install Godot **4.3 or newer** (standard version, not .NET).
2. Godot → *Import* → pick this folder's `project.godot`.

**Easy run**

| Where | Play the game | Play just the open scene |
|---|---|---|
| **Godot editor** | **F5** (or the ▶ button top-right) | **F6** (or the 🎬 button) |
| **VS Code** | **F5** (uses *Godot: Play game*) | pick *Godot: Play current scene* in the Run and Debug dropdown, then **F5** |

VS Code needs the **Godot Tools** extension (`geequlim.godot-tools`). Set the Godot path once under *Settings → Godot Tools → Editor Path*.

## Godot basics

- **`.tscn`** = a **scene**: a tree of nodes saved as text (a player, a monster, a menu). Edit it in the Godot editor, not by hand. Scenes can contain other scenes.
- **`.gd`** = a **GDScript** file: the code that makes a node do things. It is attached to a node in a scene.
- **Node** = one building block (sprite, collision shape, timer...). **Signal** = a node announcing "something happened"; other code listens. Here the shared ones live in `autoload/events.gd`.
- Everyday use: double-click a `.tscn` in the **FileSystem** dock (bottom-left) to open it → pick a node in the **Scene** dock (top-left) → change its settings in the **Inspector** (right) → click the 📜 icon to open or attach its `.gd`.
- **Save** with Ctrl/Cmd+S, then press **F6** to test just your scene. Red text in the **Output** / **Debugger** panel at the bottom = an error to fix.

## Who owns what

Ownership is **per file**, not per folder. **Only edit your own files.** If you need something changed in
someone else's file, ask them, or use a signal in `autoload/events.gd`. Every `.gd` file has its owner and
TODO list in the comment at the top.

| Person | Responsible for |
|---|---|
| **Yang** | Player (movement, shooting, HP, bullet) and the whole laser sequence: laser manager (kill charge + spawning, then the sweeping aim), laser pickup, aim mode. Also the story screen. |
| **Ploy** | All monsters and waves, the monster origin (Egg + Commander), the end screen, and `game.gd` (builds a level and wires everyone's pieces together). **Also the integrator:** reviews and merges PRs, approves changes to `events.gd`, `project.godot` and `docs/`. **Also owns all testing** (see [Testing](#testing-all-ploy)). |
| **Kong** | `GameState` (3 min timer, win/lose, level flow) and the HUD logic. |
| **Fah** | All art, animation, sound and fonts. The title screen. Also gives the others sprites, icons and sounds when they ask. |
| **Mew** | Level 1 and Level 2: maze, walls, enemy paths, spawn points, laser spots. |

## Build order (who needs what)

Go top to bottom. A file only needs things from **earlier rows**, so if you're on row 5, rows 1-4 are what you wait on. Rows in the same stage can be built **at the same time**.

| Stage | File / piece | Owner | Dependent on |
|---|---|---|---|
| **1. Start now** | 1. `levels/level_1.tscn` (maze, paths, spawn points) | Mew | nothing |
| | 2. `assets/` sprites, sound, font | Fah | nothing (sizes in `docs/contracts.md`) |
| | 3. `autoload/game_state.gd` (timer, win/lose, level flow) | Kong | nothing |
| **2. Core pieces** | 4. `player/player.tscn` (move, shoot, HP) | Yang | 1 walls, 2 sprite |
| | 5. `enemies/` + wave manager (monsters, waves) | Ploy | 1 paths, 2 sprites, 4 player to hurt |
| | 6. `laser/origins/` (Egg, Commander) | Ploy | 1 `OriginSpot` / `OriginPath`, 2 sprite |
| **3. Laser** | 7. `laser/` (laser manager, pickup, aim mode) | Yang | 1 laser spots, 5 kills, 6 origin to hit |
| **4. Wire-up and screens** | 8. `game/game.gd` (builds the level, connects everyone) | Ploy | 1, 4, 5, 6, 7 (loads them all) |
| | 9. `ui/hud.gd` (HP, laser, timer) | Kong | 3 timer, 4 HP signal, 7 laser signals, 2 hearts and font |
| | 10. `ui/title_screen.tscn` | Fah | 3 `start_new_game()` |
| | 11. `ui/story_screen.tscn` | Yang | 3 `story_id`, `goto()` |
| | 12. `ui/end_screen.tscn` | Ploy | 3 `last_result_won`, `retry_level()` |
| **5. Finish** | 13. `levels/level_2.tscn` | Mew | 1 (same rules), 6 Commander route |
| | 14. Smoke test and integration | Ploy | everything above |

Every row already has a working **starter version** in the repo, so you can start your row today and swap in the real thing as earlier rows improve. The names of nodes, signals and functions are fixed in [docs/contracts.md](docs/contracts.md); don't rename them.

## Progress so far (13 Nov 2026)

The whole loop is playable from start to finish: title → intro story → Level 1 → story → Level 2 → ending → win / lose screen.

| Piece | Owner | Status |
|---|---|---|
| Monsters and waves | Ploy | **Done.** 3 types move differently (fast zig-zags, tank stops at corners). Waves designed for Level 1 and Level 2. Left: death sprite. |
| Origins (Egg, Commander) | Ploy | **Done.** Commander changes speed and turns around so the laser is hard to time. Left: destroy animation, tuning. |
| `game.gd` wire-up | Ploy | **Done.** |
| End screen | Ploy | **Done.** Spaceship + win sound on a win, hurt astronaut + lose sound on a loss, game fonts. Left: animation, if Fah wants to add any. |
| Tests and CI | Ploy | **Done.** Load check + smoke test run on every PR (see [Testing](#testing-all-ploy)). |
| Sprites, title art | Fah | **Done.** 24 sprites and the layered home art are in. |
| Audio and fonts | Fah | **Files are in** (3 music tracks, the sound effects, Minecraft + VT323 fonts). Only the title screen and end screen play sound so far; the other owners still need to hook up their sounds. |
| Title screen | Fah | **Done.** Rebuilt from the layers: animation, START hover / click sounds, looping music. |
| Player | Yang | **Starter version works** (move, shoot, HP). Left: movement feel, hit flash / death sprite, sounds. |
| Laser (charge, pickup, aim) | Yang | **Basic version works** (charge from kills, pickup, sweeping aim, hit / miss / retry). Left: nicer beam, sounds, tuning. |
| Story screen | Yang | **Starter version works** (3 text pages). Left: story art, text effect. |
| GameState | Kong | **Starter version works** (timer, win / lose, level flow). Left: the open decisions in its TODO. |
| HUD | Kong | **Starter version works** (hearts, timer, laser status). Left: icons, timer warning, wave number. |
| Level 1 and Level 2 | Mew | **Level 1 maze is in** (walls, 2 monster routes that loop back to the egg, laser spots). Level 2 is still the starter maze. Left: Level 2, play-test tuning. |

The detailed TODO list for each piece is in the comment at the top of its `.gd` file.

## Testing (all Ploy)

CI runs both of these on every pull request. To run them yourself:

```bash
godot --headless --path . --import
godot --headless --path . -s tools/check_load.gd
godot --headless --path . -s tools/smoke_test.gd
```

- **Load check** (`tools/check_load.gd`, about 1 second): every script and scene loads.
- **Smoke test** (`tools/smoke_test.gd`, about a minute): plays the whole game loop and prints PASS / FAIL for each step.

## Project layout and who owns each file

```
abducted-escape-the-mothership/
├── project.godot                  # Ploy: only Ploy edits this (new input actions, autoloads)
├── README.md                      # Ploy
├── CREDITS.md                     # Ploy
├── .gitignore, .gitattributes     # Ploy: git settings, ask before changing
├── autoload/
│   ├── events.gd                  # shared signals, ask Ploy before adding one
│   └── game_state.gd              # Kong: timer, win/lose, level flow
├── game/
│   ├── game.gd                    # Ploy: builds a level and wires every system
│   ├── game.tscn                  # Ploy
│   └── GUIDE.md                   # Ploy
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
│   ├── laser_manager.gd           # Yang: laser charge (kills), spawn, pickup, hit/miss loop
│   ├── laser_pickup.gd            # Yang
│   ├── laser_pickup.tscn          # Yang
│   ├── aim_mode.gd                # Yang: pause + sweeping aim + fire
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
│   ├── audio/                     # Fah: music/ (3 looping tracks) and sfx/
│   └── fonts/                     # Fah: Minecraft.ttf (titles), VT323.ttf (body text)
├── art_source/                    # Fah: Illustrator and hi-res source, Godot ignores it
│   └── techlab_pack/              # Mew: original tile pack (license + full tileset) that levels/tiles/ was cut from
├── tools/
│   ├── check_load.gd              # Ploy: checks every script and scene loads (CI runs it)
│   ├── convert_sprites.py         # Fah: turns big exports into 64x64 sprites
│   └── smoke_test.gd              # Ploy: plays the whole game loop automatically
├── sandbox/                       # personal test scenes (name them yourname_*.tscn)
│   ├── ploy_test.gd/.tscn         # Ploy: waves on level 1 paths, no player
│   └── yang_test.tscn             # Yang: walk around level 1 with the player
└── docs/                          # Ploy: design.md and contracts.md, ask before changing
```

Two kinds of small files are not listed one by one:
- `*.import` files (Godot makes one next to every image) belong to the owner of the picture next to them.
- `.gdignore` and `.gitkeep` files only tell Godot or git to skip or keep a folder, so they belong to that folder's owner.

`GUIDE.md` files inside `levels/`, `player/`, `laser/` and `ui/` are older and still describe the
first split of work. If one disagrees with this README, follow this README.

## How the pieces connect

```
title_screen ──START──► story_screen ──► game.tscn ──► (win) story ──► game (L2) ──► story(ending) ──► end_screen
                                            │
       game.gd builds:  Level (Mew) ─ Player (Yang) ─ WaveManager (Ploy) ─ LaserManager (Yang) ─ Origin (Ploy) ─ HUD (Kong)
       they talk only through  Events.*  signals  +  GameState
```

## Git workflow for commit (2 ways)
### 1. Github Desktop

Use **[GitHub Desktop](https://desktop.github.com)**. Setup: install it, sign in, *File → Clone repository* → pick this repo.

**Start your work**
1. Top bar → *Current Branch* → *New Branch* → name it `yourname/feature-name` (for example `mew/level-1-tiles`).

**Do your work in Godot** (see "Godot basics"), then press **F5** (or **F6** on your scene). It should run with no red errors in the Output panel and do what its `GUIDE.md` says.

**When you finish your part**
1. Save everything in Godot (Ctrl/Cmd+S).
2. In GitHub Desktop, look at the changed-files list on the left. Only files you own should be there. If something else is, right-click it → *Discard changes*.
3. Bottom-left: type a short message ("Add level 1 tiles") → **Commit to yourname/feature-name**.
4. Click **Push origin** (top bar).
5. Click **Create Pull Request** (it opens GitHub) and tag Ploy. Ploy runs the tests and merges.
6. Don't merge your own PR. If Ploy reports a bug in your part, fix it, then commit and push again on the same branch.

Never commit to `main` (the branch name in the top bar should be yours).

### 2. Git from terminal

```bash
git checkout main && git pull
git checkout -b yourname/feature-name
# ...work, press F5 to check it runs...
git status                                   # only your own files should be listed
git add . && git commit -m "Short description"
git push -u origin yourname/feature-name   # then open a Pull Request on GitHub
```

</details>

Merge small and often (at least once a day), so the others get your work early and nobody waits for a big merge at the end.
