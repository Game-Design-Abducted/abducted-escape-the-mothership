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

	# 7. Start the clock
	GameState.begin_level()
