extends Control
## End screen (win or lose). Ploy's.
##
## Reads GameState.last_result_won.
##   won  -> spaceship + "You escaped!" + win sound + Main Menu
##   lost -> hurt astronaut + "Game Over" + lose sound + Retry (same level) + Main Menu
##
## It moves like Fah's title screen: fades in, the title pops, the picture
## sways (the spaceship flies, the astronaut wobbles), the buttons grow and
## play her hover / click sounds, and the screen fades out before it leaves.
##
## TODO Ploy:
##  - swap in real win / lose art if Fah draws some (set it on VBox/Art below)

const WIN_ART := preload("res://assets/sprites/Spaceship.png")
const LOSE_ART := preload("res://assets/sprites/Player_Hit.png")
const WIN_SOUND := preload("res://assets/audio/sfx/win.wav")
const LOSE_SOUND := preload("res://assets/audio/sfx/lose.wav")
const SFX_HOVER := preload("res://assets/audio/sfx/ui_hover.wav")
const SFX_CLICK := preload("res://assets/audio/sfx/ui_click.wav")
const LOSE_TITLE_COLOR := Color(1.0, 0.35, 0.3)
const FADE_OUT_TIME := 0.3

@onready var art: TextureRect = $VBox/Art
@onready var title: Label = $VBox/Title
@onready var retry_button: Button = $VBox/RetryButton
@onready var menu_button: Button = $VBox/MenuButton

var _won := false
var _t := 0.0
var _leaving := false
var _sfx: AudioStreamPlayer


func _ready() -> void:
	_won = GameState.last_result_won
	var time_up := not _won and GameState.time_left <= 0.0

	if _won:
		title.text = "YOU ESCAPED!"
	elif time_up:
		title.text = "TIME UP!"
	else:
		title.text = "GAME OVER"

	if not _won:
		title.add_theme_color_override("font_color", LOSE_TITLE_COLOR)

	if _won:
		$VBox/Subtitle.text = "Welcome home, astronaut."
	elif time_up:
		$VBox/Subtitle.text = "Time ran out on level %d." % GameState.current_level
	else:
		$VBox/Subtitle.text = "The aliens got you on level %d." % GameState.current_level

	art.texture = WIN_ART if _won else LOSE_ART
	$Jingle.stream = WIN_SOUND if _won else LOSE_SOUND
	$Jingle.play()

	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)

	retry_button.visible = not _won
	var first: Button = menu_button if _won else retry_button
	first.grab_focus()

	retry_button.pressed.connect(_leave.bind(GameState.retry_level))
	menu_button.pressed.connect(_leave.bind(GameState.goto.bind("title")))

	for button: Button in [retry_button, menu_button]:
		button.mouse_entered.connect(_on_hover.bind(button, true))
		button.mouse_entered.connect(_play.bind(SFX_HOVER))
		button.mouse_exited.connect(_on_hover.bind(button, false))
		button.focus_entered.connect(_on_hover.bind(button, true))
		button.focus_exited.connect(_on_hover.bind(button, false))

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5)

	await get_tree().process_frame

	art.pivot_offset = art.size / 2.0
	title.pivot_offset = title.size / 2.0
	title.scale = Vector2(0.5, 0.5)

	create_tween().tween_property(title, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	if _won:   # the spaceship flies: gentle sway and a slow swell
		art.rotation = sin(_t * 1.3) * 0.06
		art.scale = Vector2.ONE * (1.0 + sin(_t * 2.0) * 0.04)
	else:      # the astronaut wobbles, dazed
		art.rotation = sin(_t * 2.4) * 0.12


func _on_hover(button: Button, on: bool) -> void:
	button.pivot_offset = button.size / 2.0
	create_tween().tween_property(button, "scale", Vector2(1.06, 1.06) if on else Vector2.ONE, 0.1)


func _play(stream: AudioStream) -> void:
	_sfx.stream = stream
	_sfx.play()


## Click sound and a short fade, then do what the button is for
func _leave(action: Callable) -> void:
	if _leaving:
		return
	_leaving = true
	_play(SFX_CLICK)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_TIME)
	tween.tween_property($Jingle, "volume_db", -40.0, FADE_OUT_TIME)
	tween.chain().tween_callback(action)
