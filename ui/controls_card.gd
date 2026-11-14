class_name ControlsCard
extends PanelContainer
## On-screen guide cards for the title screen and pause menu, so both show the same thing. Ploy's.

const TITLE_FONT := preload("res://assets/fonts/Minecraft.ttf")
const BODY_FONT := preload("res://assets/fonts/VT323.ttf")
const YELLOW := Color(1, 0.82, 0)

## [keys, what they do]
const CONTROLS := [
	[["W A S D", "ARROWS"], "move"],
	[["SPACE", "J"], "shoot"],
	[["K", "CLICK"], "fire the laser"],
	[["ESC", "P"], "pause"],
]
const STEPS := [
	"1  Shoot monsters to charge the laser",
	"2  Grab the laser gun",
	"3  Win the laser mini-game to hit it",
]
## [item kind, name, what it does]
const JUNK := [
	["bomb", "Whoopee Bomb", "pops monsters nearby"],
	["disco", "Disco Ball", "monsters dance, can't hurt"],
	["snack", "Space Burrito", "+1 heart"],
]


static func controls() -> ControlsCard:
	var card := _card("CONTROLS")
	for row in CONTROLS:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var keys := HBoxContainer.new()   # fixed width, so the actions line up
		keys.add_theme_constant_override("separation", 6)
		keys.custom_minimum_size.x = 150
		for key: String in row[0]:
			keys.add_child(_key_chip(key))
		line.add_child(keys)
		var what := _label(row[1], 24, Color.WHITE)
		line.add_child(what)
		card.get_child(0).add_child(line)
	return card


static func how_to_win() -> ControlsCard:
	var card := _card("HOW TO ESCAPE")
	var box: VBoxContainer = card.get_child(0)
	for step: String in STEPS:
		box.add_child(_label(step, 22, Color.WHITE))
	var junk_title := _label("SPACE JUNK  (monsters drop it)", 22, YELLOW)
	box.add_child(junk_title)
	for item in JUNK:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		var icon := TextureRect.new()
		icon.texture = ItemDrop.texture_for(item[0])
		icon.custom_minimum_size = Vector2(30, 30)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		line.add_child(icon)
		line.add_child(_label("%s: %s" % [item[1], item[2]], 20, Color(0.9, 0.9, 1.0)))
		box.add_child(line)
	return card


static func _card(title: String) -> ControlsCard:
	var card := ControlsCard.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.02, 0.18, 0.82)
	style.border_color = YELLOW
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var header := _label(title, 22, YELLOW)
	header.add_theme_font_override("font", TITLE_FONT)
	box.add_child(header)
	return card


static func _key_chip(text: String) -> PanelContainer:
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.95, 1.0)
	style.border_color = Color(0.35, 0.3, 0.5)
	style.set_border_width_all(2)
	style.border_width_bottom = 4   # looks like a key you can press
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	chip.add_theme_stylebox_override("panel", style)
	chip.add_child(_label(text, 20, Color(0.12, 0.05, 0.25)))
	return chip


static func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", BODY_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label
