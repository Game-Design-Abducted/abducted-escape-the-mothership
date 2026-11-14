extends Node
## Ship pranks. Ploy's.
##
## Every 40 s or so the mothership's loudspeaker plays a prank on you for a few
## seconds. Keeps the minutes between lasers from feeling the same.
##   LIGHTS OUT         everything goes dark except a circle around you
##   FLOOR WAX DAY      you slide around instead of stopping
##   BALLOON PARTY      monsters puff up: bigger (easier to shoot) and slower
##   CONTROLS REVERSED  left is right (level 2 only, and shorter)
##
## A banner warns you WARNING_TIME before it starts and shows a bar while it
## lasts. This node pauses with the game, so aiming the laser doesn't count.
## game.gd calls setup(level, player).

const PRANKS := {
	"lights": {"title": "LIGHTS OUT", "joke": "someone sat on the light switch", "time": 8.0},
	"wax": {"title": "FLOOR WAX DAY", "joke": "the cleaning robot overdid it", "time": 7.0},
	"balloon": {"title": "BALLOON PARTY", "joke": "the monsters drank the helium", "time": 8.0},
	"reverse": {"title": "CONTROLS REVERSED", "joke": "the aliens rewired your boots", "time": 5.0},
}
const POOL := {
	1: ["lights", "wax", "balloon"],
	2: ["lights", "wax", "balloon", "reverse"],
}
const FIRST_AFTER := {1: 30.0, 2: 25.0}   ## seconds into the level before the first prank
const GAP_MIN := 32.0                     ## seconds between the end of one prank and the next warning
const GAP_MAX := 42.0
const WARNING_TIME := 1.6
const LIGHT_HOLE := 0.075                 ## clear circle around the player (fraction of the darkness texture)

const TITLE_FONT := preload("res://assets/fonts/Minecraft.ttf")
const BODY_FONT := preload("res://assets/fonts/VT323.ttf")
const SFX_ALARM := preload("res://assets/audio/sfx/timer_tick.wav")
const SFX_START := preload("res://assets/audio/sfx/monster_spawn.wav")
const YELLOW := Color(1, 0.82, 0)

var active := ""            ## the prank running right now ("" = none)
var _level: Node2D
var _player: Node2D
var _next := 0.0
var _warning := 0.0
var _left := 0.0
var _last := ""
var _dark: Sprite2D
var _banner: PanelContainer
var _title: Label
var _joke: Label
var _bar: ColorRect
var _sfx: AudioStreamPlayer


func setup(level: Node2D, player: Node2D) -> void:
	_level = level
	_player = player
	_next = FIRST_AFTER.get(GameState.current_level, 30.0)
	_build_banner()
	Events.enemy_spawned.connect(_on_enemy_spawned)
	Events.level_finished.connect(func(_won): stop())


func _process(delta: float) -> void:
	if not GameState.running or _level == null:
		return
	if _warning > 0.0:
		_warning -= delta
		if _warning <= 0.0:
			_begin()
	elif active != "":
		_left -= delta
		_bar.scale.x = clampf(_left / PRANKS[active]["time"], 0.0, 1.0)
		if is_instance_valid(_dark) and is_instance_valid(_player):
			_dark.global_position = _player.global_position
		if _left <= 0.0:
			stop()
	else:
		_next -= delta
		if _next <= 0.0:
			var pool: Array = POOL.get(GameState.current_level, POOL[1]).duplicate()
			pool.erase(_last)
			announce(pool.pick_random())


## Warn, then start `kind` WARNING_TIME later. Public so tests can force one.
func announce(kind: String) -> void:
	active = ""
	_last = kind
	_warning = WARNING_TIME
	_title.text = "ATTENTION HUMAN:  " + PRANKS[kind]["title"]
	_joke.text = PRANKS[kind]["joke"]
	_bar.scale.x = 1.0
	_banner.set_meta("kind", kind)
	_banner.show()
	_banner.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_banner, "modulate:a", 1.0, 0.2)
	for i in 3:
		get_tree().create_timer(i * 0.35, false).timeout.connect(_play.bind(SFX_ALARM, 0.7))


func _begin() -> void:
	active = _banner.get_meta("kind")
	_left = PRANKS[active]["time"]
	_play(SFX_START, 1.4)
	_set_effect(active, true)


## End the prank now (also when the level ends)
func stop() -> void:
	_warning = 0.0
	if active != "":
		_set_effect(active, false)
		_next = randf_range(GAP_MIN, GAP_MAX)
	active = ""
	if is_instance_valid(_banner) and _banner.visible:
		var tween := create_tween()
		tween.tween_property(_banner, "modulate:a", 0.0, 0.3)
		tween.tween_callback(_banner.hide)


func _set_effect(kind: String, on: bool) -> void:
	match kind:
		"lights":
			if on:
				_make_dark()
			elif is_instance_valid(_dark):
				var dark := _dark
				_dark = null
				var tween := dark.create_tween()
				tween.tween_property(dark, "modulate:a", 0.0, 0.4)
				tween.tween_callback(dark.queue_free)
		"wax":
			if is_instance_valid(_player) and "slippery" in _player:
				_player.slippery = on
		"reverse":
			if is_instance_valid(_player) and "controls_reversed" in _player:
				_player.controls_reversed = on
		"balloon":
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if enemy.has_method("balloon"):
					enemy.balloon(on)


func _on_enemy_spawned(enemy: Node) -> void:
	if active == "balloon" and enemy.has_method("balloon"):
		enemy.balloon.call_deferred(true)


func _make_dark() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, LIGHT_HOLE, LIGHT_HOLE * 1.9, 1.0])
	gradient.colors = PackedColorArray([Color(0, 0, 0.02, 0.0), Color(0, 0, 0.02, 0.0), Color(0, 0, 0.02, 0.93), Color(0, 0, 0.02, 0.95)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 256
	tex.height = 256
	_dark = Sprite2D.new()
	_dark.texture = tex
	_dark.scale = Vector2.ONE * 13.0   # 3300 px, covers the screen from anywhere
	_dark.z_index = 90                 # over the map and monsters, under the laser aim (100)
	_dark.global_position = _player.global_position if is_instance_valid(_player) else Vector2.ZERO
	_dark.modulate.a = 0.0
	_level.add_child(_dark)
	_dark.create_tween().tween_property(_dark, "modulate:a", 1.0, 0.4)


func _build_banner() -> void:
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)
	var layer := CanvasLayer.new()
	layer.layer = 15
	add_child(layer)
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
	holder.offset_top = 62
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(holder)
	_banner = PanelContainer.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.02, 0.1, 0.9)
	style.border_color = Color(1.0, 0.3, 0.3)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 6
	style.content_margin_bottom = 8
	_banner.add_theme_stylebox_override("panel", style)
	holder.add_child(_banner)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_banner.add_child(box)
	_title = _label(TITLE_FONT, 22, YELLOW)
	box.add_child(_title)
	_joke = _label(BODY_FONT, 22, Color(1, 1, 1, 0.85))
	box.add_child(_joke)
	var track := ColorRect.new()
	track.color = Color(0, 0, 0, 0.5)
	track.custom_minimum_size = Vector2(0, 5)
	box.add_child(track)
	_bar = ColorRect.new()
	_bar.color = Color(1.0, 0.35, 0.35)
	_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	track.add_child(_bar)
	_banner.hide()


func _label(font: Font, size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _play(stream: AudioStream, pitch := 1.0) -> void:
	_sfx.stream = stream
	_sfx.pitch_scale = pitch
	_sfx.play()
