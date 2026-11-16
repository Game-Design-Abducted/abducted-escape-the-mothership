extends SceneTree
## Play-test bot for balance checks, not in CI. godot --path . -s tools/playtest_bot.gd -- --level=1 --runs=4 --speed=3 --out=FOLDER [--hardcore]

var out_dir := ""
var level_number := 1
var run_count := 4
var hardcore := false
var speed := 3.0   # physics tick rate is raised to match, so each tick moves things as far as in real play

var st: Node
var ev: Node
var results := []
var run := {}
var level: Node
var walls: TileMapLayer
var player: Node2D
var origin: Node2D
var active := false
var pickup_pos = null
const ITEM_GRAB_RANGE := 260.0
var ITEM_SCRIPT: Script
var aim_err := 0.0
var aim_seen: Node = null
var fire_release := false
var last_pos := Vector2.ZERO
var still := 0.0
var last_hp := 0
var next_cell_cache := Vector2i.ZERO
var repath_in := 0.0
var goal_cell_cache := Vector2i(-99, -99)


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var value := arg.get_slice("=", 1)
		if arg.begins_with("--level="):
			level_number = clampi(int(value), 1, 2)
		elif arg.begins_with("--runs="):
			run_count = maxi(int(value), 1)
		elif arg.begins_with("--speed="):
			speed = clampf(float(value), 1.0, 5.0)
		elif arg == "--hardcore":
			hardcore = true
		elif arg.begins_with("--out="):
			out_dir = value
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	Engine.physics_ticks_per_second = int(60 * speed)
	Engine.max_physics_steps_per_frame = 32
	_run()


func _now() -> float:
	return snappedf(st.LEVEL_TIME - st.time_left, 0.1)


func _run() -> void:
	st = root.get_node("GameState")
	st.hardcore = hardcore
	ev = root.get_node("Events")
	ITEM_SCRIPT = load("res://items/item_drop.gd")
	await process_frame
	ev.enemy_killed.connect(_on_kill)
	ev.player_hp_changed.connect(_on_hp)
	ev.laser_spawned.connect(_on_laser_spawned)
	ev.laser_picked_up.connect(_on_laser_picked)
	ev.laser_fired.connect(_on_laser_fired)
	ev.laser_mode_started.connect(func(mode_name, _how): if active and not run.laser.is_empty(): run.laser[-1]["mode"] = mode_name)
	ev.level_finished.connect(_on_finished)
	ev.item_used.connect(func(kind, _at): if active: run.items.append(kind))
	physics_frame.connect(_tick)
	for i in run_count:
		seed(level_number * 1000 + i * 37 + 5)
		st.current_level = level_number
		change_scene_to_file("res://game/game.tscn")
		await process_frame
		await process_frame
		await physics_frame
		level = current_scene.get_node("World").get_child(0)
		walls = level.get_node("Walls")
		player = get_first_node_in_group("player")
		origin = get_first_node_in_group("origin")
		last_hp = player.max_hp
		last_pos = player.global_position
		pickup_pos = null
		aim_seen = null
		run = {"level": level_number, "run": i, "kill_times": [], "damage": [], "laser": [], "stuck": [], "max_enemies": 0, "unreachable_spots": [], "items": []}
		for spot in level.get_laser_spawn_points():
			if _next_cell(walls.local_to_map(player.global_position), walls.local_to_map(spot)) == Vector2i(-1, -1):
				run.unreachable_spots.append([spot.x, spot.y])
		Engine.time_scale = speed
		active = true
		while active:
			await process_frame
		_move(Vector2.ZERO)
		Input.action_release("attack")
		Engine.time_scale = 1.0
		if out_dir != "" and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/L%d_run%d_end.png" % [out_dir, level_number, i])
		results.append(run)
		print("L%d run %d: %s at %.0fs, kills %d, damage %d, lasers %s, stuck %d, max enemies %d, items %s" % [level_number, i, run.result, run.t_end, run.kill_times.size(), run.damage.size(), JSON.stringify(run.laser), run.stuck.size(), run.max_enemies, JSON.stringify(run.items)])
		for k in 600:   # let GameState leave the game scene
			await process_frame
			if current_scene != null and current_scene.name != "Game":
				break
		for k in 5:      # never start a second scene change before the first one has finished
			await process_frame
	if out_dir != "":
		var f := FileAccess.open("%s/results_L%d.json" % [out_dir, level_number], FileAccess.WRITE)
		f.store_string(JSON.stringify(results, "  "))
		f.close()
	var wins := results.filter(func(r): return r.result == "WIN").size()
	print("")
	print("LEVEL %d: %d of %d runs won" % [level_number, wins, results.size()])
	quit(0)


func _on_kill(_enemy: Node) -> void:
	if active:
		run.kill_times.append(_now())


func _on_laser_spawned(p: Vector2) -> void:
	if active:
		pickup_pos = p
		run.laser.append({"spawned": _now(), "at": [p.x, p.y]})


func _on_laser_picked() -> void:
	if active:
		run.laser[-1]["picked"] = _now()
		run.laser[-1]["dist_to_origin"] = snappedf(player.global_position.distance_to(origin.global_position), 1)


func _on_laser_fired(hit: bool) -> void:
	if active:
		run.laser[-1]["hit"] = hit
		pickup_pos = null


func _on_hp(hp: int, _max_hp: int) -> void:
	if active and hp < last_hp:
		var near := ""
		var near_progress := 0.0
		var best := 1e9
		for e in get_nodes_in_group("enemies"):
			var d: float = e.global_position.distance_to(player.global_position)
			if d < best:
				best = d
				near = e.scene_file_path.get_file().get_basename()
				near_progress = e.progress
		run.damage.append({"t": _now(), "at": [roundi(player.global_position.x), roundi(player.global_position.y)], "by": near, "going_for_laser": pickup_pos != null,
				"walked": roundi(near_progress), "prank": current_scene.get_node("ShipPranks").active if current_scene.has_node("ShipPranks") else ""})
	last_hp = hp


func _on_finished(won: bool) -> void:
	if not active:
		return
	run["result"] = "WIN" if won else ("DIED" if player.hp <= 0 else "TIME UP")
	run["t_end"] = _now()
	run["hp_left"] = player.hp
	active = false


func _is_wall(cell: Vector2i) -> bool:
	if walls.get_cell_source_id(cell) == -1:
		return true
	return walls.get_cell_atlas_coords(cell).x <= 2


func _wall_at(p: Vector2) -> bool:
	return _is_wall(walls.local_to_map(p))


func _clear_line(a: Vector2, b: Vector2) -> bool:
	var n := int(a.distance_to(b) / 8.0) + 1
	var side := (b - a).normalized().orthogonal() * 5.0
	for k in n + 1:
		var p := a.lerp(b, float(k) / n)
		if _wall_at(p) or _wall_at(p + side) or _wall_at(p - side):
			return false
	return true


## first step of the shortest tile route, (-1,-1) = no route
func _next_cell(from: Vector2i, to: Vector2i) -> Vector2i:
	if from == to:
		return from
	var prev := {to: to}
	var queue: Array[Vector2i] = [to]
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var n: Vector2i = c + d
			if prev.has(n) or _is_wall(n):
				continue
			prev[n] = c
			if n == from:
				return c
			queue.append(n)
	return Vector2i(-1, -1)


func _move(dir: Vector2) -> void:
	for a in [["move_right", dir.x > 0.5], ["move_left", dir.x < -0.5], ["move_down", dir.y > 0.5], ["move_up", dir.y < -0.5]]:
		if a[1]:
			Input.action_press(a[0])
		else:
			Input.action_release(a[0])


func _go_to(goal: Vector2, dt: float) -> void:
	var pos := player.global_position
	var cur := walls.local_to_map(pos)
	var goal_cell := walls.local_to_map(goal)
	if _is_wall(goal_cell):   # a monster hugging a wall edge: aim for the nearest floor tile
		for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			if not _is_wall(goal_cell + d):
				goal_cell += d
				break
	if cur == goal_cell:
		var to := goal - pos
		_move(Vector2(signf(to.x) if absf(to.x) > 2.0 else 0.0, signf(to.y) if absf(to.y) > 2.0 else 0.0))
		return
	repath_in -= dt
	if repath_in <= 0.0 or goal_cell != goal_cell_cache or next_cell_cache == cur:
		next_cell_cache = _next_cell(cur, goal_cell)
		goal_cell_cache = goal_cell
		repath_in = 0.25
	if next_cell_cache == Vector2i(-1, -1):
		_move(Vector2.ZERO)
		return
	var centre := walls.map_to_local(cur)
	var step := next_cell_cache - cur
	if step.x != 0:
		_move(Vector2(0, signf(centre.y - pos.y)) if absf(pos.y - centre.y) > 1.5 else Vector2(step.x, 0))
	else:
		_move(Vector2(signf(centre.x - pos.x), 0) if absf(pos.x - centre.x) > 1.5 else Vector2(0, step.y))


func _aim_tick() -> void:
	if fire_release:
		fire_release = false
		var up := InputEventAction.new()
		up.action = "fire_laser"
		up.pressed = false
		Input.parse_input_event(up)
	var aim: Node = null
	for c in level.get_children():
		if c.has_signal("fired") and not c._fired:
			aim = c
	if aim == null:
		return
	if aim != aim_seen:
		aim_seen = aim
		aim_err = randfn(0.0, 0.07)   # human timing error in seconds
	if aim._armed_in > 0.0:
		return
	var mode: String = aim.mode_name()
	if mode == "POWER SHOT":
		if not aim._charging:
			_laser_key(true)
		elif aim.bot_should_release(aim_err):
			_laser_key(false)
		return
	if mode == "BEAT DROP":
		if absf(aim.to_next_beat() - aim_err) < 0.012:
			_laser_key(true)
			fire_release = true
		return
	# SWEEP and TRICK SHOT
	var lead := deg_to_rad(aim.current_speed()) * aim_err
	for want: float in aim.bot_want_angles():
		var remaining := wrapf(want - aim._angle, -PI, PI)   # the sweep adds to the angle
		if remaining <= lead and remaining > lead - 0.25:
			_laser_key(true)
			fire_release = true
			return


func _laser_key(pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = "fire_laser"
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _tick() -> void:
	if not active or not is_instance_valid(player) or not is_instance_valid(level):
		return
	if paused:
		Engine.time_scale = 1.0   # aim in real time, so the sweep is as fine-grained as in normal play
		_aim_tick()
		return
	Engine.time_scale = speed
	var dt := 1.0 / 60.0   # game seconds per physics tick (180 ticks per real second at 3x)
	if player.hp <= 0:
		return
	var pos := player.global_position
	Input.action_press("attack")
	var nearest: Node2D = null
	var best := 1e9
	var alive := 0
	for e in get_nodes_in_group("enemies"):
		if e._dead:
			continue
		alive += 1
		var d: float = e.global_position.distance_to(pos)
		if d < best:
			best = d
			nearest = e
	run.max_enemies = maxi(run.max_enemies, alive)

	var item: Node2D = null
	var item_dist := ITEM_GRAB_RANGE
	for c in level.get_entities().get_children():
		# (by script path: naming the ItemDrop class here would compile it before the autoloads exist)
		if c.get_script() == ITEM_SCRIPT and c.global_position.distance_to(pos) < item_dist:
			item_dist = c.global_position.distance_to(pos)
			item = c

	var moving := true
	if pickup_pos != null:
		_go_to(pickup_pos, dt)
	elif item != null:
		_go_to(item.global_position, dt)
	elif nearest != null:
		var to := nearest.global_position - pos
		var axis := Vector2.ZERO
		if absf(to.y) < 14.0 and absf(to.x) > 1.0:
			axis = Vector2(signf(to.x), 0)
		elif absf(to.x) < 14.0 and absf(to.y) > 1.0:
			axis = Vector2(0, signf(to.y))
		if axis != Vector2.ZERO and _clear_line(pos, nearest.global_position):
			if player.facing.dot(axis) < 0.9 or best > 160.0:
				_move(axis)
			else:
				_move(Vector2.ZERO)
				moving = false
		elif best < 56.0:
			var away := -to.normalized()
			var cands := [Vector2(signf(away.x), 0), Vector2(0, signf(away.y))]
			if absf(away.y) > absf(away.x):
				cands.reverse()
			var picked := Vector2.ZERO
			for c: Vector2 in cands:
				if c != Vector2.ZERO and not _wall_at(pos + c * 24.0):
					picked = c
					break
			_move(picked)
		else:
			_go_to(nearest.global_position, dt)
	else:
		_move(Vector2.ZERO)
		moving = false

	if moving and pos.distance_to(last_pos) < 0.05:
		still += dt
		if still > 2.0 and run.stuck.size() < 12:
			run.stuck.append({"t": _now(), "at": [roundi(pos.x), roundi(pos.y)], "going_for_laser": pickup_pos != null})
			still = 0.0
	else:
		still = 0.0
	last_pos = pos
