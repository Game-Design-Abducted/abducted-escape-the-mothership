# ui/ + assets/ + art_source/: Fah (Art + UI + Animation)

**You own:** `ui/` (title, story, HUD, end screen), `assets/` (sprites, home art, audio, fonts), `art_source/` (.ai files)
**Others depend on:** the sprite **file names** in `assets/sprites/`. Scenes load them by path, so if you rename a file, Godot breaks the scenes that use it. To update art, **overwrite the file with the same name**.

## Already done ✅
- All character, monster, egg, big monster, laser, heart sprites → `assets/sprites/`
- Home screen pieces → `assets/home/`, Illustrator file → `art_source/`
- Starter title screen (uses Homescreen.jpg), story screen with text, HUD (hearts, timer, laser status), end screen

## How your art is used in game
| File | Used by |
|---|---|
| Player / _Hit / _Dead | player.tscn (Yang) |
| Monster1/2/3 (+ _Hit, _Dead) | enemy_basic / fast / tank (Ploy) |
| Egg (+ _Hit, _Dead) | Level 1 origin (Kong) |
| BigMonster (+ _Hit, _Dead) | Level 2 Alien Commander (Kong) |
| Bullet | player's normal shot |
| Laser Item / Laser | laser pickup / laser beam (Kong) |
| Heart / HeartDeducted | HUD hearts |
| Spaceship | not used yet: title UFO / ending? |

## Still missing (please make)
- [ ] *(optional)* Own wall + floor tiles, 32×32 px. For now the levels use the free CC0 "Tech Lab" tiles (see CREDITS.md). Replace them only if you want a matching purple style
- [ ] Story screen / loading art, win & lose art
- [ ] Sounds: shoot, enemy hit/die, player hit, laser pickup, laser fire, win, lose, music
- [ ] Pixel font (.ttf) → `assets/fonts/`

## Sprite sizes (already converted for you)
Your 1001×1001 exports are a perfect 32×32 pixel grid, so they were converted **without any quality loss** to crisp game-sized PNGs:
- `assets/sprites/*.png` → **64×64** (2 screen px per art pixel). The `_Dead` crops keep their own size (e.g. 48×46).
- Your original big files are kept in `art_source/hires_sprites/` (Godot ignores that folder).
- In game: characters at scale 1 (~44 px tall), Egg & BigMonster at scale 2, bullet at 0.5. Filter = Nearest, so the edges stay sharp.

**Adding or updating a sprite:** draw on the same 32×32 grid and export at **64×64** (or 32×32, then tell the owner to double the scale). Use exactly the same file name.
Or keep exporting 1001×1001 into `art_source/hires_sprites/` and ask for the conversion script to be run again.

## Tasks
| Deadline | Task |
|---|---|
| **Nov 12** | Player, monsters, egg, laser sprites ✅ (done, converted to 64 px) |
| **Nov 14** | Animations + visual effects (hit flash, explosions, laser beam, heart lost) |
| **Nov 15** | Home screen polish, loading screen, story screens, promotional document draft |

## Test
- Open any ui scene and press **F6**. `game/game.tscn` → **F6** shows the HUD in action.
