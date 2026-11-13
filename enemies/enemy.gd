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
##  - emits Events.enemy_killed(self) when it dies, Events.enemy_hit(self)
##    when it is hurt but survives (game.gd plays the sounds)
##
## TODO Ploy:
##  - basic movement along a path (done, works)
##  - make the 3 types feel different (done: speed, HP, fast zig-zags,
##    tank stops at corners)
##  - hit flash + death sprite (the textures are already exported below)
##  - level 2 difficulty (see WAVES[2] in wave_manager.gd)
##  - talk to the group about what happens at the END of a path.
##    Right now it loops forever. Could damage the ship instead (tower defense
##    style), e.g. a new signal Events.core_damaged.

@export var speed := 80.0
@export var max_hp := 1
@export var contact_damage := 1
## Fast monster: sideways wobble in px (0 = off) and wobble cycles per second
@export var zigzag_amplitude := 0.0
@export var zigzag_speed := 3.0
## Tank: seconds to stop at each corner of the path (0 = never stops)
@export var corner_pause := 0.0

@export_group("Sprites")
@export var normal_texture: Texture2D
@export var hit_texture: Texture2D
@export var dead_texture: Texture2D

const CONTACT_CHECK_INTERVAL := 0.2

var hp: int
var _dead := false
var _contact_tick := CONTACT_CHECK_INTERVAL
var _zigzag_time := 0.0
var _pause_left := 0.0
var _corners := PackedFloat32Array()   # filled on first use, see _corner_offsets()

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
	if _pause_left > 0.0:
		_pause_left -= delta
	else:
		var before := progress
		progress += speed * delta
		_stop_at_corner(before)
	_apply_zigzag(delta)
	# body_entered only fires at the moment of first touch, so re-check a few
	# times per second. Otherwise a player who stays on top of a monster (or
	# touched it while invincible) would never be hurt again.
	_contact_tick -= delta
	if _contact_tick <= 0.0:
		_contact_tick = CONTACT_CHECK_INTERVAL
		for body in hitbox.get_overlapping_bodies():
			_on_hitbox_body_entered(body)


## If we just walked past a corner (interior curve point), snap to it and wait.
## Handles the loop wrap: progress dropping means we passed the end and restarted.
func _stop_at_corner(before: float) -> void:
	if corner_pause <= 0.0:
		return
	if _corners.is_empty():
		_corners = _corner_offsets((get_parent() as Path2D).curve)
	var wrapped := progress < before
	for c in _corners:
		var crossed := (c > before or c <= progress) if wrapped else (before < c and c <= progress)
		if crossed:
			progress = c
			_pause_left = corner_pause
			return


## Distance along the path to each interior point. Measured as the length of the
## curve up to that point, so a path that crosses itself still gets the right spot.
static func _corner_offsets(curve: Curve2D) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	var part := Curve2D.new()
	part.bake_interval = curve.bake_interval
	for i in curve.point_count - 1:
		part.add_point(curve.get_point_position(i), curve.get_point_in(i), curve.get_point_out(i))
		if i >= 1:
			result.append(part.get_baked_length())
	return result


## Wobble sideways (perpendicular to the path direction) on every leg.
func _apply_zigzag(delta: float) -> void:
	if zigzag_amplitude <= 0.0:
		return
	_zigzag_time += delta
	var curve := (get_parent() as Path2D).curve
	var a := curve.sample_baked(progress)
	var b := curve.sample_baked(progress + 2.0)
	if a.is_equal_approx(b):   # at the very end of the curve, look backwards
		b = a
		a = curve.sample_baked(progress - 2.0)
	var dir := (b - a).normalized()
	var side := Vector2(-dir.y, dir.x) * sin(_zigzag_time * TAU * zigzag_speed) * zigzag_amplitude
	h_offset = side.x
	v_offset = side.y


func take_damage(amount: int) -> void:
	if _dead:
		return
	hp -= amount
	if hp <= 0:
		die()
		return
	Events.enemy_hit.emit(self)
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
