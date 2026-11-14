extends Control
## Story screen. Yang's.
##
## Shown between levels. GameState.story_id decides which page:
##   "intro"  -> before level 1
##   "level2" -> before level 2
##   "ending" -> after level 2 (then the end screen)
## Press any key / click to continue.
##
## Each page shows Fah's animated art (assets/story/) behind the text.
##
## TODO Yang:
##  - typewriter text effect, pixel font
##  - "loading" screen, could just be a short fade here

const ART := {
	"intro": "res://assets/story/Story_Intro.tscn",
	"level2": "res://assets/story/Story_Level2.tscn",
	"ending": "res://assets/story/Story_Ending.tscn",
}

const PAGES := {
	"intro": {
		"title": "LEVEL 1 - THE ALIEN EGG",
		"text": "You wake up inside an alien spacecraft. You've been abducted.\n\nMonsters are pouring out of a mysterious alien egg. Your gun can stop the monsters, but not the egg.\n\nSurvive until the alien LASER GUN appears, then grab it and blast the egg. You have 3 minutes.",
	},
	"level2": {
		"title": "LEVEL 2 - THE ALIEN COMMANDER",
		"text": "The egg is destroyed and the control room is open.\n\nBut the monsters answer to someone: the Alien Commander. It never stops moving.\n\nGet the laser, aim carefully, and take it down before time runs out.",
	},
	"ending": {
		"title": "HOMEWARD BOUND",
		"text": "The Commander falls and drops the NAVIGATION CORE.\n\nYou plug it into the ship's controls, set the destination: EARTH.\n\nThe mothership turns around. You're going home.",
	},
}

@onready var title_label: Label = $VBox/Title
@onready var body_label: Label = $VBox/Body

const INPUT_DELAY_MSEC := 600   # so a key held from the last screen doesn't skip this one

var _accept_input_at := 0
var _left := false


func _ready() -> void:
	var page: Dictionary = PAGES.get(GameState.story_id, PAGES["intro"])
	title_label.text = page["title"]
	body_label.text = page["text"]
	var art: PackedScene = load(ART.get(GameState.story_id, ART["intro"]))
	var art_node := art.instantiate()
	add_child(art_node)
	move_child(art_node, $Background.get_index() + 1)   # over the plain background, under the text
	$Background.hide()
	# A timestamp, not an awaited timer: a pending await kept this screen
	# (and its art) alive when the scene changed before the timer fired.
	_accept_input_at = Time.get_ticks_msec() + INPUT_DELAY_MSEC


func _unhandled_input(event: InputEvent) -> void:
	if _left or Time.get_ticks_msec() < _accept_input_at:
		return
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_left = true
		if GameState.story_id == "ending":
			GameState.goto("end")
		else:
			GameState.goto("game")
