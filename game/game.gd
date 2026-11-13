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
const BULLET_SCENE_PATH := "res://player/bullet.tscn"
## The clock ticks out loud for this many seconds at the end
const TICK_LAST_SECONDS := 10

## Volume in dB (0 = as loud as the file). Music sits under the sound effects.
@export var music_volume_db := -10.0
@export var sfx_volume_db := -4.0
## Shooting and monster sounds happen many times a second, so they are quieter
@export var frequent_sfx_volume_db := -12.0

var _last_hp := -1
var _last_tick_second := -1

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

	# 7. Start the clock
	GameState.begin_level()


func _setup_audio(level_number: int) -> void:
	var music := AudioStreamPlayer.new()
	music.name = "Music"
	music.stream = MUSIC.get(level_number, MUSIC[1])
	music.volume_db = music_volume_db
	music.process_mode = Node.PROCESS_MODE_ALWAYS   # keep playing while the game is paused for aiming
	add_child(music)
	music.play()

	Events.level_started.connect(func(_level): _play(SFX_LEVEL_START))
	Events.laser_spawned.connect(func(_pos): _play(SFX_LASER_SPAWN))
	Events.laser_picked_up.connect(func():
		_play(SFX_PICKUP)
		_play(SFX_LASER_CHARGE))
	Events.laser_fired.connect(func(hit: bool):
		_play(SFX_LASER_FIRE)
		if not hit:
			_play(SFX_LASER_MISS))
	Events.origin_destroyed.connect(func(): _play(SFX_ORIGIN_DESTROYED))

	Events.enemy_hit.connect(func(_enemy): _play(SFX_ENEMY_HIT, frequent_sfx_volume_db))
	Events.enemy_killed.connect(func(_enemy): _play(SFX_ENEMY_DIE, frequent_sfx_volume_db))
	Events.wave_started.connect(func(_wave): _play(SFX_MONSTER_SPAWN))
	Events.player_hp_changed.connect(_on_player_hp_changed)
	Events.player_died.connect(func(): _play(SFX_PLAYER_DIE))
	Events.time_changed.connect(_on_time_changed)


func _on_player_hp_changed(hp: int, _max_hp: int) -> void:
	if hp < _last_hp and hp > 0:   # at 0 the death sound plays instead
		_play(SFX_PLAYER_HURT)
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
