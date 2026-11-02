extends Button
## A square button with a simple glyph drawn in code. `text` keeps the action's name
## (drawn transparent) for tooltips, accessibility and tests.
const UI = preload("res://scripts/ui/style.gd")
var glyph: String = "more":
	set(value):
		glyph = value
		queue_redraw()

func _draw() -> void:
	var ink = UI.MUTED.darkened(0.3) if disabled else UI.TEXT
	var middle = size / 2 + (Vector2(0, 2) if get_draw_mode() == DRAW_PRESSED else Vector2.ZERO)
	var unit = minf(size.x, size.y) * 0.18
	match glyph:
		"pause":
			for dx in [-0.55, 0.55]:
				draw_rect(Rect2(middle + Vector2(dx * unit - unit * 0.28, -unit), Vector2(unit * 0.56, unit * 2)), ink)
		"play":
			draw_colored_polygon(PackedVector2Array([middle + Vector2(-unit * 0.7, -unit), middle + Vector2(unit, 0), middle + Vector2(-unit * 0.7, unit)]), ink)
		"more":
			for dx in [-1.0, 0.0, 1.0]: draw_circle(middle + Vector2(dx * unit * 1.05, 0), unit * 0.3, ink)
		"close":
			for sign in [-1.0, 1.0]:
				draw_line(middle + Vector2(-unit, -unit * sign), middle + Vector2(unit, unit * sign), ink, 2.5, true)
		"back":
			draw_polyline(PackedVector2Array([middle + Vector2(unit * 0.4, -unit), middle + Vector2(-unit * 0.5, 0), middle + Vector2(unit * 0.4, unit)]), ink, 2.5, true)
