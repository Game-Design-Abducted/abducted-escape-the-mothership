# Abducted: Escape the Mothership

2D action game: **Pac-Man maze + Tower Defense**, made with **Godot 4.3+ (GDScript)**.
You've been abducted. Survive the monster waves, grab the alien laser, and destroy the monster origin before the 3-minute timer runs out.

Full design: [docs/design.md](docs/design.md) · **Shared rules: [docs/contracts.md](docs/contracts.md) (read this first!)**

## Run it

1. Install Godot **4.3 or newer** (standard version, not .NET).
2. Godot → *Import* → pick this folder's `project.godot`.
3. Press **F5** to play from the title screen, or open any scene and press **F6** to run just that scene.

## Who owns what

Each folder has one owner and a `GUIDE.md` with that person's tasks and deadlines.
**Only edit your own folder.** If you need something changed in someone else's folder, ask them.

| Folder | Owner | Contents |
|---|---|---|
| [`levels/`](levels/GUIDE.md) | **Mew** | Level 1 & 2 mazes, walls, enemy paths, spawn/laser spots |
| [`player/`](player/GUIDE.md) | **Yang** | Player movement, shooting, HP, bullet |
| [`enemies/`](enemies/GUIDE.md) | **Ploy** | 3 monster types, wave manager. **Also the integrator**  |
| [`laser/`](laser/GUIDE.md) + [`game/`](game/GUIDE.md) + `autoload/game_state.gd` | **Kong** | Laser pickup, aim/shoot, Egg & Commander, win/lose, level flow |
| [`ui/`](ui/GUIDE.md) + `assets/` + `art_source/` | **Fah** | Sprites, title/story/end screens, HUD, sounds, effects |
| `autoload/events.gd`, `project.godot`, `docs/` | shared, don't make any change to these files na ja pls |

## Project layout

```
autoload/      Events (shared signals) + GameState (timer, level flow)
levels/        level.gd base + level_1.tscn, level_2.tscn, tiles/
player/        player.tscn, bullet.tscn
enemies/       enemy.gd + enemy_basic/fast/tank.tscn, wave_manager.gd
laser/         laser_manager.gd, laser_pickup.tscn, aim_mode.gd, origins/egg + commander
game/          game.tscn: builds one level and wires everything together
ui/            title_screen, story_screen, hud, end_screen
assets/        sprites/ (in-game), home/ (title art), audio/, fonts/
art_source/    Illustrator source files (Godot ignores this folder)
sandbox/       personal test scenes
docs/          design doc + contracts
```

## How the pieces connect

```
title_screen ──START──► story_screen ──► game.tscn ──► (win) story ──► game (L2) ──► story(ending) ──► end_screen
                                            │
       game.gd builds:  Level (Mew) ─ Player (Yang) ─ WaveManager (Ploy) ─ LaserManager + Origin (Kong) ─ HUD (Fah)
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
