extends Button
## The sleepy-card coach. Shows a thinking pose while an analysis is running.
const IDLE = preload("res://assets/art/coach.png")
const THINKING = preload("res://assets/art/coach-thinking.png")
var thinking: bool = false:
	set(value):
		if thinking == value: return
		thinking = value
		queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(72, 78)
	tooltip_text = "打开 / 收起牌桌教练"
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	text = ""

func _draw() -> void:
	var at = Vector2(size.x / 2, 30)
	draw_circle(at + Vector2(0, 3), 31, Color(0, 0, 0, 0.3))
	draw_circle(at, 30, Color("d8bb7d"))
	draw_circle(at, 28, Color("204b48"))
	# The circle is small, so show the upper body where the glasses and expression are.
	var texture: Texture2D = THINKING if thinking else IDLE
	var source = Rect2(0, 0, texture.get_width(), texture.get_height() * 0.66)
	var height = 44.0
	var width = height * source.size.x / source.size.y
	draw_texture_rect_region(texture, Rect2(at - Vector2(width / 2, height / 2 + 2), Vector2(width, height)), source)
	draw_string(get_theme_default_font(), Vector2(at.x - 16, 76), "教练", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e9d7af"))
