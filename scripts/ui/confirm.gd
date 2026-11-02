extends ColorRect
signal accepted
signal cancelled
const UI = preload("res://scripts/ui/style.gd")
var title: Label
var body: Label
var accept_button: Button
var cancel_button: Button
var panel: PanelContainer
var row: BoxContainer
var portrait: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.02, 0.035, 0.05, 0.90)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = UI.panel(UI.PANEL, 20, 24)
	center.add_child(panel)
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	panel.add_child(col)
	col.add_child(UI.label("请确认这次操作", 16, UI.GOLD))
	title = UI.label("", 28)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)
	body = UI.label("", 19, UI.MUTED)
	body.custom_minimum_size = Vector2(540, 90)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(body)
	row = BoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	cancel_button = UI.outline("取消，保留当前状态", cancel, 54)
	accept_button = UI.button("确认", func(): hide(); accepted.emit(), UI.ACTION_RAISE, 54)
	for button in [cancel_button, accept_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
	resized.connect(_layout)
	_layout()
	hide()

func open(heading: String, message: String, action: String) -> void:
	title.text = heading
	body.text = message
	accept_button.text = action
	show()
	_layout()
	cancel_button.grab_focus()

func cancel() -> void:
	hide()
	cancelled.emit()


func set_portrait(value: bool) -> void:
	portrait = value
	row.vertical = portrait
	body.custom_minimum_size = Vector2(0 if portrait else 540, 90)
	_layout()

func _layout() -> void:
	if panel == null: return
	var width = size.x - 32 if portrait else 600.0
	panel.custom_minimum_size.x = width
	body.custom_minimum_size.x = width - 48
	title.custom_minimum_size.x = width - 48
