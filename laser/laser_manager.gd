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
##                -> GameState: win. Before that, charge again (RETRY_QUOTAS) -> back to step 2
##        miss -> charge again (RETRY_QUOTAS) -> back to step 2
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
## Keep each number below what the level's early waves actually spawn: kills
## over a type's quota don't count, so a type that rarely shows up stalls the
## whole charge. Level 2 only sends basics inside "mixed" waves (a random
## pick of the 3 types), about 1 in 6 of its monsters.
const FIRST_QUOTAS := {
	1: {"basic": 10, "fast": 7, "tank": 3},
	2: {"basic": 2, "fast": 6, "tank": 2},
}
## Kills needed after a hit that didn't finish the origin, or after a miss, per level
const RETRY_QUOTAS := {
	1: {"basic": 3, "fast": 2, "tank": 1},
	2: {"basic": 1, "fast": 3, "tank": 1},
}
## Laser hits the origin takes before it is destroyed, per level (overrides
## laser_hits_needed in Ploy's origin.gd)
const HITS_NEEDED := {1: 2, 2: 3}

## PITY LASER: every miss in a row makes the next shot easier (bigger hit zone,
## slower sweep) until you hit. Resets on a hit. Keeps the multi-hit fights
## winnable for real players without making a first-try hit free.
const PITY_RADIUS_PER_MISS := 0.3    # +30 % hit radius per miss
const PITY_RADIUS_MAX := 2.0         # never more than double
const PITY_SPEED_PER_MISS := 0.85    # sweep x0.85 per miss
const PITY_SPEED_MIN := 0.5
## Long shots: the hit zone grows this many px per px of distance, so a target
## 900 px away is as hard to hit as one 300 px away would be without it
const HIT_RADIUS_PER_DISTANCE := 0.06

## LASER MODES: every shot is a different little game, so the third laser of a
## level doesn't feel like the first. The first shot of level 1 is always SWEEP
## (it teaches the idea), level 2 opens with TRICK SHOT, then each shot picks a
## random mode from the level's pool, never the same one twice in a row.
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
## Trick shot bounces, so the far end of the line moves faster: sweep a bit slower
const TRICK_SPEED_FACTOR := 0.75

const PICKUP_SCENE := preload("res://laser/laser_pickup.tscn")

var _level: Level
var _player: Node2D
var _origin: Origin
var _base_hit_radius := 48.0
var _misses := 0          ## misses since the last hit (pity laser)
var _kills := 0          ## counted kills over all types (what the HUD total shows)
var _needed := 0
var _quota := {}         ## monster type -> kills needed for the current charge
var _counts := {}        ## monster type -> kills counted so far
var _charging := false   ## true while counting kills toward the next pickup
var _last_mode := ""
## For tests: force the next shot's mode ("" = pick normally)
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
	# Start pointing AWAY from the origin, so the player gets time to read the sweep
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
		hit = aim.result == 1   # the mode decided (timing modes, trick shot)
	elif _origin != null:
		# Same zone the aim ring shows: pity radius + a bonus for distance
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
		if not _origin.destroyed:   # needs more hits
			_start_charging(_retry_quota())
	else:
		_start_charging(_retry_quota())
