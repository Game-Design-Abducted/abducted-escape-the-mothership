extends CanvasLayer
## HUD. Kong's (logic). Fah supplies the art, font and icons.
##
## Only LISTENS to Events, it never touches player/enemy code directly.
## Process mode is Always (set in hud.tscn) so it keeps updating while paused.
##
##   hearts  <- Events.player_hp_changed(hp, max_hp)   (a lost heart pops and shakes)
##   timer   <- Events.time_changed(seconds_left)       (turns red under 30 s)
##   laser   <- Events.laser_charge_changed / laser_spawned / laser_picked_up / laser_fired
##   level   <- Events.level_started(level_number)
##   wave    <- Events.wave_started(wave_number)
##   message <- Events.level_finished(won)  ("TIME UP!" when GameState.last_result_time_up)
##
## Top-left row (TopLeft): hearts, level, wave. Top-right row (LaserBox): icon + laser
## status. Both are HBoxContainers, so the pieces stay together when the text changes.

const HEART := preload("res://assets/sprites/Heart.png")
const HEART_LOST := preload("res://assets/sprites/HeartDeducted.png")
const LOW_TIME := 30.0                          # seconds left when the timer turns red
const LOW_TIME_COLOR := Color(1.0, 0.35, 0.3)   # same red as the end screen's lose title

@onready var hearts: HBoxContainer = $TopLeft/Hearts
@onready var level_label: Label = $TopLeft/LevelLabel
@onready var wave_label: Label = $TopLeft/WaveLabel
@onready var time_label: Label = $TimeLabel
@onready var laser_label: Label = $LaserBox/LaserLabel
@onready var message_label: Label = $MessageLabel

var _previous_hp := -1
var _low_time := false
var _finished := false   # once the level is over, the end message stays


func _ready() -> void:
	message_label.text = ""
	level_label.text = "LEVEL %d" % GameState.current_level
	wave_label.text = "WAVE 1"
	Events.player_hp_changed.connect(_on_hp_changed)
	Events.time_changed.connect(_on_time_changed)
	Events.laser_charge_changed.connect(_on_laser_charge)
	Events.laser_spawned.connect(func(_pos): laser_label.text = "LASER READY! Grab it!")
	Events.laser_picked_up.connect(func(): message_label.text = "PRESS SPACE WHEN THE BEAM CROSSES THE TARGET")
	Events.laser_fired.connect(_on_laser_fired)
	Events.level_started.connect(_on_level_started)
	Events.wave_started.connect(_on_wave_started)
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
	# Animate only the hearts just lost (not on the first update, when the level starts)
	if _previous_hp != -1:
		for i in range(hp, mini(_previous_hp, hearts.get_child_count())):
			_animate_lost_heart(hearts.get_child(i) as TextureRect)
	_previous_hp = hp


func _animate_lost_heart(heart: TextureRect) -> void:
	heart.pivot_offset = heart.size / 2.0
	var tween := create_tween()
	tween.tween_property(heart, "scale", Vector2(1.4, 1.4), 0.12)
	tween.tween_property(heart, "rotation_degrees", 15.0, 0.05)
	tween.tween_property(heart, "rotation_degrees", -15.0, 0.05)
	tween.tween_property(heart, "rotation_degrees", 10.0, 0.05)
	tween.tween_property(heart, "rotation_degrees", 0.0, 0.05)
	tween.tween_property(heart, "scale", Vector2.ONE, 0.12)


func _on_time_changed(seconds_left: float) -> void:
	var s := ceili(seconds_left)
	@warning_ignore("integer_division")
	time_label.text = "%d:%02d" % [s / 60, s % 60]
	# time_changed fires every frame, so only touch the colour when it crosses LOW_TIME
	var low := seconds_left <= LOW_TIME
	if low != _low_time:
		_low_time = low
		if low:
			time_label.add_theme_color_override("font_color", LOW_TIME_COLOR)
		else:
			time_label.remove_theme_color_override("font_color")


func _on_laser_charge(kills: int, kills_needed: int) -> void:
	laser_label.text = "Laser charge: %d / %d kills" % [kills, kills_needed]


func _on_laser_fired(hit: bool) -> void:
	message_label.text = "DIRECT HIT!" if hit else "MISSED! Survive for another chance..."
	# A connected timer, not an await: it is dropped if the HUD is freed first
	get_tree().create_timer(1.5).timeout.connect(_clear_message)


func _clear_message() -> void:
	if not _finished:
		message_label.text = ""


func _on_level_started(level_number: int) -> void:
	level_label.text = "LEVEL %d" % level_number


func _on_wave_started(wave_number: int) -> void:
	wave_label.text = "WAVE %d" % wave_number


func _on_level_finished(won: bool) -> void:
	_finished = true
	if won:
		message_label.text = "YOU WIN!"
	elif GameState.last_result_time_up:
		message_label.text = "TIME UP!"
	else:
		message_label.text = "GAME OVER"
