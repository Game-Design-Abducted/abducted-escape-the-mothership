class_name Player
extends CharacterBody2D
## =====================================================================
## PLAYER. OWNER: Yang (Player + Combat Programmer)
## =====================================================================
## What already works (starter code):
##   - 8-direction movement with WASD/arrows, blocked by walls (layer 1)
##   - `attack` (Space/J) shoots a bullet in the facing direction
##   - take_damage(): HP goes down, short invincibility, Events.player_died at 0
##
## Contract (others rely on this, don't rename):
##   - Root is in group "player", collision layer 2 (player), mask 1 (walls)
##   - func take_damage(amount: int)   <- Ploy's enemies call this on contact
##   - Emits Events.player_hp_changed(hp, max_hp) and Events.player_died
##   - Kong's laser pickup detects this body; Kong's aim mode reads global_position
##
## TODO (Yang):
##   Nov 11  [ ] Decide movement feel: free 8-dir (now) or Pac-Man grid movement
##               (4-dir, snaps to 32px corridors, buffered turns). See _get_move_dir().
##   Nov 13  [ ] Attack cooldown / ammo? Damage numbers? Tune bullet speed.
##           [ ] Hit flash (Player_Hit.png) + death sprite (Player_Dead.png)
##   Nov 14  [ ] Integrate with Kong's laser pickup (just make sure the pickup
##               detects you. It already should, via layer 2.)
##   Nov 15  [ ] Bug fixing

@export var speed := 180.0
@export var max_hp := 3
@export var invincible_time := 1.0
@export var attack_cooldown := 0.25
@export var bullet_scene: PackedScene = preload("res://player/bullet.tscn")

@export_group("Sprites")
@export var normal_texture: Texture2D = preload("res://assets/sprites/Player.png")
@export var hit_texture: Texture2D = preload("res://assets/sprites/Player_Hit.png")
@export var dead_texture: Texture2D = preload("res://assets/sprites/Player_Dead.png")

var hp: int
var facing := Vector2.RIGHT
var _invincible := false
var _cooldown := 0.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	hp = max_hp
	_emit_hp.call_deferred()   # deferred so the HUD exists before we tell it


func _physics_process(delta: float) -> void:
	if hp <= 0:
		return
	var dir := _get_move_dir()
	velocity = dir * speed
	if dir != Vector2.ZERO:
		facing = dir.normalized()
		sprite.flip_h = facing.x < 0
	move_and_slide()

	_cooldown -= delta
	if Input.is_action_pressed("attack") and _cooldown <= 0.0:
		shoot()


func _get_move_dir() -> Vector2:
	# Free movement. Replace this for Pac-Man style grid movement if you want it.
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func shoot() -> void:
	_cooldown = attack_cooldown
	var bullet = bullet_scene.instantiate()
	bullet.direction = facing
	bullet.global_position = global_position + facing * 20.0
	get_parent().add_child(bullet)


func take_damage(amount: int) -> void:
	if _invincible or hp <= 0:
		return
	hp = maxi(hp - amount, 0)
	_emit_hp()
	if hp <= 0:
		die()
		return
	# Short invincibility so one monster can't hit you every frame
	_invincible = true
	sprite.texture = hit_texture
	await get_tree().create_timer(invincible_time, false).timeout
	if not is_inside_tree():
		return
	_invincible = false
	sprite.texture = normal_texture


func die() -> void:
	sprite.texture = dead_texture
	Events.player_died.emit()


func _emit_hp() -> void:
	Events.player_hp_changed.emit(hp, max_hp)
