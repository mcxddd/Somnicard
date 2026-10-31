extends Control
## Resolution-independent original card artwork. Negative IDs never contain hidden cards.
const UI = preload("res://scripts/ui/style.gd")
const RANKS = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
const SUITS = ["♠", "♥", "♦", "♣"]
const BACK = preload("res://assets/art/card-back.png")
var card_id: int = -2
var four_color: bool = false
var motion: bool = true
var reveal: float = 1.0
var animation: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func set_card(value: int, colors: bool = false, animate: bool = true) -> void:
	var changed = card_id != value
	card_id = value
	four_color = colors
	if animation != null: animation.kill()
	reveal = 1.0
	if changed and value >= 0 and motion and animate and is_inside_tree():
		reveal = 0.0
		animation = create_tween()
		animation.tween_method(func(progress): reveal = progress; queue_redraw(), 0.0, 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	queue_redraw()

func ink() -> Color:
	if card_id < 0: return UI.GOLD
	var suit: int = int(card_id / 13)
	if four_color: return [Color("203447"), Color("b63e50"), Color("2062a3"), Color("16704d")][suit]
	return Color("b63e50") if suit in [1, 2] else Color("203447")

func _draw() -> void:
	var rect = Rect2(Vector2(1, 1 + 5 * (1 - reveal)), size - Vector2(2, 3))
	var font = get_theme_default_font()
	var small = size.x < 46
	if card_id == -2:
		# Undealt community cards are guides, not five competing solid panels.
		var empty = UI.surface(Color.TRANSPARENT, 5, 0, Color(0.50, 0.68, 0.62, 0.20))
		empty.set_border_width_all(1)
		draw_style_box(empty, rect)
		return
	var style = UI.surface(Color("f4efe3") if card_id >= 0 else Color("142e40"), 5 if small else 8, 0, Color("d5c9ad") if card_id >= 0 else Color("47606b"))
	style.set_border_width_all(1)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 3
	style.shadow_offset = Vector2(1, 3)
	draw_style_box(style, rect)
	if card_id == -1:
		draw_texture_rect(BACK, rect, false)
		return
	var color = ink()
	var rank = RANKS[card_id % 13]
	var suit = SUITS[int(card_id / 13)]
	var rank_size = maxi(14, int(size.x * 0.31))
	draw_string(font, Vector2(5, rank_size + 1), rank, HORIZONTAL_ALIGNMENT_LEFT, -1, rank_size, color)
	if small:
		_center(font, suit, Vector2(size.x * 0.60, size.y * 0.83), int(size.x * 0.64), color)
	else:
		draw_string(font, Vector2(5, rank_size + 16), suit, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
		_center(font, suit, Vector2(size.x * 0.56, size.y * 0.68), int(size.x * 0.63), color)
		var width = font.get_string_size(rank, HORIZONTAL_ALIGNMENT_LEFT, -1, rank_size).x
		draw_string(font, Vector2(size.x - width - 5, size.y - 6), rank, HORIZONTAL_ALIGNMENT_LEFT, -1, rank_size, color)

func _center(font: Font, text: String, at: Vector2, font_size: int, color: Color) -> void:
	var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, at - Vector2(width / 2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
