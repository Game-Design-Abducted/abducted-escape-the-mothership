extends Node
## GameState (autoload). Kong's: win/lose, level switching, the countdown.
## default process mode on purpose, so the clock stops while the tree is paused (laser aim).

const LEVEL_TIME := 180.0
const LAST_LEVEL := 2

const SCENES := {
	"title": "res://ui/title_screen.tscn",
	"story": "res://ui/story_screen.tscn",
	"game": "res://game/game.tscn",
	"end": "res://ui/end_screen.tscn",
}

var current_level := 1
var time_left := LEVEL_TIME
var running := false
var last_result_won := false
## True when the last level was lost because the clock ran out (HUD and end screen show "TIME UP!")
var last_result_time_up := false
## Which page story_screen shows: "intro", "level2" or "ending"
var story_id := "intro"


func _ready() -> void:
	Events.origin_destroyed.connect(func(): finish_level(true))
	Events.player_died.connect(func(): finish_level(false))


func _process(delta: float) -> void:
	if not running:
		return
	time_left = maxf(time_left - delta, 0.0)
	Events.time_changed.emit(time_left)
	if time_left <= 0.0:
		finish_level(false, true)


# ---------- called by UI / game ----------

## Title screen START button
func start_new_game() -> void:
	current_level = 1
	story_id = "intro"
	goto("story")


## game.gd calls this after the level has been built
func begin_level() -> void:
	time_left = LEVEL_TIME
	running = true
	Events.level_started.emit(current_level)
	Events.time_changed.emit(time_left)


## Pause menu RESTART / QUIT: stop the clock so it can't run out after we've left the level
func stop_level() -> void:
	running = false


## End screen RETRY button
func retry_level() -> void:
	goto("game")


## Called on win (origin destroyed) or loss (died / time up)
func finish_level(won: bool, time_up := false) -> void:
	if not running:
		return   # already finished, ignore duplicates
	running = false
	last_result_won = won
	last_result_time_up = time_up
	Events.level_finished.emit(won)
	# short delay so players see what happened. runs while paused too
	get_tree().create_timer(1.5, true).timeout.connect(_after_level.bind(won))


func _after_level(won: bool) -> void:
	get_tree().paused = false
	if not won:
		goto("end")
	elif current_level < LAST_LEVEL:
		current_level += 1
		story_id = "level2"
		goto("story")
	else:
		story_id = "ending"
		goto("story")


func goto(scene_key: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(SCENES[scene_key])
