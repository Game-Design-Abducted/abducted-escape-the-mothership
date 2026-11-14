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
## It looks alive without extra art: it breathes all the time, bulges when a
## monster comes out (game.gd calls pulse()), and when the laser destroys it,
## it flashes white, shakes, swaps to the Dead sprite and sinks away.
##
## TODO Ploy:
##  - destroy animation (done, see above; swap in Fah's VFX if she makes some)
##  - maybe more than 1 laser hit for the Commander? (`laser_hits_needed`)

## How close (pixels) the laser line must pass to the center to count as a hit
@export var hit_radius := 48.0
@export var laser_hits_needed := 1

@export_group("Sprites")
@export var normal_texture: Texture2D
@export var hit_texture: Texture2D
@export var dead_texture: Texture2D

@export_group("Look")
## Idle breathing: how much the sprite grows and shrinks (0.04 = 4 %) and how fast
@export var breathe_amount := 0.04
@export var breathe_speed := 2.2

var _hits := 0
var destroyed := false
var _base_scale := Vector2.ONE
var _breath := 0.0
var _bulge := 0.0          # extra scale from pulse(), eases back to 0
var _shake := 0.0          # pixels of shake left after the laser hit
var _sprite_home := Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D


func _enter_tree() -> void:
	# Keep breathing and dying while the game is paused for aiming
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_base_scale = sprite.scale
	_sprite_home = sprite.position


func _process(delta: float) -> void:
	_animate(delta)


## Call from _process. A subclass that overrides _process (the Commander) calls it too.
func _animate(delta: float) -> void:
	if destroyed:
		_shake = move_toward(_shake, 0.0, 30.0 * delta)
		sprite.position = _sprite_home + Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		return
	_breath += delta * breathe_speed
	_bulge = move_toward(_bulge, 0.0, delta * 0.6)
	var s := 1.0 + sin(_breath) * breathe_amount + _bulge
	sprite.scale = _base_scale * Vector2(s, 2.0 - s)   # wider when shorter, like breathing


## A quick bulge, e.g. when a monster comes out
func pulse() -> void:
	if not destroyed:
		_bulge = 0.12


func take_laser_hit() -> void:
	if destroyed:
		return
	_hits += 1
	if _hits >= laser_hits_needed:
		destroyed = true
		if dead_texture:
			sprite.texture = dead_texture
		_play_destroyed()
		Events.origin_destroyed.emit()
	elif hit_texture:
		sprite.texture = hit_texture
		await get_tree().create_timer(0.3, false).timeout
		if is_inside_tree() and not destroyed:
			sprite.texture = normal_texture


## White flash, shake, a swell, then it sinks and fades. About 1.3 s, which fits
## inside GameState's 1.5 s wait before the scene changes.
func _play_destroyed() -> void:
	_shake = 10.0
	sprite.scale = _base_scale
	sprite.modulate = Color(4.0, 4.0, 4.0)   # over-bright = white flash
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)
	tween.parallel().tween_property(sprite, "scale", _base_scale * 1.25, 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.35)
	tween.tween_property(sprite, "scale", _base_scale * Vector2(1.2, 0.6), 0.7).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)


## True if a laser fired from `from` in direction `dir` passes through this origin.
## Pure math, so it also works while the game is paused.
func is_hit_by_ray(from: Vector2, dir: Vector2) -> bool:
	var to_center := global_position - from
	var along := to_center.dot(dir.normalized())
	if along < 0.0:
		return false   # origin is behind the player
	var closest := from + dir.normalized() * along
	return closest.distance_to(global_position) <= hit_radius
