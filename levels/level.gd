class_name Level
extends Node2D
## Level base script. Mew's.
##
## Put this on the root of every level scene (level_1, level_2). game.gd (Kong)
## only talks to a level through the helper functions below, so you can change
## how the map looks as much as you want as long as the node names from
## docs/contracts.md section 5 stay the same.
##
## How to build a level:
##   1. Click `Walls` (TileMapLayer). The "Tech Lab" tileset is already set up
##      (levels/tiles/techlab_tileset.tres, free CC0 art):
##        tiles 0, 1, 2 = walls WITH collision (plain steel, steel + light, console)
##        tiles 3, 4    = floors, no collision (panel, vent)
##      Paint the floor everywhere first, then paint walls on top.
##      Grid is 32 px, so 1280x720 is 40 x 22.5 tiles. Keep corridors at least 2 tiles wide.
##   2. Click a Path2D under `Paths` and use the "Add Point" tool at the top of
##      the 2D view to draw the route through the corridors.
##        - the FIRST point is where enemies appear (put it at the egg)
##        - enemies loop the path, so the last point should lead back near the start
##        - Ctrl+D on Path_A to add more routes. Name them Path_C, Path_D...
##   3. Move `PlayerStart`, `OriginSpot` and the `LaserSpawns/Spot*` markers where you want them.
##   4. Level 2 only: draw `OriginPath`, the loop the Commander walks.
##
## To test: open the level scene and press F6. To walk around inside it, run
## sandbox/yang_test.tscn (loads level_1 with the player).

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
