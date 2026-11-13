extends Node2D
## Glowing mark on the floor where monsters come out. Ploy's.
##
## Level 1 does not need it (the egg sits on that spot). In Level 2 the
## Commander walks around, so without a mark the monsters would appear out of
## thin air in the middle of a corridor. game.gd adds one per spawn spot and
## calls pulse() when a monster comes out.
##
## Drawn in code (two rings and a soft disc), so it needs no art. If Fah draws
## a hatch or a portal, put a Sprite2D here instead and keep pulse().

@export var color := Color(0.5, 1.0, 0.55)
@export var radius := 22.0

var _t := 0.0
var _kick := 0.0   # 1 right after a monster comes out, eases back to 0


func _process(delta: float) -> void:
	_t += delta
	_kick = move_toward(_kick, 0.0, delta * 2.0)
	queue_redraw()


func pulse() -> void:
	_kick = 1.0


func _draw() -> void:
	var breathe := 0.5 + 0.5 * sin(_t * 3.0)
	var r := radius + 3.0 * breathe + 12.0 * _kick
	draw_circle(Vector2.ZERO, r, Color(color, 0.10 + 0.06 * breathe + 0.15 * _kick))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(color, 0.55), 2.0)
	draw_arc(Vector2.ZERO, r * 0.55, _t, _t + TAU * 0.75, 24, Color(color, 0.35), 2.0)   # inner ring slowly turns
