extends Control
const UI = preload("res://scripts/ui/style.gd")
var text: String = "S"
var tint: Color = UI.GOLD

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var middle = size / 2
	var radius = minf(size.x, size.y) / 2 - 2
	draw_circle(middle + Vector2(0, 2), radius, Color(0, 0, 0, 0.3))
	draw_circle(middle, radius, tint.darkened(0.65))
	draw_arc(middle, radius - 1, 0, TAU, 40, tint, 1.5, true)
	for i in range(8):
		var direction = Vector2.from_angle(i * TAU / 8)
		draw_line(middle + direction * (radius - 3), middle + direction * (radius - 1), tint, 2, true)
	var font = get_theme_default_font()
	var font_size = maxi(10, int(radius * (0.80 if text.length() > 1 else 1.12)))
	var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, middle + Vector2(-width / 2, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UI.TEXT)
