class_name Level
extends Node2D
## =====================================================================
## LEVEL BASE SCRIPT. OWNER: Mew
## =====================================================================
## Attach this script to the root of every level scene (level_1, level_2).
## game.gd (Kong) only talks to a level through the helper functions below,
## so you can change how the map looks freely, as long as the node names
## from docs/contracts.md §5 stay the same.
##
## HOW TO BUILD A LEVEL
##   1. Select `Walls` (TileMapLayer). The "Tech Lab" tileset is already set
##      (levels/tiles/techlab_tileset.tres, free CC0 art):
##        tiles 0,1,2 = walls WITH collision (plain steel, steel + light, console)
##        tiles 3,4   = floors, no collision (panel, vent)
##      Paint floor everywhere first, then paint the walls on top.
##      Grid is 32 px. 1280x720 = 40 x 22.5 tiles. Corridors at least 2 tiles wide.
##   2. Select a Path2D under `Paths` → use the "Add Point" tool at the top of
##      the 2D view to draw the route through the corridors.
##      * The FIRST point is where enemies appear (put it at the egg).
##      * Enemies loop the path, so the last point should lead back near the start.
##      * Duplicate Path_A (Ctrl+D) to add more routes. Name them Path_C, Path_D...
##   3. Move `PlayerStart`, `OriginSpot`, and the `LaserSpawns/Spot*` markers.
##   4. Level 2 only: draw `OriginPath`, the loop the Commander walks.
##
## TEST: open the level scene and press F6. To walk around inside it, run
## sandbox/yang_test.tscn (it loads level_1 with the player).

## Shown in the HUD / story screen if you want it
@export var level_title := "Level"


func get_enemy_paths() -> Array[Path2D]:
	var result: Array[Path2D] = []
	for child in $Paths.get_children():
		if child is Path2D:
			result.append(child)
	return result


func get_player_start() -> Vector2:
	return $PlayerStart.global_position


func get_origin_spot() -> Vector2:
	return $OriginSpot.global_position


## Level 2 Commander route. Returns null if the path has no points.
func get_origin_path() -> Path2D:
	var p := get_node_or_null("OriginPath") as Path2D
	if p and p.curve and p.curve.point_count >= 2:
		return p
	return null


func get_laser_spawn_points() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for child in $LaserSpawns.get_children():
		if child is Node2D:
			result.append(child.global_position)
	return result


## Container where the player and other runtime objects get added (y-sorted)
func get_entities() -> Node2D:
	return $Entities
