extends Node2D
## Game scene: builds one level and wires everyone's parts together. Ploy's.

const LEVEL_SCENES := {
	1: preload("res://levels/level_1.tscn"),
	2: preload("res://levels/level_2.tscn"),
}
const PLAYER_SCENE := preload("res://player/player.tscn")
const EGG_SCENE := preload("res://laser/origins/egg.tscn")
const COMMANDER_SCENE := preload("res://laser/origins/commander.tscn")

const MUSIC := {
	1: preload("res://assets/audio/music/bgm_level.ogg"),
	2: preload("res://assets/audio/music/bgm_boss.ogg"),
}
const SHIP_PRANKS := preload("res://game/ship_pranks.gd")
const SFX_LEVEL_START := preload("res://assets/audio/sfx/level_start.wav")
const SFX_LASER_SPAWN := preload("res://assets/audio/sfx/laser_spawn.wav")
const SFX_PICKUP := preload("res://assets/audio/sfx/pickup.wav")
const SFX_LASER_CHARGE := preload("res://assets/audio/sfx/laser_charge.wav")
const SFX_LASER_FIRE := preload("res://assets/audio/sfx/laser_fire.wav")
const SFX_LASER_MISS := preload("res://assets/audio/sfx/laser_miss.wav")
const SFX_ORIGIN_DESTROYED := preload("res://assets/audio/sfx/origin_destroyed.wav")
const SFX_SHOOT := preload("res://assets/audio/sfx/shoot.wav")
const SFX_ENEMY_HIT := preload("res://assets/audio/sfx/enemy_hit.wav")
const SFX_ENEMY_DIE := preload("res://assets/audio/sfx/enemy_die.wav")
const SFX_MONSTER_SPAWN := preload("res://assets/audio/sfx/monster_spawn.wav")
const SFX_PLAYER_HURT := preload("res://assets/audio/sfx/player_hurt.wav")
const SFX_PLAYER_DIE := preload("res://assets/audio/sfx/player_die.wav")
const SFX_TIMER_TICK := preload("res://assets/audio/sfx/timer_tick.wav")
const SFX_IMMUNE := preload("res://assets/audio/sfx/immune_tink.wav")
const SPAWN_MARKER := preload("res://game/spawn_marker.gd")
const BULLET_SCENE_PATH := "res://player/bullet.tscn"
## seconds of loud ticking at the end
const TICK_LAST_SECONDS := 10

## dB, 0 = as loud as the file
@export var music_volume_db := -10.0
@export var sfx_volume_db := -4.0
## quieter since these play many times a second
@export var frequent_sfx_volume_db := -12.0

## dB drop for the music while aiming the laser
@export var aim_music_duck_db := -8.0

@export_group("Screen feel")
## shake in pixels, 0 = off
@export var shake_player_hurt := 6.0
@export var shake_laser_fired := 8.0
@export var shake_origin_destroyed := 18.0
## pixels per second
@export var shake_fade := 40.0
@export var shake_bomb := 12.0
## freeze-frame on a laser hit, real seconds, 0 = off
@export var hit_stop_time := 0.12

const KILL_WORDS := ["SPLAT!", "BONK!", "POP!", "SQUISH!", "YEET!", "BLORP!", "BOOP!", "SPLOOT!"]
const KILL_WORD_COLORS := [Color(1.0, 0.9, 0.3), Color(0.5, 1.0, 0.6), Color(1.0, 0.55, 0.8), Color(0.6, 0.85, 1.0)]
## level 1 = egg, level 2 = commander
const TAUNTS_MISS := {
	1: ["missed me!", "nice try, human", "is that a laser\nor a flashlight?", "*smug egg noises*", "I'm not even moving!"],
	2: ["TOO SLOW, EARTHLING", "I do cardio.", "aim with your\neyes open!", "catch me if you can~", "my grandma dodges\nbetter than that"],
}
const TAUNTS_HIT := {
	1: ["OW! my shell!", "that... cracked something", "hey! rude!"],
	2: ["that tickled.", "OK that one hurt", "you'll pay for that!"],
}
## after a miss the next shot is easier (laser_manager.gd PITY_*)
const PITY_WORDS := ["laser out of pity: target BIGGER", "the laser believes in you", "aim assist: activated (shh)", "bigger target unlocked"]
const VICTORY_WORDS := ["WOOHOO!", "EGG-CELLENT!", "GET REKT, ALIEN", "HOME, HERE I COME!"]

var _last_hp := -1
var _last_tick_second := -1
var _shake := 0.0
var _flash: ColorRect
var _flash_tween: Tween
var _music: AudioStreamPlayer
var _music_tween: Tween
var _origin: Origin
var _camera: Camera2D
var _spawn_markers: Array[Node2D] = []
var _level: Level
var _player: Node2D
var _bubble: Control
var _last_word_ms := 0

## 0 = GameState.current_level. Set 1 or 2 to force a level when testing with F6.
@export var debug_start_level := 0

@onready var world: Node2D = $World
@onready var wave_manager: Node = $WaveManager
@onready var laser_manager: Node = $LaserManager
@onready var drop_manager: Node = $DropManager


func _ready() -> void:
	if debug_start_level > 0:
		GameState.current_level = debug_start_level
	var level_number: int = GameState.current_level

	# 1. Level (Mew)
	var level: Level = LEVEL_SCENES[level_number].instantiate()
	world.add_child(level)

	# 2. Player (Yang)
	var player: Node2D = PLAYER_SCENE.instantiate()
	player.position = level.get_player_start()
	level.get_entities().add_child(player)

	# 3. Origin (Ploy): egg in level 1, commander in level 2
	var origin: Origin
	var origin_path := level.get_origin_path()
	if level_number >= 2 and origin_path:
		var commander = COMMANDER_SCENE.instantiate()
		commander.position = level.get_origin_spot()
		level.get_entities().add_child(commander)
		commander.follow_path(origin_path)
		origin = commander
		_add_spawn_markers(level)
	else:
		origin = EGG_SCENE.instantiate()
		origin.position = level.get_origin_spot()
		level.get_entities().add_child(origin)

	# 4. Waves (Ploy)
	wave_manager.setup(level.get_enemy_paths(), level_number)

	# 5. Laser (Yang)
	laser_manager.setup(level, player, origin)

	# 10. Space Junk drops
	_level = level
	_player = player
	drop_manager.setup(level, player)

	# 12. Ship pranks
	var pranks := Node.new()
	pranks.name = "ShipPranks"
	pranks.set_script(SHIP_PRANKS)
	add_child(pranks)
	pranks.setup(level, player)

	# 8. Audio, before the clock starts so level_started is heard
	_setup_audio(level_number)
	# bullets get added next to the player, so a new bullet there = a shot
	level.get_entities().child_entered_tree.connect(func(node: Node):
		if node.scene_file_path == BULLET_SCENE_PATH:
			_play(SFX_SHOOT, frequent_sfx_volume_db))

	# 9. Screen feel
	_setup_feel(origin)

	# 11. Pause menu
	add_child(PauseMenu.new())

	# 7. Start the clock
	GameState.begin_level()


func _process(delta: float) -> void:
	# shake moves only the camera, so level positions and the HUD stay put
	if _shake > 0.0:
		_shake = move_toward(_shake, 0.0, shake_fade * delta)
		_camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	elif _camera.offset != Vector2.ZERO:
		_camera.offset = Vector2.ZERO


func _setup_feel(origin: Origin) -> void:
	# centered camera = same view as no camera
	_camera = Camera2D.new()
	_camera.name = "Camera"
	_camera.position = get_viewport_rect().size / 2.0
	add_child(_camera)
	_camera.make_current()

	var layer := CanvasLayer.new()
	layer.name = "ScreenFx"
	layer.layer = 5
	add_child(layer)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(0, 0, 0, 1)
	layer.add_child(_flash)
	_flash_to(Color(0, 0, 0, 0), 0.5)

	# a method, not a lambda: a lambda that never touches self stays connected after the scene is gone
	_origin = origin
	Events.enemy_spawned.connect(_on_enemy_spawned)
	Events.laser_fired.connect(func(_hit):
		_shake = maxf(_shake, shake_laser_fired)
		_flash_from(Color(1, 1, 1, 0.45), 0.25))
	Events.origin_destroyed.connect(func():
		_shake = maxf(_shake, shake_origin_destroyed)
		_flash_from(Color(1, 1, 1, 0.85), 0.6))
	Events.level_finished.connect(_on_level_finished)

	# 10. Space Junk + jokes
	Events.enemy_killed.connect(_on_enemy_killed_word)
	Events.item_dropped.connect(_on_item_dropped)
	Events.item_used.connect(_on_item_used)
	drop_manager.boom.connect(_on_bomb_boom)
	Events.laser_fired.connect(_on_laser_fired_feel)
	Events.origin_destroyed.connect(_on_origin_destroyed_feel)


func _exit_tree() -> void:
	Engine.time_scale = 1.0   # never leave a hit-stop running into the next scene


# ---------- 10. Space Junk + jokes ----------

## throttled so a bomb doesn't fill the screen with words
func _on_enemy_killed_word(enemy: Node) -> void:
	if not (is_instance_valid(enemy) and enemy is Node2D) or _level == null:
		return
	var now := Time.get_ticks_msec()
	if now - _last_word_ms < 90:
		return
	_last_word_ms = now
	FloatText.spawn(_level, (enemy as Node2D).global_position + Vector2(0, -18),
			KILL_WORDS.pick_random(), KILL_WORD_COLORS.pick_random(), 18)


func _on_item_dropped(_kind: String, _at: Vector2) -> void:
	_play(SFX_LASER_SPAWN, frequent_sfx_volume_db, 1.7)   # a little "ding!"


func _on_item_used(kind: String, _at: Vector2) -> void:
	match kind:
		"bomb":
			_play(SFX_LASER_MISS, sfx_volume_db, 0.55)   # the wheeze
		"disco":
			_play(SFX_PICKUP, sfx_volume_db, 1.3)
			_play(SFX_LEVEL_START, sfx_volume_db, 1.25)
			_flash_from(Color(1.0, 0.4, 1.0, 0.3), 0.5)
			_music.pitch_scale = 1.15
			get_tree().create_timer(drop_manager.DISCO_TIME, false).timeout.connect(_end_disco_music)
		"snack":
			_play(SFX_PICKUP, sfx_volume_db, 0.8)
			_flash_from(Color(1.0, 0.85, 0.3, 0.25), 0.4)


func _end_disco_music() -> void:
	_music.pitch_scale = 1.0


func _on_bomb_boom(_at: Vector2) -> void:
	_shake = maxf(_shake, shake_bomb)
	_play(SFX_ORIGIN_DESTROYED, sfx_volume_db, 1.5)
	_flash_from(Color(0.5, 1.0, 0.3, 0.2), 0.35)


func _on_laser_fired_feel(hit: bool) -> void:
	if hit and hit_stop_time > 0.0:
		Engine.time_scale = 0.05
		get_tree().create_timer(hit_stop_time, true, false, true).timeout.connect(_end_hit_stop)
	if not hit and is_instance_valid(_player):
		FloatText.spawn(_level, _player.global_position + Vector2(0, -36), PITY_WORDS.pick_random(),
				Color(1.0, 0.9, 0.3), 20, 34.0, 1.6)
	if not is_instance_valid(_origin) or _origin.destroyed:
		return
	var lines: Dictionary = TAUNTS_HIT if hit else TAUNTS_MISS
	var level_lines: Array = lines.get(GameState.current_level, lines[1])
	_say(level_lines.pick_random())


func _end_hit_stop() -> void:
	Engine.time_scale = 1.0


func _say(line: String) -> void:
	if is_instance_valid(_bubble):
		_bubble.queue_free()
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.95)
	style.border_color = Color(0.1, 0.05, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = line
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FloatText.FONT)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.1, 0.05, 0.2))
	panel.add_child(label)
	panel.z_index = 60
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_origin.add_child(panel)   # follows the Commander around
	panel.reset_size()
	panel.position = Vector2(-panel.size.x / 2.0, -panel.size.y - 52.0)
	panel.pivot_offset = Vector2(panel.size.x / 2.0, panel.size.y)
	if _origin.global_position.y + panel.position.y < 56.0:   # would cover the HUD, put it below
		panel.position.y = 52.0
		panel.pivot_offset.y = 0.0
	panel.scale = Vector2(0.2, 0.2)
	_bubble = panel
	var tween := panel.create_tween()
	tween.tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(2.0)
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(panel.queue_free)


func _on_origin_destroyed_feel() -> void:
	if is_instance_valid(_bubble):
		_bubble.queue_free()
	if not is_instance_valid(_player):
		return
	var sprite := _player.get_node_or_null("Sprite2D") as Node2D
	if sprite:
		var base_scale := sprite.scale
		var tween := sprite.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(sprite, "rotation", sprite.rotation + TAU * 2.0, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(sprite, "scale", base_scale * 1.3, 0.2)
		tween.tween_property(sprite, "scale", base_scale, 0.3)
	FloatText.spawn(_level, _player.global_position + Vector2(0, -34), VICTORY_WORDS.pick_random(),
			Color(1.0, 0.9, 0.3), 28, 40.0, 1.4)


func _on_enemy_spawned(_enemy: Node) -> void:
	if is_instance_valid(_origin):
		_origin.pulse()
	for marker in _spawn_markers:
		marker.pulse()


## level 2 only, the Commander walks away from the spawns. Close routes share one mark.
func _add_spawn_markers(level: Level) -> void:
	var spots: Array[Vector2] = []
	for path in level.get_enemy_paths():
		if path.curve == null or path.curve.point_count == 0:
			continue
		var start := path.to_global(path.curve.get_point_position(0))
		var is_new := true
		for i in spots.size():
			if spots[i].distance_to(start) < 48.0:
				spots[i] = (spots[i] + start) / 2.0
				is_new = false
		if is_new:
			spots.append(start)
	for spot in spots:
		var marker := Node2D.new()
		marker.set_script(SPAWN_MARKER)
		marker.position = spot
		level.add_child(marker)
		level.move_child(marker, level.get_node("Walls").get_index() + 1)   # on the floor, under everything else
		_spawn_markers.append(marker)


## on a win the leftover monsters vanish so nothing can hurt the player any more
func _on_level_finished(won: bool) -> void:
	wave_manager.stop()
	if won:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			enemy.vanish()
	else:
		_flash_to(Color(0.25, 0.0, 0.05, 0.55), 1.2)


func _flash_from(color: Color, seconds: float) -> void:
	_flash.color = color
	_flash_to(Color(color, 0.0), seconds)


func _flash_to(color: Color, seconds: float) -> void:
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_flash_tween.tween_property(_flash, "color", color, seconds)


func _fade_music(volume_db: float, seconds: float) -> void:
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_music_tween.tween_property(_music, "volume_db", volume_db, seconds)


func _setup_audio(level_number: int) -> void:
	var music := AudioStreamPlayer.new()
	music.name = "Music"
	music.stream = MUSIC.get(level_number, MUSIC[1])
	music.volume_db = music_volume_db
	music.process_mode = Node.PROCESS_MODE_ALWAYS   # keep playing while paused for aiming
	add_child(music)
	music.play()
	_music = music

	Events.level_started.connect(func(_level): _play(SFX_LEVEL_START))
	Events.laser_spawned.connect(func(_pos): _play(SFX_LASER_SPAWN))
	Events.laser_picked_up.connect(func():
		_play(SFX_PICKUP)
		_play(SFX_LASER_CHARGE)
		_fade_music(music_volume_db + aim_music_duck_db, 0.3))
	Events.laser_fired.connect(func(hit: bool):
		_play(SFX_LASER_FIRE)
		_fade_music(music_volume_db, 0.6)
		if not hit:
			_play(SFX_LASER_MISS))
	Events.origin_destroyed.connect(func(): _play(SFX_ORIGIN_DESTROYED))

	Events.enemy_hit.connect(func(_enemy): _play(SFX_ENEMY_HIT, frequent_sfx_volume_db))
	Events.enemy_blocked.connect(func(_enemy): _play(SFX_IMMUNE, frequent_sfx_volume_db))
	Events.enemy_killed.connect(func(_enemy): _play(SFX_ENEMY_DIE, frequent_sfx_volume_db))
	Events.wave_started.connect(func(_wave): _play(SFX_MONSTER_SPAWN))
	Events.player_hp_changed.connect(_on_player_hp_changed)
	Events.player_died.connect(func(): _play(SFX_PLAYER_DIE))
	Events.time_changed.connect(_on_time_changed)


func _on_player_hp_changed(hp: int, _max_hp: int) -> void:
	if hp < _last_hp:
		_shake = maxf(_shake, shake_player_hurt)
		if hp > 0:   # at 0 the death sound and the lose fade take over
			_play(SFX_PLAYER_HURT)
			_flash_from(Color(1.0, 0.1, 0.1, 0.3), 0.35)
	_last_hp = hp


func _on_time_changed(seconds_left: float) -> void:
	var second := ceili(seconds_left)
	if second == _last_tick_second:
		return
	_last_tick_second = second
	if second > 0 and second <= TICK_LAST_SECONDS and GameState.running:
		_play(SFX_TIMER_TICK)


## own player per call so sounds overlap. Runs while paused since laser sounds play in aim mode.
func _play(stream: AudioStream, volume_db := sfx_volume_db, pitch := 1.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()
