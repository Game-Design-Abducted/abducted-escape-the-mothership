extends "res://laser/aim_mode.gd"
## Laser mode: hit 2 of 3 beats as the rings land on the target. Ploy's.

func mode_name() -> String:
	return "BEAT DROP"


func how_to() -> String:
	return "Press SPACE as each ring hits the target"

const BEATS := 3
const NEED := 2
const FIRST_BEAT := 1.3                 ## seconds after the shot starts
const INTERVAL := {1: 0.85, 2: 0.7}     ## seconds between beats
const WINDOW := {1: 0.14, 2: 0.12}      ## +- seconds on the beat, before assist
const PENALTY_RANGE := 0.35             ## near-miss presses lose the beat so mashing doesn't work
const RING_LEAD := 0.8                  ## seconds a ring shrinks before its beat
const FONT := preload("res://assets/fonts/VT323.ttf")
const SFX_TICK := preload("res://assets/audio/sfx/timer_tick.wav")
const SFX_GOOD := preload("res://assets/audio/sfx/ui_click.wav")

var _t := 0.0
var _judged: Array = []     ## per beat: "" (waiting), "NICE!", "MISS"
var _ticked: Array = []
var _good := 0


func _ready() -> void:
	super()
	for i in BEATS:
		_judged.append("")
		_ticked.append(false)


func beat_time(i: int) -> float:
	return FIRST_BEAT + i * INTERVAL.get(level_number, 0.8)


func window() -> float:
	return WINDOW.get(level_number, 0.13) * minf(assist, 1.7)


## seconds to the next unjudged beat (negative = past). used by the bot.
func to_next_beat() -> float:
	for i in BEATS:
		if _judged[i] == "":
			return beat_time(i) - _t
	return INF


func _process(delta: float) -> void:
	if PauseMenu.open:
		return
	if not _fired:
		_armed_in -= delta
		_t += delta
		if is_instance_valid(target):
			_angle = (target.global_position - from_position).angle()
		for i in BEATS:
			if not _ticked[i] and _t >= beat_time(i):
				_ticked[i] = true
				_sound(SFX_TICK, 1.0 + 0.15 * i, -8.0)
			if _judged[i] == "" and _t > beat_time(i) + window():
				_judged[i] = "MISS"
		_check_done()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _fired or PauseMenu.open or not _is_fire(event):
		return
	get_viewport().set_input_as_handled()
	for i in BEATS:
		if _judged[i] != "":
			continue
		var off := absf(_t - beat_time(i))
		if off <= window():
			_judged[i] = "NICE!"
			_good += 1
			_sound(SFX_GOOD, 1.2 + 0.2 * _good)
		elif off <= PENALTY_RANGE:
			_judged[i] = "MISS"
		break
	_check_done()


func _check_done() -> void:
	if _fired:
		return
	var waiting := 0
	var missed := 0
	for j in _judged:
		if j == "":
			waiting += 1
		elif j == "MISS":
			missed += 1
	var dir := Vector2.from_angle(_angle)
	if _good >= NEED:
		_fire(dir, 1)
	elif missed > BEATS - NEED or waiting == 0:
		_fire(dir.rotated(deg_to_rad(22.0)), 0, maxf(from_position.distance_to(target.global_position) * 0.5, 60.0))


func _draw() -> void:
	var start := to_local(from_position)
	if _fired:
		_draw_beam(start, _beam_dir, _beam_length)
	else:
		draw_line(start, start + Vector2.from_angle(_angle) * LINE_LENGTH, Color(1.0, 0.3, 0.9, 0.35 + 0.2 * _good), 2.0 + _good)
		_draw_target_ring(0.5)
	if not is_instance_valid(target):
		return
	var at := to_local(target.global_position)
	var r := target_radius()
	if not _fired:
		for i in BEATS:
			var until := beat_time(i) - _t
			if _judged[i] == "" and until <= RING_LEAD and until > -window():
				var k := clampf(until / RING_LEAD, 0.0, 1.0)
				var on_beat := absf(until) <= window()
				var color := Color(0.3, 1.0, 0.5) if on_beat else Color(1.0, 0.4, 1.0, 0.9)
				draw_arc(at, r + k * 150.0, 0.0, TAU, 48, color, 4.0 if on_beat else 3.0)
	for i in BEATS:
		var p := at + Vector2((i - 1) * 34.0, r + 26.0)
		var c := Color(0.25, 0.2, 0.35)
		if _judged[i] == "NICE!":
			c = Color(0.3, 1.0, 0.5)
		elif _judged[i] == "MISS":
			c = Color(1.0, 0.3, 0.3)
		draw_circle(p, 10.0, c)
		draw_arc(p, 10.0, 0.0, TAU, 20, Color(1, 1, 1, 0.7), 2.0)
	for i in range(BEATS - 1, -1, -1):
		if _judged[i] != "":
			var good: bool = _judged[i] == "NICE!"
			draw_string(FONT, at + Vector2(-30, -r - 18), _judged[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 30,
					Color(0.4, 1.0, 0.5) if good else Color(1.0, 0.4, 0.4))
			break
