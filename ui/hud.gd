extends CanvasLayer
## HUD. Kong's (logic). Fah supplies the art, font and icons.
##
## Only LISTENS to Events, it never touches player/enemy code directly.
## Process mode is Always (set in hud.tscn) so it keeps updating while paused.
##
##   hearts  <- Events.player_hp_changed(hp, max_hp)
##   timer   <- Events.time_changed(seconds_left)
##   laser   <- Events.laser_quota_changed / laser_spawned / laser_picked_up / laser_fired
##   message <- Events.level_finished(won)
##
## TODO Kong (ask Fah for the art):
##  - pixel font (put the .ttf in assets/fonts and set it in a Theme)
##  - heart lose animation, timer turns red under 30 s
##  - laser icon (Laser Item.png) next to the laser status
##  - wave number (Events.wave_started), level title

const HEART := preload("res://assets/sprites/Heart.png")
const HEART_LOST := preload("res://assets/sprites/HeartDeducted.png")

@onready var hearts: HBoxContainer = $Hearts
@onready var time_label: Label = $TimeLabel
@onready var laser_label: Label = $LaserLabel
@onready var message_label: Label = $MessageLabel


func _ready() -> void:
	message_label.text = ""
	Events.player_hp_changed.connect(_on_hp_changed)
	Events.time_changed.connect(_on_time_changed)
	Events.laser_quota_changed.connect(_on_laser_quota)
	Events.laser_spawned.connect(func(_pos): laser_label.text = "LASER READY! Grab it!")
	Events.laser_picked_up.connect(func(): message_label.text = "PRESS SPACE WHEN THE BEAM CROSSES THE TARGET")
	Events.laser_fired.connect(_on_laser_fired)
	Events.level_finished.connect(_on_level_finished)


func _on_hp_changed(hp: int, max_hp: int) -> void:
	# Create heart icons only when the count changes, then just swap textures
	while hearts.get_child_count() < max_hp:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(64, 64)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hearts.add_child(icon)
	for i in hearts.get_child_count():
		var heart := hearts.get_child(i) as TextureRect
		heart.visible = i < max_hp
		heart.texture = HEART if i < hp else HEART_LOST


func _on_time_changed(seconds_left: float) -> void:
	var s := ceili(seconds_left)
	@warning_ignore("integer_division")
	time_label.text = "%d:%02d" % [s / 60, s % 60]


func _on_laser_quota(progress: Dictionary) -> void:
	var parts: Array[String] = []
	for type in progress:
		parts.append("%s %d/%d" % [type.capitalize(), progress[type][0], progress[type][1]])
	laser_label.text = "Laser charge\n" + "  ".join(parts)


func _on_laser_fired(hit: bool) -> void:
	message_label.text = "DIRECT HIT!" if hit else "MISSED! Survive for another chance..."
	await get_tree().create_timer(1.5).timeout
	if message_label.text != "YOU WIN!" and message_label.text != "GAME OVER":
		message_label.text = ""


func _on_level_finished(won: bool) -> void:
	message_label.text = "YOU WIN!" if won else "GAME OVER"
