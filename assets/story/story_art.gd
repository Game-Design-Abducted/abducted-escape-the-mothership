extends Control
## Animated story / end-screen art. Fah's.
##
## Every child can move by itself. Select a node, then in the Inspector
## (bottom: Metadata) set:
##   motion  = "bob" | "hop" | "pulse" | "glow" | "twinkle" | "blink" | "shake" | "flyaway"
##   amp     = how far (px) or how much (scale, for pulse)
##   speed   = how fast
##   phase   = start offset, so things don't move in sync
##   low     = lowest alpha (twinkle)
##   move    = Vector2 travel distance (flyaway)
## Nodes without "motion" stay still.
##
## Use: instance this scene behind the text (story_screen / end_screen).

@export var fade_in := 0.5

var _items: Array = []
var _t := 0.0


func _ready() -> void:
	for n in get_children():
		if n is Control and n.has_meta("motion"):
			n.pivot_offset = n.size / 2.0
			_items.append({
				"node": n, "kind": String(n.get_meta("motion")),
				"pos": n.position, "scale": n.scale, "alpha": n.modulate.a,
				"amp": float(n.get_meta("amp", 6.0)), "speed": float(n.get_meta("speed", 1.0)),
				"phase": float(n.get_meta("phase", randf() * TAU)), "low": float(n.get_meta("low", 0.3)),
				"move": n.get_meta("move", Vector2.ZERO),
			})
	if fade_in > 0.0:
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, fade_in)


func _process(delta: float) -> void:
	_t += delta
	for it in _items:
		var n: Control = it.node
		var s: float = sin(_t * it.speed + it.phase)
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
				n.modulate.a = lerpf(it.low, 1.0, 0.5 + 0.5 * s)
			"blink":
				n.modulate.a = 1.0 if s > 0.0 else 0.15
			"shake":
				if int(_t * 12.0) % 2 == 0:
					n.position = it.pos + Vector2(randf_range(-it.amp, it.amp), randf_range(-it.amp, it.amp))
			"flyaway":
				var f: float = fmod(_t * it.speed + it.phase / TAU, 1.0)
				n.position = it.pos + it.move * f
				n.scale = it.scale * (1.0 - 0.7 * f)
				n.modulate.a = 1.0 - f * f
