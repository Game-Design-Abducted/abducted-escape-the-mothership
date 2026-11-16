extends Node
## Wave manager, game.gd calls setup(). Ploy's.
# uses a Timer node so spawning pauses by itself during laser aim mode

const MAZE_WANDER := preload("res://enemies/maze_wander.gd")
const ENEMY_SCENES := {
	"basic": preload("res://enemies/enemy_basic.tscn"),
	"fast": preload("res://enemies/enemy_fast.tscn"),
	"tank": preload("res://enemies/enemy_tank.tscn"),
}

## "interval" = seconds between spawns, "pause" = quiet before the next wave
const WAVES := {
	1: [
		{"type": "basic", "count": 4, "interval": 2.0, "pause": 5.0},
		{"type": "basic", "count": 6, "interval": 1.5, "pause": 5.0},
		{"type": "fast", "count": 4, "interval": 1.6, "pause": 6.0},
		{"type": "tank", "count": 2, "interval": 3.0, "pause": 7.0},
		{"type": "mixed", "count": 10, "interval": 1.4, "pause": 6.0},
		{"type": "fast", "count": 8, "interval": 1.0, "pause": 6.0},
		{"type": "mixed", "count": 14, "interval": 1.0, "pause": 5.0},
	],
	2: [
		{"type": "mixed", "count": 8, "interval": 1.6, "pause": 4.0},    # a breather to find the Commander
		{"type": "fast", "count": 8, "interval": 1.1, "pause": 4.0},
		{"type": "tank", "count": 4, "interval": 1.8, "pause": 3.0},
		{"type": "fast", "count": 10, "interval": 0.6, "pause": 3.0},
		{"type": "mixed", "count": 14, "interval": 0.8, "pause": 3.0},
		{"type": "tank", "count": 5, "interval": 1.4, "pause": 2.0},
		{"type": "fast", "count": 12, "interval": 0.5, "pause": 3.0},
		{"type": "mixed", "count": 18, "interval": 0.6, "pause": 3.0},
	],
}

## interval multiplier each time the wave list loops
@export var loop_speedup := 0.85
## floor for the loop speedup so late game doesn't flood
@export var min_speed_factor := 0.4
## true = every monster gets its own random route (maze_wander.gd), false = Mew's fixed paths
@export var random_routes := true
## random routes reach you from more sides, so those monsters walk a bit slower
const RANDOM_ROUTE_SPEED := 0.75
## seconds of quiet at level start
@export var start_delay := 2.0
## spawning waits while this many monsters are alive
@export var max_alive := 40

var _paths: Array[Path2D] = []
var _waves: Array = []
var _wave_index := -1
var _left_in_wave := 0
var _speed_factor := 1.0
var _timer: Timer
var _wander: RefCounted   # maze_wander.gd


## per level cap, overrides max_alive. random routes come from every side, so fewer than with fixed paths
const MAX_ALIVE := {1: 8, 2: 10}
## hardcore (GameState.hardcore): more monsters, walking faster, chasing you more often
const HARDCORE_MAX_ALIVE := {1: 13, 2: 13}
const HARDCORE_ROUTE_SPEED := 0.9
const HARDCORE_CHASE_SCALE := 2.0


func setup(paths: Array[Path2D], level_number: int) -> void:
	_paths = paths
	_waves = WAVES.get(level_number, WAVES[1])
	max_alive = (HARDCORE_MAX_ALIVE if GameState.hardcore else MAX_ALIVE).get(level_number, max_alive)
	if _paths.is_empty():
		push_warning("WaveManager: level has no paths under 'Paths', nothing will spawn.")
		return
	var level := _paths[0].get_parent().get_parent() if _paths[0].get_parent() else null   # Paths sits on the level root
	var walls := level.get_node_or_null("Walls") as TileMapLayer if level else null
	if random_routes and walls:
		_wander = MAZE_WANDER.new(walls)
		if not _wander.is_ready():
			_wander = null
		elif GameState.hardcore:
			_wander.chase_scale = HARDCORE_CHASE_SCALE
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer)
	add_child(_timer)
	_start_next_wave()


## game.gd calls this when the level is won or lost
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
		_timer.start(0.5)
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
	if _wander:
		# its own Path2D: starts where Mew's path starts (the egg), then wanders off
		var start := path.to_global(path.curve.get_point_position(0))
		var own := Path2D.new()
		own.curve = Curve2D.new()
		own.curve.add_point(start)
		path.get_parent().add_child(own)
		enemy.wander = _wander
		enemy.speed *= HARDCORE_ROUTE_SPEED if GameState.hardcore else RANDOM_ROUTE_SPEED
		enemy.monster_type = type
		own.add_child(enemy)
		enemy.extend_route()
		enemy.tree_exited.connect(own.queue_free)
	else:
		path.add_child(enemy)   # PathFollow2D must be a child of a Path2D
	Events.enemy_spawned.emit(enemy)
	return enemy
