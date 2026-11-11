extends Node
## =====================================================================
## LASER MANAGER: the special mechanic. OWNER: Kong
## =====================================================================
## Loop:
##   1. Countdown (first_delay s) while the player survives
##   2. Spawn laser_pickup at a random LaserSpawns marker  -> Events.laser_spawned
##   3. Player touches it -> PAUSE the game, start aim mode -> Events.laser_picked_up
##   4. Player clicks -> check hit -> UNPAUSE              -> Events.laser_fired(hit)
##        hit  -> origin.take_laser_hit() -> Events.origin_destroyed -> GameState: win
##        miss -> countdown again (retry_delay s) -> back to step 2
##
## game.gd calls setup(level, player, origin).
##
## TODO (Kong):
##   Nov 12  [x] Spawn + pickup (works)
##   Nov 13  [x] Freeze, aim, shoot, hit/miss, retry (basic version works)
##           [ ] Laser beam visual + sound on fire (Fah's Laser.png)
##           [ ] Should walls block the laser? (now: it goes through walls)
##   Nov 14  [ ] Tune delays per level (Level 2 harder?)
##           [ ] Count kills instead of / as well as time? (listen to Events.enemy_killed)

@export var first_delay := 30.0   ## seconds before the first laser appears
@export var retry_delay := 20.0   ## seconds after a miss before the next one

const PICKUP_SCENE := preload("res://laser/laser_pickup.tscn")
const AIM_SCRIPT := preload("res://laser/aim_mode.gd")

var _level: Level
var _player: Node2D
var _origin: Origin
var _countdown := 0.0
var _waiting := false   ## true while counting down to the next pickup


func setup(level: Level, player: Node2D, origin: Origin) -> void:
	_level = level
	_player = player
	_origin = origin
	_start_countdown(first_delay)


func _process(delta: float) -> void:
	if not _waiting:
		return
	_countdown -= delta
	Events.laser_countdown_changed.emit(maxf(_countdown, 0.0))
	if _countdown <= 0.0:
		_waiting = false
		_spawn_pickup()


func _start_countdown(seconds: float) -> void:
	_countdown = seconds
	_waiting = true


func _spawn_pickup() -> void:
	var spots := _level.get_laser_spawn_points()
	if spots.is_empty():
		push_warning("LaserManager: level has no LaserSpawns markers.")
		return
	var pickup = PICKUP_SCENE.instantiate()
	pickup.global_position = spots.pick_random()
	pickup.picked_up.connect(_on_picked_up)
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
	aim.fired.connect(_on_fired)
	_level.add_child(aim)


func _on_fired(direction: Vector2) -> void:
	var hit := _origin != null and _origin.is_hit_by_ray(_player.global_position, direction)
	get_tree().paused = false
	Events.laser_fired.emit(hit)
	if hit:
		_origin.take_laser_hit()
		if not _origin.destroyed:   # needs more hits
			_start_countdown(retry_delay)
	else:
		_start_countdown(retry_delay)
