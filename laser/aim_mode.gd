extends Node2D
## Aim mode. Yang's.
##
## laser_manager.gd creates this after the player grabs the laser. The whole
## game is paused while it runs, so this node uses PROCESS_MODE_ALWAYS to
## keep working.
##
## A red aim line SWEEPS around the player on its own. The player presses fire
## (Space / J / K / click) at the right moment. Timing is the skill, so the shot
## can really miss. `sweep_speed` sets the difficulty. After firing, a bright
## beam flashes for a moment, then this node frees itself.
##
## LOCK-ON (makes it fair for real players): a ring shows the target's real hit
## zone, and while the line is within SLOW_ZONE_DEG of the target the sweep
## slows down to `slow_factor` and turns yellow. Still a timing shot, but the
## right moment lasts about 0.3 s instead of 0.1 s.
##
## LASER MODES: this is the SWEEP mode and the base for the others in
## laser/aim_modes/ (POWER SHOT, TRICK SHOT, BEAT DROP). laser_manager.gd picks
## one per shot so the laser doesn't play the same every time. A mode decides
## the shot itself by calling _fire(direction, hit) (hit: 1 = hit, 0 = miss),
## or leaves `result` at -1 and the manager tests the ray against the target.
##
## TODO Yang:
##  - nicer visuals (Fah's Laser.png as the beam, crosshair, fire sound, ask Fah if you need more art)
##  - tune sweep_speed per level (it is set in laser_manager.gd)
##  - optional: reverse direction randomly, or speed up after each miss
##  - optional: time limit on aiming (e.g. 2 full turns, then it auto-misses)

signal fired(direction: Vector2)

const LINE_LENGTH := 2000.0
## Ignore input for a moment so a held/mashed attack key doesn't fire instantly
const ARM_DELAY := 0.4
const BEAM_FLASH_TIME := 0.25

## Set by laser_manager.gd before this node enters the tree
var from_position := Vector2.ZERO
var sweep_speed := 90.0     ## degrees per second
var start_angle := 0.0      ## radians
var target: Node2D = null   ## the origin (it keeps moving on level 2)
var hit_radius := 48.0      ## drawn as the ring, so players see what counts
var slow_factor := 0.45     ## sweep speed multiplier right next to the target
var radius_per_distance := 0.0   ## hit zone grows with distance (laser_manager sets it)
var assist := 1.0           ## pity laser: 1 = normal, up to 2 after misses (timing modes widen their window)
var level_number := 1

## Shown by the HUD when the shot starts
func mode_name() -> String:
	return "SWEEP"


func how_to() -> String:
	return "Press SPACE when the beam crosses the target"

## -1 = let the manager test the ray, 0 = miss, 1 = hit (set by _fire)
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
		return   # the pause menu is up: the line waits
	if not _fired:
		_armed_in -= delta
		_angle = wrapf(_angle + deg_to_rad(current_speed()) * delta, -PI, PI)
	queue_redraw()


## Sweep speed right now (degrees per second): slower close to the target
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
	# Line: red far away, yellow and thicker near the target
	var color := Color(1.0, 0.2, 0.2, 0.8).lerp(Color(1.0, 0.9, 0.2, 0.95), close)
	draw_line(start, start + dir * LINE_LENGTH, color, 3.0 + 2.0 * close)


func _draw_beam(start: Vector2, dir: Vector2, length: float) -> void:
	draw_line(start, start + dir * length, Color(1.0, 0.95, 0.4, _beam_alpha), 10.0)
	draw_line(start, start + dir * length, Color(1.0, 1.0, 1.0, _beam_alpha), 4.0)


## The real hit zone around the target, pulsing. close (0..1) makes it brighter.
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


## Angles the player should fire at (the play-test bot uses this)
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


## Shoot. hit: -1 = the manager tests the ray, 0 = miss, 1 = hit.
## length: a short beam reads as "fizzled".
func _fire(direction: Vector2, hit := -1, length := LINE_LENGTH) -> void:
	if _fired:
		return
	_fired = true
	result = hit
	_beam_dir = direction
	_beam_length = length
	queue_redraw()
	fired.emit(direction)
	# Beam flash, then remove. The tween belongs to this node, so it also
	# runs while paused and is cleaned up if the scene changes.
	var tween := create_tween()
	tween.tween_property(self, "_beam_alpha", 0.0, BEAM_FLASH_TIME)
	tween.tween_callback(queue_free)


func _sound(stream: AudioStream, pitch := 1.0, volume_db := -4.0) -> void:
	_sfx.stream = stream
	_sfx.pitch_scale = pitch
	_sfx.volume_db = volume_db
	_sfx.play()
