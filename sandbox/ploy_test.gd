extends Node2D
## Ploy's sandbox: level 1 paths + wave manager, no player, no timer.
## Change LEVEL to 2 to watch the level 2 waves.

const LEVEL := 1
const LEVEL_SCENES := {1: "res://levels/level_1.tscn", 2: "res://levels/level_2.tscn"}


func _ready() -> void:
	var level: Level = load(LEVEL_SCENES[LEVEL]).instantiate()
	add_child(level)
	var waves := Node.new()
	waves.set_script(preload("res://enemies/wave_manager.gd"))
	add_child(waves)
	waves.setup(level.get_enemy_paths(), LEVEL)
