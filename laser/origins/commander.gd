extends Origin
## Alien Commander, the level 2 moving origin. Ploy's.
##
## game.gd calls follow_path(level.get_origin_path()), and it walks the loop
## Mew drew in level 2's `OriginPath`.
##
## It KEEPS MOVING while the player aims the laser (process mode = Always), so
## the player has to time the sweeping beam against a moving target. That's the
## level 2 challenge from the design doc.
##
## To make the beam hard to time, every 1 to 2.5 seconds it picks a new speed
## and sometimes turns around. It never stops, so it is never a free hit.
##
## TODO Ploy:
##  - tune the numbers below with playtesting (all in the Inspector)

@export var move_speed := 90.0
## Speed is move_speed times a random number between these two
@export var speed_min_factor := 0.6
@export var speed_max_factor := 1.5
## Seconds between changes of speed / direction (random between these two)
@export var change_min := 1.0
@export var change_max := 2.5
## Chance (0 to 1) to turn around at each change
@export var turn_chance := 0.35

var _path: Path2D
var _offset := 0.0
var _velocity := 0.0   # px/s along the path, negative = walking backwards
var _change_in := 0.0


func _ready() -> void:
	super()
	process_mode = Node.PROCESS_MODE_ALWAYS
	breathe_speed = 6.0     # reads as a quick walk instead of slow breathing
	_velocity = move_speed
	_change_in = maxf(randf_range(change_min, change_max), 0.1)   # 0 would mean jitter


func follow_path(path: Path2D) -> void:
	_path = path


func _process(delta: float) -> void:
	_animate(delta)
	if _path == null or destroyed:
		return
	var length := _path.curve.get_baked_length()
	if length <= 0.0:
		return
	_change_in -= delta
	if _change_in <= 0.0:
		_change_in = maxf(randf_range(change_min, change_max), 0.1)   # 0 would mean jitter
		var direction := -signf(_velocity) if randf() < turn_chance else signf(_velocity)
		_velocity = direction * move_speed * randf_range(speed_min_factor, speed_max_factor)
	_offset = fposmod(_offset + _velocity * delta, length)
	global_position = _path.to_global(_path.curve.sample_baked(_offset))
