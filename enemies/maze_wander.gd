extends RefCounted
## Random monster routes through the maze. Ploy's.
## walks a grid of tile corners that have floor on all 4 sides, so routes run down
## the middle of 2-wide corridors and never clip a wall.

const TILE := 32
## chance the next stop is where the player is right now, per monster type (0 = fully random)
const CHASE_CHANCE := {"basic": 0.08, "fast": 0.15, "tank": 0.05}
const MIN_TRIP := 6   ## a random stop is at least this many tiles away
const AVOID_RADIUS := 3   ## wandering monsters route around this many tiles around the player...
const AVOID_COST := 8.0   ## ...if the detour costs less than this many times the straight way

## multiplies CHASE_CHANCE (hardcore sets it)
var chase_scale := 1.0
var _walls: TileMapLayer
var _grid := AStarGrid2D.new()
var _points: Array[Vector2i] = []


func _init(walls: TileMapLayer) -> void:
	_walls = walls
	var used := walls.get_used_rect()
	_grid.region = Rect2i(used.position, used.size + Vector2i.ONE)
	_grid.cell_size = Vector2.ONE * TILE
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_grid.update()
	for x in range(_grid.region.position.x, _grid.region.end.x):
		for y in range(_grid.region.position.y, _grid.region.end.y):
			var p := Vector2i(x, y)
			var open := _floor(p) and _floor(p + Vector2i.LEFT) and _floor(p + Vector2i.UP) and _floor(p + Vector2i(-1, -1))
			_grid.set_point_solid(p, not open)
			if open:
				_points.append(p)


func is_ready() -> bool:
	return _points.size() > 1


## Route (world points) from `from` to a new stop: random, or the player's spot.
## first = fresh out of the egg: leave on the side away from the player, so camping the egg isn't a death trap
func next_route(from: Vector2, monster_type: String, player: Node2D, first := false) -> PackedVector2Array:
	var start := _nearest(from)
	var goal := start
	var has_player := is_instance_valid(player)
	var chasing: bool = has_player and not first and randf() < CHASE_CHANCE.get(monster_type, 0.25) * chase_scale
	if chasing:
		goal = _nearest(player.global_position)
	for i in 20:   # a few tries to find a far enough random stop
		if goal != start:
			break
		var p: Vector2i = _points.pick_random()
		if (p - start).length() < MIN_TRIP:
			continue
		if first and has_player:
			var away := from - player.global_position
			if (_world(p) - from).dot(away) <= 0.0 or _world(p).distance_to(player.global_position) < away.length() + 64.0:
				continue   # out the far side of the egg, not past you
		goal = p
	# wanderers go around you when they can, otherwise two-way traffic keeps bumping into you from behind
	var avoid: Array[Vector2i] = []
	if has_player and not chasing:
		var me := _nearest(player.global_position)
		for x in range(-AVOID_RADIUS, AVOID_RADIUS + 1):
			for y in range(-AVOID_RADIUS, AVOID_RADIUS + 1):
				var c := me + Vector2i(x, y)
				if _grid.is_in_boundsv(c) and not _grid.is_point_solid(c) and c != start and c != goal:
					_grid.set_point_weight_scale(c, AVOID_COST)
					avoid.append(c)
	var cells := _grid.get_id_path(start, goal)
	for c in avoid:
		_grid.set_point_weight_scale(c, 1.0)
	var route := PackedVector2Array()
	for c in _straighten(cells):
		route.append(_world(c))
	return route


## A* zig-zags through open rooms (1 right, 1 down, ...). Replace runs of it with
## the longest L-shaped legs the floor allows, so monsters walk straight and turn rarely.
func _straighten(cells: Array[Vector2i]) -> Array[Vector2i]:
	if cells.size() < 3:
		return cells
	var out: Array[Vector2i] = [cells[0]]
	var i := 0
	while i < cells.size() - 1:
		var a := cells[i]
		var best := i + 1
		var corner := a
		for j in range(cells.size() - 1, i, -1):
			var b := cells[j]
			for c: Vector2i in [Vector2i(b.x, a.y), Vector2i(a.x, b.y)]:
				if _clear(a, c) and _clear(c, b):
					best = j
					corner = c
					break
			if best == j:
				break
		if corner != a and corner != cells[best]:
			out.append(corner)
		out.append(cells[best])
		i = best
	# drop points in the middle of a straight line, so tanks only stop at real corners
	var lean: Array[Vector2i] = [out[0]]
	for k in range(1, out.size() - 1):
		if (out[k] - lean[-1]).sign() != (out[k + 1] - out[k]).sign():
			lean.append(out[k])
	lean.append(out[-1])
	return lean


## Straight horizontal or vertical run with no solid point on it
func _clear(a: Vector2i, b: Vector2i) -> bool:
	var step := (b - a).sign()
	var p := a
	while p != b:
		p += step
		if _grid.is_point_solid(p):
			return false
	return true


func _floor(cell: Vector2i) -> bool:
	if _walls.get_cell_source_id(cell) == -1:
		return false   # nothing painted, outside the map
	var data := _walls.get_cell_tile_data(cell)
	return data == null or data.get_collision_polygons_count(0) == 0


func _world(p: Vector2i) -> Vector2:
	return _walls.to_global(_walls.map_to_local(p) - Vector2.ONE * TILE * 0.5)


func _nearest(world: Vector2) -> Vector2i:
	var local := _walls.to_local(world) / TILE
	var guess := Vector2i(roundi(local.x), roundi(local.y))
	if _grid.is_in_boundsv(guess) and not _grid.is_point_solid(guess):
		return guess
	var best := _points[0]
	var best_d := INF
	for p in _points:
		var d := (Vector2(p) - local).length_squared()
		if d < best_d:
			best_d = d
			best = p
	return best
