class_name FloatText
extends Label
## Floating pop-up words ("SPLAT!", "PFFFT!", taunts). Ploy's.
##
##   FloatText.spawn(parent, global_pos, "SPLAT!", Color.YELLOW)
##
## Pops in, drifts up, fades out and frees itself. Runs while the game is
## paused too, so words started just before the laser freeze still finish.

const FONT := preload("res://assets/fonts/VT323.ttf")


static func spawn(parent: Node, at: Vector2, text: String, color := Color.WHITE,
		size := 20, rise := 26.0, seconds := 0.7) -> FloatText:
	var label := FloatText.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.0, 0.1))
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 50
	label.process_mode = Node.PROCESS_MODE_ALWAYS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	label.reset_size()
	label.pivot_offset = label.size / 2.0
	label.global_position = at - label.size / 2.0
	label.rotation = randf_range(-0.15, 0.15)
	label.scale = Vector2(0.3, 0.3)
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "position:y", label.position.y - rise, seconds).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, seconds * 0.5).set_delay(seconds * 0.5)
	tween.tween_callback(label.queue_free)
	return label
