extends Area2D
## Bullet, the player's normal weapon. Yang's.
##
## Layer 4 (player_attack), mask 1 (walls) + 3 (enemies).
## When it hits an enemy Hitbox it calls take_damage() on that enemy's scene root.
## It can NOT hurt the origin (egg/commander), only the laser can.

@export var speed := 450.0
@export var damage := 1
@export var lifetime := 1.5

var direction := Vector2.RIGHT


func _ready() -> void:
	rotation = direction.angle()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	get_tree().create_timer(lifetime, false).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta


func _on_body_entered(_body: Node) -> void:
	queue_free()   # hit a wall


func _on_area_entered(area: Area2D) -> void:
	var target := area.owner
	if target and target.has_method("take_damage"):
		target.take_damage(damage)
		queue_free()
