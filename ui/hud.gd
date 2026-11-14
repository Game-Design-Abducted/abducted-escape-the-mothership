extends CanvasLayer
## HUD. Kong's (logic). Fah supplies the art, font and icons.
##
## Only LISTENS to Events, it never touches player/enemy code directly.
## Process mode is Always (set in hud.tscn) so it keeps updating while paused.
##
##   hearts  <- Events.player_hp_changed(hp, max_hp)
##   timer   <- Events.time_changed(seconds_left)
##   laser   <- Events.laser_charge_changed / laser_spawned / laser_picked_up / laser_fired
##   message <- Events.level_finished(won)
##
## TODO Kong (ask Fah for the art):
##  - pixel font (put the .ttf in assets/fonts and set it in a Theme)
##  - heart lose animation, timer turns red under 30 s
##  - laser icon (Laser Item.png) next to the laser status
##  - wave number (Events.wave_started), level title

const HEART := preload("res://assets/sprites/Heart.png")
const HEART_LOST := preload("res://assets/sprites/HeartDeducted.png")
var previous_hp := -1

@onready var hearts: HBoxContainer = $Hearts
@onready var time_label: Label = $TimeLabel
@onready var laser_label: Label = $LaserLabel
@onready var message_label: Label = $MessageLabel
@onready var level_label: Label = $LevelLabel
@onready var wave_label: Label = $WaveLabel


func _ready() -> void:
	message_label.text = ""
	Events.player_hp_changed.connect(_on_hp_changed)
	Events.time_changed.connect(_on_time_changed)
	Events.laser_charge_changed.connect(_on_laser_charge)
	Events.laser_spawned.connect(func(_pos): laser_label.text = "LASER READY! Grab it!")
	Events.laser_picked_up.connect(func(): message_label.text = "PRESS SPACE WHEN THE BEAM CROSSES THE TARGET")
	Events.laser_fired.connect(_on_laser_fired)
	Events.level_finished.connect(_on_level_finished)
	level_label.text = "LEVEL %d" % GameState.current_level
	wave_label.text = "WAVE 1"
	Events.level_started.connect(_on_level_started)
	Events.wave_started.connect(_on_wave_started)



func _on_hp_changed(hp: int, max_hp: int) -> void:
	var old_hp = previous_hp

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

	if old_hp != -1 and hp < old_hp:
		for i in range(hp, old_hp):
			if i < hearts.get_child_count():
				animate_lost_heart(hearts.get_child(i))

	previous_hp = hp


func animate_lost_heart(heart: TextureRect) -> void:
	heart.pivot_offset = Vector2(32, 32)

	var tween = create_tween()

	tween.tween_property(heart, "scale", Vector2(1.4, 1.4), 0.12)
	tween.tween_property(heart, "rotation_degrees", 15.0, 0.05)
	tween.tween_property(heart, "rotation_degrees", -15.0, 0.05)
	tween.tween_property(heart, "rotation_degrees", 10.0, 0.05)
	tween.tween_property(heart, "rotation_degrees", 0.0, 0.05)
	tween.tween_property(heart, "scale", Vector2(1, 1), 0.12)




func _on_time_changed(seconds_left: float) -> void:
	var s = ceili(seconds_left)
	@warning_ignore("integer_division")
	time_label.text = "%d:%02d" % [s / 60, s % 60]

	if seconds_left <= 30.0:
		time_label.add_theme_color_override("font_color", Color.RED)
	else:
		time_label.remove_theme_color_override("font_color")



func _on_laser_charge(kills: int, kills_needed: int) -> void:
	laser_label.text = "Laser charge: %d / %d kills" % [kills, kills_needed]


func _on_laser_fired(hit: bool) -> void:
	message_label.text = "DIRECT HIT!" if hit else "MISSED! Survive for another chance..."
	await get_tree().create_timer(1.5).timeout
	if message_label.text != "YOU WIN!" and message_label.text != "GAME OVER":
		message_label.text = ""



func _on_level_finished(won: bool) -> void:
	print("FINISHED: won=", won, " | time_left=", GameState.time_left)
	
	if won:
		message_label.text = "YOU WIN!"
	elif GameState.time_left <= 0.0:
		message_label.text = "TIME UP!"
	else:
		message_label.text = "GAME OVER"

	
func _on_level_started(level_number: int) -> void:
	level_label.text = "LEVEL %d" % level_number


func _on_wave_started(wave_number: int) -> void:
	wave_label.text = "WAVE %d" % wave_number
