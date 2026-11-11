extends Control
## =====================================================================
## STORY SCREEN. OWNER: Fah
## =====================================================================
## Shown between levels. Which page appears is set by GameState.story_id:
##   "intro"  -> before Level 1
##   "level2" -> before Level 2
##   "ending" -> after Level 2 (then the end screen)
## Press any key / click to continue.
##
## TODO (Fah, Nov 15):
##   [ ] Story art for each page (Spaceship.png for the ending?)
##   [ ] Typewriter text effect, pixel font
##   [ ] "Loading" screen. Could simply be a short fade here.

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

var _can_continue := false


func _ready() -> void:
	var page: Dictionary = PAGES.get(GameState.story_id, PAGES["intro"])
	title_label.text = page["title"]
	body_label.text = page["text"]
	# Small delay so a key held from the last screen doesn't skip this one
	await get_tree().create_timer(0.6).timeout
	_can_continue = true


func _unhandled_input(event: InputEvent) -> void:
	if not _can_continue:
		return
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_can_continue = false
		if GameState.story_id == "ending":
			GameState.goto("end")
		else:
			GameState.goto("game")
