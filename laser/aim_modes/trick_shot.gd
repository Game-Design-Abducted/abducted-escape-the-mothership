extends "res://laser/aim_mode.gd"
## Laser mode: sweep, but only the part bounced off the outer wall counts. Ploy's.

const ARENA := Rect2(32, 32, 1216, 656)   ## inside of the outer wall (1280x720 levels, 32 px tiles)
const FONT := preload("res://assets/fonts/VT323.ttf")

var _verdict := ""


func mode_name() -> String:
	return "TRICK SHOT"


func how_to() -> String:
	return "Only BOUNCED beams count! Bank it off the outer wall"


## returns [point, wall normal]
func _bounce(from: Vector2, angle: float) -> Array:
	var d := Vector2.from_angle(angle)
	var best := INF
	var normal := Vector2.ZERO
	if d.x > 0.0001:
		var t := (ARENA.end.x - from.x) / d.x
		if t < best:
			best = t
			normal = Vector2.LEFT
	elif d.x < -0.0001:
		var t := (ARENA.position.x - from.x) / d.x
		if t < best:
			best = t
			normal = Vector2.RIGHT
	if d.y > 0.0001:
		var t := (ARENA.end.y - from.y) / d.y
		if t < best:
			best = t
			normal = Vector2.UP
	elif d.y < -0.0001:
		var t := (ARENA.position.y - from.y) / d.y
		if t < best:
			best = t
			normal = Vector2.DOWN
	return [from + d * maxf(best, 0.0), normal]


func _reflect(d: Vector2, n: Vector2) -> Vector2:
	return d - 2.0 * d.dot(n) * n


func bounce_hits(angle: float) -> bool:
	if not is_instance_valid(target):
		return false
	var b: Array = _bounce(from_position, angle)
	var point: Vector2 = b[0]
	var out := _reflect(Vector2.from_angle(angle), b[1])
	var to_center := target.global_position - point
	var along := to_center.dot(out)
	if along < 0.0:
		return false
	return (point + out * along).distance_to(target.global_position) <= target_radius(point)


## mirror the target in each wall
func bot_want_angles() -> Array:
	var result := []
	if not is_instance_valid(target):
		return result
	var t := target.global_position
	var mirrors := {
		Vector2.RIGHT: Vector2(2.0 * ARENA.position.x - t.x, t.y),
		Vector2.LEFT: Vector2(2.0 * ARENA.end.x - t.x, t.y),
		Vector2.DOWN: Vector2(t.x, 2.0 * ARENA.position.y - t.y),
		Vector2.UP: Vector2(t.x, 2.0 * ARENA.end.y - t.y),
	}
	for n: Vector2 in mirrors:
		var a: float = (mirrors[n] - from_position).angle()
		if _bounce(from_position, a)[1] == n:   # beam has to reach that wall first
			result.append(a)
	return result


func closeness() -> float:
	var best := 0.0
	for a: float in bot_want_angles():
		var off := absf(rad_to_deg(angle_difference(_angle, a)))
		best = maxf(best, clampf(1.0 - off / SLOW_ZONE_DEG, 0.0, 1.0))
	return best


func _unhandled_input(event: InputEvent) -> void:
	if _fired or _armed_in > 0.0 or PauseMenu.open:
		return
	if _is_fire(event):
		get_viewport().set_input_as_handled()
		var hit := bounce_hits(_angle)
		_verdict = "TRICK SHOT!" if hit else "NO BOUNCE, NO GLORY"
		_fire(Vector2.from_angle(_angle), 1 if hit else 0)


func _draw() -> void:
	var start := to_local(from_position)
	var b: Array = _bounce(from_position, _angle)
	var point := to_local(b[0])
	var out := _reflect(Vector2.from_angle(_angle), b[1])
	if _fired:
		_draw_beam(start, Vector2.from_angle(_angle), start.distance_to(point))
		_draw_beam(point, out, LINE_LENGTH)
		draw_circle(point, 14.0 * _beam_alpha, Color(1, 1, 1, _beam_alpha))
		var good := result == 1
		draw_string(FONT, start + Vector2(-60, -40), _verdict, HORIZONTAL_ALIGNMENT_LEFT, -1, 28,
				Color(0.4, 1.0, 0.5, _beam_alpha) if good else Color(1.0, 0.45, 0.35, _beam_alpha))
		return
	var close := closeness()
	_draw_target_ring(close)
	draw_line(start, point, Color(1.0, 0.3, 0.3, 0.35), 2.0)
	var color := Color(1.0, 0.2, 0.2, 0.85).lerp(Color(1.0, 0.9, 0.2, 1.0), close)
	draw_line(point, point + out * LINE_LENGTH, color, 3.0 + 2.0 * close)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0)
	draw_circle(point, 5.0 + 3.0 * pulse, Color(1.0, 0.9, 0.4, 0.9))
