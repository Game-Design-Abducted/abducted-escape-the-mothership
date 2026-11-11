class_name Origin
extends Area2D
## Monster origin (base script). Ploy's.
##
## Level 1: egg.tscn (stands still at Mew's OriginSpot)
## Level 2: commander.tscn (walks along Mew's OriginPath, see commander.gd)
##
## Normal bullets can't hurt it. There's no take_damage() here on purpose,
## only the laser calls take_laser_hit().
##
## Layer 6 (origin), group "origin".
##
## TODO Ploy:
##  - destroy animation / explosion (ask Fah for VFX)
##  - maybe more than 1 laser hit for the Commander? (`laser_hits_needed`)

## How close (pixels) the laser line must pass to the center to count as a hit
@export var hit_radius := 48.0
@export var laser_hits_needed := 1

@export_group("Sprites")
@export var normal_texture: Texture2D
@export var hit_texture: Texture2D
@export var dead_texture: Texture2D

var _hits := 0
var destroyed := false

@onready var sprite: Sprite2D = $Sprite2D


func take_laser_hit() -> void:
	if destroyed:
		return
	_hits += 1
	if _hits >= laser_hits_needed:
		destroyed = true
		if dead_texture:
			sprite.texture = dead_texture
		Events.origin_destroyed.emit()
	elif hit_texture:
		sprite.texture = hit_texture
		await get_tree().create_timer(0.3, false).timeout
		if is_inside_tree() and not destroyed:
			sprite.texture = normal_texture


## True if a laser fired from `from` in direction `dir` passes through this origin.
## Pure math, so it also works while the game is paused.
func is_hit_by_ray(from: Vector2, dir: Vector2) -> bool:
	var to_center := global_position - from
	var along := to_center.dot(dir.normalized())
	if along < 0.0:
		return false   # origin is behind the player
	var closest := from + dir.normalized() * along
	return closest.distance_to(global_position) <= hit_radius
