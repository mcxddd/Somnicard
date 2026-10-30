extends PanelContainer
signal tapped
const UI = preload("res://scripts/ui/style.gd")
var label: Label
var target = Vector2.ZERO

func _ready() -> void:
	add_theme_stylebox_override("panel", UI.surface(Color("eee8d9"), 15, 12, Color("91bfb0")))
	label = UI.label("", 18, Color("153c36"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			accept_event()
			tapped.emit())
	hide()

func set_text(text: String, width: float) -> void:
	# Give wrapping a real width before asking for height; a zero-width label
	# otherwise measures one glyph per line while the panel is still hidden.
	label.custom_minimum_size.x = width - 24
	label.size.x = width - 24
	label.text = text.left(36)
	var height = label.get_minimum_size().y + 24
	size = Vector2(width, maxf(52, height))

func aim(at: Vector2) -> void:
	target = at - position
	queue_redraw()

func _draw() -> void:
	if not visible: return
	var start = target.clamp(Vector2(14, 14), size - Vector2(14, 14))
	var direction = (target - start).normalized()
	var side = direction.orthogonal() * 7
	draw_colored_polygon(PackedVector2Array([start + side, target, start - side]), Color("eee8d9"))
