extends ColorRect
## A draft editor: controls never mutate the running game until Apply is pressed.
signal applied(values: Dictionary)
signal cancelled
const UI = preload("res://scripts/ui/style.gd")
const TouchScroll = preload("res://scripts/ui/touch_scroll.gd")
const OpponentEditor = preload("res://scripts/ui/opponent_editor.gd")
const DataPage = preload("res://scripts/ui/data_settings.gd")
var evidence_page
const CATEGORIES = ["牌桌与操作", "外观与声音", "教练与教学", "电脑对手", "数据与备份"]
var index_page: VBoxContainer
var heading: Label
var context: Label
var back_button: Button
var reset_button: Button
var data_page
var current_page: int = -1
var opponent_editor
var player_count: int = 2
var controls: Dictionary = {}
var pages: Array = []
var tabs: Array = []
var apply_button: Button
var cancel_button: Button
var summary: Label
var initial: Dictionary = {}
var panel: PanelContainer
var rows: Array = []
var scroll: ScrollContainer
var portrait: bool = false
var keyboard_inset: float = 0.0
var keyboard_focus: Control
const DEFAULTS = preload("res://scripts/ui/preferences.gd").DEFAULTS

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.025, 0.04, 0.065, 0.96)
	panel = UI.panel(UI.PANEL, 22, 24)
	add_child(panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	back_button = UI.button("‹ 返回", back_action)
	header.add_child(back_button)
	heading = UI.label("设置", 28, UI.GOLD)
	header.add_child(heading)
	context = UI.label("应用于本机的所有练习桌", 17, UI.MUTED)
	context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(context)
	scroll = TouchScroll.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	index_page = VBoxContainer.new()
	index_page.add_theme_constant_override("separation", 12)
	body.add_child(index_page)
	var descriptions = ["行动间隔、弃牌快进、全押确认", "配色、BB 单位、花色、动效、提示音与省电", "悬浮教练、提示时机、复盘教学", "默认难度、每位对手、本地实测", "导入和导出牌局与学习记录"]
	for i in range(CATEGORIES.size()):
		var tab = UI.button(CATEGORIES[i] + "  ›\n" + descriptions[i], func():
			if scroll.can_activate(): _select_page(i), Color("1b3039"), 82)
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.add_theme_font_size_override("font_size", 19)
		index_page.add_child(tab)
		tabs.append(tab)
	for i in range(CATEGORIES.size()):
		var page = VBoxContainer.new()
		page.add_theme_constant_override("separation", 10)
		page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_child(page)
		pages.append(page)
	_add_option(0, "speed", "对局节奏", "只调整电脑行动间隔，不改变决策难度。", ["慢速", "标准", "快速"])
	_add_toggle(0, "fast_fold", "弃牌后快进", "你弃牌后，加快其余电脑的行动。")
	_add_toggle(0, "sidebar", "显示讲解与行动记录", "从“更多”查看讲解与行动记录。")
	# Retain the legacy preference for compatibility, but remove its obsolete switch.
	controls.sidebar.get_parent().get_parent().hide()
	pages[0].add_child(UI.label("讲解与行动记录：从牌桌“更多”进入。", 18, UI.MUTED))
	_add_toggle(0, "confirm_all_in", "全押前确认", "全押按钮、跟注全押与加注到全部筹码都适用。")
	var note = UI.label("重开牌桌始终需要确认。\n取消换桌不会改变筹码和初始人数；历史记录持续保留。\n\nEsc / 安卓返回键：返回上一层。\n切到后台：暂停牌局，回来后手动继续。", 19, UI.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pages[0].add_child(note)
	_add_option(1, "felt", "牌桌配色", "牌面和筹码保持清晰的对比。", ["经典墨绿", "午夜蓝"])
	_add_option(1, "bb", "筹码显示单位", "1 BB = 10 筹码；输入与复盘同步切换。", ["筹码金额", "大盲 BB"])
	_add_toggle(1, "four_color", "四色花色", "黑桃黑、红桃红、方块蓝、梅花绿。")
	_add_toggle(1, "motion", "牌局动效", "发牌与输赢提示动画；关闭后立即显示结果。")
	_add_option(1, "sound", "牌桌提示音", "发牌、筹码、轮到你和结算使用短提示音；不播放背景音乐。", ["静音", "轻声", "标准"])
	_add_toggle(1, "haptics", "轮到我时轻震", "仅支持震动的手机生效；后台和暂停时不提示。")
	_add_option(1, "performance", "画面帧率", "省电模式限制为 30 帧；标准模式最多 60 帧。不会改变规则或电脑难度。", ["标准 · 60 帧", "省电 · 30 帧"])
	_add_toggle(2, "live_teaching", "显示牌桌教练", "显示悬浮头像，点击后在牌桌内查看建议；关闭后隐藏头像。")
	_add_toggle(2, "coach_after", "先行动，再看教练", "行动后暂停并解释刚才的决策；开启时不提前展示建议。")
	_add_toggle(2, "coach_auto", "轮到我时自动提示", "关闭时只在点击头像后分析，不主动揭示建议。")
	_add_option(2, "coach_detail", "提示内容", "简洁模式先给操作与关键理由，详细模式显示完整原因。", ["简洁", "详细"])
	_add_option(2, "coach_side", "悬浮头像位置", "放在牌桌左下或右下，避开你的手牌和下注按钮。", ["左侧", "右侧"])
	_add_toggle(2, "review_teaching", "复盘中的教学", "在自己的历史决策点显示分析入口。关闭后仍可回放、查看行动和结算。")
	var scope_note = UI.label("两个开关独立保存。教学页也可以即时开关。\n\n数值分析在本地完成。2–9 人支持范围推断；CFR 仅覆盖限定的双人河牌抽象，不代表完整 GTO。\n\n先思考自己的选择，再揭示讲解，有助于区分决策质量与最后输赢。", 18, UI.MUTED)
	scope_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pages[2].add_child(scope_note)
	_add_option(3, "difficulty", "默认电脑难度", "跟随默认的座位会一起更新；单独指定难度的座位保持原设置。下方可以逐个配置。", ["入门", "标准", "进阶（实验）"])
	opponent_editor = OpponentEditor.new()
	pages[3].add_child(opponent_editor)
	opponent_editor.changed.connect(_changed)
	controls.difficulty.item_selected.connect(func(index): opponent_editor.default_level = index; opponent_editor._render())
	evidence_page = preload("res://scripts/ui/arena_evidence.gd").new()
	pages[3].add_child(evidence_page)
	data_page = DataPage.new()
	pages[4].add_child(data_page)
	summary = UI.label("", 16, UI.GOLD)
	column.add_child(summary)
	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	column.add_child(footer)
	reset_button = UI.button("恢复全部默认", func(): _fill(DEFAULTS); _changed())
	index_page.add_child(reset_button)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	cancel_button = UI.button("取消", cancel)
	footer.add_child(cancel_button)
	apply_button = UI.button("保存设置", func(): applied.emit(values()), UI.GREEN)
	apply_button.custom_minimum_size.x = 180
	footer.add_child(apply_button)
	_select_page(-1)
	resized.connect(_layout)
	_layout()
	hide()

func _add_row(page: int, title: String, hint: String) -> BoxContainer:
	var panel = UI.panel(Color("101c26"), 10, 12)
	pages[page].add_child(panel)
	var row = BoxContainer.new()
	rows.append(row)
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var labels = VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(labels)
	labels.add_child(UI.label(title, 20, UI.TEXT))
	var description = UI.label(hint, 16, UI.MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(description)
	return row

func _add_option(page: int, key: String, title: String, hint: String, choices: Array) -> void:
	var row = _add_row(page, title, hint)
	var picker = OptionButton.new()
	for choice in choices: picker.add_item(choice)
	picker.custom_minimum_size = Vector2(170, 48)
	picker.item_selected.connect(func(_value): _changed())
	row.add_child(picker)
	controls[key] = picker

func _add_toggle(page: int, key: String, title: String, hint: String) -> void:
	var row = _add_row(page, title, hint)
	var toggle = UI.button("", func(): pass)
	toggle.toggle_mode = true
	toggle.custom_minimum_size = Vector2(170, 48)
	toggle.toggled.connect(func(_value): _style_toggle(toggle); _changed())
	row.add_child(toggle)
	controls[key] = toggle

func _style_toggle(toggle: Button) -> void:
	toggle.text = "已开启  ✓" if toggle.button_pressed else "已关闭  —"
	toggle.add_theme_stylebox_override("normal", UI.surface(UI.GREEN.darkened(0.2) if toggle.button_pressed else Color("263540"), 8, 12))
	toggle.add_theme_stylebox_override("pressed", UI.surface(UI.GREEN.darkened(0.2), 8, 12))

func _select_page(index: int) -> void:
	current_page = index
	if scroll != null: scroll.reset_scroll()
	index_page.visible = index < 0
	for i in range(pages.size()): pages[i].visible = i == index
	heading.text = "设置" if index < 0 else CATEGORIES[index]
	back_button.text = "‹ 返回" if index < 0 else "‹ 分类"
	if is_visible_in_tree(): back_button.grab_focus()

func back_action() -> void:
	if data_page.dialog.visible:
		data_page.dialog.hide()
	elif current_page >= 0:
		_select_page(-1)
		back_button.grab_focus()
	else: cancel()

func open(current: Dictionary) -> void:
	_fill(current)
	initial = values().duplicate(true)
	_select_page(-1)
	_changed()
	show()
	cancel_button.grab_focus()

func _fill(data: Dictionary) -> void:
	opponent_editor.seat_names = preload("res://scripts/poker/player_names.gd").normalize(data.get("seat_names", []))
	opponent_editor.fill(data.get("opponents", []), player_count, int(data.get("difficulty", 1)))
	for key in controls:
		var control = controls[key]
		if control is OptionButton: control.select(int(data.get(key, DEFAULTS[key])))
		else:
			control.set_pressed_no_signal(bool(data.get(key, DEFAULTS[key])))
			_style_toggle(control)

func values() -> Dictionary:
	var out: Dictionary = {}
	for key in controls:
		var control = controls[key]
		out[key] = control.selected if control is OptionButton else control.button_pressed
	out["opponents"] = opponent_editor.profiles.duplicate(true)
	out["seat_names"] = opponent_editor.seat_names.duplicate()
	out.bb = bool(out.bb)
	return out

func _changed() -> void:
	if apply_button == null: return
	var dirty = values() != initial
	summary.text = "有未保存的修改 · 取消会放弃本次修改" if dirty else "没有待保存的修改"
	apply_button.disabled = not dirty
	cancel_button.text = "取消修改" if dirty else "返回"

func cancel() -> void:
	hide()
	cancelled.emit()


func set_portrait(value: bool) -> void:
	portrait = value
	for row in rows: row.vertical = portrait
	_layout()

func _layout(inset: float = -1.0) -> void:
	if panel == null: return
	if inset < 0: inset = _keyboard_inset()
	keyboard_inset = inset
	var available = Vector2(size.x, maxf(300, size.y - inset))
	panel.size = available - Vector2(24, 24) if portrait else Vector2(920, minf(760, available.y - 24))
	panel.position = (available - panel.size) / 2

func _keyboard_inset() -> float:
	if not OS.has_feature("mobile"): return 0.0
	# The safe-area panel is shorter than the viewport; use the viewport scale.
	return DisplayServer.virtual_keyboard_get_height() * get_viewport().get_visible_rect().size.y / maxf(1, get_window().size.y)

func _reveal_editor(editor: Control) -> void:
	if is_instance_valid(editor) and scroll.is_ancestor_of(editor): scroll.ensure_control_visible(editor)

func _process(_delta: float) -> void:
	if not visible or not OS.has_feature("mobile"): return
	var inset = _keyboard_inset()
	var changed_height = absf(inset - keyboard_inset) > 1
	if changed_height: _layout(inset)
	var focused = get_viewport().gui_get_focus_owner()
	if inset > 0 and (focused is LineEdit or focused is TextEdit):
		if changed_height or focused != keyboard_focus: _reveal_editor.call_deferred(focused)
		keyboard_focus = focused
	else: keyboard_focus = null
