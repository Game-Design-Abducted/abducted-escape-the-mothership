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


func _run() -> void:
	_events = root.get_node("Events")
	_state = root.get_node("GameState")
	# Watchdog: if a step crashes, the test would wait forever. Stop after 90 s.
	create_timer(90.0).timeout.connect(func():
		print("FAIL  test did not finish within 90 s (a step crashed, see the errors above)")
		quit(2))
	await process_frame

	await _enemy_type_checks()

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
	player.global_position = target.global_position - Vector2(70, 0)
	player.facing = Vector2.RIGHT
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

	print("")
	print("ALL PASSED" if _failures == 0 else "%d CHECK(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)
