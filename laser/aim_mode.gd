extends Node2D
## =====================================================================
## AIM MODE. OWNER: Kong
## =====================================================================
## Created by laser_manager.gd after the player picks up the laser.
## The whole game is paused while this runs. This node uses
## PROCESS_MODE_ALWAYS so it still works.
##
## Draws a line from the player toward the mouse. Click (or K) = fire.
##
## TODO (Kong, Nov 13):
##   [ ] Better aim visuals (dotted line, crosshair, Fah's Laser.png beam on fire)
##   [ ] Keyboard aiming (rotate with arrows) in case mouse isn't wanted?
##   [ ] Time limit on aiming? (e.g. 5 s, then auto-miss)

signal fired(direction: Vector2)

const LINE_LENGTH := 2000.0

var from_position := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var dir := (get_global_mouse_position() - from_position).normalized()
	var start := to_local(from_position)
	draw_line(start, start + dir * LINE_LENGTH, Color(1, 0.2, 0.2, 0.8), 3.0)
	draw_circle(to_local(get_global_mouse_position()), 8.0, Color(1, 0.2, 0.2, 0.6))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fire_laser"):
		var dir := (get_global_mouse_position() - from_position).normalized()
		if dir == Vector2.ZERO:
			return
		get_viewport().set_input_as_handled()
		fired.emit(dir)
		queue_free()
