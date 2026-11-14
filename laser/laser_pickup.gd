extends Area2D
## Laser gun pickup, spawned by laser_manager.gd. Yang's.
## layer 5, mask 2 (player).

signal picked_up

var _taken := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(_delta: float) -> void:
	$Sprite2D.position.y = sin(Time.get_ticks_msec() / 200.0) * 3.0


func _on_body_entered(body: Node) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	picked_up.emit()
	queue_free()
