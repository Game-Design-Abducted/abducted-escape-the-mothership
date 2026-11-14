class_name Level
extends Node2D
## Level base script, on the root of every level scene. Mew's.
## game.gd finds things by node name, keep: Walls, Paths, PlayerStart, OriginSpot, LaserSpawns, Entities.
## building a level:
##   Walls: 32 px grid, tiles 0-2 are walls, 3-4 floor. paint floor first, then walls. corridors 2+ tiles wide.
##   Paths: each Path2D's first point is at the egg (enemies spawn there), last point back near the start.
##   move PlayerStart, OriginSpot and LaserSpawns/Spot*. level 2 also needs OriginPath.

## Shown in the HUD / story screen
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
