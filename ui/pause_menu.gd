class_name PauseMenu
extends CanvasLayer
## Pause menu. Ploy's. game.gd adds one to every level.
##
## ESC or P (the "pause" action) opens it: RESUME, RESTART LEVEL, QUIT TO MENU,
## plus the controls card. Works during aiming too: it remembers that the game
## was already paused for the laser and goes back to that on resume.
##
## Anything that keeps running while the tree is paused (the aim line, the
## Commander) checks PauseMenu.open and stands still while the menu is up.

static var open := false

const TITLE_FONT := preload("res://assets/fonts/Minecraft.ttf")
const BODY_FONT := preload("res://assets/fonts/VT323.ttf")
const SFX_HOVER := preload("res://assets/audio/sfx/ui_hover.wav")
const SFX_CLICK := preload("res://assets/audio/sfx/ui_click.wav")
const YELLOW := Color(1, 0.82, 0)
const QUIPS := [
	"the aliens are waiting politely",
	"monsters frozen mid-blorp",
	"take a breath, astronaut",
	"the egg is pretending not to watch",
	"snack break? (no burritos here)",
]

var _was_paused := false
var _root: Control
var _subtitle: Label
var _resume: Button
var _sfx: AudioStreamPlayer


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	open = false
	_build()
	_root.hide()


func _exit_tree() -> void:
	open = false   # never leave the flag on for the next scene


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if open:
			resume()
		else:
			pause()


## For tests and tools that can't name the class (see smoke_test.gd)
func is_open() -> bool:
	return open


func pause() -> void:
	if open or not GameState.running:
		return   # not while the level is ending
	_was_paused = get_tree().paused
	get_tree().paused = true
	open = true
	_subtitle.text = QUIPS.pick_random()
	_root.show()
	_resume.grab_focus()


func resume() -> void:
	if not open:
		return
	open = false
	_root.hide()
	get_tree().paused = _was_paused   # back to aiming if we paused while aiming


func _restart() -> void:
	_play(SFX_CLICK)
	open = false
	GameState.stop_level()
	GameState.retry_level()


func _quit() -> void:
	_play(SFX_CLICK)
	open = false
	GameState.stop_level()
	GameState.goto("title")


func _build() -> void:
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)

	# Small reminder in the corner while playing
	var hint := Label.new()
	hint.text = "ESC  pause"
	hint.add_theme_font_override("font", BODY_FONT)
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	hint.position = Vector2(12, 692)
	add_child(hint)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.0, 0.08, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 48)
	center.add_child(row)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 14)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(left)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", YELLOW)
	left.add_child(title)
	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_override("font", BODY_FONT)
	_subtitle.add_theme_font_size_override("font_size", 24)
	_subtitle.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	left.add_child(_subtitle)
	_resume = _button("RESUME", resume)
	left.add_child(_resume)
	left.add_child(_button("RESTART LEVEL", _restart))
	left.add_child(_button("QUIT TO MENU", _quit))

	var card := ControlsCard.controls()
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(card)


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 58)
	b.add_theme_font_override("font", TITLE_FONT)
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", YELLOW)
	b.add_theme_color_override("font_focus_color", YELLOW)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.0, 0.3, 0.95)
	normal.border_color = Color(1, 0.82, 0, 0.6)
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(29)
	var hover := normal.duplicate()
	hover.border_color = YELLOW
	hover.bg_color = Color(0.25, 0.05, 0.42, 1.0)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.pressed.connect(action)
	b.mouse_entered.connect(_play.bind(SFX_HOVER))
	return b


func _play(stream: AudioStream) -> void:
	_sfx.stream = stream
	_sfx.play()
