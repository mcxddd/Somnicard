extends RefCounted
const TEXT = Color("eee9dc")
const MUTED = Color("97aaa8")
const GOLD = Color("e5c17a")
const GREEN = Color("237766")
const BACKGROUND = Color("0a111b")
const PANEL = Color("15232d")
const BORDER = Color("30444d")
const BLUE = Color("70a8df")

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
	result.set_stylebox("slider", "HSlider", surface(Color("30424b"), 3, 3))
	result.set_stylebox("grabber_area", "HSlider", surface(GOLD.darkened(0.2), 3, 3))
	result.set_stylebox("grabber_area_highlight", "HSlider", surface(GOLD, 3, 3))
	result.set_stylebox("panel", "TooltipPanel", surface(PANEL, 8, 12, BORDER))
	result.set_color("font_color", "TooltipLabel", TEXT)
	return result

static func panel(color: Color, radius: int = 12, padding: int = 12) -> PanelContainer:
	var node := PanelContainer.new()
	var style = surface(color, radius, padding, Color("30434a"))
	style.set_border_width_all(1)
	style.shadow_color = Color(0, 0, 0, 0.18)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	node.add_theme_stylebox_override("panel", style)
	return node

static func label(text: String, size: int = 18, color := TEXT, centered: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	if centered:
		node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return node

static func button(text: String, callback: Callable, color := Color("243a40"), height: int = 48) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(64, height)
	node.pressed.connect(callback)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fill = color
		if state == "hover": fill = color.lightened(0.15)
		if state == "pressed": fill = color.lightened(0.06)
		if state == "disabled": fill = Color("17292d")
		var style = surface(fill, 9, 12, fill.lightened(0.14) if state != "disabled" else Color.TRANSPARENT)
		style.set_border_width_all(1)
		node.add_theme_stylebox_override(state, style)
	node.add_theme_stylebox_override("focus", surface(Color.TRANSPARENT, 8, 0, GOLD))
	node.add_theme_color_override("font_color", TEXT)
	node.add_theme_color_override("font_hover_color", Color.WHITE)
	node.add_theme_color_override("font_disabled_color", Color("657a7c"))
	return node

static func money(chips: int, bb: int, use_bb: bool) -> String:
	if not use_bb: return str(chips)
	return ("%.1f" % (float(chips) / bb)).trim_suffix(".0") + " BB"

static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
