extends CanvasLayer
## HUD. Kong's (logic). Fah supplies the art, font and icons.
##
## Only LISTENS to Events, it never touches player/enemy code directly.
## Process mode is Always (set in hud.tscn) so it keeps updating while paused.
##
##   hearts  <- Events.player_hp_changed(hp, max_hp)
##   timer   <- Events.time_changed(seconds_left)
##   laser   <- Events.laser_countdown_changed / laser_spawned / laser_picked_up / laser_fired
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
	Events.laser_countdown_changed.connect(_on_laser_countdown)
	Events.laser_spawned.connect(func(_pos): laser_label.text = "LASER READY! Grab it!")
	Events.laser_picked_up.connect(func(): message_label.text = "AIM AT THE ORIGIN - CLICK TO FIRE")
	Events.laser_fired.connect(_on_laser_fired)
	Events.level_finished.connect(_on_level_finished)


func _on_hp_changed(hp: int, max_hp: int) -> void:
	for child in hearts.get_children():
		child.queue_free()
	for i in max_hp:
		var icon := TextureRect.new()
		icon.texture = HEART if i < hp else HEART_LOST
		icon.custom_minimum_size = Vector2(64, 64)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hearts.add_child(icon)


func _on_time_changed(seconds_left: float) -> void:
	var s := int(ceil(seconds_left))
	time_label.text = "%d:%02d" % [s / 60, s % 60]


func _on_laser_countdown(seconds_left: float) -> void:
	laser_label.text = "Laser in %d s" % int(ceil(seconds_left))


func _on_laser_fired(hit: bool) -> void:
	message_label.text = "DIRECT HIT!" if hit else "MISSED! Survive for another chance..."
	await get_tree().create_timer(1.5).timeout
	if message_label.text != "YOU WIN!" and message_label.text != "GAME OVER":
		message_label.text = ""


func _on_level_finished(won: bool) -> void:
	message_label.text = "YOU WIN!" if won else "GAME OVER"
