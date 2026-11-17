# Abducted: Escape the Mothership

A 2D action game that mixes a Pac-Man style maze with tower defense, made in **Godot 4.3 (GDScript)**.

Aliens have abducted you. Their ship is full of monsters that keep hatching from a monster origin, and your blaster can't hurt the origin. Kill enough monsters to charge the alien laser, grab it, win a quick laser mini-game to hit the origin, and get home before the 3-minute timer runs out.

**Play in the browser:** https://game-design-abducted.github.io/abducted-escape-the-mothership/

Design doc: [docs/design.md](docs/design.md). Credits and asset licenses: [CREDITS.md](CREDITS.md).

## Controls

| Keys | Action |
|---|---|
| W A S D / arrow keys | Move |
| Space / J | Shoot |
| K / left click | Fire the laser |
| Esc / P | Pause |

On a phone or tablet (in the browser, held sideways): the left thumb is a joystick, hold the right side to shoot, tap anywhere to fire the laser, and the II button pauses. The game goes full screen on the first tap. On an iPhone, Safari can't do that, so add the game to the Home Screen (Share, then Add to Home Screen) and play from the icon.

## Game flow

Title screen → intro story → **Level 1** → story → **Level 2** → ending story → win / lose screen.

Each level lasts about 1.5–2 minutes for a decent player. The cap is 3 minutes.

| | Level 1: The Egg | Level 2: The Alien Commander |
|---|---|---|
| Origin | A stationary egg | Walks its own route, changes speed at random and sometimes turns around |
| Laser hits to win | 2 | 3 |
| Waves | 7 waves, starting gently | 8 waves, faster and denser |
| Ship pranks | Lights out, floor wax, balloon party | The same plus reversed controls |

## Game mechanics

### The core loop
1. **Survive and shoot.** Monsters hatch from the origin and roam the maze. Touching one costs a heart, and you have 4.
2. **Charge the laser.** Each level sets a kill quota per monster type, shown on the HUD. Filling every quota spawns the laser gun at one of the level's laser spots.
3. **Grab it and fire.** Picking it up freezes the game and starts a laser mini-game aimed at the origin.
4. **Hit or miss.**
   - A hit damages the origin. Destroy it and you win the level.
   - A miss, or a hit that doesn't finish the origin, sends you back to step 2 with a smaller quota.
5. **Lose** if the timer reaches 0 or you run out of hearts.

### Monsters
| Type | Speed | HP | How it moves |
|---|---|---|---|
| Basic | Medium | 1 | Walks steadily |
| Fast | Fast | 1 | Zig-zags side to side |
| Tank | Slow | 3 | Stops briefly at every corner |

- **Routes.** Each monster picks random routes through the maze, so no two runs play the same. Now and then one heads for where you are.
- **Spawning.** Waves come from a timed list. When the list ends it loops, about 15% faster each time.
- **Hatching.** A new monster is small and see-through. It can't hurt you or be hurt for a moment, and it always leaves the origin on the side away from you, so standing near the origin isn't a death trap.

### Laser mini-games
Each laser shot is one of four mini-games, picked at random but never the same one twice in a row. Level 1's first shot is always Sweep, so the first one teaches the idea.

| Mode | How it works |
|---|---|
| **Sweep** | An aim line rotates around you. Fire when it crosses the origin. |
| **Power Shot** | Hold to charge a bar and let go inside the green zone. |
| **Beat Drop** | Rings shrink onto the origin to a beat. Press on at least 2 of 3 beats. Pressing too early or too late loses the beat, so mashing doesn't work. |
| **Trick Shot** | Sweep, but only the beam that bounces off the outer wall counts. |

**Pity laser:** each miss in a row makes the next shot a bit easier (bigger hit area, slower aim line). The bonus resets on a hit. Long shots also get a slightly bigger hit area, so standing far away isn't punished.

### Space Junk (item drops)
Killed monsters sometimes drop an item, at most 2 on the floor at once. If nothing has dropped for 25 seconds, the next kill always drops one.

| Item | Effect |
|---|---|
| Whoopee Bomb | Pops every monster close to it after a short wheeze |
| Disco Ball | Monsters stop to dance for a few seconds and can't hurt you |
| Space Burrito | +1 heart |

### Ship pranks
About every 40 seconds the ship plays a short prank on you, with a warning first. It's the game's running joke and also keeps the middle of a level from feeling the same.

| Prank | What happens |
|---|---|
| **Lights out** | Everything goes dark except a circle around you |
| **Floor wax day** | You slide around on the floor |
| **Balloon party** | Monsters puff up to 1.5x size and slow down: easier to hit, harder to slip past |
| **Controls reversed** (Level 2) | Your movement keys are flipped for 5 seconds |

## Technical overview

### Scene structure
```
title_screen ─► story_screen ─► game.tscn (Level 1) ─► story ─► game.tscn (Level 2) ─► story (ending) ─► end_screen
                                    │
        game.gd builds: Level ─ Player ─ WaveManager ─ LaserManager ─ Origin ─ HUD ─ DropManager ─ ShipPranks ─ PauseMenu
```

- **One game scene, two levels.** `game/game.tscn` loads a level scene (`levels/level_1.tscn` or `level_2.tscn`) and builds everything else around it from code. Every level scene uses the same node names (`Walls`, `Paths`, `PlayerStart`, `OriginSpot`, `LaserSpawns`, `Entities`), so adding a level means drawing a new maze, not changing any code.
- **Systems talk through an event bus.** `autoload/events.gd` is a global list of signals, such as `enemy_killed`, `laser_picked_up`, `laser_fired(hit)` and `player_hp_changed`. Systems emit and listen instead of calling each other, so, for example, the HUD never touches the player or monster code.
- **`GameState` autoload.** Holds the 3-minute countdown, win / lose, which level you're on and which story page to show, and survives scene changes.

### Monster AI and pathfinding (`enemies/`)
- **Monster body.** Each monster is a `PathFollow2D` that walks along a `Path2D` curve. The three types share `enemy.gd` and differ only in their numbers (speed, HP, zig-zag, corner pause).
- **Route planning.** `maze_wander.gd` reads the wall tilemap and builds an `AStarGrid2D` on the tile corners. A corner is walkable only if the four tiles around it are floor, so routes run down the middle of the 2-tile corridors and never clip a wall.
- **Random stops.** When a monster nears the end of its route, it asks for a new random stop at least 6 tiles away and appends that route to its curve, so it never stops.
- **Straight walking.** Raw A\* paths zig-zag in open rooms. They're straightened into long L-shaped legs, so monsters walk straight lines and turn only at real corners.
- **Going around the player.** While a monster is wandering (not chasing), the tiles around the player get a higher A\* cost. Monsters then take another way when there is one, instead of running into you from behind.

### Pausing
Godot's pause system does most of the work.
- **Laser mini-game.** Picking up the laser pauses the scene tree. Monsters, spawn timers and the countdown use the default *Inherit* process mode, so they all freeze automatically.
- **Things that keep running.** The laser mini-game, HUD and pop-up text use *Always* so they keep running. So does the Level 2 Commander, which keeps moving at half speed while you aim, and that's what makes Level 2 harder.
- **Pause menu.** The pause menu stops even the *Always* nodes.

### Combat details
- **Collision layers.** Layers are named in Project Settings: walls, player, enemies, player_attack, pickups, origin. Each object's mask lists only what it needs to hit.
- **Origin can't be shot.** Only the laser can hurt it: it has no `take_damage()`, just `take_laser_hit()`.
- **The blaster.** It points where you shoot and mirrors when aiming left. It checks for a wall between your hand and the muzzle, so bullets can't go through walls when you hug one.

### Balancing with a play-test bot
`tools/playtest_bot.gd` is a scripted, deliberately average player. It plays whole levels at 3x speed and reports win / loss, time, kills and every hit it took.
- **Our target:** the bot wins about 80–95% of runs in 1.5–2 minutes.
- **What we tuned with it:** wave timing, kill quotas, monster speed and how many monsters can be alive at once.
- **Latest results with random routes:** Level 1 won 45 of 48 runs, Level 2 won 23 of 24.

### Automated tests and deployment
- **CI on every pull request** (`.github/workflows/ci.yml`) installs Godot 4.3 and runs two checks:
  - **Load check** (`tools/check_load.gd`): every script and scene loads.
  - **Smoke test** (`tools/smoke_test.gd`): plays the whole game loop headless (title → story → both levels → end screen) and fails on any script error.
- **Web deploy** (`.github/workflows/deploy-web.yml`): every push to `main` exports a web build and publishes it to GitHub Pages.

## Running it

1. Install **Godot 4.3 or newer** (the standard version, not .NET).
2. In Godot, choose *Import* and pick this folder's `project.godot`.
3. Press **F5** to play.

Running the tests yourself:

```bash
godot --headless --path . --import
godot --headless --path . -s tools/check_load.gd
godot --headless --path . -s tools/smoke_test.gd
godot --path . -s tools/playtest_bot.gd -- --level=1 --runs=4
```

## Project layout

```
abducted-escape-the-mothership/
├── project.godot          # input map, autoloads, collision layer names
├── autoload/
│   ├── events.gd          # global signal bus
│   └── game_state.gd      # timer, win / lose, level flow
├── game/
│   ├── game.gd/.tscn      # builds a level and connects every system
│   ├── ship_pranks.gd     # the timed silly twists
│   ├── float_text.gd      # pop-up words ("SPLAT!")
│   └── spawn_marker.gd    # glowing floor mark where monsters come out (Level 2)
├── levels/                # level_1 and level_2 mazes, shared level script, tileset
├── player/                # player movement, blaster, HP, bullets
├── enemies/
│   ├── enemy.gd           # shared monster behavior
│   ├── enemy_*.tscn       # basic, fast, tank
│   ├── wave_manager.gd    # wave lists and spawning
│   └── maze_wander.gd     # A* random routes through the maze
├── laser/
│   ├── laser_manager.gd   # kill quotas, pickup, picks the mini-game, hit / miss
│   ├── aim_mode.gd        # Sweep, and the base for the other modes
│   ├── aim_modes/         # Power Shot, Beat Drop, Trick Shot
│   └── origins/           # Egg (Level 1) and Commander (Level 2)
├── items/                 # Space Junk drops
├── ui/                    # title, story, HUD, pause menu, end screen
├── assets/                # sprites, story art, music, sound effects, fonts
├── tools/                 # load check, smoke test, play-test bot, sprite converter
└── docs/                  # design doc and shared technical rules
```
