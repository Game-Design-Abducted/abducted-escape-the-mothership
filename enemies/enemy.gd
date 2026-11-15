class_name Enemy
extends PathFollow2D
## Enemy base script, shared by basic/fast/tank (only the inspector numbers differ). Ploy's.
## must live under a Path2D. root in group "enemies", Hitbox on layer 3 mask 2, bullets call take_damage().

@export var speed := 80.0
@export var max_hp := 1
@export var contact_damage := 1
## fast monster: sideways wobble in px (0 = off)
@export var zigzag_amplitude := 0.0
@export var zigzag_speed := 3.0
## tank: seconds to stop at each path corner (0 = never)
@export var corner_pause := 0.0
## seconds of hatching after spawn: can't be hurt, can't hurt (0 = off)
@export var spawn_protection := 0.7

@export_group("Sprites")
@export var normal_texture: Texture2D
@export var hit_texture: Texture2D
@export var dead_texture: Texture2D

const CONTACT_CHECK_INTERVAL := 0.2
const DEATH_TIME := 0.4
const HATCH_START_SCALE := 0.35
const HATCH_TINT := Color(0.7, 1.0, 0.75, 0.7)
const BOB_AMOUNT := 0.06
const BOB_PER_PIXEL := 0.2     # bob follows walk speed so tanks plod and fast ones scurry

var hp: int
var _dead := false
var _contact_tick := CONTACT_CHECK_INTERVAL
var _zigzag_time := 0.0
var _pause_left := 0.0
var _protected_for := 0.0
var _bob := 0.0
var _pop := 1.0
var _dance_left := 0.0
var speed_scale := 1.0        # set by the BALLOON PARTY ship prank
var _corners := PackedFloat32Array()
## random routes (wave_manager sets these): when the route runs out it adds a new stretch
var wander: RefCounted   # maze_wander.gd
var monster_type := "basic"
const ROUTE_LOOKAHEAD := 64.0   ## px before the end of the route to add more
const EGG_EXIT_PX := 48.0       ## random-route monsters can't hurt you before walking this far

@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: Area2D = $Hitbox


func _ready() -> void:
	hp = max_hp
	loop = wander == null   # random routes keep growing, looping back would teleport
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
	_dance_left = maxf(_dance_left - delta, 0.0)
	if _pause_left > 0.0:
		_pause_left -= delta
	else:
		var before := progress
		if wander and progress > (get_parent() as Path2D).curve.get_baked_length() - ROUTE_LOOKAHEAD:
			extend_route()
		progress += speed * speed_scale * delta
		_stop_at_corner(before)
		_bob += speed * speed_scale * delta * BOB_PER_PIXEL
	_apply_zigzag(delta)
	_update_look()
	# body_entered only fires once, so recheck or a player standing on a monster never gets hurt again
	_contact_tick -= delta
	if _contact_tick <= 0.0:
		_contact_tick = CONTACT_CHECK_INTERVAL
		for body in hitbox.get_overlapping_bodies():
			_on_hitbox_body_entered(body)


## progress going down means we looped past the end
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


## measured as baked length up to each point so self-crossing paths still work
static func _corner_offsets(curve: Curve2D) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	var part := Curve2D.new()
	part.bake_interval = curve.bake_interval
	for i in curve.point_count - 1:
		part.add_point(curve.get_point_position(i), curve.get_point_in(i), curve.get_point_out(i))
		if i >= 1:
			result.append(part.get_baked_length())
	return result


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


## Disco Ball drop. dancing monsters can't hurt the player but can still be shot.
func dance(seconds: float) -> void:
	if _dead:
		return
	_dance_left = maxf(_dance_left, seconds)
	_pause_left = maxf(_pause_left, seconds)


## BALLOON PARTY ship prank (game/ship_pranks.gd)
func balloon(on: bool) -> void:
	if _dead:
		return
	speed_scale = 0.6 if on else 1.0
	create_tween().tween_property(self, "scale", Vector2.ONE * (1.5 if on else 1.0), 0.35) 			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Adds the next random stretch to this monster's own path.
func extend_route() -> void:
	var curve := (get_parent() as Path2D).curve
	var from := curve.get_point_position(curve.point_count - 1)
	var route: PackedVector2Array = wander.next_route(get_parent().to_global(from), monster_type,
			get_tree().get_first_node_in_group("player"), curve.point_count == 1)
	for i in route.size():
		var p: Vector2 = get_parent().to_local(route[i])
		if not p.is_equal_approx(curve.get_point_position(curve.point_count - 1)):
			curve.add_point(p)
	_corners = PackedFloat32Array()   # recomputed for the longer path


## random routes: harmless until it has walked out of the egg, so it can't hatch on top of you and hit right away
func _leaving_egg() -> bool:
	return wander != null and progress < EGG_EXIT_PX


func is_dancing() -> bool:
	return _dance_left > 0.0


func is_hatching() -> bool:
	return _protected_for > 0.0


func _update_look() -> void:
	var grow := 1.0
	if spawn_protection > 0.0 and _protected_for > 0.0:
		var t := 1.0 - _protected_for / spawn_protection
		grow = lerpf(HATCH_START_SCALE, 1.0, ease(t, 0.4))
		sprite.modulate = HATCH_TINT.lerp(Color.WHITE, t * t)
	elif sprite.modulate != Color.WHITE:
		sprite.modulate = Color.WHITE
	var squash := sin(_bob) * BOB_AMOUNT
	if _dance_left > 0.0:
		var t := Time.get_ticks_msec() / 1000.0
		sprite.rotation = sin(t * 12.0) * 0.35
		squash = sin(t * 24.0) * 0.12
		if not is_hatching():
			sprite.modulate = Color.from_hsv(fmod(t * 1.5 + progress * 0.01, 1.0), 0.45, 1.0)
	elif sprite.rotation != 0.0:
		sprite.rotation = 0.0
	sprite.scale = Vector2(1.0 + squash, 1.0 - squash) * grow * _pop
	sprite.position.y = -absf(sin(_bob * 0.5)) * 2.0


func take_damage(amount: int) -> void:
	if _dead:
		return
	if is_hatching():
		Events.enemy_blocked.emit(self)
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
	# deferred: kills happen in a physics callback and listeners spawn pickups
	Events.enemy_killed.emit.call_deferred(self)
	sprite.modulate = Color.WHITE
	var tween := create_tween().set_parallel()
	tween.tween_property(sprite, "position:y", sprite.position.y - 14.0, DEATH_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", 0.0, DEATH_TIME).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)


## dissolve without counting as a kill (game.gd, when the origin is destroyed)
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
	if not _dead and not is_hatching() and not is_dancing() and not _leaving_egg() and body.is_in_group("player"):
		body.take_damage(contact_damage)
