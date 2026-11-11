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

var _angle := 0.0
var _armed_in := ARM_DELAY
var _fired := false
var _beam_alpha := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100
	_angle = start_angle


func _process(delta: float) -> void:
	if not _fired:
		_armed_in -= delta
		_angle = wrapf(_angle + deg_to_rad(sweep_speed) * delta, -PI, PI)
	queue_redraw()


func _draw() -> void:
	var start := to_local(from_position)
	var dir := Vector2.from_angle(_angle)
	if _fired:
		draw_line(start, start + dir * LINE_LENGTH, Color(1.0, 0.95, 0.4, _beam_alpha), 10.0)
		draw_line(start, start + dir * LINE_LENGTH, Color(1.0, 1.0, 1.0, _beam_alpha), 4.0)
	else:
		draw_line(start, start + dir * LINE_LENGTH, Color(1.0, 0.2, 0.2, 0.8), 3.0)


func _unhandled_input(event: InputEvent) -> void:
	if _fired or _armed_in > 0.0:
		return
	if event.is_action_pressed("fire_laser") or event.is_action_pressed("attack"):
		get_viewport().set_input_as_handled()
		_fired = true
		fired.emit(Vector2.from_angle(_angle))
		# Beam flash, then remove. The tween belongs to this node, so it also
		# runs while paused and is cleaned up if the scene changes.
		var tween := create_tween()
		tween.tween_property(self, "_beam_alpha", 0.0, BEAM_FLASH_TIME)
		tween.tween_callback(queue_free)
