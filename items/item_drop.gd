class_name ItemDrop
extends Area2D
## Space Junk item on the floor. Ploy's. layer 5, mask 2. drop_manager.gd does the effect.

const LIFETIME := 8.0        # seconds on the floor before it disappears
const BLINK_FROM := 2.5      # starts blinking this many seconds before that
const PIXEL := 3             # each art pixel is drawn this many screen pixels wide

const GLOW := {
	"bomb": Color(0.45, 1.0, 0.35),
	"disco": Color(0.95, 0.6, 1.0),
	"snack": Color(1.0, 0.8, 0.35),
}

static var _textures := {}   # kind -> ImageTexture, built once

var kind := "bomb"
var _age := 0.0
var _taken := false
var _sprite: Sprite2D


func _ready() -> void:
	collision_layer = 16
	collision_mask = 2
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 14.0
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = texture_for(kind)
	_sprite.scale = Vector2(PIXEL, PIXEL)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	z_index = 5
	body_entered.connect(_on_body_entered)
	scale = Vector2(0.2, 0.2)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_age += delta
	_sprite.position.y = sin(_age * 5.0) * 3.0 - 4.0
	_sprite.rotation = sin(_age * 3.0) * 0.12
	if _age > LIFETIME - BLINK_FROM:
		visible = fmod(_age * 8.0, 1.0) < 0.6
	if _age >= LIFETIME and not _taken:
		queue_free()
	queue_redraw()


func _draw() -> void:
	# Pulsing glow on the floor so it reads as "grab me"
	var glow: Color = GLOW.get(kind, Color.WHITE)
	var pulse := 0.5 + 0.5 * sin(_age * 6.0)
	draw_circle(Vector2(0, 6), 14.0 + pulse * 3.0, Color(glow, 0.18 + 0.12 * pulse))
	draw_circle(Vector2(0, 6), 8.0, Color(glow, 0.25))


func _on_body_entered(body: Node) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	Events.item_used.emit(kind, global_position)
	queue_free()


# ---------- placeholder pixel art (12 x 12), drawn from shapes ----------

static func texture_for(item_kind: String) -> Texture2D:
	if not _textures.has(item_kind):
		_textures[item_kind] = ImageTexture.create_from_image(_draw_art(item_kind))
	return _textures[item_kind]


static func _draw_art(item_kind: String) -> Image:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	for y in 12:
		for x in 12:
			img.set_pixel(x, y, _art_pixel(item_kind, x, y))
	return img


static func _art_pixel(item_kind: String, x: int, y: int) -> Color:
	match item_kind:
		"bomb":    # pink whoopee cushion with a nozzle on the right
			var inside := _in_ellipse(x, y, 5.0, 6.5, 4.8, 3.8)
			var nozzle := x >= 9 and y >= 7 and y <= 9
			if not (inside or nozzle):
				return Color(0, 0, 0, 0)
			var edge := not (_in_ellipse(x - 1, y, 5.0, 6.5, 4.8, 3.8) and _in_ellipse(x + 1, y, 5.0, 6.5, 4.8, 3.8)
					and _in_ellipse(x, y - 1, 5.0, 6.5, 4.8, 3.8) and _in_ellipse(x, y + 1, 5.0, 6.5, 4.8, 3.8))
			if nozzle and not inside:
				return Color(0.45, 0.08, 0.28) if (y == 7 or y == 9 or x == 11) else Color(1.0, 0.7, 0.82)
			if edge:
				return Color(0.45, 0.08, 0.28)
			if (x == 3 and y == 4) or (x == 4 and y == 4) or (x == 3 and y == 5):
				return Color(1, 1, 1)
			return Color(1.0, 0.45, 0.7) if y < 8 else Color(0.85, 0.3, 0.55)
		"disco":   # silver mirror ball on a string, with sparkles
			if x == 6 and y <= 1:
				return Color(0.2, 0.2, 0.25)
			if (x == 0 and y == 2) or (x == 11 and y == 3) or (x == 1 and y == 11):
				return Color(1, 1, 1)
			if not _in_ellipse(x, y, 5.5, 6.5, 4.6, 4.6):
				return Color(0, 0, 0, 0)
			if not _in_ellipse(x, y, 5.5, 6.5, 3.7, 3.7):
				return Color(0.25, 0.25, 0.35)
			if x == 4 and y == 4:
				return Color(1, 1, 1)
			return Color(0.85, 0.88, 0.95) if (x + y) % 2 == 0 else Color(0.55, 0.6, 0.75)
		"snack":   # burrito, wrapped, with filling peeking out of the top end
			var d := _dist_to_segment(Vector2(x, y), Vector2(2.5, 9.5), Vector2(8.5, 3.5))
			if d > 3.0:
				return Color(0, 0, 0, 0)
			var near_top := Vector2(x, y).distance_to(Vector2(8.5, 3.5)) < 2.6
			if d > 2.2:
				return Color(0.45, 0.25, 0.1)
			if near_top:
				return [Color(0.3, 0.8, 0.3), Color(0.9, 0.2, 0.15), Color(1.0, 0.85, 0.2)][(x + y) % 3]
			if (x + y) % 4 == 0:
				return Color(0.8, 0.6, 0.35)
			return Color(0.95, 0.8, 0.52)
	return Color(0, 0, 0, 0)


static func _in_ellipse(x: float, y: float, cx: float, cy: float, rx: float, ry: float) -> bool:
	var dx := (x - cx) / rx
	var dy := (y - cy) / ry
	return dx * dx + dy * dy <= 1.0


static func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)
