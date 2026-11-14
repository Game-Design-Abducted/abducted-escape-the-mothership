class_name Player
extends CharacterBody2D
## Player. Yang's.
##
## Already working (starter code):
##  - 8-direction movement with WASD/arrows, blocked by walls (layer 1)
##  - `attack` (Space/J) shoots a bullet where you're facing
##  - take_damage(): HP goes down, short invincibility, Events.player_died at 0
##
## Other people's code relies on these, so please don't rename them:
##  - root is in group "player", collision layer 2 (player), mask 1 (walls)
##  - func take_damage(amount: int), Ploy's enemies call it on contact
##  - emits Events.player_hp_changed(hp, max_hp) and Events.player_died
##  - laser_pickup.gd detects this body, and aim_mode.gd reads global_position (both are yours too now)
##
## TODO Yang:
##  - decide how movement should feel: free 8-dir (what we have) or
##    Pac-Man grid movement (4-dir, snaps to the 32px corridors, buffered
##    turns). See _get_move_dir().
##  - attack cooldown / ammo? damage numbers? tune bullet speed
##  - hit flash + death effect (done: hit sprite, blink, spin and fade on death)
##  - check the laser pickup (laser_pickup.gd) works with your player (it should already,
##    it detects you through layer 2)
##  - bug fixing

@export var speed := 180.0
@export var max_hp := 3
@export var invincible_time := 1.0
@export var attack_cooldown := 0.25
@export var bullet_scene: PackedScene = preload("res://player/bullet.tscn")

@export_group("Sprites")
@export var normal_texture: Texture2D = preload("res://assets/sprites/Player.png")
@export var hit_texture: Texture2D = preload("res://assets/sprites/Player_Hit.png")
@export var dead_texture: Texture2D = preload("res://assets/sprites/Player_Dead.png")

const HIT_FLASH_TIME := 0.15   ## how long the hit sprite shows
const BLINK_TIME := 0.08       ## half a blink while invincible

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
	# Hit sprite for a moment, then blink until the invincibility runs out
	var blinks := maxi(int((invincible_time - HIT_FLASH_TIME) / (BLINK_TIME * 2.0)), 1)
	var tween := create_tween()
	tween.tween_callback(func(): sprite.texture = normal_texture).set_delay(HIT_FLASH_TIME)
	for i in blinks:
		tween.tween_property(sprite, "modulate:a", 0.3, BLINK_TIME)
		tween.tween_property(sprite, "modulate:a", 1.0, BLINK_TIME)
	tween.finished.connect(func(): _invincible = false)


func die() -> void:
	sprite.texture = dead_texture
	Events.player_died.emit()
	# GameState waits 1.5 s before the end screen, so this plays in that time
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.4, 1.4), 0.12)
	tween.tween_callback(_death_fade)


func _death_fade() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(0.6, 0.6), 0.9)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.9)
	tween.tween_property(sprite, "rotation", PI, 0.9)


func _emit_hp() -> void:
	Events.player_hp_changed.emit(hp, max_hp)
