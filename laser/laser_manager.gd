extends Node
## Laser manager: kill quotas charge it, grab the pickup, aim, shoot the origin. Yang's.
# TODO: should walls block the laser? right now it goes through them

@export var sweep_speed_level_1 := 100.0   ## aim line speed, degrees per second
@export var sweep_speed_level_2 := 130.0

## kills per type for the first laser. keep below what early waves spawn or the charge stalls
const FIRST_QUOTAS := {
	1: {"basic": 10, "fast": 7, "tank": 3},
	2: {"basic": 2, "fast": 6, "tank": 2},
}
## kills needed to recharge after a miss or a non-final hit
const RETRY_QUOTAS := {
	1: {"basic": 3, "fast": 2, "tank": 1},
	2: {"basic": 1, "fast": 3, "tank": 1},
}
## overrides laser_hits_needed in origin.gd
const HITS_NEEDED := {1: 2, 2: 3}

## pity laser: each miss in a row makes the next shot easier, resets on hit
const PITY_RADIUS_PER_MISS := 0.3
const PITY_RADIUS_MAX := 2.0
const PITY_SPEED_PER_MISS := 0.85
const PITY_SPEED_MIN := 0.5
## px of extra hit radius per px of distance, so long shots aren't way harder
const HIT_RADIUS_PER_DISTANCE := 0.06

## first shot of level 1 is sweep since it teaches the idea
const MODES := {
	"sweep": preload("res://laser/aim_mode.gd"),
	"power": preload("res://laser/aim_modes/power_shot.gd"),
	"beat": preload("res://laser/aim_modes/beat_drop.gd"),
	"trick": preload("res://laser/aim_modes/trick_shot.gd"),
}
const FIRST_MODE := {1: "sweep", 2: "trick"}
const MODE_POOL := {
	1: ["sweep", "power", "beat"],
	2: ["sweep", "power", "beat", "trick"],
}
## trick shot bounces so the far end moves faster
const TRICK_SPEED_FACTOR := 0.75

const PICKUP_SCENE := preload("res://laser/laser_pickup.tscn")

var _level: Level
var _player: Node2D
var _origin: Origin
var _base_hit_radius := 48.0
var _misses := 0
var _kills := 0
var _needed := 0
var _quota := {}         ## type -> kills needed
var _counts := {}        ## type -> kills so far
var _charging := false
var _last_mode := ""
## for tests: force the next shot's mode ("" = pick normally)
var next_mode := ""


func setup(level: Level, player: Node2D, origin: Origin) -> void:
	_level = level
	_player = player
	_origin = origin
	if _origin != null:
		_base_hit_radius = _origin.hit_radius
		_origin.laser_hits_needed = HITS_NEEDED.get(GameState.current_level, 1)
	Events.enemy_killed.connect(_on_enemy_killed)
	_start_charging(FIRST_QUOTAS.get(GameState.current_level, FIRST_QUOTAS[1]))


func _retry_quota() -> Dictionary:
	return RETRY_QUOTAS.get(GameState.current_level, RETRY_QUOTAS[1])


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
		return
	_counts[type] += 1
	_emit_charge()
	for t in _quota:
		if _counts[t] < _quota[t]:
			return
	_charging = false
	_spawn_pickup()


## enemies have no type field, so go by the scene path
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
	# deferred so the HUD exists for the first one
	Events.laser_quota_changed.emit.call_deferred(progress)


func _spawn_pickup() -> void:
	var spots := _level.get_laser_spawn_points()
	if spots.is_empty():
		push_warning("LaserManager: level has no LaserSpawns markers.")
		return
	var pickup = PICKUP_SCENE.instantiate()
	pickup.position = spots.pick_random()
	pickup.picked_up.connect(_on_picked_up)
	# deferred: adding an Area2D in a physics callback errors with "flushing queries"
	_add_pickup.call_deferred(pickup)


func _add_pickup(pickup: Node2D) -> void:
	_level.get_entities().add_child(pickup)
	Events.laser_spawned.emit(pickup.global_position)


func _on_picked_up() -> void:
	# deferred: don't change pause state inside a physics callback
	_start_aim.call_deferred()


func _start_aim() -> void:
	get_tree().paused = true
	Events.laser_picked_up.emit()
	var mode := _pick_mode()
	var aim = Node2D.new()
	aim.set_script(MODES[mode])
	aim.from_position = _player.global_position
	aim.level_number = GameState.current_level
	aim.assist = minf(1.0 + PITY_RADIUS_PER_MISS * _misses, PITY_RADIUS_MAX)
	var speed := sweep_speed_level_2 if GameState.current_level >= 2 else sweep_speed_level_1
	if mode == "trick":
		speed *= TRICK_SPEED_FACTOR
	aim.sweep_speed = speed * maxf(pow(PITY_SPEED_PER_MISS, _misses), PITY_SPEED_MIN)
	aim.target = _origin
	aim.hit_radius = _origin.hit_radius
	aim.radius_per_distance = HIT_RADIUS_PER_DISTANCE
	# start pointing away from the origin so the player has time to read the sweep
	var away := _player.global_position - _origin.global_position
	aim.start_angle = away.angle() if away != Vector2.ZERO else 0.0
	aim.fired.connect(_on_fired.bind(aim))
	_level.add_child(aim)
	Events.laser_mode_started.emit(aim.mode_name(), aim.how_to())


func _pick_mode() -> String:
	var mode := next_mode
	next_mode = ""
	if mode == "":
		if _last_mode == "":
			mode = FIRST_MODE.get(GameState.current_level, "sweep")
		else:
			var pool: Array = MODE_POOL.get(GameState.current_level, MODE_POOL[1]).duplicate()
			pool.erase(_last_mode)
			mode = pool.pick_random()
	_last_mode = mode
	return mode


func _on_fired(direction: Vector2, aim: Node) -> void:
	var hit := false
	if aim.result >= 0:
		hit = aim.result == 1   # the mode decided
	elif _origin != null:
		# same zone the aim ring shows
		var pity_radius := _origin.hit_radius
		_origin.hit_radius = pity_radius + HIT_RADIUS_PER_DISTANCE * _player.global_position.distance_to(_origin.global_position)
		hit = _origin.is_hit_by_ray(_player.global_position, direction)
		_origin.hit_radius = pity_radius
	get_tree().paused = false
	_misses = 0 if hit else _misses + 1
	if _origin != null:
		_origin.hit_radius = _base_hit_radius * minf(1.0 + PITY_RADIUS_PER_MISS * _misses, PITY_RADIUS_MAX)
	Events.laser_fired.emit(hit)
	if hit:
		_origin.take_laser_hit()
		if not _origin.destroyed:
			_start_charging(_retry_quota())
	else:
		_start_charging(_retry_quota())
