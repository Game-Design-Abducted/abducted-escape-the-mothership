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
const POINTER_DIST := 30.0     ## aim arrow distance from the middle, px
const LEAN := 0.16             ## radians of tilt when running sideways
const KICK_PX := 3.0           ## recoil per shot
const HAND := Vector2(19, 8)    ## right hand in the art, px from the middle (left = mirrored)
const GUN_GRIP := Vector2(2.5, 5.0)   ## grip pixel in GUN_ART, the gun pivots around it
const MUZZLE := Vector2(11.5, 1.5)    ## where bullets come out, pixel in GUN_ART
## blaster pixel art, pointing right. o outline, w body, c stripe, y muzzle, g grip
const GUN_ART := [
	"..oooooooo..",
	".owwwwwwwwoy",
	".occcccccwoy",
	".oowwwwwwoo.",
	".ogoo.......",
	".ogo........",
	".oo.........",
]
const GUN_COLORS := {
	"o": Color(0.15, 0.05, 0.25), "w": Color(0.88, 0.9, 0.96), "c": Color(0.35, 0.8, 1.0),
	"y": Color(1.0, 0.85, 0.2), "g": Color(0.45, 0.45, 0.55),
}
@export var show_aim_arrow := false

var hp: int
var facing := Vector2.RIGHT
var _invincible := false
var _cooldown := 0.0
var _lean := 0.0
var _kick := 0.0
## Ship pranks (game/ship_pranks.gd)
var controls_reversed := false   ## CONTROLS REVERSED: left is right
var slippery := false            ## FLOOR WAX DAY: you slide instead of stopping
const SLIP_GRIP := 2.2           ## how fast you get a grip on the wax (higher = less slide)

@onready var sprite: Sprite2D = $Sprite2D
var _gun: Sprite2D


func _ready() -> void:
	hp = max_hp
	_gun = Sprite2D.new()
	_gun.texture = _gun_texture()
	_gun.offset = Vector2(GUN_ART[0].length(), GUN_ART.size()) * 0.5 - GUN_GRIP
	_gun.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_gun)
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
	_animate(dir, delta)

	_cooldown -= delta
	if Input.is_action_pressed("attack") and _cooldown <= 0.0:
		shoot()


# the art always faces the camera, so the arrow + lean are what show your aim
func _animate(dir: Vector2, delta: float) -> void:
	_lean = lerpf(_lean, dir.x * LEAN, minf(12.0 * delta, 1.0))
	_kick = maxf(_kick - delta * 8.0, 0.0)
	sprite.rotation = _lean
	sprite.position = -facing * KICK_PX * _kick
	sprite.scale = Vector2(1.0 + 0.08 * _kick, 1.0 - 0.08 * _kick)
	var left := sprite.flip_h   # straight up/down keeps the hand you last turned to
	_gun.position = Vector2(-HAND.x if left else HAND.x, HAND.y) + sprite.position - facing * KICK_PX * _kick
	_gun.rotation = facing.angle()
	_gun.scale = Vector2(2, -2 if facing.x < -0.01 or (left and absf(facing.x) < 0.01) else 2)   # mirror so the grip stays under the barrel
	queue_redraw()


static func _gun_texture() -> Texture2D:
	var img := Image.create(GUN_ART[0].length(), GUN_ART.size(), false, Image.FORMAT_RGBA8)
	for y in GUN_ART.size():
		for x in GUN_ART[y].length():
			var key: String = GUN_ART[y][x]
			if GUN_COLORS.has(key):
				img.set_pixel(x, y, GUN_COLORS[key])
	return ImageTexture.create_from_image(img)


func _draw() -> void:
	if hp <= 0 or not show_aim_arrow:
		return
	var side := facing.orthogonal() * 8.0
	var base := facing * (POINTER_DIST + _kick * 3.0)
	var tip := base + facing * 12.0
	var arrow := PackedVector2Array([tip, base + side, base - side])
	draw_colored_polygon(arrow, Color(1.0, 0.85, 0.2, 0.9 + 0.1 * _kick))
	draw_polyline(PackedVector2Array([tip, base + side, base - side, tip]), Color(0.15, 0.05, 0.25, 1.0), 2.0)


func _get_move_dir() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func shoot() -> void:
	_cooldown = attack_cooldown
	_kick = 1.0
	var bullet = bullet_scene.instantiate()
	bullet.direction = facing
	var muzzle := _gun.to_global(MUZZLE - GUN_GRIP)
	var body := global_position + facing * 20.0
	# the gun sits off to the side, so near walls fire from the body instead: no shots through walls or eaten by the wall you hug
	if _gun_in_wall(muzzle) or (not _path_clear(muzzle) and _path_clear(body)):
		muzzle = body
	bullet.global_position = muzzle
	get_parent().add_child(bullet)


func _gun_in_wall(muzzle: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	if not space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, muzzle, 1)).is_empty():
		return true
	return not space.intersect_shape(_bullet_query(muzzle, Vector2.ZERO), 1).is_empty()


func _path_clear(from: Vector2) -> bool:
	return get_world_2d().direct_space_state.cast_motion(_bullet_query(from, facing * 40.0))[0] >= 1.0


func _bullet_query(at: Vector2, motion: Vector2) -> PhysicsShapeQueryParameters2D:
	var circle := CircleShape2D.new()
	circle.radius = 6.0   # bullet radius + a pixel
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = circle
	q.transform = Transform2D(0.0, at)
	q.motion = motion
	q.collision_mask = 1
	return q


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
	queue_redraw()   # hides the aim arrow
	_gun.hide()
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
