extends Button
## Navigation row with an icon, a title and one line of supporting text.
## The plain-text form stays in `text` (drawn transparent) for accessibility and tests.
const UI = preload("res://scripts/ui/style.gd")
var title_label: Label
var subtitle_label: Label
var bar: ProgressBar
var inset: MarginContainer
var base_height: float

func setup(title_text: String, subtitle: String, icon_name: String, vertical: bool) -> void:
	base_height = 132 if vertical else 76
	custom_minimum_size = Vector2(64, base_height)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fill = UI.CARD
		if state == "hover": fill = UI.CARD.lightened(0.08)
		if state == "pressed": fill = UI.CARD.lightened(0.04)
		var style = UI.surface(fill, 14, 0, Color("2a4048"))
		style.set_border_width_all(1)
		add_theme_stylebox_override(state, style)
	add_theme_stylebox_override("focus", UI.surface(Color.TRANSPARENT, 14, 0, UI.GOLD))
	for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		add_theme_color_override(color, Color.TRANSPARENT)
	inset = MarginContainer.new()
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: inset.add_theme_constant_override("margin_" + edge, 14)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(inset)
	var row: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
	row.add_theme_constant_override("separation", 8 if vertical else 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.add_child(row)
	var picture = UI.icon(icon_name, 44 if vertical else 40)
	if picture != null:
		picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if vertical: picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		row.add_child(picture)
	var lines = VBoxContainer.new()
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.add_theme_constant_override("separation", 4)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lines)
	title_label = UI.label("", UI.SIZE_BODY + 1, UI.TEXT)
	subtitle_label = UI.caption("")
	for label in [title_label, subtitle_label]:
		# Explicit line breaks only: wrapped labels report a huge height before layout.
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lines.add_child(label)
	if not vertical:
		var chevron = UI.label("›", 26, UI.MUTED)
		chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(chevron)
	set_lines(title_text, subtitle)

## Show a thin progress bar under the text; a negative rate hides it.
func set_progress(rate: float) -> void:
	if bar == null:
		bar = UI.progress(0)
		subtitle_label.get_parent().add_child(bar)
	bar.visible = rate >= 0
	bar.value = clampf(rate, 0, 1)
	_fit.call_deferred()

func set_lines(title_text: String, subtitle: String) -> void:
	title_label.text = title_text
	subtitle_label.text = subtitle
	subtitle_label.visible = not subtitle.is_empty()
	text = title_text + ("\n" + subtitle if not subtitle.is_empty() else "")
	tooltip_text = text.replace("\n", "：")
	_fit.call_deferred()

## Grow with wrapped text or a progress bar instead of letting them spill out.
func _fit() -> void:
	custom_minimum_size.y = maxf(base_height, inset.get_combined_minimum_size().y)
