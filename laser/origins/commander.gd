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
## TODO Ploy:
##  - make it harder to hit: random speed changes, pauses, turning around
##  - tune move_speed with playtesting

@export var move_speed := 90.0

var _path: Path2D
var _offset := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func follow_path(path: Path2D) -> void:
	_path = path


func _process(delta: float) -> void:
	if _path == null or destroyed:
		return
	var length := _path.curve.get_baked_length()
	if length <= 0.0:
		return
	_offset = fmod(_offset + move_speed * delta, length)
	global_position = _path.to_global(_path.curve.sample_baked(_offset))
