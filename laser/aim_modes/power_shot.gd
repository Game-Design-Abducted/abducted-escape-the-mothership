extends "res://laser/aim_mode.gd"
## Laser mode POWER SHOT. Ploy's.
##
## The beam locks onto the target by itself. HOLD fire to charge the power
## bar, LET GO while it's in the green zone.
##   let go too early  -> "TOO WEAK"     the beam fizzles out short (miss)
##   hold too long     -> "OVERCHARGED!" it fires by itself, wobbly (miss)
## The green zone gets wider with `assist` (after misses).

func mode_name() -> String:
	return "POWER SHOT"


func how_to() -> String:
	return "HOLD SPACE, let go in the GREEN"

const FILL_TIME := {1: 1.3, 2: 1.05}   ## seconds from empty to full
const ZONE_CENTER := 0.75
const ZONE_HALF := {1: 0.1, 2: 0.08}   ## half the green zone, before assist
const BAR_SIZE := Vector2(16, 120)
const FONT := preload("res://assets/fonts/VT323.ttf")
const SFX_TICK := preload("res://assets/audio/sfx/timer_tick.wav")

var power := 0.0
var _charging := false
var _wobble := 0.0
var _verdict := ""


func zone() -> Vector2:
	var half: float = ZONE_HALF.get(level_number, 0.1) * minf(assist, 1.8)
	return Vector2(ZONE_CENTER - half, minf(ZONE_CENTER + half, 0.97))


func _process(delta: float) -> void:
	if PauseMenu.open:
		return
	if not _fired:
		_armed_in -= delta
		if is_instance_valid(target):
			_angle = (target.global_position - from_position).angle()   # locked on
		if _charging:
			var before := power
			power += delta / FILL_TIME.get(level_number, 1.2)
			var z := zone()
			if before < z.x and power >= z.x:
				_sound(SFX_TICK, 1.6)   # entering the green
			if power >= 1.0:
				power = 1.0
				_overcharge()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _fired or PauseMenu.open:
		return
	if _is_fire(event) and _armed_in <= 0.0 and not _charging:
		get_viewport().set_input_as_handled()
		_charging = true
	elif _is_fire_release(event) and _charging:
		get_viewport().set_input_as_handled()
		_release()


func _release() -> void:
	_charging = false
	var dir := Vector2.from_angle(_angle)
	var z := zone()
	if power < z.x:
		_verdict = "TOO WEAK"
		_fire(dir, 0, maxf(from_position.distance_to(target.global_position) * 0.45, 60.0))
	else:
		_verdict = "FULL POWER!"
		_fire(dir, 1)


func _overcharge() -> void:
	_charging = false
	_verdict = "OVERCHARGED!"
	_fire(Vector2.from_angle(_angle + deg_to_rad(28.0 * (1 if randf() < 0.5 else -1))), 0)


## Bot: hold, then let go in the middle of the green
func bot_should_release(err_sec: float) -> bool:
	return power >= ZONE_CENTER + err_sec / FILL_TIME.get(level_number, 1.2)


func _draw() -> void:
	var start := to_local(from_position)
	if _fired:
		_draw_beam(start, _beam_dir, _beam_length)
		_draw_verdict(start)
		return
	_draw_target_ring(1.0 if _charging else 0.6)
	var dir := Vector2.from_angle(_angle)
	# Locked line, shaking more as the power rises
	_wobble += 0.6
	var shake := Vector2(0, sin(_wobble) * 3.0 * power).rotated(_angle)
	var color := Color(1.0, 0.2, 0.2, 0.55).lerp(Color(1.0, 0.95, 0.3, 0.95), power)
	draw_line(start, start + dir * LINE_LENGTH + shake * 20.0, color, 2.0 + 4.0 * power)
	# Power bar next to the player
	var bar := Rect2(start + Vector2(28, -BAR_SIZE.y * 0.5), BAR_SIZE)
	draw_rect(bar.grow(3), Color(0.05, 0.0, 0.12, 0.9))
	var z := zone()
	var zone_rect := Rect2(bar.position.x, bar.end.y - BAR_SIZE.y * z.y, BAR_SIZE.x, BAR_SIZE.y * (z.y - z.x))
	draw_rect(zone_rect, Color(0.2, 1.0, 0.35, 0.55))
	var fill := BAR_SIZE.y * power
	var in_zone := power >= z.x and power <= z.y
	var fill_color := Color(0.3, 1.0, 0.4) if in_zone else (Color(1.0, 0.3, 0.2) if power > z.y else Color(1.0, 0.85, 0.3))
	draw_rect(Rect2(bar.position.x, bar.end.y - fill, BAR_SIZE.x, fill), fill_color)
	# Zone edges on top, sticking out of the bar, so they stay visible under the fill
	for edge in [z.x, z.y]:
		var y: float = bar.end.y - BAR_SIZE.y * edge
		draw_line(Vector2(bar.position.x - 7, y), Vector2(bar.end.x + 7, y), Color.WHITE, 2.0)
	draw_rect(bar.grow(3), Color(1.0, 0.82, 0.0), false, 2.0)
	if not _charging and _armed_in <= 0.0:
		var blink := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
		draw_string(FONT, bar.position + Vector2(-10, -12), "HOLD!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.5 + 0.5 * blink))


func _draw_verdict(start: Vector2) -> void:
	if _verdict == "":
		return
	var color := Color(0.4, 1.0, 0.5, _beam_alpha) if _verdict == "FULL POWER!" else Color(1.0, 0.45, 0.35, _beam_alpha)
	draw_string(FONT, start + Vector2(-50, -40), _verdict, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, color)
