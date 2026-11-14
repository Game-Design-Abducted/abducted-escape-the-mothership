extends Origin
## Alien Commander, level 2 origin that walks OriginPath. Ploy's.
# keeps moving while the player aims (process mode Always), that's the level 2 challenge

@export var move_speed := 90.0
## speed multiplier while the player aims
@export var aiming_speed_factor := 0.5
## random move_speed multiplier range
@export var speed_min_factor := 0.6
@export var speed_max_factor := 1.5
## seconds between speed/direction changes
@export var change_min := 1.0
@export var change_max := 2.5
## chance (0 to 1) to turn around at each change
@export var turn_chance := 0.35

var _path: Path2D
var _offset := 0.0
var _velocity := 0.0   # px/s, negative = backwards
var _change_in := 0.0


func _ready() -> void:
	super()
	process_mode = Node.PROCESS_MODE_ALWAYS
	breathe_speed = 6.0     # reads as walking
	_velocity = move_speed
	_change_in = maxf(randf_range(change_min, change_max), 0.1)   # 0 would mean jitter


func follow_path(path: Path2D) -> void:
	_path = path


func _process(delta: float) -> void:
	if PauseMenu.open:
		return   # runs while paused for aiming, but not under the pause menu
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
	var step := _velocity * delta
	if get_tree().paused:
		step *= aiming_speed_factor
	_offset = fposmod(_offset + step, length)
	global_position = _path.to_global(_path.curve.sample_baked(_offset))
