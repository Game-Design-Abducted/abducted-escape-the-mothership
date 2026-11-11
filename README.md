# Abducted: Escape the Mothership

2D action game: **Pac-Man maze + Tower Defense**, made with **Godot 4.3+ (GDScript)**.
You've been abducted by aliens. Survive the monster waves, grab the alien laser, and destroy the monster origin (Level 1: an egg, Level 2: the Alien Commander) before the 3-minute timer runs out.

Design doc: [docs/design.md](docs/design.md) · Shared rules (collision layers, node names, signals): [docs/contracts.md](docs/contracts.md)

## Run it

1. Install Godot **4.3 or newer** (standard version, not .NET).
2. Godot → *Import* → pick this folder's `project.godot`.
3. Press **F5** to play from the title screen, or open any scene and press **F6** to run just that scene.

## Who owns what

Ownership is **per file**, not per folder. **Only edit your own files.** If you need something changed in
someone else's file, ask them, or use a signal in `autoload/events.gd`. Every `.gd` file has its owner and
TODO list in the comment at the top.

| Person | Responsible for |
|---|---|
| **Yang** | Player (movement, shooting, HP, bullet) and the whole laser sequence: laser manager (kill charge + spawning, then the sweeping aim), laser pickup, aim mode. Also the story screen. |
| **Ploy** | All monsters and waves, the monster origin (Egg + Commander), the end screen. **Also the integrator:** reviews and merges PRs, approves changes to `events.gd`, `project.godot` and `docs/`. **Also owns all testing** (see [Testing](#testing-all-ploy)). |
| **Kong** | `GameState` (3 min timer, win/lose, level flow), `game.gd` (builds a level and wires everyone's pieces together) and the HUD logic. |
| **Fah** | All art, animation, sound and fonts. The title screen. Also gives the others sprites, icons and sounds when they ask. |
| **Mew** | Level 1 and Level 2: maze, walls, enemy paths, spawn points, laser spots. |

## Who depends on who

Every system has a **working starter version already**, so nobody is blocked from day one. The tables below
say what each person gets from others, and what to do **if it isn't ready yet and you can't wait**.

The general trick is the same everywhere: **build against the agreed shape, not the finished thing.**
The shape (node names, signal names, function names) is fixed in [docs/contracts.md](docs/contracts.md), so you
can fake the other side in your own `sandbox/` scene and swap in the real one later.

### Yang: player + laser + story screen

| You need | From | If it isn't ready and you can't wait |
|---|---|---|
| Walls to collide with | Mew (`Walls` tiles on layer 1) | Paint a few wall tiles yourself in a *copy* of `level_1.tscn` inside `sandbox/` (never in Mew's file) |
| Monsters to shoot | Ploy (`enemy_*.tscn`, `take_damage`) | Use the starter `enemy_basic.tscn` (see `sandbox/ploy_test.tscn`), or make a dummy: an Area2D on layer 3 whose root script has `take_damage(amount)` |
| Laser kills to count | Ploy (`Events.enemy_killed`) | Fake kills: `Events.enemy_killed.emit(null)` from a debug key. Or set `first_kills` to 1 **locally** and don't commit it |
| An origin to hit | Ploy (`egg.tscn`: `is_hit_by_ray`, `take_laser_hit`) | The starter egg already works. Test the aim with it in your sandbox |
| Laser spawn spots | Mew (`LaserSpawns/Spot*`) | Add your own `Marker2D` spots in your sandbox copy of the level |
| Story page text and state | Kong (`GameState.story_id`, `goto()`) | Set `GameState.story_id = "intro"` in a sandbox script and press F6 on `story_screen.tscn` |

**Waiting on you:** Ploy's enemies call `player.take_damage(amount)` and look for group `"player"`. Kong's `game.gd` calls
`laser_manager.setup(level, player, origin)`. Kong's HUD listens to `player_hp_changed` and the laser signals.
Don't rename any of these.

### Ploy: monsters + waves + origins + end screen + integration

| You need | From | If it isn't ready and you can't wait |
|---|---|---|
| Enemy paths | Mew (`Paths/Path_*`) | `sandbox/ploy_test.tscn` already walks Mew's starter paths. Or draw your own `Path2D` in a sandbox scene |
| A player to hurt | Yang (`take_damage`, group `"player"`) | Use the starter player, or a dummy `CharacterBody2D` in group `"player"` with `take_damage()` that prints |
| Origin spot / Commander route | Mew (`OriginSpot`, `OriginPath`) | The starter levels already have both. For a different route, draw your own in a sandbox copy |
| Sprites for new monster types | Fah | Reuse an existing monster PNG with a different tint until the art arrives |
| Win/lose state for the end screen | Kong (`GameState.last_result_won`, `retry_level()`) | Set `GameState.last_result_won = true/false` in a sandbox script, then F6 `end_screen.tscn` |
| Everyone's pull requests | the whole team | If a PR is not ready, ask for a stub first (right node names, does nothing yet), so the others can keep going |

**Waiting on you:** Yang's laser charge needs `Events.enemy_killed`. Yang's aim needs the origin's `is_hit_by_ray()` and
`take_laser_hit()`. Kong's win condition needs `Events.origin_destroyed`. Kong's `game.gd` calls `wave_manager.setup(paths, level)` and
`commander.follow_path(path)`. Enemy hitboxes must stay on layer 3 so Yang's bullets hit them.

### Kong: game state + game.gd + HUD

| You need | From | If it isn't ready and you can't wait |
|---|---|---|
| Everyone's scenes for `game.gd` to load | Mew (levels), Yang (player, laser), Ploy (waves, origins) | The starter versions are already wired in. Keep the node and function names from `contracts.md` and it keeps working when they improve their parts |
| HP and laser values for the HUD | Yang (`player_hp_changed`, `laser_charge_changed`, ...) | Fake them from a sandbox script: `Events.player_hp_changed.emit(2, 3)` |
| Hearts, icons, font | Fah | The starter HUD already uses Fah's heart sprites. Use plain `Label`s until the font arrives |
| `origin_destroyed` / `player_died` to test win and lose | Ploy, Yang | Call `GameState.finish_level(true)` or `(false)` yourself in a sandbox script |

**Waiting on you:** Fah's title screen calls `GameState.start_new_game()`. Yang's story screen reads `GameState.story_id` and calls
`goto()`. Ploy's end screen reads `GameState.last_result_won` and calls `retry_level()`. The HUD (and everyone) listens to
`Events.time_changed` and `Events.level_finished`.

### Fah: art, sound, fonts, title screen

| You need | From | If it isn't ready and you can't wait |
|---|---|---|
| Sprite sizes and which file goes where | the others (in `docs/contracts.md`) | Draw on the 32×32 grid and export 64×64 PNGs. Keep the **same file names** as the old ones |
| `GameState.start_new_game()` for the START button | Kong | The starter already works. F6 `title_screen.tscn` to test |
| A request for new art or sound | whoever needs it | Ask in the group chat, then drop the files in `assets/` with a clear name |

**Waiting on you:** everyone loads sprites by file name from `assets/sprites/`. If you rename a file, the scenes break.
Overwrite a file with the same name instead. Ploy needs monster sprites, Yang the beam art, Kong the HUD font and icons.

### Mew: levels

You depend on almost nobody, so you are the one everyone else is waiting on first.

| You need | From | If it isn't ready and you can't wait |
|---|---|---|
| Wall and floor tiles | Fah (optional) | The free CC0 Tech Lab tileset is already set up (`levels/tiles/`) |
| To see enemies on your paths | Ploy | F6 `sandbox/ploy_test.tscn` |
| To see if the player fits corridors | Yang | F6 `sandbox/yang_test.tscn`. Corridors at least 2 tiles (64 px) wide |

**Waiting on you:** Ploy's monsters follow your `Path2D`s. Yang spawns lasers at your `LaserSpawns` markers. Kong's `game.gd` finds
`PlayerStart`, `OriginSpot`, `OriginPath`, `Entities` by name. Do **not rename** nodes (see `contracts.md`), and merge a first
rough maze early, even if it's ugly, so the others can test on it.

### If you're blocked, in this order

1. **Use the starter version.** It's already in the repo and works.
2. **Fake the other side** in your own `sandbox/yourname_*.tscn` (a dummy node, or a signal fired by hand). Never edit someone else's file to unblock yourself.
3. **Ask for a stub:** a version with the agreed node/signal/function names that may do nothing yet. That's enough for you to keep going.
4. **Ask in the group chat.** If it's still stuck after a few hours, tell Ploy (integrator), who can reorder merges.

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
│   ├── audio/                     # Fah: music and sounds (empty for now)
│   └── fonts/                     # Fah: pixel font (empty for now)
├── art_source/                    # Fah: Illustrator and hi-res source, Godot ignores it
│   └── techlab_pack/              # Mew: original tile pack (license + full tileset) that levels/tiles/ was cut from
├── tools/
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

`GUIDE.md` files inside `levels/`, `player/`, `laser/`, `game/` and `ui/` are older and still describe the
first split of work. If one disagrees with this README, follow this README.

## How the pieces connect

```
title_screen ──START──► story_screen ──► game.tscn ──► (win) story ──► game (L2) ──► story(ending) ──► end_screen
                                            │
       game.gd builds:  Level (Mew) ─ Player (Yang) ─ WaveManager (Ploy) ─ LaserManager (Yang) ─ Origin (Ploy) ─ HUD (Kong)
       they talk only through  Events.*  signals  +  GameState
```

## Testing (all Ploy)

**Ploy does all the testing.** Everyone else just builds their part and opens a PR.

What Ploy does:
- Runs the **automatic test** before every merge. It plays the whole game loop by itself (about 15 seconds) and prints PASS/FAIL for each step:

  ```bash
  godot --headless --path . -s tools/smoke_test.gd
  ```

  (Replace `godot` with the full path to your Godot .exe if needed.) It must end with **ALL PASSED**.
- Plays the game by hand after each merge: title → Level 1 → Level 2 → ending, and also a game over.
- Keeps the **bug list** in the group chat, with the owner of each bug (see "Who owns what"), and checks the fix after it's merged.
- On a PR that changes a rule on purpose (for example how the laser charges), updates `tools/smoke_test.gd` so the test matches the new rule.
- Does the final playtest and export.

What everyone else does: nothing special. You don't need to run the smoke test or write tests. It's still nice to press **F5** (or **F6** on your own scene) so you can see your own change working, and to
fix the bugs Ploy assigns to you.

## Git workflow (short version)

```bash
git checkout main && git pull
git checkout -b yourname/feature-name
# ...work, press F5 to check it runs...
git add . && git commit -m "Short description"
git push -u origin yourname/feature-name   # then open a Pull Request on GitHub
```

Merge small and often (at least once a day), so the others get your work early and nobody waits for a big merge at the end.
