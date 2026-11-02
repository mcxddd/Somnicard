extends ColorRect
## Reusable, scrollable sheet. The owner controls gameplay and focus while open.
signal closed
const UI = preload("res://scripts/ui/style.gd")
var panel: PanelContainer
var title: Label
var content: VBoxContainer
var footer: HBoxContainer
var close_button: Button
var scroll: ScrollContainer
var preferred_height: float = 610
var touch_scroll: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.015, 0.025, 0.04, 0.88)
	panel = UI.panel(UI.PANEL, 22, 22)
	add_child(panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	var heading = HBoxContainer.new()
	column.add_child(heading)
	title = UI.label("", 26, UI.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_child(title)
	close_button = UI.outline("收起", close)
	heading.add_child(close_button)
	scroll = preload("res://scripts/ui/touch_scroll.gd").new() if touch_scroll else ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)
	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	column.add_child(footer)
	resized.connect(_layout)
	hide()

func open(heading: String) -> void:
	title.text = heading
	show()
	_layout()
	scroll.scroll_vertical = 0
	close_button.grab_focus()

func close() -> void:
	if OS.has_feature("mobile"): DisplayServer.virtual_keyboard_hide()
	hide()
	closed.emit()

func _layout() -> void:
	if panel == null: return
	var narrow = size.x < 850
	var keyboard = 0.0
	if OS.has_feature("mobile"):
		keyboard = DisplayServer.virtual_keyboard_get_height() * size.y / maxf(1, get_window().size.y)
	var available = maxf(250, size.y - keyboard)
	panel.size = Vector2(size.x if narrow else minf(760, size.x - 40), minf(preferred_height, available - 24))
	panel.position = Vector2((size.x - panel.size.x) / 2, available - panel.size.y)

func _process(_delta: float) -> void:
	if visible and OS.has_feature("mobile"): _layout()
