class_name TouchControls
extends CanvasLayer
## On-screen controls for phones and tablets. Ploy's. game.gd adds one to every level.
## left half = floating joystick, right half = hold to shoot, any tap fires the laser, II button pauses.
## It only presses the normal input actions, so player.gd and the laser modes don't know it exists.

## true while the player is using a touch screen. the title, story, HUD and controls card read it for their wording
static var active := OS.has_feature("web_android") or OS.has_feature("web_ios") \
		or OS.has_feature("android") or OS.has_feature("ios")

const BODY_FONT := preload("res://assets/fonts/VT323.ttf")
const YELLOW := Color(1, 0.82, 0)
const SCREEN := Vector2(1280, 720)
const STICK_HOME := Vector2(150, 560)    ## where the joystick rests when no thumb is down
const STICK_RADIUS := 85.0               ## thumb travel for full speed, px
const STICK_DEADZONE := 0.18
const SHOOT_HOME := Vector2(1125, 565)
const SHOOT_RADIUS := 78.0
const PAUSE_RECT := Rect2(1198, 62, 66, 66)
const MOVE_ACTIONS := ["move_left", "move_right", "move_up", "move_down"]

var pause_menu: PauseMenu   ## set by game.gd

var _stick_touch := -1          # finger index on the joystick, -1 = none
var _stick_origin := STICK_HOME
var _stick := Vector2.ZERO      # -1..1 on each axis
var _shoot_touch := -1
var _fire_touches := {}         # fingers that pressed "fire the laser" and haven't lifted yet
var _aiming := false            # a laser mini-game is on screen
var _pad: Node2D


## Call from any screen's input function: switches the wording to touch on the first tap, back on the first key
static func watch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		active = true
	elif event is InputEventKey and event.pressed:
		active = false


## "Press SPACE when ..." -> "TAP when ..." on a touch screen
static func words(text: String) -> String:
	if not active:
		return text
	return text.replace("Press SPACE", "TAP").replace("HOLD SPACE", "HOLD").replace("Press any key", "Tap")


func _ready() -> void:
	layer = 25   # over the HUD and prank banners, under the pause menu (30)
	process_mode = Node.PROCESS_MODE_ALWAYS   # the laser mini-games run while the tree is paused
	_pad = Node2D.new()
	_pad.draw.connect(_draw_pad)
	add_child(_pad)
	Events.laser_mode_started.connect(func(_mode: String, _how: String): _aiming = true)
	Events.laser_fired.connect(func(_hit: bool): _aiming = false)
	Events.level_finished.connect(func(_won: bool): _let_go())


func _exit_tree() -> void:
	_let_go()   # never leave a move key held for the next scene


func _process(_delta: float) -> void:
	_pad.visible = active and GameState.running and not PauseMenu.open
	if _pad.visible:
		_pad.queue_redraw()


func _input(event: InputEvent) -> void:
	watch(event)
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
	elif event is InputEventScreenDrag:
		if event.index == _stick_touch:
			_move_stick(event.position)
	elif event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION and _playing():
		# Godot also turns the first finger into a mouse click, which is "fire_laser". we send our own, so drop it
		get_viewport().set_input_as_handled()


## in a level, with no menu in the way
func _playing() -> bool:
	return GameState.running and not PauseMenu.open


func _touch_down(index: int, at: Vector2) -> void:
	if not _playing():
		return   # the pause menu's buttons get the tap
	if PAUSE_RECT.grow(14).has_point(at):
		if pause_menu:
			pause_menu.pause()
		return
	if _aiming:
		_fire_touches[index] = true
		_send_fire(true)
	elif at.x < SCREEN.x * 0.5:
		if _stick_touch == -1:
			_stick_touch = index
			# the stick appears under the thumb, kept on screen
			_stick_origin = at.clamp(Vector2(STICK_RADIUS, 150), Vector2(SCREEN.x * 0.5 - STICK_RADIUS, SCREEN.y - STICK_RADIUS))
			_move_stick(at)
	elif _shoot_touch == -1:
		_shoot_touch = index
		Input.action_press("attack")


func _touch_up(index: int) -> void:
	if index == _stick_touch:
		_stick_touch = -1
		_set_stick(Vector2.ZERO)
	elif index == _shoot_touch:
		_shoot_touch = -1
		Input.action_release("attack")
	elif _fire_touches.erase(index):
		_send_fire(false)


func _move_stick(at: Vector2) -> void:
	_set_stick(((at - _stick_origin) / STICK_RADIUS).limit_length(1.0))


func _set_stick(value: Vector2) -> void:
	_stick = value
	var push := value if value.length() >= STICK_DEADZONE else Vector2.ZERO
	var strengths := [-push.x, push.x, -push.y, push.y]   # same order as MOVE_ACTIONS
	for i in MOVE_ACTIONS.size():
		if strengths[i] > 0.0:
			Input.action_press(MOVE_ACTIONS[i], strengths[i])
		else:
			Input.action_release(MOVE_ACTIONS[i])


## a real input event, because the laser modes listen in _unhandled_input (Input.action_press sends none)
func _send_fire(pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = "fire_laser"
	event.pressed = pressed
	Input.parse_input_event(event)


func _let_go() -> void:
	_stick_touch = -1
	_shoot_touch = -1
	_fire_touches.clear()
	_stick = Vector2.ZERO
	for action: String in MOVE_ACTIONS + ["attack"]:
		Input.action_release(action)


func _draw_pad() -> void:
	_draw_pause()
	if _aiming:
		_pad.draw_string(BODY_FONT, Vector2(0, 690), "TAP ANYWHERE TO FIRE", HORIZONTAL_ALIGNMENT_CENTER, SCREEN.x, 30, Color(1, 1, 1, 0.7))
		return
	var held := _stick_touch != -1
	var base := _stick_origin if held else STICK_HOME
	_pad.draw_circle(base, STICK_RADIUS, Color(1, 1, 1, 0.10 if held else 0.06))
	_pad.draw_arc(base, STICK_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.45 if held else 0.25), 3.0, true)
	_pad.draw_circle(base + _stick * STICK_RADIUS, 36.0, Color(YELLOW, 0.75 if held else 0.35))

	var shooting := _shoot_touch != -1
	_pad.draw_circle(SHOOT_HOME, SHOOT_RADIUS, Color(1.0, 0.35, 0.3, 0.55 if shooting else 0.25))
	_pad.draw_arc(SHOOT_HOME, SHOOT_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.8 if shooting else 0.4), 3.0, true)
	_pad.draw_string(BODY_FONT, SHOOT_HOME + Vector2(-SHOOT_RADIUS, 11), "SHOOT", HORIZONTAL_ALIGNMENT_CENTER, SHOOT_RADIUS * 2.0, 34, Color(1, 1, 1, 0.9 if shooting else 0.6))


func _draw_pause() -> void:
	_pad.draw_rect(PAUSE_RECT, Color(0.16, 0.0, 0.3, 0.6))
	_pad.draw_rect(PAUSE_RECT, Color(YELLOW, 0.6), false, 2.0)
	var bar := Vector2(10, 30)
	var mid := PAUSE_RECT.get_center()
	_pad.draw_rect(Rect2(mid + Vector2(-16, -15), bar), Color(1, 1, 1, 0.85))
	_pad.draw_rect(Rect2(mid + Vector2(6, -15), bar), Color(1, 1, 1, 0.85))
