extends Control
## Exact amounts with separate value/unit typography. Never abbreviates or changes chips.
const UI = preload("res://scripts/ui/style.gd")
const Chips = preload("res://scripts/ui/chip_art.gd")
var amount: int = 0
var blind: int = 10
var use_bb: bool = true
var role: String = "stack"
var number_size: int = 22
var caption: String = "总底池"
var text: String = ""
var value_label: Label
var unit_label: Label
var caption_label: Label
var content_rect: Rect2

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label = UI.label("", number_size, UI.TEXT)
	unit_label = UI.label("", 11, UI.MUTED)
	caption_label = UI.label("", 13, UI.MUTED)
	for label in [value_label, unit_label, caption_label]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
	resized.connect(_arrange)
	theme_changed.connect(_arrange)
	_refresh()

func configure(kind: String, font_size: int) -> void:
	role = kind
	number_size = font_size
	custom_minimum_size.y = 60 if role == "pot" else 28 if role == "wager" else 44
	_refresh()

func set_amount(chips: int, big_blind: int, bb: bool) -> void:
	amount = chips
	blind = big_blind
	use_bb = bb
	_refresh()

static func grouped_number(chips: int, big_blind: int, bb: bool) -> String:
	var raw = UI.money(chips, big_blind, bb).trim_suffix(" BB")
	var parts = raw.split(".")
	var whole = parts[0]
	var grouped = ""
	for i in range(whole.length()):
		if i > 0 and (whole.length() - i) % 3 == 0: grouped += ","
		grouped += whole[i]
	return grouped + ("." + parts[1] if parts.size() > 1 else "")

func _refresh() -> void:
	text = UI.money(amount, blind, use_bb)
	if value_label == null: return
	value_label.text = grouped_number(amount, blind, use_bb)
	unit_label.text = "BB" if use_bb else "筹码"
	caption_label.text = caption
	tooltip_text = ("剩余筹码 " if role == "stack" else "本轮投入 " if role == "wager" else caption + " ") + text
	_arrange()

func _place(label: Label, at: Vector2, font_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.size = label.get_minimum_size()
	label.position = at

func _arrange() -> void:
	if value_label == null or size.x <= 0: return
	caption_label.visible = role == "pot"
	var font = value_label.get_theme_font("font")
	var unit_size = 13 if role == "pot" or number_size >= 26 else 12
	_place(unit_label, Vector2.ZERO, unit_size)
	var reserve = 0.0 if role == "stack" else unit_label.size.x + 34 if role == "wager" else unit_label.size.x + 48
	var actual_size = number_size
	while actual_size > 12 and font.get_string_size(value_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, actual_size).x > size.x - reserve:
		actual_size -= 1
	_place(value_label, Vector2.ZERO, actual_size)
	if role == "stack":
		var height = value_label.size.y + unit_label.size.y - 3
		var top = maxf(0, (size.y - height) / 2)
		value_label.position = Vector2((size.x - value_label.size.x) / 2, top)
		unit_label.position = Vector2((size.x - unit_label.size.x) / 2, top + value_label.size.y - 3)
		content_rect = Rect2(Vector2(0, top), Vector2(size.x, height))
	else:
		var width = value_label.size.x + unit_label.size.x + (32 if role == "wager" else 44)
		var start = maxf(0, (size.x - width) / 2)
		var top = 0.0 if role == "wager" else 20.0
		value_label.position = Vector2(start + (26 if role == "wager" else 36), top + (size.y - top - value_label.size.y) / 2)
		var baseline = value_label.position.y + font.get_ascent(actual_size)
		unit_label.position = Vector2(value_label.position.x + value_label.size.x + 4, baseline - unit_label.get_theme_font("font").get_ascent(unit_size))
		content_rect = Rect2(Vector2(start, top), Vector2(width, size.y - top))
		if role == "pot":
			_place(caption_label, Vector2.ZERO, 13)
			caption_label.position.x = (size.x - caption_label.size.x) / 2
	value_label.add_theme_color_override("font_color", UI.GOLD if role == "wager" else UI.TEXT)
	unit_label.add_theme_color_override("font_color", Color("c2b590") if role != "stack" else Color("9bb8b5"))
	queue_redraw()

func get_content_rect() -> Rect2:
	return content_rect

func _draw() -> void:
	if role == "stack": return
	if role == "wager":
		var style = UI.surface(Color("20362f"), 13, 0, Color("58644b"))
		style.set_border_width_all(1)
		draw_style_box(style, Rect2(Vector2.ZERO, size))
		Chips.draw_chip(self, Vector2(content_rect.position.x + 12, size.y / 2 + 2), 9, Color("a05e50"))
	else:
		var plaque = content_rect.grow_individual(7, 0, 7, 0)
		var style = UI.surface(Color("102e2a"), 12, 0, Color("50644c"))
		style.set_border_width_all(1)
		draw_style_box(style, plaque)
		var at = content_rect.position + Vector2(14, content_rect.size.y / 2 + 3)
		Chips.draw_chip(self, at + Vector2(-3, 0), 10, Color("457e82"), 2)
		Chips.draw_chip(self, at + Vector2(8, 3), 10, Color("b28a49"), 2)
