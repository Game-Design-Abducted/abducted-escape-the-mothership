extends Node
## Laser manager, the special mechanic. Yang's.
##
## How it loops:
##   1. the laser CHARGES from kills: the player has to kill a quota of each
##      monster type (FIRST_QUOTAS, Events.enemy_killed) -> Events.laser_charge_changed
##      (so hiding in a corner never gets you a laser). Kills over a type's
##      quota don't count. Per-type progress goes out as Events.laser_quota_changed
##   2. spawn laser_pickup at a random LaserSpawns marker -> Events.laser_spawned
##   3. player touches it -> PAUSE the game, start aim mode -> Events.laser_picked_up
##   4. the aim line sweeps, player presses fire -> UNPAUSE -> Events.laser_fired(hit)
##        hit  -> origin.take_laser_hit(); after HITS_NEEDED hits -> Events.origin_destroyed
##                -> GameState: win. Before that, charge again (RETRY_QUOTA) -> back to step 2
##        miss -> charge again (RETRY_QUOTA) -> back to step 2
##
## game.gd calls setup(level, player, origin).
##
## TODO Yang:
##  - charge + spawn + pickup (done, works)
##  - freeze, sweep-aim, shoot, hit/miss, retry (basic version works)
##  - sound when the charge completes / on fire
##  - should walls block the laser? Right now it goes through them
##  - tune the kill quotas, hits needed and sweep speed per level with playtesting

@export var sweep_speed_level_1 := 100.0   ## aim line speed, degrees per second
@export var sweep_speed_level_2 := 130.0

## Kills of each monster type needed before the first laser appears, per level
const FIRST_QUOTAS := {
	1: {"basic": 10, "fast": 6, "tank": 3},
	2: {"basic": 12, "fast": 8, "tank": 4},
}
## Kills needed after a hit that didn't finish the origin, or after a miss
const RETRY_QUOTA := {"basic": 4, "fast": 3, "tank": 1}
## Laser hits the origin takes before it is destroyed, per level (overrides
## laser_hits_needed in Ploy's origin.gd)
const HITS_NEEDED := {1: 2, 2: 3}

const PICKUP_SCENE := preload("res://laser/laser_pickup.tscn")
const AIM_SCRIPT := preload("res://laser/aim_mode.gd")

var _level: Level
var _player: Node2D
var _origin: Origin
var _kills := 0          ## counted kills over all types (what the HUD total shows)
var _needed := 0
var _quota := {}         ## monster type -> kills needed for the current charge
var _counts := {}        ## monster type -> kills counted so far
var _charging := false   ## true while counting kills toward the next pickup


func setup(level: Level, player: Node2D, origin: Origin) -> void:
	_level = level
	_player = player
	_origin = origin
	if _origin != null:
		_origin.laser_hits_needed = HITS_NEEDED.get(GameState.current_level, 1)
	Events.enemy_killed.connect(_on_enemy_killed)
	_start_charging(FIRST_QUOTAS.get(GameState.current_level, FIRST_QUOTAS[1]))


func _start_charging(quota: Dictionary) -> void:
	_quota = quota
	_counts = {}
	for type in _quota:
		_counts[type] = 0
	_charging = true
	_emit_charge()


func _on_enemy_killed(enemy: Node) -> void:
	if not _charging:
		return
	var type := _enemy_type(enemy)
	if not _quota.has(type) or _counts[type] >= _quota[type]:
		return   # this type's quota is already full, the kill doesn't count
	_counts[type] += 1
	_emit_charge()
	for t in _quota:
		if _counts[t] < _quota[t]:
			return
	_charging = false
	_spawn_pickup()


## Enemies have no type field, so it comes from which scene they were made from
func _enemy_type(enemy: Node) -> String:
	var path := enemy.scene_file_path
	if "fast" in path:
		return "fast"
	if "tank" in path:
		return "tank"
	return "basic"


func _emit_charge() -> void:
	var kills := 0
	var needed := 0
	var progress := {}
	for type in _quota:
		kills += _counts[type]
		needed += _quota[type]
		progress[type] = [_counts[type], _quota[type]]
	_kills = kills
	_needed = needed
	Events.laser_charge_changed.emit(kills, needed)
	# Deferred so the HUD exists when the first one goes out
	Events.laser_quota_changed.emit.call_deferred(progress)


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
			_start_charging(RETRY_QUOTA)
	else:
		_start_charging(RETRY_QUOTA)
