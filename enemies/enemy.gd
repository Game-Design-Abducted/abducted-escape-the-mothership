class_name Enemy
extends PathFollow2D
## =====================================================================
## ENEMY BASE SCRIPT. OWNER: Ploy (Enemy + Wave Programmer)
## =====================================================================
## Every monster is a PathFollow2D: it must be added as a CHILD of one of
## Mew's Path2D nodes, then it walks along that path by increasing `progress`.
## (wave_manager.gd does this for you.)
##
## The 3 monster scenes all use this one script with different numbers:
##   enemy_basic.tscn  Monster1  normal speed, 1 HP
##   enemy_fast.tscn   Monster2  fast, 1 HP
##   enemy_tank.tscn   Monster3  slow, 3 HP
## To change stats, select the root node of that scene and edit the Inspector.
##
## Contract (others rely on this):
##   - Root in group "enemies"
##   - Child `Hitbox` (Area2D): layer 3 (enemies), mask 2 (player)
##       -> Yang's bullets find it and call take_damage() on this root
##       -> touching the player calls player.take_damage(contact_damage)
##   - Emits Events.enemy_killed(self) when it dies
##
## TODO (Ploy):
##   Nov 11  [x] Basic movement along a path (works)
##   Nov 13  [ ] Make the 3 types feel different (speed/HP/movement pattern,
##               e.g. fast one zig-zags with v_offset, tank pauses at corners)
##           [ ] Hit flash + death sprite (textures are already exported below)
##   Nov 14  [ ] Level 2 difficulty (see wave_manager.gd WAVES[2])
##   ?       [ ] Decide with the group: what happens at the END of a path?
##               Now: loop forever. Option: damage the ship (tower-defense
##               style), e.g. emit a new signal Events.core_damaged.

@export var speed := 80.0
@export var max_hp := 1
@export var contact_damage := 1

@export_group("Sprites")
@export var normal_texture: Texture2D
@export var hit_texture: Texture2D
@export var dead_texture: Texture2D

var hp: int
var _dead := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: Area2D = $Hitbox


func _ready() -> void:
	hp = max_hp
	loop = true
	rotates = false
	if normal_texture:
		sprite.texture = normal_texture
	hitbox.body_entered.connect(_on_hitbox_body_entered)


func _process(delta: float) -> void:
	if _dead:
		return
	progress += speed * delta


func take_damage(amount: int) -> void:
	if _dead:
		return
	hp -= amount
	if hp <= 0:
		die()
		return
	_flash_hit()


func die() -> void:
	_dead = true
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	if dead_texture:
		sprite.texture = dead_texture
	Events.enemy_killed.emit(self)
	await get_tree().create_timer(0.4, false).timeout
	queue_free()


func _flash_hit() -> void:
	if hit_texture == null:
		return
	sprite.texture = hit_texture
	await get_tree().create_timer(0.15, false).timeout
	if not _dead and is_inside_tree():
		sprite.texture = normal_texture


func _on_hitbox_body_entered(body: Node) -> void:
	if not _dead and body.is_in_group("player"):
		body.take_damage(contact_damage)
