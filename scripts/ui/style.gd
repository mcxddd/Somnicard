extends RefCounted
const TEXT = Color("eee9dc")
const MUTED = Color("97aaa8")
const GOLD = Color("e5c17a")
const GREEN = Color("237766")
const BACKGROUND = Color("0a111b")
const PANEL = Color("15232d")
const BORDER = Color("30444d")
const BLUE = Color("70a8df")
## Colour roles: TEXT for content, MUTED for supporting text, GOLD only for section
## headings and the one key number on a card, GREEN for the primary action.
const SUCCESS = Color("7cd7b7")
const DANGER = Color("f2a3a9")
const CARD = Color("142a32")
const HERO = Color("163c37")
const INSET = Color("10222a")
## Type scale. Pages use these four sizes instead of ad-hoc ones.
const SIZE_TITLE = 28
const SIZE_HEADING = 21
const SIZE_BODY = 19
const SIZE_CAPTION = 15
## Interface motion (press feedback, page fades). Main turns it off with the
## "牌局动效" preference and in power-saving mode.
static var motion: bool = true

static func surface(color: Color, radius: int = 12, padding: int = 12, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	style.border_color = border
	style.set_border_width_all(2 if border.a > 0 else 0)
	return style

static func make_theme(mobile: bool) -> Theme:
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	# Android shapes "BB。" as one Latin run in Roboto, which has no CJK punctuation;
	# an explicit CJK fallback fills those glyphs instead of tofu boxes.
	var cjk = SystemFont.new()
	cjk.font_names = PackedStringArray(["Noto Sans CJK SC", "Noto Sans SC", "Microsoft YaHei"])
	font.fallbacks = [cjk]
	var result = Theme.new()
	result.default_font = font
	result.default_font_size = 21 if mobile else 18
	for type in ["OptionButton", "LineEdit", "PopupMenu", "TabContainer"]:
		result.set_color("font_color", type, TEXT)
		result.set_color("font_hover_color", type, TEXT)
		result.set_color("font_focus_color", type, TEXT)
		result.set_color("font_disabled_color", type, MUTED.darkened(0.15))
	for type in ["OptionButton", "LineEdit"]:
		result.set_stylebox("normal", type, surface(Color("0e1a24"), 8, 12, BORDER))
		result.set_stylebox("hover", type, surface(PANEL.lightened(0.06), 8, 12, GOLD.darkened(0.4)))
		result.set_stylebox("focus", type, surface(Color.TRANSPARENT, 8, 12, GOLD))
		result.set_stylebox("disabled", type, surface(Color("121d26"), 8, 12))
	result.set_stylebox("panel", "PopupMenu", surface(PANEL, 10, 12, BORDER))
	result.set_stylebox("hover", "PopupMenu", surface(GREEN.darkened(0.3), 6, 10))
	result.set_constant("v_separation", "PopupMenu", 20)
	result.set_stylebox("slider", "HSlider", surface(Color("30424b"), 5, 5))
	result.set_stylebox("grabber_area", "HSlider", surface(GOLD.darkened(0.2), 5, 5))
	result.set_stylebox("grabber_area_highlight", "HSlider", surface(GOLD, 5, 5))
	# A thumb-sized round grabber; the default one is a few pixels wide.
	for state in ["grabber", "grabber_highlight"]:
		result.set_icon(state, "HSlider", _knob(30, GOLD if state == "grabber" else GOLD.lightened(0.2)))
	result.set_stylebox("panel", "TooltipPanel", surface(PANEL, 8, 12, BORDER))
	result.set_color("font_color", "TooltipLabel", TEXT)
	return result

static func _knob(diameter: int, color: Color) -> ImageTexture:
	var image = Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var middle = (diameter - 1) / 2.0
	for y in range(diameter):
		for x in range(diameter):
			var distance = Vector2(x - middle, y - middle).length()
			var edge = clampf(middle - distance + 0.5, 0, 1)
			var fill = color if distance < middle - 3 else BACKGROUND.lightened(0.85)
			image.set_pixel(x, y, Color(fill, edge))
	return ImageTexture.create_from_image(image)

## A 56×32 on/off switch for CheckButton: green track with the knob right when on.
static func switch_icon(on: bool) -> ImageTexture:
	var w = 56
	var h = 32
	var image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var track = GREEN.lightened(0.1) if on else Color("2c3f47")
	var knob_x = w - h / 2.0 if on else h / 2.0
	for y in range(h):
		for x in range(w):
			var px = Vector2(x + 0.5, y + 0.5)
			var nearest = Vector2(clampf(px.x, h / 2.0, w - h / 2.0), h / 2.0)
			var inside = clampf(h / 2.0 - px.distance_to(nearest) + 0.5, 0, 1)
			var knob = clampf(h / 2.0 - 4 - px.distance_to(Vector2(knob_x, h / 2.0)) + 0.5, 0, 1)
			var color = track.lerp(TEXT, knob)
			image.set_pixel(x, y, Color(color, inside))
	return ImageTexture.create_from_image(image)

static func panel(color: Color, radius: int = 12, padding: int = 12) -> PanelContainer:
	var node := PanelContainer.new()
	var style = surface(color, radius, padding, Color("30434a"))
	style.set_border_width_all(1)
	style.shadow_color = Color(0, 0, 0, 0.18)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	node.add_theme_stylebox_override("panel", style)
	return node

## Card surfaces: "hero" for the one main card on a page, "card" for ordinary
## groups, "inset" for content nested inside another card.
static func card(kind: String = "card") -> PanelContainer:
	if kind == "hero": return panel(HERO, 20, 20)
	if kind == "inset":
		var node := PanelContainer.new()
		node.add_theme_stylebox_override("panel", surface(INSET, 10, 12))
		return node
	return panel(CARD, 14, 16)

static func _wrapped(text: String, size: int, color: Color) -> Label:
	var node = label(text, size, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node

static func title(text: String) -> Label: return _wrapped(text, SIZE_TITLE, TEXT)
static func heading(text: String) -> Label: return _wrapped(text, SIZE_HEADING, GOLD)
static func body(text: String) -> Label: return _wrapped(text, SIZE_BODY, TEXT)
static func caption(text: String) -> Label: return _wrapped(text, SIZE_CAPTION, MUTED)

## The single most important action on a screen.
static func primary(text: String, callback: Callable, height: int = 60) -> Button:
	var node = button(text, callback, GREEN, height)
	node.add_theme_font_size_override("font_size", 22)
	return node

static func secondary(text: String, callback: Callable, height: int = 52) -> Button:
	return button(text, callback, Color("1d343e"), height)

## Square icon button drawn in code (see icon_button.gd): pause, play, more, close, back.
static func icon_button(glyph: String, text: String, callback: Callable, size: int = BUTTON_S) -> Button:
	var node = load("res://scripts/ui/icon_button.gd").new()
	node.text = text
	node.glyph = glyph
	node.tooltip_text = text
	node.custom_minimum_size = Vector2(size, size)
	node.pressed.connect(callback)
	paint(node, Color("1d343e"))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		node.add_theme_color_override(state, Color.TRANSPARENT)
	press_feedback(node)
	return node

## A navigation row: optional icon, title, one line of supporting text and a chevron.
static func entry(title_text: String, subtitle: String, callback: Callable, icon_name: String = "", vertical: bool = false) -> Button:
	var node = load("res://scripts/ui/entry_button.gd").new()
	node.setup(title_text, subtitle, icon_name, vertical)
	node.pressed.connect(callback)
	return node

## One figure: a large value with a small label underneath.
static func stat(value: String, caption_text: String, tint := TEXT) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_constant_override("separation", 2)
	node.add_child(label(value, 26, tint, true))
	node.add_child(label(caption_text, SIZE_CAPTION, MUTED, true))
	return node

## Equal-width figures on an inset card. Items are [value, label] or [value, label, colour].
static func stat_row(items: Array) -> PanelContainer:
	var holder = card("inset")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	holder.add_child(row)
	for item in items: row.add_child(stat(item[0], item[1], item[2] if item.size() > 2 else TEXT))
	return holder

## A thin bar for a 0–1 rate; the fill is green.
static func progress(rate: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 1
	bar.step = 0.001
	bar.value = clampf(rate, 0, 1)
	bar.show_percentage = false
	bar.custom_minimum_size.y = 6
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", surface(Color("223840"), 3, 0))
	bar.add_theme_stylebox_override("fill", surface(GREEN.lightened(0.15), 3, 0))
	return bar

## Icons live in res://assets/icons/<name>.png; a missing icon is simply left out.
static func icon(name: String, size: float) -> TextureRect:
	var path = "res://assets/icons/%s.png" % name
	if name.is_empty() or not ResourceLoader.exists(path): return null
	var node = art(load(path), size)
	node.custom_minimum_size.x = size
	return node

## A centred illustration that keeps its aspect ratio within the given height.
static func art(texture: Texture2D, height: float) -> TextureRect:
	var node := TextureRect.new()
	node.texture = texture
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.custom_minimum_size.y = height
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func label(text: String, size: int = 18, color := TEXT, centered: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	if centered:
		node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return node

## Button sizes. Any requested height snaps to one of these, except the large
## table action buttons (64 and above), so a screen never mixes many sizes.
const BUTTON_S = 44
const BUTTON_M = 50
const BUTTON_L = 58
const BUTTON_RADIUS = 12
## Table actions: call is the bright green, raise a light gold with dark text, all-in red.
const ACTION_CALL = Color("2a8f78")
const ACTION_RAISE = Color("d9b36a")
const ACTION_ALL_IN = Color("b84f5d")

static func _snap_height(height: int) -> int:
	if height >= 64: return height
	if height < 47: return BUTTON_S
	if height < 54: return BUTTON_M
	return BUTTON_L

## Solid button. GREEN gives the primary style; other fills are secondary.
## A thicker darker bottom edge gives depth; pressing sinks it and shifts the text.
static func button(text: String, callback: Callable, color := Color("1d343e"), height: int = 48) -> Button:
	var node := Button.new()
	node.text = text
	height = _snap_height(height)
	node.custom_minimum_size = Vector2(64, height)
	node.pressed.connect(callback)
	paint(node, color)
	node.add_theme_font_size_override("font_size", 16 if height == BUTTON_S else 18 if height == BUTTON_M else 20)
	press_feedback(node)
	return node

## (Re)style a button as a solid fill. Light fills get dark text.
static func paint(node: Button, color: Color) -> void:
	var light = color.get_luminance() > 0.5
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fill = color
		if state == "hover": fill = color.lightened(0.07)
		if state == "pressed": fill = color.darkened(0.08)
		if state == "disabled": fill = color.lerp(BACKGROUND, 0.6)
		var style = surface(fill, BUTTON_RADIUS, 12)
		style.border_color = fill.darkened(0.45)
		style.border_width_bottom = 0 if state == "disabled" else 1 if state == "pressed" else 3
		if state == "pressed": style.content_margin_top += 2
		node.add_theme_stylebox_override(state, style)
	_focus(node)
	var ink = BACKGROUND if light else TEXT
	node.add_theme_color_override("font_color", ink)
	node.add_theme_color_override("font_hover_color", ink if light else Color.WHITE)
	node.add_theme_color_override("font_pressed_color", ink)
	node.add_theme_color_override("font_focus_color", ink)
	node.add_theme_color_override("font_disabled_color", MUTED.darkened(0.35))

## Transparent with a thin border: back, close and cancel.
static func outline(text: String, callback: Callable, height: int = 48) -> Button:
	var node = button(text, callback, PANEL, height)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style = surface(Color(1, 1, 1, [0.02, 0.06, 0.1, 0.0][["normal", "hover", "pressed", "disabled"].find(state)]), BUTTON_RADIUS, 12, BORDER.lightened(0.15) if state != "disabled" else BORDER.darkened(0.2))
		style.set_border_width_all(1)
		node.add_theme_stylebox_override(state, style)
	node.add_theme_color_override("font_color", TEXT)
	node.add_theme_color_override("font_pressed_color", TEXT)
	node.add_theme_color_override("font_focus_color", TEXT)
	return node

## Text only, for small inline actions such as "完整分析 ›".
static func link(text: String, callback: Callable) -> Button:
	var node = button(text, callback, PANEL, BUTTON_S)
	for state in ["normal", "hover", "pressed", "disabled"]:
		node.add_theme_stylebox_override(state, surface(Color(1, 1, 1, 0.06) if state == "pressed" else Color.TRANSPARENT, BUTTON_RADIUS, 8))
	for state in ["font_color", "font_pressed_color", "font_focus_color"]: node.add_theme_color_override(state, SUCCESS)
	node.add_theme_color_override("font_hover_color", SUCCESS.lightened(0.2))
	return node

## One shared focus ring for every button. It is only visible after keyboard input;
## a tap or click hides it again, so touch users never see a stray outline.
static var _ring: StyleBoxFlat

static func _focus(node: Control) -> void:
	if _ring == null:
		_ring = surface(Color.TRANSPARENT, BUTTON_RADIUS, 0, Color(GOLD, 0.0))
		_ring.set_border_width_all(2)
	node.add_theme_stylebox_override("focus", _ring)

static func show_focus(visible: bool) -> void:
	if _ring != null and (_ring.border_color.a > 0) != visible: _ring.border_color = Color(GOLD, 1.0 if visible else 0.0)

## Shrink slightly while held, so a tap visibly lands.
static func press_feedback(node: Control) -> void:
	node.button_down.connect(func(): _press(node, 0.96))
	node.button_up.connect(func(): _press(node, 1.0))

static func _press(node: Control, to: float) -> void:
	if not node.is_inside_tree(): return
	node.pivot_offset = node.size / 2
	if not motion:
		node.scale = Vector2.ONE
		return
	node.create_tween().tween_property(node, "scale", Vector2(to, to), 0.08)

## Fade a page in when it appears.
static func fade_in(node: CanvasItem) -> void:
	if not motion or not node.is_inside_tree() or not node.visible: return
	node.modulate.a = 0.0
	node.create_tween().tween_property(node, "modulate:a", 1.0, 0.16)

## A short bounce, for a number or seat that just changed in your favour.
static func pop(node: Control, amount: float = 1.08) -> void:
	if not motion or not node.is_inside_tree(): return
	node.pivot_offset = node.size / 2
	var tween = node.create_tween()
	tween.tween_property(node, "scale", Vector2(amount, amount), 0.09)
	tween.tween_property(node, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

static func money(chips: int, bb: int, use_bb: bool) -> String:
	if not use_bb: return str(chips)
	return ("%.1f" % (float(chips) / bb)).trim_suffix(".0") + " BB"

static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
