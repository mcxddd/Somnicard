extends HBoxContainer
## A row of mutually exclusive choices, used where an OptionButton would hide two or
## three short options behind a popup. Mirrors the OptionButton calls settings rely on:
## add_item, select (no signal), selected and item_selected.
signal item_selected(index: int)
const UI = preload("res://scripts/ui/style.gd")
var selected: int = -1
var buttons: Array[Button] = []

func _init() -> void:
	add_theme_constant_override("separation", 4)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

func add_item(text: String) -> void:
	var index = buttons.size()
	var button = UI.button(text, func(): _choose(index), UI.INSET, 48)
	button.toggle_mode = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", UI.SIZE_CAPTION + 2)
	var chosen = UI.surface(UI.GREEN.darkened(0.15), 9, 12, UI.GREEN.lightened(0.3))
	chosen.set_border_width_all(1)
	button.add_theme_stylebox_override("pressed", chosen)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	buttons.append(button)
	add_child(button)
	if selected < 0: select(0)

func get_item_text(index: int) -> String:
	return buttons[index].text

func select(index: int) -> void:
	selected = clampi(index, 0, buttons.size() - 1)
	for i in range(buttons.size()): buttons[i].set_pressed_no_signal(i == selected)

func _choose(index: int) -> void:
	var changed = index != selected
	select(index)
	if changed: item_selected.emit(index)
