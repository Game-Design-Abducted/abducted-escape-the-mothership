extends Node
## Wave manager. Ploy's.
##
## game.gd (Kong) creates this and calls
##     wave_manager.setup(level.get_enemy_paths(), GameState.current_level)
## After that it keeps spawning monsters on Mew's paths, wave after wave.
## When the wave list runs out it repeats the last wave, a bit faster each loop.
##
## It uses a Timer node, so spawning stops by itself when the game is paused
## (laser aim mode).
##
## TODO Ploy:
##  - basic spawning (done, works)
##  - design real waves for level 1 in WAVES[1] (done)
##  - maybe pick a path per enemy type (e.g. tanks only on Path_A)
##  - level 2 waves in WAVES[2] (done: denser, more fast monsters)
##  - Events.wave_started(n) is emitted for every wave, so Kong's HUD can show "Wave 3" (done)
##  - quiet start (`start_delay`) and a cap on monsters alive (`max_alive`) (done)

const ENEMY_SCENES := {
	"basic": preload("res://enemies/enemy_basic.tscn"),
	"fast": preload("res://enemies/enemy_fast.tscn"),
	"tank": preload("res://enemies/enemy_tank.tscn"),
}

## Each wave: which monster, how many, seconds between spawns.
## "pause" = seconds of quiet before the NEXT wave starts.
const WAVES := {
	1: [
		{"type": "basic", "count": 4, "interval": 2.0, "pause": 5.0},    # learn to shoot
		{"type": "basic", "count": 6, "interval": 1.5, "pause": 5.0},
		{"type": "fast", "count": 4, "interval": 1.6, "pause": 6.0},     # fast ones show up
		{"type": "tank", "count": 2, "interval": 3.0, "pause": 7.0},     # first tanks
		{"type": "mixed", "count": 10, "interval": 1.4, "pause": 6.0},
		{"type": "fast", "count": 8, "interval": 1.0, "pause": 6.0},
		{"type": "mixed", "count": 14, "interval": 1.0, "pause": 5.0},
	],
	2: [
		{"type": "mixed", "count": 8, "interval": 1.2, "pause": 3.0},
		{"type": "fast", "count": 8, "interval": 0.8, "pause": 3.0},
		{"type": "tank", "count": 4, "interval": 1.8, "pause": 3.0},
		{"type": "fast", "count": 10, "interval": 0.6, "pause": 3.0},
		{"type": "mixed", "count": 14, "interval": 0.8, "pause": 3.0},
		{"type": "tank", "count": 5, "interval": 1.4, "pause": 2.0},     # tanks first
		{"type": "fast", "count": 12, "interval": 0.5, "pause": 3.0},    # then fast ones
		{"type": "mixed", "count": 18, "interval": 0.6, "pause": 3.0},
	],
}

## Every time the wave list loops, intervals are multiplied by this
@export var loop_speedup := 0.85
## ...but never below this, or the last minute floods the map with monsters
@export var min_speed_factor := 0.4
## Seconds of quiet at the start of a level, so the player can look around first
@export var start_delay := 2.0
## Never more than this many monsters alive at once. Spawning waits while the map
## is full, so a player who stops shooting gets a crowd, not hundreds of monsters.
@export var max_alive := 40

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


## No more monsters. game.gd calls this when the level is won or lost.
func stop() -> void:
	if _timer:
		_timer.stop()


func _start_next_wave() -> void:
	_wave_index += 1
	if _wave_index >= _waves.size():
		_wave_index = _waves.size() - 1   # keep repeating the hardest wave
		_speed_factor = maxf(_speed_factor * loop_speedup, min_speed_factor)
	_left_in_wave = _waves[_wave_index]["count"]
	Events.wave_started.emit(_wave_index + 1)
	_timer.start(maxf(start_delay, 0.05) if _wave_index == 0 and _speed_factor == 1.0 else 0.5)


func _on_timer() -> void:
	var wave: Dictionary = _waves[_wave_index]
	if _left_in_wave <= 0:
		_start_next_wave()
		return
	if get_tree().get_nodes_in_group("enemies").size() >= max_alive:
		_timer.start(0.5)   # map is full: try again soon, the wave is not used up
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
	Events.enemy_spawned.emit(enemy)
	return enemy
