class_name Enemy
extends PathFollow2D
## Enemy base script. Ploy's.
##
## Every monster is a PathFollow2D. It has to be a CHILD of one of Mew's
## Path2D nodes, and it walks along by increasing `progress`.
## (wave_manager.gd already does this for you.)
##
## The 3 monster scenes share this script, only the numbers differ:
##   enemy_basic.tscn  Monster1  normal speed, 1 HP
##   enemy_fast.tscn   Monster2  fast, 1 HP
##   enemy_tank.tscn   Monster3  slow, 3 HP
## To change stats, click the root node of the scene and edit the Inspector.
##
## Other people's code relies on these, so don't break them:
##  - root is in group "enemies"
##  - child `Hitbox` (Area2D) on layer 3 (enemies), mask 2 (player)
##      Yang's bullets find it and call take_damage() on this root
##      touching the player calls player.take_damage(contact_damage)
##  - emits Events.enemy_killed(self) when it dies
##
## TODO Ploy:
##  - basic movement along a path (done, works)
##  - make the 3 types feel different (speed, HP, movement pattern,
##    e.g. the fast one zig-zags with v_offset, the tank stops at corners)
##  - hit flash + death sprite (the textures are already exported below)
##  - level 2 difficulty (see WAVES[2] in wave_manager.gd)
##  - talk to the group about what happens at the END of a path.
##    Right now it loops forever. Could damage the ship instead (tower defense
##    style), e.g. a new signal Events.core_damaged.

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
