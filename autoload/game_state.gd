extends Node
## GameState (autoload). Kong's: win/lose and switching between levels.
##
## Keeps the stuff that has to survive a scene change: current level, the
## 3 minute countdown, and which story page comes next.
##
## Flow:
##   title_screen -> story("intro") -> game (level 1)
##     win  -> story("level2") -> game (level 2)
##     win  -> story("ending") -> end_screen (won)
##     lose -> end_screen (lost) -> retry same level or back to menu
##
## The timer only ticks while `running` is true. This node uses the default
## process mode, so the clock also stops when the tree is paused (laser aim).
## If you want it to keep going while aiming, set
## process_mode = PROCESS_MODE_ALWAYS in _ready() and check
## get_tree().paused yourself in _process().
##
## TODO Kong:
##  - a short "YOU WIN / TIME UP" moment before the scene changes (right now
##    it's just a 1.5 s delay)
##  - decide if the timer should pause while aiming (it does at the moment)
##  - decide if retry restarts level 1 or the level you died on (right now
##    it's the same level)

const LEVEL_TIME := 180.0   # 3 minutes, from the design doc
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
		finish_level(false)


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


## End screen RETRY button
func retry_level() -> void:
	goto("game")


## Called on win (origin destroyed) or loss (died / time up)
func finish_level(won: bool) -> void:
	if not running:
		return   # already finished, ignore duplicates
	running = false
	last_result_won = won
	Events.level_finished.emit(won)
	# Short delay so players can see what happened. Runs even while the game is paused.
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
