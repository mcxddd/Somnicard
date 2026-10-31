extends ColorRect
signal closed
signal replay_requested(record: Dictionary)
const UI = preload("res://scripts/ui/style.gd")
const History = preload("res://scripts/poker/history.gd")
const Practice = preload("res://scripts/poker/practice.gd")
const Profiles = preload("res://scripts/poker/opponent_profiles.gd")
const Scroll = preload("res://scripts/ui/touch_scroll.gd")
const UnitSwitch = preload("res://scripts/ui/unit_switch.gd")
const Notes = preload("res://scripts/ui/hand_notes.gd")
const TrainingHub = preload("res://scripts/ui/training_hub.gd")
const TrainingCase = preload("res://scripts/ui/training_case.gd")
var store
var history_directory = History.DIRECTORY
var use_bb = true
var difficulty = 1
var opponent_profiles: Array = Profiles.normalize([])
var speed = 0.65
var hub_tabs: HBoxContainer
var hub_buttons: Array = []
var hub_page: int = 0
var return_text: String = "‹ 返回"
var hub
var hub_scroll
var case_page
var status: Label
var close_button: Button
var notes
var units

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color("0b1c23")
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for e in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + e, 12)
	add_child(margin)
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	col.add_child(head)
	close_button = UI.button("‹ 返回", back_action)
	head.add_child(close_button)
	var heading = UI.label("训练室", 24, UI.GOLD)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(heading)
	var unit = UnitSwitch.new()
	units = unit
	unit.custom_minimum_size.x = 110
	unit.item_selected.connect(_units_changed)
	head.add_child(unit)
	status = _label("", 16)
	col.add_child(status)
	hub_tabs = HBoxContainer.new()
	hub_tabs.add_theme_constant_override("separation", 8)
	col.add_child(hub_tabs)
	for i in range(3):
		var tab = UI.button(["开始练习", "练习记录", "表现统计"][i], _select_hub_page.bind(i))
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hub_tabs.add_child(tab)
		hub_buttons.append(tab)
	hub_scroll = Scroll.new()
	hub_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(hub_scroll)
	hub = TrainingHub.new()
	hub.host = self
	hub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hub.add_theme_constant_override("separation", 14)
	hub_scroll.add_child(hub)
	hub.build()
	case_page = TrainingCase.new()
	case_page.host = self
	case_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(case_page)
	case_page.build()
	notes = Notes.new()
	add_child(notes)
	_select_hub_page(0)
	hide()
	case_page.hide()

func _label(text: String, size_value: int = 18, tint: Color = UI.MUTED) -> Label:
	var label = UI.label(text, size_value, tint)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _picker(options: Array, parent: Node) -> OptionButton:
	var p = OptionButton.new()
	p.custom_minimum_size.y = 48
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.fit_to_longest_item = false
	for option in options: p.add_item(option)
	parent.add_child(p)
	return p

func _select_hub_page(index: int) -> void:
	hub_page = index
	for i in range(hub.hub_pages.size()):
		hub.hub_pages[i].visible = i == index
		hub_buttons[i].add_theme_stylebox_override("normal", UI.surface(UI.GREEN if i == index else Color("243a40"), 9, 12))
	if hub_scroll != null: hub_scroll.reset_scroll()

func open_hub() -> void:
	close_button.text = return_text
	hub_tabs.show()
	_select_hub_page(hub_page)
	units.select(1 if use_bb else 0)
	show()
	case_page.hide()
	hub_scroll.show()
	case_page.job = null
	case_page.builder = null
	case_page.playing = false
	case_page.game = null
	hub.open()

func open_case(record: Dictionary, point: int) -> void:
	case_page.start([{"record": record.duplicate(true), "point": point, "topic": "决策练习"}])

func _review_branch(id: String) -> void:
	if not store.data.branches.has(id): return
	var b = store.data.branches[id]
	var original: Dictionary = {}
	var current: Dictionary = case_page.current
	if not current.is_empty() and History.hand_id(current.record) == b.source: original = current.record
	else:
		for c in hub.candidates:
			if History.hand_id(c.record) == b.source:
				original = c.record
				break
	if original.is_empty(): replay_requested.emit(b.record)
	else: replay_requested.emit({"record": b.record, "original": original, "mode": b.mode})

func back_action() -> void:
	if notes.visible:
		notes.close()
		return
	if case_page.visible:
		case_page._persist()
		open_hub()
	else:
		hide()
		closed.emit()

func _units_changed(index: int) -> void:
	case_page._units_changed(index)

func suspend() -> void:
	case_page.suspend()
