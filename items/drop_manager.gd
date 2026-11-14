extends Node
## Space Junk drops. Ploy's, bomb idea from Yang. game.gd calls setup(level, player).
## DROP_CHANCE per kill, but after PITY_TIME with no drop the next kill always drops one.

signal boom(position: Vector2)   ## the Whoopee Bomb went off (game.gd shakes the screen)

const DROP_CHANCE := 0.08
const PITY_TIME := 25.0
const FIRST_DROP_AFTER := 12.0
const MAX_ON_MAP := 2
const WEIGHTS := {"bomb": 45, "disco": 30, "snack": 25}

const BOMB_FUSE := 0.45
const BOMB_RADIUS := 130.0
const DISCO_TIME := 3.5

var _level: Level
var _player: Node2D
var _since_drop := 0.0
var _hp := 0
var _max_hp := 0


func setup(level: Level, player: Node2D) -> void:
	_level = level
	_player = player
	_since_drop = PITY_TIME - FIRST_DROP_AFTER
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.item_used.connect(_on_item_used)
	Events.player_hp_changed.connect(_on_hp_changed)


func _process(delta: float) -> void:
	if GameState.running:
		_since_drop += delta   # this node pauses with the game, so aiming doesn't count


func _on_hp_changed(hp: int, max_hp: int) -> void:
	_hp = hp
	_max_hp = max_hp


func _on_enemy_killed(enemy: Node) -> void:
	if not GameState.running or not (is_instance_valid(enemy) and enemy is Node2D) or _level == null:
		return
	if _count_on_map() >= MAX_ON_MAP:
		return
	if _since_drop < PITY_TIME and randf() >= DROP_CHANCE:
		return
	drop(_pick_kind(), (enemy as Node2D).global_position)


## Puts an item on the floor. Public so the smoke test can force one.
func drop(kind: String, at: Vector2) -> ItemDrop:
	_since_drop = 0.0
	var item := ItemDrop.new()
	item.kind = kind
	item.position = at
	# Deferred: kills can come from a physics callback, and adding an Area2D there fails
	_level.get_entities().add_child.call_deferred(item)
	Events.item_dropped.emit(kind, at)
	return item


func _count_on_map() -> int:
	var n := 0
	for child in _level.get_entities().get_children():
		if child is ItemDrop:
			n += 1
	return n


func _pick_kind() -> String:
	var weights := WEIGHTS.duplicate()
	if _hp >= _max_hp:
		weights.erase("snack")   # no burrito when you're full
	elif _hp * 2 <= _max_hp:
		weights["snack"] = 70    # comeback: low on hearts, burritos show up more
	var total := 0
	for k in weights:
		total += weights[k]
	var roll := randi() % total
	for k in weights:
		roll -= weights[k]
		if roll < 0:
			return k
	return "bomb"


func _on_item_used(kind: String, at: Vector2) -> void:
	match kind:
		"bomb":
			FloatText.spawn(_level, at + Vector2(0, -20), "PFFFT...", Color(0.6, 1.0, 0.4), 22, 18.0, 0.6)
			var burst := WhoopeeBurst.new()
			burst.radius = BOMB_RADIUS
			burst.fuse = BOMB_FUSE
			burst.position = at
			burst.exploded.connect(_on_bomb_exploded)
			_level.get_entities().add_child(burst)
		"disco":
			FloatText.spawn(_level, at + Vector2(0, -24), "DISCO TIME!", Color(1.0, 0.6, 1.0), 26, 30.0, 1.0)
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if enemy.has_method("dance"):
					enemy.dance(DISCO_TIME)
		"snack":
			FloatText.spawn(_level, at + Vector2(0, -24), "+1 HP  tastes purple", Color(1.0, 0.85, 0.4), 20, 30.0, 1.1)
			if is_instance_valid(_player) and _player.has_method("heal"):
				_player.heal(1)


func _on_bomb_exploded(at: Vector2) -> void:
	FloatText.spawn(_level, at + Vector2(0, -30), "BRRRAAAP!", Color(0.6, 1.0, 0.4), 34, 34.0, 0.9)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if (enemy as Node2D).global_position.distance_to(at) <= BOMB_RADIUS:
			enemy.take_damage(99)
	boom.emit(at)
