extends Area2D
## Laser gun pickup. Yang's.
##
## laser_manager.gd spawns it at one of Mew's LaserSpawns markers.
## Layer 5 (pickups), mask 2 (player). Emits `picked_up` when the player touches it.
##
## TODO Yang (Fah can help with the art):
##  - bobbing / glowing animation so players actually notice it
##  - maybe make it disappear after N seconds if nobody grabs it?

signal picked_up

var _taken := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	# Simple bob so it stands out. Replace with a real animation later.
	$Sprite2D.position.y = sin(Time.get_ticks_msec() / 200.0) * 3.0


func _on_body_entered(body: Node) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	picked_up.emit()
	queue_free()
