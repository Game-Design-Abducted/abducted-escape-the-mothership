extends Control
## Title screen, the game's main scene. Fah's.
## sounds load only if the files exist, so it still runs without assets/audio.

const TITLE_FONT := "res://assets/fonts/Minecraft.ttf"
const BODY_FONT := "res://assets/fonts/VT323.ttf"
const MUSIC := "res://assets/audio/music/bgm_menu.ogg"
const SFX_HOVER := "res://assets/audio/sfx/ui_hover.wav"
const SFX_CLICK := "res://assets/audio/sfx/ui_click.wav"

@onready var ufo: TextureRect = $UFO
@onready var beam: TextureRect = $Beam
@onready var astronaut: TextureRect = $Astronaut
@onready var stars: Control = $Stars
@onready var start_button: Button = $StartButton
@onready var music: AudioStreamPlayer = $Music
@onready var sfx: AudioStreamPlayer = $Sfx

var _t := 0.0
var _ufo_y := 0.0
var _astro_y := 0.0
var _starting := false
var _hover_tween: Tween
var _mode_button: Button
var _mode_info: Label   # the hint label under START

## [name, one-line description, color] for GameState.hardcore false / true
const MODES := {
	false: ["NORMAL", "4 hearts, laser gets easier after a miss", Color.WHITE],
	true: ["HARDCORE", "2 hearts, faster monsters, no laser help", Color(1.0, 0.35, 0.3)],
}


func _ready() -> void:
	_ufo_y = ufo.position.y
	_astro_y = astronaut.position.y
	_apply_fonts()
	_setup_audio()
	_twinkle_stars()
	_add_guide_cards()
	_add_mode_picker()
	start_button.grab_focus() # before connecting, so no hover sound on load
	start_button.pressed.connect(_on_start)
	start_button.mouse_entered.connect(_on_hover.bind(true))
	start_button.mouse_entered.connect(_play.bind(SFX_HOVER)) # mouse only: focus would play it again
	start_button.mouse_exited.connect(_on_hover.bind(false))
	start_button.focus_entered.connect(_on_hover.bind(true))
	start_button.focus_exited.connect(_on_hover.bind(false))
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)


func _process(delta: float) -> void:
	_t += delta
	ufo.position.y = _ufo_y + sin(_t * 2.0) * 6.0
	ufo.rotation = sin(_t * 1.3) * 0.04
	beam.modulate.a = 0.55 + 0.25 * sin(_t * 3.0)
	astronaut.position.y = _astro_y + sin(_t * 1.5) * 8.0


## Controls on the left, how to win (and the Space Junk items) on the right
func _add_guide_cards() -> void:
	var controls := ControlsCard.controls()
	controls.position = Vector2(36, 300)
	add_child(controls)
	var how := ControlsCard.how_to_win()
	add_child(how)
	how.reset_size()
	how.position = Vector2(size.x - how.size.x - 36, 300)


## NORMAL / HARDCORE switch between START and the hint. click it or press left / right.
## the hint line under it shows what the mode means
func _add_mode_picker() -> void:
	_mode_button = Button.new()
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.12, 0, 0.25, 0.9 if state == "normal" else 1.0)
		box.set_border_width_all(2)
		box.set_corner_radius_all(18)
		_mode_button.add_theme_stylebox_override(state, box)
	_mode_button.add_theme_font_override("font", start_button.get_theme_font("font"))
	_mode_button.add_theme_font_size_override("font_size", 22)
	_mode_button.position = Vector2(start_button.position.x + 45, 390)
	_mode_button.size = Vector2(start_button.size.x - 90, 38)
	_mode_button.focus_mode = Control.FOCUS_NONE   # left / right and clicks switch it, ENTER stays on START
	_mode_button.pressed.connect(_toggle_mode)
	_mode_button.mouse_entered.connect(_play.bind(SFX_HOVER))
	add_child(_mode_button)
	_mode_info = $Hint
	_mode_info.position.y = 434
	_mode_info.add_theme_font_size_override("font_size", 22)
	_show_mode()


func _toggle_mode() -> void:
	GameState.hardcore = not GameState.hardcore
	_play(SFX_CLICK)
	_show_mode()


func _show_mode() -> void:
	var mode: Array = MODES[GameState.hardcore]
	_mode_button.text = "< %s >" % mode[0]
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		_mode_button.add_theme_color_override(c, mode[2])
	for state in ["normal", "hover", "pressed", "focus"]:
		(_mode_button.get_theme_stylebox(state) as StyleBoxFlat).border_color = mode[2]
	_mode_info.text = mode[1]
	_mode_info.modulate = Color(mode[2], 0.8)


func _twinkle_stars() -> void:
	for s in stars.get_children():
		s.pivot_offset = s.size / 2.0
		var tw := create_tween().set_loops()
		var speed := randf_range(0.6, 1.4)
		tw.tween_interval(randf_range(0.0, 1.5))
		tw.tween_property(s, "modulate:a", 0.25, speed).set_trans(Tween.TRANS_SINE)
		tw.tween_property(s, "modulate:a", 1.0, speed).set_trans(Tween.TRANS_SINE)


func _on_hover(on: bool) -> void:
	start_button.pivot_offset = start_button.size / 2.0
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(start_button, "scale", Vector2(1.08, 1.08) if on else Vector2.ONE, 0.1)


func _on_start() -> void:
	if _starting:
		return
	_starting = true
	_play(SFX_CLICK)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_property(music, "volume_db", -40.0, 0.5)
	tw.chain().tween_callback(GameState.start_new_game)


## _input, not _unhandled_input: a focused button would eat left / right for focus moves
func _input(event: InputEvent) -> void:
	if not _starting and (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")):
		_toggle_mode()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _starting and event.is_action_pressed("ui_accept") and not start_button.has_focus():
		_on_start()


# ---------------------------------------------------------------- helpers

func _apply_fonts() -> void:
	var title_font: Font = _load_if_exists(TITLE_FONT)
	var body_font: Font = _load_if_exists(BODY_FONT)
	if title_font:
		$Title.add_theme_font_override("font", title_font)
		start_button.add_theme_font_override("font", title_font)
	if body_font:
		$Subtitle.add_theme_font_override("font", body_font)
		$Hint.add_theme_font_override("font", body_font)
	elif title_font:
		$Subtitle.add_theme_font_override("font", title_font)


func _setup_audio() -> void:
	var stream = _load_if_exists(MUSIC)
	if stream:
		music.stream = stream # loops via its .import file
		music.play()


func _play(path: String) -> void:
	var s = _load_if_exists(path)
	if s:
		sfx.stream = s
		sfx.play()


func _load_if_exists(path: String) -> Resource:
	return load(path) if ResourceLoader.exists(path) else null
