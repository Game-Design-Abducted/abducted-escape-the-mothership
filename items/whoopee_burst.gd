class_name WhoopeeBurst
extends Node2D
## The Whoopee Bomb going off. Ploy's.
##
## A green cloud swells for `fuse` seconds (the wheeze), then bursts: emits
## `exploded`, puffs out to `radius` and fades. drop_manager.gd does the damage.

signal exploded(position: Vector2)

var radius := 130.0
var fuse := 0.45
var _t := 0.0
var _done := false
var _puffs: Array[Vector3] = []   # x, y = offset, z = size, for a lumpy cloud


func _ready() -> void:
	z_index = 4
	for i in 9:
		var a := TAU * i / 9.0 + randf_range(-0.3, 0.3)
		_puffs.append(Vector3(cos(a), sin(a), randf_range(0.35, 0.55)))


func _process(delta: float) -> void:
	_t += delta
	if not _done and _t >= fuse:
		_done = true
		exploded.emit(global_position)
	if _t >= fuse + 0.6:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var green := Color(0.55, 0.95, 0.3)
	if _t < fuse:
		# Wheeze: a small cloud that wobbles bigger
		var k := _t / fuse
		var r := 10.0 + 18.0 * k + sin(_t * 40.0) * 2.0
		draw_circle(Vector2.ZERO, r, Color(green, 0.55))
		return
	# Burst: lumpy cloud that grows to the full radius and fades
	var k := clampf((_t - fuse) / 0.6, 0.0, 1.0)
	var grow := ease(k, 0.3)
	var alpha := 0.6 * (1.0 - k)
	draw_circle(Vector2.ZERO, radius * grow, Color(green, alpha * 0.35))
	draw_arc(Vector2.ZERO, radius * grow, 0.0, TAU, 48, Color(green, alpha), 3.0)
	for p in _puffs:
		var at := Vector2(p.x, p.y) * radius * 0.6 * grow
		draw_circle(at, radius * p.z * grow * 0.6, Color(green.darkened(0.15), alpha * 0.6))
