extends Node2D
## Laser mode: sweep line, fire when it crosses the target. Base for aim_modes/. Yang's.
# the game is paused while this runs, so it uses PROCESS_MODE_ALWAYS
# TODO: use Fah's Laser.png for the beam

signal fired(direction: Vector2)

const LINE_LENGTH := 2000.0
## seconds to ignore input so a held attack key doesn't fire instantly
const ARM_DELAY := 0.4
const BEAM_FLASH_TIME := 0.25

## set by laser_manager.gd before this enters the tree
var from_position := Vector2.ZERO
var sweep_speed := 90.0     ## degrees per second
var start_angle := 0.0      ## radians
var target: Node2D = null
var hit_radius := 48.0
var slow_factor := 0.45     ## sweep speed multiplier right next to the target
var radius_per_distance := 0.0
var assist := 1.0           ## pity laser: 1 = normal, up to 2 after misses
var level_number := 1

## shown by the HUD when the shot starts
func mode_name() -> String:
	return "SWEEP"


func how_to() -> String:
	return "Press SPACE when the beam crosses the target"

## -1 = manager tests the ray, 0 = miss, 1 = hit
var result := -1

const SLOW_ZONE_DEG := 25.0

var _angle := 0.0
var _armed_in := ARM_DELAY
var _fired := false
var _beam_alpha := 1.0
var _beam_dir := Vector2.RIGHT
var _beam_length := LINE_LENGTH
var _sfx: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100
	_angle = start_angle
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)


func _process(delta: float) -> void:
	if PauseMenu.open:
		return
	if not _fired:
		_armed_in -= delta
		_angle = wrapf(_angle + deg_to_rad(current_speed()) * delta, -PI, PI)
	queue_redraw()


## degrees per second, slower near the target
func current_speed() -> float:
	var close := closeness()
	return sweep_speed * lerpf(1.0, slow_factor, close)


## 0 = far from the target, 1 = pointing right at it
func closeness() -> float:
	if not is_instance_valid(target):
		return 0.0
	var want := (target.global_position - from_position).angle()
	var off := absf(rad_to_deg(angle_difference(_angle, want)))
	return clampf(1.0 - off / SLOW_ZONE_DEG, 0.0, 1.0)


func _draw() -> void:
	var start := to_local(from_position)
	var dir := Vector2.from_angle(_angle)
	if _fired:
		_draw_beam(start, _beam_dir, _beam_length)
		return
	var close := closeness()
	_draw_target_ring(close)
	var color := Color(1.0, 0.2, 0.2, 0.8).lerp(Color(1.0, 0.9, 0.2, 0.95), close)
	draw_line(start, start + dir * LINE_LENGTH, color, 3.0 + 2.0 * close)


func _draw_beam(start: Vector2, dir: Vector2, length: float) -> void:
	draw_line(start, start + dir * length, Color(1.0, 0.95, 0.4, _beam_alpha), 10.0)
	draw_line(start, start + dir * length, Color(1.0, 1.0, 1.0, _beam_alpha), 4.0)


## the real hit zone, so players see what counts
func _draw_target_ring(close: float) -> void:
	if not is_instance_valid(target):
		return
	var at := to_local(target.global_position)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0)
	var r := target_radius()
	draw_arc(at, r, 0.0, TAU, 40, Color(1.0, 0.9, 0.3, 0.5 + 0.4 * close), 2.0 + 2.0 * close)
	draw_arc(at, r + 6.0 + pulse * 4.0, 0.0, TAU, 40, Color(1.0, 0.9, 0.3, 0.25 * (0.3 + close)), 2.0)


func target_radius(from := from_position) -> float:
	if not is_instance_valid(target):
		return hit_radius
	return hit_radius + radius_per_distance * from.distance_to(target.global_position)


## used by the play-test bot
func bot_want_angles() -> Array:
	if not is_instance_valid(target):
		return []
	return [(target.global_position - from_position).angle()]


func _is_fire(event: InputEvent) -> bool:
	return event.is_action_pressed("fire_laser") or event.is_action_pressed("attack")


func _is_fire_release(event: InputEvent) -> bool:
	return event.is_action_released("fire_laser") or event.is_action_released("attack")


func _unhandled_input(event: InputEvent) -> void:
	if _fired or _armed_in > 0.0 or PauseMenu.open:
		return
	if _is_fire(event):
		get_viewport().set_input_as_handled()
		_fire(Vector2.from_angle(_angle))


## hit: -1 = manager tests the ray, 0 = miss, 1 = hit. short length reads as a fizzle.
func _fire(direction: Vector2, hit := -1, length := LINE_LENGTH) -> void:
	if _fired:
		return
	_fired = true
	result = hit
	_beam_dir = direction
	_beam_length = length
	queue_redraw()
	fired.emit(direction)
	# node-owned tween so it runs while paused
	var tween := create_tween()
	tween.tween_property(self, "_beam_alpha", 0.0, BEAM_FLASH_TIME)
	tween.tween_callback(queue_free)


func _sound(stream: AudioStream, pitch := 1.0, volume_db := -4.0) -> void:
	_sfx.stream = stream
	_sfx.pitch_scale = pitch
	_sfx.volume_db = volume_db
	_sfx.play()
