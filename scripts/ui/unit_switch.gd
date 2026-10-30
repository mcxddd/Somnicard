extends HBoxContainer
signal item_selected(index: int)
const UI = preload("res://scripts/ui/style.gd")
var selected: int = 1
var buttons: Array[Button] = []

func _ready() -> void:
	add_theme_constant_override("separation", 2)
	for i in range(2):
		var button = UI.button(["筹码", "BB"][i], _choose.bind(i), Color("152c30"), 48)
		button.custom_minimum_size.x = 54
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", 16)
		button.tooltip_text = ["显示实际筹码数量", "按大盲显示金额，1 BB = 本桌大盲"][i]
		buttons.append(button)
		add_child(button)
	select(selected)

func _choose(index: int) -> void:
	if index == selected:
		select(selected)
		return
	select(index)
	item_selected.emit(index)

func select(index: int) -> void:
	selected = clampi(index, 0, 1)
	for i in range(buttons.size()):
		buttons[i].set_pressed_no_signal(i == selected)
		var selected_style = UI.surface(Color("3d5145"), 8, 8, Color("b79c64"))
		selected_style.set_border_width_all(1)
		buttons[i].add_theme_stylebox_override("pressed", selected_style)
		buttons[i].add_theme_color_override("font_pressed_color", Color("f2d79d"))
