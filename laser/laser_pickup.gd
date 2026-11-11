extends Area2D
## =====================================================================
## LASER GUN PICKUP. OWNER: Kong
## =====================================================================
## Spawned by laser_manager.gd at one of Mew's LaserSpawns markers.
## Layer 5 (pickups), mask 2 (player). Emits `picked_up` when the player touches it.
##
## TODO (Kong / Fah):
##   [ ] Bobbing / glowing animation so players notice it
##   [ ] Optional: disappear after N seconds if not collected?

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
