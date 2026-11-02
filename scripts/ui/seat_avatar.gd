extends Control
## A computer opponent's round portrait. Uses res://assets/art/avatars/<slug>.png when
## present; otherwise the first character of the name on the seat's accent colour.
const UI = preload("res://scripts/ui/style.gd")
## Seat 1..8, in the same order as PlayerNames.DEFAULTS.
const SLUGS = ["xiaoxia", "alan", "milo", "qinghe", "noah", "chengzi", "ache", "xingye"]
const ACCENTS = [Color("f28c6b"), Color("7fa7c9"), Color("a08bd8"), Color("7cd7b7"), Color("4fb3b0"), Color("f2a63b"), Color("e0697a"), Color("5b6fc7")]
var seat: int = 1
var initial: String = ""
var texture: Texture2D
var active: bool = false:
	set(value):
		if active == value: return
		active = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func setup(seat_id: int, name_text: String) -> void:
	seat = seat_id
	initial = name_text.left(1)
	var path = "res://assets/art/avatars/%s.png" % SLUGS[(seat - 1) % SLUGS.size()]
	texture = load(path) if ResourceLoader.exists(path) else null
	queue_redraw()

func accent() -> Color:
	return ACCENTS[(seat - 1) % ACCENTS.size()]

func _draw() -> void:
	var middle = size / 2
	var radius = minf(size.x, size.y) / 2 - 1
	draw_circle(middle, radius, UI.GOLD if active else accent().darkened(0.15))
	draw_circle(middle, radius - 2, accent().darkened(0.62))
	if texture != null:
		# Portraits are square with the face in the upper part; show it inside the ring.
		var inner = (radius - 3) * 2
		draw_texture_rect(texture, Rect2(middle - Vector2(inner, inner) / 2, Vector2(inner, inner)), false)
		return
	var font = get_theme_default_font()
	var font_size = maxi(10, int(radius * 1.05))
	var width = font.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, middle + Vector2(-width / 2, font_size * 0.36), initial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, accent().lightened(0.35))
