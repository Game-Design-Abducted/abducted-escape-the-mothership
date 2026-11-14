extends Control
## Title / home screen. Fah's. This is the game's main scene.
##
## Built from the layered art in assets/home/ so the pieces can move:
##   - stars twinkle, light beam pulses, UFO bobs, astronaut floats in the beam
##   - START button: hover grow + sound, click sound, fade out
##   - title music loops
## Enter / Space also press START.
##
## Sounds are loaded only if the files exist, so this scene still runs if
## assets/audio is missing. (The fonts are also set in the .tscn, so those must exist.)

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


func _ready() -> void:
	_ufo_y = ufo.position.y
	_astro_y = astronaut.position.y
	_apply_fonts()
	_setup_audio()
	_twinkle_stars()
	start_button.grab_focus() # before connecting, so no hover sound on load
	start_button.pressed.connect(_on_start)
	start_button.mouse_entered.connect(_on_hover.bind(true))
	start_button.mouse_entered.connect(_play.bind(SFX_HOVER)) # mouse only: focus would play it again
	start_button.mouse_exited.connect(_on_hover.bind(false))
	start_button.focus_entered.connect(_on_hover.bind(true))
	start_button.focus_exited.connect(_on_hover.bind(false))
	# fade in
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)


func _process(delta: float) -> void:
	_t += delta
	ufo.position.y = _ufo_y + sin(_t * 2.0) * 6.0
	ufo.rotation = sin(_t * 1.3) * 0.04
	beam.modulate.a = 0.55 + 0.25 * sin(_t * 3.0)
	astronaut.position.y = _astro_y + sin(_t * 1.5) * 8.0


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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not start_button.has_focus():
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
