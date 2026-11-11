extends Origin
## =====================================================================
## ALIEN COMMANDER: Level 2 moving origin. OWNER: Kong
## =====================================================================
## game.gd calls follow_path(level.get_origin_path()).
## It walks the loop that Mew drew in Level 2's `OriginPath`.
##
## TODO (Kong, Nov 14):
##   [ ] Make it harder to hit: random speed changes, pauses, reversing direction
##   [ ] Decide: does it keep moving while the player aims? Right now it FREEZES
##       with everything else. To keep it moving, set this node's
##       process_mode = PROCESS_MODE_ALWAYS in _ready().

@export var move_speed := 90.0

var _path: Path2D
var _offset := 0.0


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
