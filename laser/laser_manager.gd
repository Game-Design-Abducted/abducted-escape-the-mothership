extends Node
## Laser manager, the special mechanic. Yang's.
##
## How it loops:
##   1. the laser CHARGES from kills: the player has to kill `first_kills`
##      monsters (Events.enemy_killed) -> Events.laser_charge_changed
##      (so hiding in a corner never gets you a laser)
##   2. spawn laser_pickup at a random LaserSpawns marker -> Events.laser_spawned
##   3. player touches it -> PAUSE the game, start aim mode -> Events.laser_picked_up
##   4. the aim line sweeps, player presses fire -> UNPAUSE -> Events.laser_fired(hit)
##        hit  -> origin.take_laser_hit() -> Events.origin_destroyed -> GameState: win
##        miss -> charge again (`retry_kills` kills) -> back to step 2
##
## game.gd calls setup(level, player, origin).
##
## TODO Yang:
##  - charge + spawn + pickup (done, works)
##  - freeze, sweep-aim, shoot, hit/miss, retry (basic version works)
##  - sound when the charge completes / on fire
##  - should walls block the laser? Right now it goes through them
##  - tune the kill counts and sweep speed per level with playtesting

@export var first_kills := 10     ## kills needed before the first laser appears
@export var retry_kills := 6      ## kills needed after a miss
@export var sweep_speed_level_1 := 90.0    ## aim line speed, degrees per second
@export var sweep_speed_level_2 := 120.0

const PICKUP_SCENE := preload("res://laser/laser_pickup.tscn")
const AIM_SCRIPT := preload("res://laser/aim_mode.gd")

var _level: Level
var _player: Node2D
var _origin: Origin
var _kills := 0
var _needed := 0
var _charging := false   ## true while counting kills toward the next pickup


func setup(level: Level, player: Node2D, origin: Origin) -> void:
	_level = level
	_player = player
	_origin = origin
	Events.enemy_killed.connect(_on_enemy_killed)
	_start_charging(first_kills)


func _start_charging(kills_needed: int) -> void:
	_kills = 0
	_needed = kills_needed
	_charging = true
	Events.laser_charge_changed.emit(_kills, _needed)


func _on_enemy_killed(_enemy: Node) -> void:
	if not _charging:
		return
	_kills += 1
	Events.laser_charge_changed.emit(_kills, _needed)
	if _kills >= _needed:
		_charging = false
		_spawn_pickup()


func _spawn_pickup() -> void:
	var spots := _level.get_laser_spawn_points()
	if spots.is_empty():
		push_warning("LaserManager: level has no LaserSpawns markers.")
		return
	var pickup = PICKUP_SCENE.instantiate()
	pickup.position = spots.pick_random()
	pickup.picked_up.connect(_on_picked_up)
	# Deferred: the last kill comes from a bullet collision, and adding an
	# Area2D inside a physics callback prints "flushing queries"
	_add_pickup.call_deferred(pickup)


func _add_pickup(pickup: Node2D) -> void:
	_level.get_entities().add_child(pickup)
	Events.laser_spawned.emit(pickup.global_position)


func _on_picked_up() -> void:
	# Deferred: changing pause state inside a physics callback is unsafe
	_start_aim.call_deferred()


func _start_aim() -> void:
	get_tree().paused = true
	Events.laser_picked_up.emit()
	var aim = Node2D.new()
	aim.set_script(AIM_SCRIPT)
	aim.from_position = _player.global_position
	aim.sweep_speed = sweep_speed_level_2 if GameState.current_level >= 2 else sweep_speed_level_1
	# Start pointing AWAY from the origin, so the player gets time to read the sweep
	var away := _player.global_position - _origin.global_position
	aim.start_angle = away.angle() if away != Vector2.ZERO else 0.0
	aim.fired.connect(_on_fired)
	_level.add_child(aim)


func _on_fired(direction: Vector2) -> void:
	var hit := _origin != null and _origin.is_hit_by_ray(_player.global_position, direction)
	get_tree().paused = false
	Events.laser_fired.emit(hit)
	if hit:
		_origin.take_laser_hit()
		if not _origin.destroyed:   # needs more hits
			_start_charging(retry_kills)
	else:
		_start_charging(retry_kills)
