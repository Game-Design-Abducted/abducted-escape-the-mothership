extends Control
## Animated story / end-screen art. Fah's.
##
## Every node in the scene can move by itself (children of children too, so a
## trail parented under the spaceship follows it). Select a node, then in the
## Inspector (bottom: Metadata) set:
##   motion  = "bob" | "hop" | "pulse" | "glow" | "twinkle" | "blink" | "shake" | "flyaway"
##   amp     = how far in px (bob, hop, shake), or how much scale (pulse, e.g. 0.03)
##   speed   = how fast
##   phase   = start offset, so things don't move in sync
##   low     = lowest alpha (twinkle)
##   move    = Vector2 travel distance (flyaway)
## Nodes without "motion" stay still. The pivot you set in the Inspector is
## kept; nodes with no pivot scale around their centre.
##
## Use: story_screen.gd puts one of these behind the text for each page.

@export var fade_in := 0.5

## Default amp per motion, used when a node has no "amp" metadata.
const DEFAULT_AMP := {"pulse": 0.03}
const DEFAULT_AMP_PX := 6.0
const SHAKE_RATE := 12.0   # new shake offset this many times per second


class Item:
	var node: Control
	var kind: String
	var pos: Vector2
	var scale: Vector2
	var alpha: float
	var amp: float
	var speed: float
	var phase: float
	var low: float
	var move: Vector2
	var shake_tick := -1


var _items: Array[Item] = []
var _t := 0.0


func _ready() -> void:
	for n in find_children("*", "Control", true, false):
		if not n.has_meta("motion"):
			continue
		var it := Item.new()
		it.node = n
		it.kind = String(n.get_meta("motion"))
		it.pos = n.position
		it.scale = n.scale
		it.alpha = n.modulate.a
		it.amp = float(n.get_meta("amp", DEFAULT_AMP.get(it.kind, DEFAULT_AMP_PX)))
		it.speed = float(n.get_meta("speed", 1.0))
		it.phase = float(n.get_meta("phase", randf() * TAU))
		it.low = float(n.get_meta("low", 0.3))
		it.move = n.get_meta("move", Vector2.ZERO)
		if n.pivot_offset == Vector2.ZERO:
			n.pivot_offset = n.size / 2.0
		_items.append(it)
	if fade_in > 0.0:
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, fade_in)


func _process(delta: float) -> void:
	_t += delta
	for it in _items:
		var n := it.node
		var s := sin(_t * it.speed + it.phase)
		match it.kind:
			"bob":
				n.position.y = it.pos.y + s * it.amp
			"hop":
				n.position.y = it.pos.y - absf(s) * it.amp
			"pulse":
				n.scale = it.scale * (1.0 + s * it.amp)
			"glow":
				n.modulate.a = it.alpha * (0.65 + 0.35 * s)
			"twinkle":
				n.modulate.a = it.alpha * lerpf(it.low, 1.0, 0.5 + 0.5 * s)
			"blink":
				n.modulate.a = it.alpha if s > 0.0 else it.alpha * 0.15
			"shake":
				var tick := int(_t * SHAKE_RATE)
				if tick != it.shake_tick:
					it.shake_tick = tick
					n.position = it.pos + Vector2(randf_range(-it.amp, it.amp), randf_range(-it.amp, it.amp))
			"flyaway":
				var f := fmod(_t * it.speed + it.phase / TAU, 1.0)
				n.position = it.pos + it.move * f
				n.scale = it.scale * (1.0 - 0.7 * f)
				n.modulate.a = it.alpha * (1.0 - f * f)
