class_name Player
extends CharacterBody2D
## Player. Yang's.
## others rely on: group "player", layer 2 / mask 1, take_damage(amount). don't rename.

@export var speed := 180.0
@export var max_hp := 4
@export var invincible_time := 1.5
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
## Ship pranks (game/ship_pranks.gd)
var controls_reversed := false   ## CONTROLS REVERSED: left is right
var slippery := false            ## FLOOR WAX DAY: you slide instead of stopping
const SLIP_GRIP := 2.2           ## how fast you get a grip on the wax (higher = less slide)

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	hp = max_hp
	_emit_hp.call_deferred()   # deferred so the HUD exists before we tell it


func _physics_process(delta: float) -> void:
	if hp <= 0:
		return
	var dir := _get_move_dir()
	if controls_reversed:
		dir = -dir
	if slippery:
		velocity = velocity.lerp(dir * speed, minf(SLIP_GRIP * delta, 1.0))
	else:
		velocity = dir * speed
	if dir != Vector2.ZERO:
		facing = dir.normalized()
		sprite.flip_h = facing.x < 0
	move_and_slide()

	_cooldown -= delta
	if Input.is_action_pressed("attack") and _cooldown <= 0.0:
		shoot()


func _get_move_dir() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func shoot() -> void:
	_cooldown = attack_cooldown
	var bullet = bullet_scene.instantiate()
	bullet.direction = facing
	bullet.global_position = global_position + facing * 20.0
	get_parent().add_child(bullet)


## Space Snack drop: +amount HP, never above max_hp
func heal(amount: int) -> void:
	if hp <= 0:
		return
	hp = mini(hp + amount, max_hp)
	_emit_hp()


func take_damage(amount: int) -> void:
	if _invincible or hp <= 0:
		return
	hp = maxi(hp - amount, 0)
	_emit_hp()
	if hp <= 0:
		die()
		return
	# so one monster can't hit you every frame
	_invincible = true
	sprite.texture = hit_texture
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
	# GameState waits 1.5 s before the end screen, this plays in that gap
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
