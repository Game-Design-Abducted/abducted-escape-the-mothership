# levels/: Mew (Map + Level Designer)

**You own:** `level.gd`, `level_1.tscn`, `level_2.tscn`, `tiles/`
**Others depend on:** the node names in [contracts §5](../docs/contracts.md#5-level-scene-layout-mew). Don't rename them.

## Already set up for you
- Both level scenes have every required node, plus example enemy paths and laser spots.
- A real tileset, `tiles/techlab_tileset.tres` (free CC0 "Tech Lab" pack). **Tiles 0–2 = walls with collision**, tiles 3–4 = floors. The full original pack is in `art_source/techlab_pack/Tileset.png` if you want more tiles (corners, doors, hazard stripes). Ask before adding them.
- How-to steps are in the comment at the top of `level.gd`.

## Tasks
| Deadline | Task |
|---|---|
| **Nov 11** | Level 1 maze painted in `Walls`, enemy routes `Path_A/B/...` follow the corridors |
| **Nov 13** | Level 2 maze (harder), `OriginPath` route for the Commander, balance spawn spots |
| **Nov 15** | Play both levels and adjust (corridor width, too easy / too hard, laser spots reachable?) |

## Tips
- Corridors at least **2 tiles wide (64 px)**. The player and monsters are ~44 px.
- Enemy paths should run down the *middle* of corridors (tile center = multiple of 32 + 16).
- Path point 1 = spawn point. Put it at `OriginSpot` so monsters come out of the egg.
- Laser spots should be somewhat far from the origin, so grabbing the laser takes some risk.
- Each Level should look a bit different: e.g. Level 1 mostly plain steel walls, Level 2 more consoles.

## Test
- Open `level_1.tscn` → **F6** shows the layout.
- `sandbox/yang_test.tscn` → **F6** lets you walk around level 1 with the player.
- `sandbox/ploy_test.tscn` → **F6** shows enemies walking your paths.
