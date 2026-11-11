extends Node
## =====================================================================
## WAVE MANAGER. OWNER: Ploy (Enemy + Wave Programmer)
## =====================================================================
## game.gd (Kong) creates this and calls:
##     wave_manager.setup(level.get_enemy_paths(), GameState.current_level)
## After that it spawns monsters forever, wave after wave, on Mew's paths.
## When the list of waves runs out it repeats the last one, each loop a bit faster.
##
## It uses a Timer node, so spawning stops automatically while the game is
## paused (laser aim mode).
##
## TODO (Ploy):
##   Nov 11  [x] Basic spawning (works)
##   Nov 13  [ ] Design real waves for level 1 in WAVES[1]
##           [ ] Pick a path per enemy type? (e.g. tanks only use Path_A)
##   Nov 14  [ ] Level 2 waves in WAVES[2] (harder + more fast monsters)
##           [ ] Optional: emit Events.wave_started so Fah's HUD can show "Wave 3"

const ENEMY_SCENES := {
	"basic": preload("res://enemies/enemy_basic.tscn"),
	"fast": preload("res://enemies/enemy_fast.tscn"),
	"tank": preload("res://enemies/enemy_tank.tscn"),
}

## Each wave: which monster, how many, seconds between spawns.
## "pause" = seconds of quiet before the NEXT wave starts.
const WAVES := {
	1: [
		{"type": "basic", "count": 5, "interval": 1.5, "pause": 3.0},
		{"type": "fast", "count": 4, "interval": 1.2, "pause": 3.0},
		{"type": "tank", "count": 2, "interval": 2.5, "pause": 4.0},
		{"type": "mixed", "count": 10, "interval": 1.0, "pause": 4.0},
	],
	2: [
		{"type": "mixed", "count": 8, "interval": 1.0, "pause": 2.0},
		{"type": "fast", "count": 8, "interval": 0.7, "pause": 2.0},
		{"type": "tank", "count": 4, "interval": 1.5, "pause": 3.0},
		{"type": "mixed", "count": 15, "interval": 0.6, "pause": 3.0},
	],
}

## Every time the wave list loops, intervals are multiplied by this
@export var loop_speedup := 0.85

var _paths: Array[Path2D] = []
var _waves: Array = []
var _wave_index := -1
var _left_in_wave := 0
var _speed_factor := 1.0
var _timer: Timer


func setup(paths: Array[Path2D], level_number: int) -> void:
	_paths = paths
	_waves = WAVES.get(level_number, WAVES[1])
	if _paths.is_empty():
		push_warning("WaveManager: level has no paths under 'Paths', nothing will spawn.")
		return
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer)
	add_child(_timer)
	_start_next_wave()


func _start_next_wave() -> void:
	_wave_index += 1
	if _wave_index >= _waves.size():
		_wave_index = _waves.size() - 1   # keep repeating the hardest wave
		_speed_factor *= loop_speedup
	_left_in_wave = _waves[_wave_index]["count"]
	Events.wave_started.emit(_wave_index + 1)
	_timer.start(0.5)


func _on_timer() -> void:
	var wave: Dictionary = _waves[_wave_index]
	if _left_in_wave <= 0:
		_start_next_wave()
		return
	spawn_enemy(wave["type"])
	_left_in_wave -= 1
	if _left_in_wave > 0:
		_timer.start(wave["interval"] * _speed_factor)
	else:
		_timer.start(wave["pause"] * _speed_factor)


func spawn_enemy(type: String) -> Node:
	if type == "mixed":
		type = ENEMY_SCENES.keys().pick_random()
	var enemy: Node = ENEMY_SCENES[type].instantiate()
	var path: Path2D = _paths.pick_random()
	path.add_child(enemy)   # enemy is a PathFollow2D, so it must live under a Path2D
	return enemy
