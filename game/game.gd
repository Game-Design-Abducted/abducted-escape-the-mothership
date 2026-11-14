extends Node2D
## Game scene script. Ploy's. Builds and runs ONE level.
##
## This is the only script that knows about everyone's pieces. In order it:
##   1. loads Mew's level for GameState.current_level
##   2. puts Yang's player at PlayerStart
##   3. puts Ploy's origin (egg / commander) in the level
##   4. starts Ploy's wave manager on the level's paths
##   5. starts Yang's laser manager
##   6. (Kong's HUD is already inside game.tscn and just listens to Events)
##   7. tells GameState to start the 3 minute timer
##   8. plays the level music and every in-level sound: laser, shooting,
##      monsters, player hurt / death, timer tick (it only listens to Events,
##      so nobody else's script has to know about audio)
##   9. adds the screen feel: fade in, screen shake, hit / laser flashes, music
##      that dips while aiming (again only by listening to Events)
##
## Press F6 on game.tscn to play the current level directly (level 1 by default).
## To jump straight to level 2, change `debug_start_level` in the Inspector.
##
## TODO Ploy: when two systems need to talk to each other, wire them up here
## instead of letting them reach into each other's code.

const LEVEL_SCENES := {
	1: preload("res://levels/level_1.tscn"),
	2: preload("res://levels/level_2.tscn"),
}
const PLAYER_SCENE := preload("res://player/player.tscn")
const EGG_SCENE := preload("res://laser/origins/egg.tscn")
const COMMANDER_SCENE := preload("res://laser/origins/commander.tscn")

## Fah's audio. Level 1 gets the level track, level 2 the boss track.
const MUSIC := {
	1: preload("res://assets/audio/music/bgm_level.ogg"),
	2: preload("res://assets/audio/music/bgm_boss.ogg"),
}
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
## The clock ticks out loud for this many seconds at the end
const TICK_LAST_SECONDS := 10

## Volume in dB (0 = as loud as the file). Music sits under the sound effects.
@export var music_volume_db := -10.0
@export var sfx_volume_db := -4.0
## Shooting and monster sounds happen many times a second, so they are quieter
@export var frequent_sfx_volume_db := -12.0

## Music gets this much quieter while the game is frozen for aiming the laser
@export var aim_music_duck_db := -8.0

@export_group("Screen feel")
## Screen shake in pixels for each event (0 = off)
@export var shake_player_hurt := 6.0
@export var shake_laser_fired := 8.0
@export var shake_origin_destroyed := 18.0
## How fast a shake dies down, pixels per second
@export var shake_fade := 40.0

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

## 0 = use GameState.current_level. Set 1 or 2 to force a level while testing with F6.
@export var debug_start_level := 0

@onready var world: Node2D = $World
@onready var wave_manager: Node = $WaveManager
@onready var laser_manager: Node = $LaserManager


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

	# 3. Origin (Ploy): level 1 = egg standing still, level 2 = commander walking
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

	# 8. Audio (connected before the clock starts, so level_started is heard)
	_setup_audio(level_number)
	# Yang's bullets are added next to the player, so a new bullet there = a shot
	level.get_entities().child_entered_tree.connect(func(node: Node):
		if node.scene_file_path == BULLET_SCENE_PATH:
			_play(SFX_SHOOT, frequent_sfx_volume_db))

	# 9. Screen feel: fade in, shake, flashes, the origin bulging when a monster comes out
	_setup_feel(origin)

	# 7. Start the clock
	GameState.begin_level()


func _process(delta: float) -> void:
	# Screen shake: only the camera moves, so nothing in the level (walls,
	# player, pickups) changes position. The HUD is on its own layer and stays still.
	if _shake > 0.0:
		_shake = move_toward(_shake, 0.0, shake_fade * delta)
		_camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	elif _camera.offset != Vector2.ZERO:
		_camera.offset = Vector2.ZERO


func _setup_feel(origin: Origin) -> void:
	# A camera in the middle of the screen shows exactly what no camera shows
	_camera = Camera2D.new()
	_camera.name = "Camera"
	_camera.position = get_viewport_rect().size / 2.0
	add_child(_camera)
	_camera.make_current()

	# One full-screen colour layer, used for the fade-in and for flashes
	var layer := CanvasLayer.new()
	layer.name = "ScreenFx"
	layer.layer = 5
	add_child(layer)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(0, 0, 0, 1)
	layer.add_child(_flash)
	_flash_to(Color(0, 0, 0, 0), 0.5)   # fade in from black

	# (a method, not a lambda: a lambda that never touches `self` would stay
	# connected to Events after this scene is gone)
	_origin = origin
	Events.enemy_spawned.connect(_on_enemy_spawned)
	Events.laser_fired.connect(func(_hit):
		_shake = maxf(_shake, shake_laser_fired)
		_flash_from(Color(1, 1, 1, 0.45), 0.25))
	Events.origin_destroyed.connect(func():
		_shake = maxf(_shake, shake_origin_destroyed)
		_flash_from(Color(1, 1, 1, 0.85), 0.6))
	Events.level_finished.connect(_on_level_finished)


## The origin bulges each time a monster comes out, and so does the floor mark
func _on_enemy_spawned(_enemy: Node) -> void:
	if is_instance_valid(_origin):
		_origin.pulse()
	for marker in _spawn_markers:
		marker.pulse()


## Level 2 only: a glowing mark where the monster routes start, because the
## Commander is somewhere else. Routes that start close together share one mark.
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


## When the level ends no more monsters come out. On a win the ones still
## walking dissolve with the origin, so nothing can hurt the player any more.
func _on_level_finished(won: bool) -> void:
	wave_manager.stop()
	if won:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			enemy.vanish()
	else:
		_flash_to(Color(0.25, 0.0, 0.05, 0.55), 1.2)   # the screen sinks into dark red


## Jump to `color`, then fade it away (a flash)
func _flash_from(color: Color, seconds: float) -> void:
	_flash.color = color
	_flash_to(Color(color, 0.0), seconds)


## Fade the screen colour from what it is now to `color`. Runs while paused too.
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
	music.process_mode = Node.PROCESS_MODE_ALWAYS   # keep playing while the game is paused for aiming
	add_child(music)
	music.play()
	_music = music

	Events.level_started.connect(func(_level): _play(SFX_LEVEL_START))
	Events.laser_spawned.connect(func(_pos): _play(SFX_LASER_SPAWN))
	Events.laser_picked_up.connect(func():
		_play(SFX_PICKUP)
		_play(SFX_LASER_CHARGE)
		_fade_music(music_volume_db + aim_music_duck_db, 0.3))   # quieter while aiming
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


## One tick per second while the last TICK_LAST_SECONDS seconds run down
func _on_time_changed(seconds_left: float) -> void:
	var second := ceili(seconds_left)
	if second == _last_tick_second:
		return
	_last_tick_second = second
	if second > 0 and second <= TICK_LAST_SECONDS and GameState.running:
		_play(SFX_TIMER_TICK)


## Plays one sound effect. Each call gets its own player, so sounds can overlap,
## and it runs while paused because the laser sounds happen during aim mode.
func _play(stream: AudioStream, volume_db := sfx_volume_db) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()
