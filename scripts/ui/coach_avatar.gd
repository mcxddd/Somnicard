extends Button
## Native vector avatar, readable at mobile size, without a bitmap dependency.

func _ready() -> void:
	custom_minimum_size = Vector2(72, 78)
	tooltip_text = "打开 / 收起牌桌教练"
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	text = ""

func _draw() -> void:
	var at = Vector2(size.x / 2, 32)
	draw_circle(at + Vector2(0, 3), 31, Color(0, 0, 0, 0.3))
	draw_circle(at, 30, Color("d8bb7d"))
	draw_circle(at, 27, Color("204b48"))
	draw_circle(at + Vector2(0, -1), 19, Color("e7bd92"))
	draw_arc(at + Vector2(0, -2), 19, PI, TAU, 24, Color("29333b"), 9, true)
	for x in [-7, 7]:
		draw_circle(at + Vector2(x, 0), 5, Color("29333b"), false, 2, true)
		draw_circle(at + Vector2(x, 0), 1.5, Color("29333b"))
	draw_line(at + Vector2(-2, 0), at + Vector2(2, 0), Color("29333b"), 2, true)
	draw_arc(at + Vector2(0, 6), 6, 0.25, PI - 0.25, 16, Color("8f5749"), 2, true)
	draw_string(get_theme_default_font(), Vector2(at.x - 16, 76), "教练", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e9d7af"))
