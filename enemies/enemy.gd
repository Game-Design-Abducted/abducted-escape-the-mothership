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
## How a monster looks alive (all done in code, on the one sprite Fah drew):
##  - HATCH: it grows out of the origin for `spawn_protection` seconds. While
##    hatching it can't be hurt and can't hurt, so nobody can farm kills by
##    standing on the egg, and nobody gets hit by a monster they couldn't see.
##  - WALK: it bobs as it walks (the art faces the camera, so it never flips).
##  - HIT: Hit sprite + a quick pop.   DEATH: Dead sprite, floats up and fades.
##
## TODO Ploy:
##  - basic movement along a path (done, works)
##  - make the 3 types feel different (done: speed, HP, fast zig-zags,
##    tank stops at corners)
##  - hit flash + death sprite (done, see above)
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
## Seconds after spawning while it hatches: can't be hurt, can't hurt (0 = off)
@export var spawn_protection := 0.7

@export_group("Sprites")
@export var normal_texture: Texture2D
@export var hit_texture: Texture2D
@export var dead_texture: Texture2D

const CONTACT_CHECK_INTERVAL := 0.2
const DEATH_TIME := 0.4
const HATCH_START_SCALE := 0.35
const HATCH_TINT := Color(0.7, 1.0, 0.75, 0.7)   # pale green and see-through while hatching
const BOB_AMOUNT := 0.06       # how much the walk squashes the sprite (0.06 = 6 %)
const BOB_PER_PIXEL := 0.2     # bob speed follows walking speed, so tanks plod and fast ones scurry

var hp: int
var _dead := false
var _contact_tick := CONTACT_CHECK_INTERVAL
var _zigzag_time := 0.0
var _pause_left := 0.0
var _protected_for := 0.0     # seconds of hatching left
var _bob := 0.0
var _pop := 1.0               # extra sprite scale, tweened by the hit pop
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
	_protected_for = spawn_protection
	_update_look()


func _process(delta: float) -> void:
	if _dead:
		return
	_protected_for = maxf(_protected_for - delta, 0.0)
	if _pause_left > 0.0:
		_pause_left -= delta
	else:
		var before := progress
		progress += speed * delta
		_stop_at_corner(before)
		_bob += speed * delta * BOB_PER_PIXEL
	_apply_zigzag(delta)
	_update_look()
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


## True while it is still hatching out of the origin
func is_hatching() -> bool:
	return _protected_for > 0.0


## Sprite size and tint for this frame: hatch grow-in, walk bob, hit pop
func _update_look() -> void:
	var grow := 1.0
	if spawn_protection > 0.0 and _protected_for > 0.0:
		var t := 1.0 - _protected_for / spawn_protection
		grow = lerpf(HATCH_START_SCALE, 1.0, ease(t, 0.4))
		sprite.modulate = HATCH_TINT.lerp(Color.WHITE, t * t)
	elif sprite.modulate != Color.WHITE:
		sprite.modulate = Color.WHITE
	var squash := sin(_bob) * BOB_AMOUNT
	sprite.scale = Vector2(1.0 + squash, 1.0 - squash) * grow * _pop
	sprite.position.y = -absf(sin(_bob * 0.5)) * 2.0   # tiny hop


func take_damage(amount: int) -> void:
	if _dead:
		return
	if is_hatching():
		Events.enemy_blocked.emit(self)   # the bullet bounces off (tink)
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
	# Deferred: a kill usually happens inside a bullet's physics callback, and
	# listeners (the laser manager spawns a pickup) must not add physics bodies there.
	Events.enemy_killed.emit.call_deferred(self)
	# Float up and fade out
	sprite.modulate = Color.WHITE
	var tween := create_tween().set_parallel()
	tween.tween_property(sprite, "position:y", sprite.position.y - 14.0, DEATH_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", 0.0, DEATH_TIME).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)


## Dissolve without counting as a kill. game.gd calls this on every monster
## when the origin is destroyed.
func vanish() -> void:
	if _dead:
		return
	_dead = true
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	if dead_texture:
		sprite.texture = dead_texture
	sprite.modulate = Color.WHITE
	var tween := create_tween().set_parallel()
	tween.tween_property(sprite, "scale", Vector2.ZERO, DEATH_TIME).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "modulate:a", 0.0, DEATH_TIME)
	tween.chain().tween_callback(queue_free)


func _flash_hit() -> void:
	_pop = 1.3
	create_tween().tween_property(self, "_pop", 1.0, 0.18).set_ease(Tween.EASE_OUT)
	if hit_texture == null:
		return
	sprite.texture = hit_texture
	await get_tree().create_timer(0.15, false).timeout
	if not _dead and is_inside_tree():
		sprite.texture = normal_texture


func _on_hitbox_body_entered(body: Node) -> void:
	if not _dead and not is_hatching() and body.is_in_group("player"):
		body.take_damage(contact_damage)
