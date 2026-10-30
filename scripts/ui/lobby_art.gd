extends Control
const Card = preload("res://scripts/ui/card_view.gd")
const UI = preload("res://scripts/ui/style.gd")
var cards: Array = []

func _ready() -> void:
	custom_minimum_size = Vector2(300, 265)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for value in [49, 24, 12]:
		var card = Card.new()
		card.card_id = value
		card.motion = false
		card.size = Vector2(104, 148)
		card.pivot_offset = card.size / 2
		add_child(card)
		cards.append(card)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	for i in range(cards.size()):
		cards[i].position = size / 2 - cards[i].size / 2 + Vector2((i - 1) * 63, abs(i - 1) * 15)
		cards[i].rotation = (i - 1) * 0.19
	queue_redraw()

func _draw() -> void:
	var center = size / 2
	for radius in [106, 122, 135]: draw_arc(center, radius, 0, TAU, 100, Color(0.85, 0.73, 0.48, 0.12), 1, true)
	for i in range(24):
		var direction = Vector2.from_angle(i * TAU / 24)
		draw_line(center + direction * 128, center + direction * 132, Color(0.85, 0.73, 0.48, 0.3), 2, true)
