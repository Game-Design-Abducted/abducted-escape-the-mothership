extends SceneTree
## =====================================================================
## SMOKE TEST: plays the whole game loop automatically (about 25 seconds).
## For Ploy (integrator): run this before merging a PR.
## =====================================================================
##   godot --headless --path . -s tools/smoke_test.gd
##
## (Replace `godot` with the path to your Godot .exe if it's not on PATH.)
## Prints PASS/FAIL for each step. Exit code 0 = everything passed.
##
## It checks: level loads, monsters spawn, contact damage, bullets kill,
## laser charges from kills, pickup pauses the game, miss -> retry,
## hit -> win -> Level 2, Commander moves (also while aiming), timeout -> lose.
##
## If you change a rule on purpose (e.g. laser charge), update the check here too.

var _failures := 0
var _events: Node
var _state: Node


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok:
		_failures += 1
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", label, str(detail)])


func _load_game(level_number: int) -> Node:
	_state.current_level = level_number
	change_scene_to_file("res://game/game.tscn")
	await process_frame
	await process_frame
	await physics_frame
	return current_scene


func _level_of(game: Node) -> Node:
	return game.get_node("World").get_child(0)


func _find_child_named(parent: Node, prefix: String) -> Node:
	for c in parent.get_children():
		if c.name.begins_with(prefix):
			return c
	return null


func _find_aim(game: Node) -> Node:
	for c in _level_of(game).get_children():
		if c.has_signal("fired") and not c._fired:   # skip an old beam that is still fading out
			return c
	return null


## Kill-charges the laser, walks the player onto the pickup, returns the aim node
func _get_to_aim_mode(game: Node, player: Node2D) -> Node:
	var lm := game.get_node("LaserManager")
	while lm._charging:
		_events.enemy_killed.emit(null)
	await process_frame
	var pickup := _find_child_named(_level_of(game).get_node("Entities"), "LaserPickup")
	if pickup == null:
		return null
	player.global_position = pickup.global_position
	for i in 8:
		await physics_frame
	return _find_aim(game)


func _fire(aim: Node, direction: Vector2) -> void:
	aim.sweep_speed = 0.0            # hold the beam still so the test is deterministic
	aim._angle = direction.angle()
	await create_timer(0.5).timeout  # wait out the arm delay
	var ev := InputEventAction.new()
	ev.action = "fire_laser"
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	await process_frame


## Which way to shoot at `target` from `distance` px away without a maze wall in
## between. Where the monster is by now depends on timing, so a fixed side can put
## the shooter behind a wall. Falls back to RIGHT if all four sides are blocked.
func _clear_shot_direction(target: Node2D, distance: float) -> Vector2:
	var space := target.get_world_2d().direct_space_state
	for dir: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		var side := Vector2(-dir.y, dir.x) * 8.0   # a bullet is 10 px wide
		var blocked := false
		for offset: Vector2 in [Vector2.ZERO, side, -side]:
			var from := target.global_position - dir * (distance + 16.0) + offset
			var query := PhysicsRayQueryParameters2D.create(from, target.global_position + offset, 1)   # layer 1 = walls
			query.hit_from_inside = true
			if not space.intersect_ray(query).is_empty():
				blocked = true
		if not blocked:
			return dir
	return Vector2.RIGHT


## Runs an enemy's movement by hand, frame by frame, so the checks don't depend on real time
func _step(enemy: Node, seconds: float) -> void:
	for i in int(round(seconds * 60.0)):
		enemy._process(1.0 / 60.0)


## How far the enemy is from the path line (0 = exactly on it)
func _off_path(enemy: Node2D, path: Path2D) -> float:
	return enemy.position.distance_to(path.curve.get_closest_point(enemy.position))


func _spawn_on_test_path(scene: String, path: Path2D) -> Node:
	var enemy: Node = load(scene).instantiate()
	path.add_child(enemy)
	enemy.set_process(false)   # only _step() moves it
	return enemy


## The 3 monster types must move differently (no level, no player needed).
## Test path is an L: 400 px right, then 400 px down. Corner at progress 400.
func _enemy_type_checks() -> void:
	var path := Path2D.new()
	path.curve = Curve2D.new()
	for p in [Vector2(0, 0), Vector2(400, 0), Vector2(400, 400)]:
		path.curve.add_point(p)
	root.add_child(path)

	# Basic: walks the line at its speed, no wobble, no stops
	var basic: Node2D = _spawn_on_test_path("res://enemies/enemy_basic.tscn", path)
	var max_off := 0.0
	for i in 60:
		_step(basic, 1.0 / 6.0)   # 10 s total, passes the corner
		max_off = maxf(max_off, _off_path(basic, path))
	var lap_err := fposmod(basic.progress - basic.speed * 10.0, 800.0)   # loop wraps at 800
	_check("basic monster walks at its speed", minf(lap_err, 800.0 - lap_err) < 2.0,
			"progress %.0f, expected %.0f" % [basic.progress, basic.speed * 10.0])
	_check("basic monster stays on the path", max_off < 1.0, "max %.1f px off" % max_off)

	# Fast: zig-zags sideways on BOTH legs (a plain v_offset would only wobble on the flat leg)
	var fast: Node2D = _spawn_on_test_path("res://enemies/enemy_fast.tscn", path)
	var amp = fast.get("zigzag_amplitude")
	if amp == null:
		_check("fast monster has a zigzag_amplitude setting", false)
	else:
		var off_flat := 0.0
		var off_down := 0.0
		var off_max := 0.0
		for i in 240:   # 4 s at 140 px/s = 560 px, so both legs
			_step(fast, 1.0 / 60.0)
			var off := _off_path(fast, path)
			off_max = maxf(off_max, off)
			if fast.progress < 380.0:
				off_flat = maxf(off_flat, off)
			elif fast.progress > 420.0:
				off_down = maxf(off_down, off)
		_check("fast monster zig-zags on the horizontal leg", off_flat > 5.0, "max %.1f px" % off_flat)
		_check("fast monster zig-zags on the vertical leg", off_down > 5.0, "max %.1f px" % off_down)
		_check("fast monster zig-zag stays inside its amplitude", off_max <= amp + 1.0,
				"max %.1f px, amplitude %.1f" % [off_max, amp])
		_check("fast monster still moves forward at its speed", absf(fast.progress - fast.speed * 4.0) < 2.0,
				"progress %.0f" % fast.progress)

	# Tank: stops at the corner for corner_pause seconds, then carries on
	var tank: Node2D = _spawn_on_test_path("res://enemies/enemy_tank.tscn", path)
	var pause_s = tank.get("corner_pause")
	if pause_s == null:
		_check("tank monster has a corner_pause setting", false)
	else:
		tank.progress = 380.0
		_step(tank, 0.5)   # reaches the corner at 0.4 s; would be at 405 without a stop
		var at_corner: float = tank.progress
		_check("tank stops at the corner", absf(at_corner - 400.0) < 2.0, "progress %.1f" % at_corner)
		_step(tank, pause_s * 0.5)
		_check("tank waits at the corner", absf(tank.progress - at_corner) < 0.5, "progress %.1f" % tank.progress)
		_step(tank, pause_s * 0.5 + 1.0)
		_check("tank moves on after corner_pause", tank.progress > at_corner + 20.0, "progress %.1f" % tank.progress)
		# Next lap: wrap past the end, then the same corner must stop it again
		tank.progress = 795.0
		_step(tank, 0.2)
		tank.progress = 380.0
		_step(tank, 0.5)
		_check("tank stops at the corner again on the next lap", absf(tank.progress - 400.0) < 2.0, "progress %.1f" % tank.progress)

		# A path that crosses itself: point 4 (100,0) also lies on the first leg.
		# The tank must not stop on the first leg at progress 100, only at the real corner (500).
		var loop_path := Path2D.new()
		loop_path.curve = Curve2D.new()
		for p in [Vector2(0, 0), Vector2(200, 0), Vector2(200, 100), Vector2(100, 100), Vector2(100, 0), Vector2(100, -100)]:
			loop_path.curve.add_point(p)
		root.add_child(loop_path)
		var tank2: Node2D = _spawn_on_test_path("res://enemies/enemy_tank.tscn", loop_path)
		tank2.progress = 80.0
		_step(tank2, 0.5)
		_check("tank does not stop where a later corner crosses an earlier leg", tank2.progress > 102.0, "progress %.1f" % tank2.progress)
		tank2.progress = 480.0
		_step(tank2, 0.5)
		_check("tank stops at that later corner", absf(tank2.progress - 500.0) < 2.0, "progress %.1f" % tank2.progress)
		loop_path.queue_free()

	# Waves: every wave names a real monster type
	var waves: Script = load("res://enemies/wave_manager.gd")
	var bad := []
	for level in waves.WAVES:
		for w in waves.WAVES[level]:
			if w["type"] != "mixed" and not waves.ENEMY_SCENES.has(w["type"]):
				bad.append("L%d %s" % [level, w["type"]])
	_check("every wave uses a real monster type", bad.is_empty(), bad)

	path.queue_free()
	await process_frame


## Monsters per second over one pass of a level's wave table
func _spawn_rate(waves: Array) -> float:
	var count := 0
	var seconds := 0.0
	for w in waves:
		count += w["count"]
		seconds += 0.5 + (w["count"] - 1) * w["interval"] + w["pause"]
	return count / seconds


## Level 2: the Commander must be hard to time (speed changes, turns around)
## but fair (stays on its path, never faster than its top speed, never stops).
func _level_2_checks() -> void:
	var path := Path2D.new()
	path.position = Vector2(100, 50)   # not at 0,0, so a mix-up of local and global positions shows
	path.curve = Curve2D.new()
	for p in [Vector2(0, 0), Vector2(600, 0), Vector2(600, 600), Vector2(0, 600), Vector2(0, 0)]:
		path.curve.add_point(p)   # closed square, like Mew's OriginPath
	root.add_child(path)
	var dt := 1.0 / 60.0
	var max_off := 0.0
	var turns_min := 9999
	var turns_max := 0
	var v_min := INF
	var v_max := 0.0
	var base := 0.0
	var slow = null
	var fast = null
	for run_seed in [1, 2, 3, 4, 5, 6]:   # several fixed "random" runs, the same every time
		seed(run_seed)
		var commander: Node2D = load("res://laser/origins/commander.tscn").instantiate()
		root.add_child(commander)
		commander.set_process(false)   # only the loop below moves it
		commander.follow_path(path)
		slow = commander.get("speed_min_factor")
		fast = commander.get("speed_max_factor")
		base = commander.move_speed
		var turns := 0
		commander._process(dt)
		var prev: Vector2 = commander.global_position
		var prev_move := Vector2.ZERO
		for i in 1800:   # 30 s
			commander._process(dt)
			var pos: Vector2 = commander.global_position
			var move := pos - prev
			max_off = maxf(max_off, pos.distance_to(path.to_global(path.curve.get_closest_point(path.to_local(pos)))))
			if move.dot(prev_move) < 0.0:
				turns += 1
			if is_equal_approx(pos.x, prev.x) or is_equal_approx(pos.y, prev.y):   # skip corner frames
				v_min = minf(v_min, move.length() / dt)
				v_max = maxf(v_max, move.length() / dt)
			prev = pos
			prev_move = move
		turns_min = mini(turns_min, turns)
		turns_max = maxi(turns_max, turns)
		commander.queue_free()
	randomize()   # back to real randomness for the rest of the test
	if slow == null or fast == null:
		_check("Commander has speed_min_factor / speed_max_factor settings", false)
	else:
		_check("Commander stays on its path", max_off < 1.0, "max %.1f px off" % max_off)
		_check("Commander turns around sometimes, but does not jitter", turns_min >= 1 and turns_max <= 30,
				"%d to %d turns per 30 s" % [turns_min, turns_max])
		_check("Commander speeds up and slows down", v_min < base * 0.9 and v_max > base * 1.1,
				"%.0f to %.0f px/s, base %.0f" % [v_min, v_max, base])
		_check("Commander never goes past its top speed", v_max <= base * fast + 1.0, "max %.0f px/s" % v_max)
		_check("Commander never stops or crawls", v_min >= base * slow - 1.0, "min %.0f px/s" % v_min)
	path.queue_free()

	# The last wave repeats faster and faster. It must level off, or the screen floods.
	var flood_path := Path2D.new()
	flood_path.curve = Curve2D.new()
	flood_path.curve.add_point(Vector2.ZERO)
	flood_path.curve.add_point(Vector2(100, 0))
	root.add_child(flood_path)
	var manager := Node.new()
	manager.set_script(load("res://enemies/wave_manager.gd"))
	root.add_child(manager)
	var flood_paths: Array[Path2D] = [flood_path]
	manager.setup(flood_paths, 2)
	for i in 60:   # far more wave loops than fit in 3 minutes
		manager._start_next_wave()
	var floor_factor = manager.get("min_speed_factor")
	_check("repeating waves stop getting faster at min_speed_factor",
			floor_factor != null and floor_factor >= 0.3 and manager._speed_factor >= floor_factor - 0.001,
			"factor %.3f, floor %s" % [manager._speed_factor, str(floor_factor)])
	manager.queue_free()
	flood_path.queue_free()

	var waves: Script = load("res://enemies/wave_manager.gd")
	var rate_1 := _spawn_rate(waves.WAVES[1])
	var rate_2 := _spawn_rate(waves.WAVES[2])
	_check("level 2 waves spawn faster than level 1", rate_2 > rate_1 * 1.3, "%.2f vs %.2f monsters/s" % [rate_2, rate_1])
	var fast_2 := 0
	var total_2 := 0
	for w in waves.WAVES[2]:
		total_2 += w["count"]
		if w["type"] == "fast":
			fast_2 += w["count"]
	_check("level 2 has at least 6 waves and a third of the named monsters are fast",
			waves.WAVES[2].size() >= 6 and fast_2 * 3 >= total_2, "%d waves, %d/%d fast" % [waves.WAVES[2].size(), fast_2, total_2])
	await process_frame


## Waits (up to `seconds`) until the scene with this root name is showing
func _wait_for_scene(scene_name: String, seconds := 5.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if current_scene != null and current_scene.name == scene_name:
			return true
		await process_frame
	return false


## File name of the picture on the end screen ("" if there is none)
func _end_art() -> String:
	var art := current_scene.get_node_or_null("VBox/Art") as TextureRect
	return art.texture.resource_path.get_file() if art and art.texture else ""


## "lose.wav playing" style description of the end screen's sound ("" if there is none)
func _end_sound() -> String:
	var jingle := current_scene.get_node_or_null("Jingle") as AudioStreamPlayer
	if jingle == null or jingle.stream == null:
		return ""
	return "%s %s" % [jingle.stream.resource_path.get_file(), "playing" if jingle.playing else "silent"]


func _press_any_key() -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_ENTER
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await process_frame


## Every level must keep the node names from docs/contracts.md section 5,
## because game.gd finds them by name. Returns what is missing or wrong.
func _level_problems(scene_path: String, needs_origin_path: bool) -> Array:
	var problems := []
	var level: Node = load(scene_path).instantiate()
	for entry in [["Walls", "TileMapLayer"], ["Paths", "Node2D"], ["PlayerStart", "Marker2D"],
			["OriginSpot", "Marker2D"], ["OriginPath", "Path2D"], ["LaserSpawns", "Node2D"], ["Entities", "Node2D"]]:
		var node := level.get_node_or_null(entry[0])
		if node == null:
			problems.append("no %s" % entry[0])
		elif not node.is_class(entry[1]):
			problems.append("%s is not a %s" % entry)
	if problems.is_empty():
		var routes := 0
		for path in level.get_node("Paths").get_children():
			if path is Path2D and path.curve != null and path.curve.point_count >= 2:
				routes += 1
			else:
				problems.append("Paths/%s has no route drawn" % path.name)
		if routes == 0:
			problems.append("no enemy route under Paths")
		var spots := 0
		for spot in level.get_node("LaserSpawns").get_children():
			if spot is Marker2D:
				spots += 1
		if spots == 0:
			problems.append("no Marker2D under LaserSpawns")
		if needs_origin_path:
			var curve: Curve2D = level.get_node("OriginPath").curve
			if curve == null or curve.point_count < 2:
				problems.append("OriginPath has no route drawn")
			elif curve.get_point_position(0).distance_to(curve.get_point_position(curve.point_count - 1)) > 1.0:
				problems.append("OriginPath is not a closed loop (last point must be on the first)")
	level.free()
	return problems


func _level_contract_checks() -> void:
	var problems := _level_problems("res://levels/level_1.tscn", false)
	_check("level 1 has every node from docs/contracts.md", problems.is_empty(), problems)
	problems = _level_problems("res://levels/level_2.tscn", true)
	_check("level 2 has every node from docs/contracts.md and a closed Commander route", problems.is_empty(), problems)


func _run() -> void:
	_events = root.get_node("Events")
	_state = root.get_node("GameState")
	# Watchdog: if a step crashes, the test would wait forever. Stop after 150 s.
	create_timer(150.0).timeout.connect(func():
		print("FAIL  test did not finish within 150 s (a step crashed, see the errors above)")
		quit(2))
	await process_frame

	await _enemy_type_checks()
	await _level_2_checks()
	_level_contract_checks()

	# ---------- Level 1 ----------
	var game: Node = await _load_game(1)
	_check("level 1 loads and the clock starts", game.name == "Game" and _state.running)
	var player: Node2D = get_first_node_in_group("player")
	player.global_position = Vector2(300, 300)   # off every monster path while we wait
	await create_timer(3.0).timeout
	var enemies := get_nodes_in_group("enemies")
	_check("monsters spawn", enemies.size() > 0, "%d after 3 s" % enemies.size())

	# Contact damage must repeat while the player stays on a monster
	var rider: Node2D = enemies[0]
	for i in 108:   # 1.8 s
		if is_instance_valid(rider):
			player.global_position = rider.global_position
		await physics_frame
	_check("contact damage repeats after invincibility", player.hp == player.max_hp - 2, "hp %d/%d" % [player.hp, player.max_hp])
	player.hp = player.max_hp
	player.global_position = Vector2(300, 300)
	await create_timer(1.1).timeout

	# A real bullet kills a monster and charges the laser
	var lm := game.get_node("LaserManager")
	var target: Node2D = get_nodes_in_group("enemies")[-1]
	var kills_before: int = lm._kills
	target.speed = 0.0
	var shot_dir := _clear_shot_direction(target, 70.0)
	player.global_position = target.global_position - shot_dir * 70.0
	player.facing = shot_dir
	player.shoot()
	await create_timer(0.3).timeout
	_check("bullet kills a monster", not is_instance_valid(target) or target._dead)
	_check("kill charges the laser", lm._kills == kills_before + 1, "%d / %d" % [lm._kills, lm._needed])
	player.global_position = Vector2(300, 300)

	# Laser: pickup pauses, miss resumes and needs a recharge
	var origin: Node2D = get_first_node_in_group("origin")
	var aim: Node = await _get_to_aim_mode(game, player)
	_check("laser appears after enough kills and pickup starts aim mode", aim != null)
	_check("game is paused while aiming", paused)
	var clock: float = _state.time_left
	await create_timer(0.3).timeout
	_check("clock is frozen while aiming", clock == _state.time_left)
	var to_origin: Vector2 = (origin.global_position - player.global_position).normalized()
	await _fire(aim, -to_origin)
	_check("miss: game resumes, origin alive, laser recharging", not paused and not origin.destroyed and lm._charging,
			"needs %d kills" % lm._needed)

	# Laser: hit wins the level
	aim = await _get_to_aim_mode(game, player)
	to_origin = (origin.global_position - player.global_position).normalized()
	await _fire(aim, to_origin)
	_check("hit: origin destroyed and level won", origin.destroyed and _state.last_result_won and not _state.running)
	await create_timer(2.0).timeout
	_check("win leads to the Level 2 story page", current_scene.name == "StoryScreen" and _state.current_level == 2,
			"%s, level %d" % [current_scene.name, _state.current_level])

	# ---------- Level 2 ----------
	game = await _load_game(2)
	origin = get_first_node_in_group("origin")
	var before: Vector2 = origin.global_position
	await create_timer(0.5).timeout
	_check("level 2 Commander moves", origin.name == "Commander" and before.distance_to(origin.global_position) > 10.0)
	paused = true
	before = origin.global_position
	await create_timer(0.5).timeout
	_check("Commander keeps moving while the game is paused (aiming)", before.distance_to(origin.global_position) > 10.0)
	paused = false

	# Timeout loses
	_state.time_left = 0.2
	await create_timer(2.2).timeout
	_check("time up leads to the lose screen", current_scene.name == "EndScreen" and not _state.last_result_won,
			current_scene.name)

	# ---------- Screens and the rest of the flow ----------
	# Lose screen: RETRY restarts the level you lost on
	var retry: Button = current_scene.get_node("VBox/RetryButton")
	_check("lose screen shows RETRY", retry.visible)
	_check("lose screen shows the hurt astronaut", _end_art() == "Player_Hit.png", _end_art())
	_check("lose screen plays the lose sound", _end_sound() == "lose.wav playing", _end_sound())
	retry.pressed.emit()
	var ok: bool = await _wait_for_scene("Game")
	await process_frame
	_check("RETRY restarts the same level", ok and _state.current_level == 2 and _state.running,
			"level %d" % _state.current_level)
	if not ok:
		game = await _load_game(2)   # so the checks below still have a level to run in

	# Player death loses
	player = get_first_node_in_group("player")
	player.take_damage(player.max_hp)
	ok = await _wait_for_scene("EndScreen")
	_check("player death leads to the lose screen", ok and not _state.last_result_won, current_scene.name)

	# Level 2 win: ending story, then the win screen, then back to the title
	game = await _load_game(2)
	get_first_node_in_group("origin").take_laser_hit()
	ok = await _wait_for_scene("StoryScreen")
	_check("level 2 win leads to the ending story", ok and _state.story_id == "ending", _state.story_id)
	await create_timer(0.8).timeout   # the story page ignores keys for its first 0.6 s
	await _press_any_key()
	ok = await _wait_for_scene("EndScreen")
	_check("ending story leads to the win screen", ok and _state.last_result_won, current_scene.name)
	await process_frame
	_check("win screen has no RETRY", ok and not current_scene.get_node("VBox/RetryButton").visible)
	_check("win screen shows the spaceship", _end_art() == "Spaceship.png", _end_art())
	_check("win screen plays the win sound", _end_sound() == "win.wav playing", _end_sound())
	if ok:
		current_scene.get_node("VBox/MenuButton").pressed.emit()
	ok = await _wait_for_scene("TitleScreen")
	_check("MAIN MENU leads to the title screen", ok, current_scene.name)

	# Title: the hover sound is for the mouse only (the button holds keyboard focus from the start)
	if ok:
		var hover_sfx: AudioStreamPlayer = current_scene.get_node("Sfx")
		current_scene.get_node("StartButton").focus_entered.emit()
		_check("title: keyboard focus does not play the hover sound", hover_sfx.stream == null)
		current_scene.get_node("StartButton").mouse_entered.emit()
		_check("title: mouse hover plays the hover sound", hover_sfx.stream != null)

	# Title: START begins a new game at level 1
	if ok:
		current_scene.get_node("StartButton").pressed.emit()
	ok = await _wait_for_scene("StoryScreen")
	_check("START leads to the intro story", ok and _state.story_id == "intro" and _state.current_level == 1,
			"%s, level %d" % [_state.story_id, _state.current_level])
	await create_timer(0.8).timeout
	await _press_any_key()
	ok = await _wait_for_scene("Game")
	await process_frame
	_check("intro story leads to level 1", ok and _state.current_level == 1 and _state.running, current_scene.name)

	print("")
	print("ALL PASSED" if _failures == 0 else "%d CHECK(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)
