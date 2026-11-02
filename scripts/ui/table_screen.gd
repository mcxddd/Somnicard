extends Node
var host
const UI = preload("res://scripts/ui/style.gd")
const UnitSwitch = preload("res://scripts/ui/unit_switch.gd")
const TableView = preload("res://scripts/ui/table_view.gd")
const TouchScroll = preload("res://scripts/ui/touch_scroll.gd")
const Sheet = preload("res://scripts/ui/sheet.gd")
var table_view
var header: Label
var turn_label: Label
var explanation: Label
var log_view: RichTextLabel
var sidebar: PanelContainer
var pause_button: Button
var fold_button: Button
var call_button: Button
var raise_button: Button
var all_in_button: Button
var next_button: Button
var amount_input: SpinBox
var unit_picker
var amount_slider: HSlider
var amount_note: Label
var minus_button: Button
var plus_button: Button
var quick_buttons: Array = []
var sizing_row: HBoxContainer
var quick_row: GridContainer
var speed_picker: OptionButton
var fast_fold: CheckBox
var lobby: ColorRect
var count_picker: OptionButton
var depth_picker: OptionButton
var lobby_note: Label
var start_button: Button
var cancel_button: Button
var preset_buttons: Dictionary = {}
var advice_button: Button
var review_hand_button: Button
var safe_root: Control
var margin: MarginContainer
var top: HBoxContainer
var subhead: HBoxContainer
var brand: VBoxContainer
var mark: Control
var dock: PanelContainer
var controls: VBoxContainer
var actions: HBoxContainer
var more_button: Button
var bet_open_button: Button
var bet_sheet
var menu_sheet
var info_sheet
var info_opponent_button: Button
var info_text: RichTextLabel
var sheet_units: OptionButton
var lobby_panel: PanelContainer
var lobby_scroll: ScrollContainer
var lobby_shell: BoxContainer
var lobby_welcome: VBoxContainer
var lobby_art: Control
var lobby_column: VBoxContainer
var lobby_extras: BoxContainer
var lobby_buttons: BoxContainer

func build_table() -> void:
	safe_root = Control.new()
	safe_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(safe_root)
	margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 20)
	safe_root.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	top = row(12)
	layout.add_child(top)
	mark = TextureRect.new()
	mark.texture = load("res://assets/logo-mark.svg")
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.custom_minimum_size = Vector2(42, 42)
	top.add_child(mark)
	brand = VBoxContainer.new()
	var wordmark = TextureRect.new()
	wordmark.texture = load("res://assets/wordmark.svg")
	wordmark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wordmark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wordmark.custom_minimum_size = Vector2(20 * wordmark.texture.get_width() / float(wordmark.texture.get_height()), 20)
	brand.add_child(wordmark)
	brand.add_child(UI.label("专注每一手决策", 13, UI.MUTED))
	top.add_child(brand)
	header = UI.label("德州扑克练习室", 20, UI.TEXT)
	header.clip_text = true
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(header)
	unit_picker = UnitSwitch.new()
	unit_picker.select(1 if host.prefs.use_bb else 0)
	unit_picker.custom_minimum_size = Vector2(110, 48)
	unit_picker.tooltip_text = "切换整桌和下注输入的显示单位，实际筹码不变"
	unit_picker.item_selected.connect(host._unit_changed)
	top.add_child(unit_picker)
	pause_button = UI.button("暂停", host._toggle_pause)
	top.add_child(pause_button)
	speed_picker = OptionButton.new()
	speed_picker.custom_minimum_size = Vector2(112, 48)
	for text in ["慢速", "标准速度", "快速"]: speed_picker.add_item(text)
	speed_picker.select(host.prefs.speed_index)
	speed_picker.item_selected.connect(host._speed_changed)
	host.add_child(speed_picker)
	speed_picker.hide()
	advice_button = UI.button("教练", host._open_advice, UI.GREEN)
	top.add_child(advice_button)
	more_button = UI.button("更多", host._open_menu)
	top.add_child(more_button)
	subhead = row(12)
	layout.add_child(subhead)
	var content = row(16)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(content)
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 10)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(main)
	table_view = TableView.new()
	table_view.effects = true
	table_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(table_view)
	table_view.set_preferences(host.prefs.felt_theme, host.prefs.four_color, host.prefs.motion and host.prefs.performance_mode == 0)
	dock = UI.panel(Color("10252d"), 16, 14)
	main.add_child(dock)
	controls = VBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	dock.add_child(controls)
	turn_label = UI.label("选择桌型，开始练习", 20, UI.GOLD)
	turn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(turn_label)
	# One large editable amount between −1 BB and +1 BB; tapping it opens the digit pad.
	sizing_row = row(10)
	controls.add_child(sizing_row)
	minus_button = UI.button("−", host.bet.adjust_bb.bind(-1), Color("1d343e"), 64)
	plus_button = UI.button("+", host.bet.adjust_bb.bind(1), Color("1d343e"), 64)
	for button in [minus_button, plus_button]:
		button.custom_minimum_size.x = 64
		button.add_theme_font_size_override("font_size", 30)
	minus_button.tooltip_text = "减少 1 BB"
	plus_button.tooltip_text = "增加 1 BB"
	sizing_row.add_child(minus_button)
	amount_input = SpinBox.new()
	amount_input.custom_minimum_size = Vector2(134, 64)
	amount_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	amount_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount_input.value_changed.connect(host.bet.amount_changed)
	# The ± buttons and slider replace the tiny desktop spin arrows.
	var blank = ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	for icon_name in ["updown", "up", "up_hover", "up_pressed", "up_disabled", "down", "down_hover", "down_pressed", "down_disabled"]:
		amount_input.add_theme_icon_override(icon_name, blank)
	var field: LineEdit = amount_input.get_line_edit()
	field.add_theme_font_size_override("font_size", 30)
	field.add_theme_color_override("font_color", UI.GOLD)
	sizing_row.add_child(amount_input)
	sizing_row.add_child(plus_button)
	amount_slider = HSlider.new()
	amount_slider.custom_minimum_size = Vector2(110, 52)
	amount_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	amount_slider.value_changed.connect(func(value): host.bet.set_target(int(value)))
	controls.add_child(amount_slider)
	amount_note = UI.label("", UI.SIZE_CAPTION + 1, UI.MUTED, true)
	amount_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(amount_note)
	quick_row = GridContainer.new()
	quick_row.columns = 4
	quick_row.add_theme_constant_override("h_separation", 8)
	quick_row.add_theme_constant_override("v_separation", 8)
	controls.add_child(quick_row)
	# Indices are stable: 0 minimum, 1–4 preflop BB sizes, 5–8 pot fractions.
	add_quick("最小", host.bet.quick_minimum)
	for bb in [2.0, 2.5, 3.0, 4.0]:
		add_quick(("%.1f" % bb).trim_suffix(".0") + " BB", host.bet.quick_bb.bind(bb))
	for pair in [["⅓ 池", 1.0 / 3.0], ["½ 池", 0.5], ["满池", 1.0], ["⅔ 池", 2.0 / 3.0]]:
		add_quick(pair[0], host.bet.quick_pot.bind(pair[1]))
	quick_row.move_child(quick_buttons[8], quick_buttons[7].get_index())
	actions = row(10)
	controls.add_child(actions)
	fold_button = UI.button("弃牌", func(): host._human_action("fold"), Color("2e3b42"), 56)
	call_button = UI.button("过牌", func(): host._human_action("check_call"), UI.GREEN, 56)
	raise_button = UI.button("加注", host._submit_raise, Color("8c6938"), 56)
	all_in_button = UI.button("全押", host._submit_all_in, Color("633c46"), 56)
	next_button = UI.button("下一手", host._next_hand, UI.GREEN, 56)
	review_hand_button = UI.button("复盘本手", host._review_current_hand, Color("8c6938"), 56)
	for button in [fold_button, call_button, raise_button, all_in_button, next_button, review_hand_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
	bet_open_button = UI.button("加注…", host._open_bet, Color("8c6938"), 60)
	bet_open_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(bet_open_button)
	bet_open_button.hide()
	fold_button.tooltip_text = "弃牌（快捷键 F）"
	call_button.tooltip_text = "过牌或跟注（空格）"
	raise_button.tooltip_text = "提交上方选定的本轮总额；R 键可聚焦输入框"
	sidebar = UI.panel(Color("102027"), 16, 16)
	sidebar.custom_minimum_size.x = 276
	content.add_child(sidebar)
	sidebar.hide()
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 12)
	sidebar.add_child(side)
	side.add_child(UI.label("牌局讲解", 21, UI.GOLD))
	explanation = UI.label("", 17)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.custom_minimum_size = Vector2(244, 158)
	side.add_child(explanation)
	side.add_child(HSeparator.new())
	side.add_child(UI.label("本手记录", 19, UI.MUTED))
	log_view = RichTextLabel.new()
	log_view.scroll_following = true
	log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_view.add_theme_font_size_override("normal_font_size", 16)
	log_view.add_theme_color_override("default_color", UI.TEXT)
	side.add_child(log_view)
	fast_fold = CheckBox.new()
	fast_fold.text = "弃牌后快进电脑行动"
	fast_fold.button_pressed = host.prefs.fast_fold_enabled
	side.add_child(fast_fold)
	fast_fold.hide()
	side.add_child(UI.label("D 庄家 · SB 小盲 · BB 大盲\n虚拟筹码 · 离线电脑对战", 14, UI.MUTED))

func build_lobby() -> void:
	lobby = ColorRect.new()
	lobby.color = Color("0b1920")
	lobby.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_root.add_child(lobby)
	lobby_panel = UI.panel(UI.PANEL, 22, 20)
	var inset = MarginContainer.new()
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: inset.add_theme_constant_override("margin_" + edge, 12)
	lobby.add_child(inset)
	inset.add_child(lobby_panel)
	var outer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 18)
	lobby_panel.add_child(outer)
	var head = row(12)
	outer.add_child(head)
	cancel_button = UI.button("‹ 返回", host._close_lobby)
	head.add_child(cancel_button)
	head.add_child(UI.label("新建牌桌", 28, UI.GOLD))
	lobby_scroll = TouchScroll.new()
	lobby_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(lobby_scroll)
	lobby_shell = VBoxContainer.new()
	lobby_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lobby_shell.add_theme_constant_override("separation", 18)
	lobby_scroll.add_child(lobby_shell)
	lobby_welcome = VBoxContainer.new()
	lobby_shell.add_child(lobby_welcome)
	lobby_welcome.add_child(UI.label("01   选择桌型", 22, UI.GOLD))
	lobby_welcome.add_child(UI.label("人数包含你和电脑对手", 17, UI.MUTED))
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	lobby_column = col
	lobby_shell.add_child(col)
	var presets = row(12)
	col.add_child(presets)
	for count in [2, 6, 9]:
		var button = UI.button("%d 人桌" % count, host._select_count.bind(count), UI.GREEN, 64)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		presets.add_child(button)
		preset_buttons[count] = button
	var custom = row(16)
	col.add_child(custom)
	custom.add_child(UI.label("任意人数", 18, UI.MUTED))
	count_picker = OptionButton.new()
	for count in range(2, 10): count_picker.add_item("%d 人 · 你 + %d 个电脑" % [count, count - 1])
	count_picker.custom_minimum_size.y = 54
	count_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_picker.item_selected.connect(func(index): host._select_count(index + 2))
	custom.add_child(count_picker)
	col.add_child(UI.label("02   初始筹码", 22, UI.GOLD))
	depth_picker = OptionButton.new()
	for bb in [50, 100, 200]: depth_picker.add_item("%d BB / 人" % bb)
	depth_picker.select([50, 100, 200].find(host.starting_bb))
	depth_picker.custom_minimum_size.y = 54
	depth_picker.item_selected.connect(func(_i): host._update_table_summary())
	col.add_child(depth_picker)
	col.add_child(UI.label("03   电脑对手", 22, UI.GOLD))
	lobby_extras = VBoxContainer.new()
	col.add_child(lobby_extras)
	lobby_extras.add_child(UI.button("配置每位对手  ›", host._open_opponents, Color("243a40"), 58))
	var hint = UI.label("每位电脑可单独设置难度和激进程度。
教练与外观在主界面的“设置”中调整。", 17, UI.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint)
	lobby_note = UI.label("", 17, UI.MUTED)
	lobby_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(lobby_note)
	lobby_buttons = VBoxContainer.new()
	outer.add_child(lobby_buttons)
	start_button = UI.button("开始对局", host._commit_table, UI.GREEN, 64)
	lobby_buttons.add_child(start_button)
	host._select_count(host.selected_count)
	lobby.hide()

func build_sheets() -> void:
	bet_sheet = Sheet.new()
	bet_sheet.preferred_height = 500
	safe_root.add_child(bet_sheet)
	bet_sheet.closed.connect(host._close_sheet)
	sheet_units = OptionButton.new()
	sheet_units.add_item("筹码金额")
	sheet_units.add_item("大盲 BB")
	sheet_units.select(1 if host.prefs.use_bb else 0)
	sheet_units.custom_minimum_size.y = 48
	sheet_units.item_selected.connect(host._unit_changed)
	bet_sheet.content.add_child(sheet_units)
	sheet_units.hide()
	var hint = UI.caption("“加到”是你本轮的总投入。选好金额后，点下方按钮确认。")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bet_sheet.content.add_child(hint)
	menu_sheet = Sheet.new()
	safe_root.add_child(menu_sheet)
	menu_sheet.closed.connect(host._close_sheet)
	menu_sheet.content.add_theme_constant_override("separation", 8)
	for item in [["牌桌设置", "settings-table", host._open_settings], ["新建牌桌", "topic-preflop", host._open_lobby], ["历史牌局与复盘", "review", host._open_history], ["训练室", "train", host._open_training], ["玩法帮助", "help", host._open_help], ["本手行动记录", "lesson", host._toggle_sidebar], ["返回主界面 · 保留牌桌", "home", host._open_home]]:
		var entry = UI.entry(item[0], "", func(): menu_sheet.close(); item[2].call(), item[1])
		entry.base_height = 62
		menu_sheet.content.add_child(entry)
	# The display unit is a table preference, not a per-hand control, so it lives here.
	var unit_caption = UI.label("金额显示", UI.SIZE_BODY, UI.MUTED)
	unit_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unit_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	menu_sheet.footer.add_child(unit_caption)
	unit_picker.reparent(menu_sheet.footer)
	menu_sheet.preferred_height = 700
	info_sheet = Sheet.new()
	info_sheet.touch_scroll = true
	safe_root.add_child(info_sheet)
	info_sheet.closed.connect(host._close_sheet)
	info_text = RichTextLabel.new()
	info_text.fit_content = true
	info_text.add_theme_color_override("default_color", UI.TEXT)
	info_text.add_theme_font_size_override("normal_font_size", 22)
	info_sheet.content.add_child(info_text)
	# The sheet is reused for seat details and action records. Keep one action,
	# and update its target on each opening instead of accumulating callbacks.
	info_opponent_button = UI.button("配置这位对手", func():
		if info_sheet.visible and host.game != null and host.info_opponent_id > 0 and host.info_opponent_id < host.game.seats.size():
			host._open_opponents(host.info_opponent_id), UI.GREEN)
	info_sheet.content.add_child(info_opponent_button)
	info_opponent_button.hide()
	table_view.seat_selected.connect(host._seat_details)
	# Confirmation remains above every sheet, including nested all-in prompts.
	safe_root.move_child(host.confirmation, -1)

func row(separation: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	return row

func add_quick(text: String, callback: Callable) -> void:
	var button = UI.button(text, callback, Color("1d343e"), 52)
	button.add_theme_font_size_override("font_size", 18)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = "仅填入本轮下注总额；必要时调整到合法范围，之后点击加注确认。"
	quick_buttons.append(button)
	quick_row.add_child(button)

func move(node: Node, parent: Node, index: int) -> void:
	if node.get_parent() != parent: node.reparent(parent)
	parent.move_child(node, mini(index, parent.get_child_count() - 1))

func arrange() -> void:
	if not host.is_inside_tree(): return
	var previous_focus = host.get_viewport().gui_get_focus_owner()
	safe_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if OS.has_feature("mobile"):
		var safe = DisplayServer.get_display_safe_area()
		var pixels = Vector2(host.get_window().size)
		var scale_factor = host.size / pixels
		safe_root.offset_left = maxf(0, safe.position.x) * scale_factor.x
		safe_root.offset_top = maxf(0, safe.position.y) * scale_factor.y
		safe_root.offset_right = -maxf(0, pixels.x - safe.end.x) * scale_factor.x
		safe_root.offset_bottom = -maxf(0, pixels.y - safe.end.y) * scale_factor.y
	# One portrait surface on every platform. Wide/maximized desktop windows
	# add side gutters instead of changing the table or expanding its overlays.
	var available_width = safe_root.size.x
	var gutter = maxf(0, (available_width - 540) / 2)
	safe_root.offset_left += gutter
	safe_root.offset_right -= gutter
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 12)
	mark.hide()
	brand.hide()
	more_button.show()
	subhead.hide()
	move(header, top, 0)
	advice_button.hide()
	move(sizing_row, bet_sheet.content, 0)
	move(amount_slider, bet_sheet.content, 1)
	move(amount_note, bet_sheet.content, 2)
	move(quick_row, bet_sheet.content, 3)
	move(all_in_button, bet_sheet.footer, 0)
	move(raise_button, bet_sheet.footer, 1)
	quick_row.columns = 4
	bet_open_button.visible = host.game == null or host.game.phase != "complete"
	for button in [fold_button, call_button, bet_open_button, raise_button, all_in_button]: button.custom_minimum_size.y = 72
	sidebar.hide()
	table_view.set_portrait(true)
	host.settings.set_portrait(true)
	host.confirmation.set_portrait(true)
	host.review.set_portrait(true)
	lobby_welcome.custom_minimum_size.x = 0
	for i in range(lobby_welcome.get_child_count()): lobby_welcome.get_child(i).visible = i in [0, 1]
	lobby_note.custom_minimum_size = Vector2(0, 60)
	if host.game != null: host._refresh()
	host.modals.sync_focus()
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree() and previous_focus.focus_mode != Control.FOCUS_NONE:
		previous_focus.grab_focus()

func update_explanation(view: Dictionary) -> void:
	if not host.prefs.live_teaching:
		explanation.text = "对局教学已关闭 · 下方保留公开行动记录。"
		return
	if view.phase == "complete":
		explanation.text = "每人选出最佳五张，逐个结算主池和边池。同牌力平分，多出的零头按庄家左侧顺序分配。\n可向下查看各玩家牌型与分池结果。" if view.result.showdown else "只剩一位玩家未弃牌，无需摊牌即可赢得底池。无人跟注的多余投入已退回。"
	elif view.actor == 0:
		var legal = view.legal
		explanation.text = "可以免费过牌。" if legal.check else "需要跟注 %s。" % host._money(legal.call_amount)
		explanation.text += "\nBB 是大盲：本桌 1 BB = 10 筹码。快捷档位只选金额，不会自动下注。\n底池比例：先计入跟注，再按比例加注；不足最小加注会自动调整。"
	else:
		explanation.text = "电脑按座位顺序独立行动，不共享底牌。金色边框标出当前行动者。\n翻牌前由大盲后第一个玩家行动；翻牌后从庄家左侧开始。\n可切换速度，或暂停后查看记录。"

func update_log(view: Dictionary) -> void:
	var lines = ["牌局 ID  " + host.History.hand_id(host.game.record_state())]
	for event in view.events: lines.append(_event_text(event))
	if view.phase == "complete" and view.result.showdown:
		for id in view.result.ranks:
			var rank = view.result.ranks[id]
			lines.append("%s：%s\n最佳五张 %s" % [view.seats[id].name, rank.name, host._cards_text(rank.cards)])
		for index in range(view.result.pots.size()):
			var pot = view.result.pots[index]
			var shares = []
			for id in pot.shares: shares.append("%s +%s" % [view.seats[id].name, host._money(pot.shares[id])])
			lines.append("%s %s：%s" % ["主池" if index == 0 else "边池 %d" % index, host._money(pot.amount), "，".join(shares)])
	log_view.text = "\n\n".join(lines)

func _event_text(event: Dictionary) -> String:
	var name_text = host.game.seats[event.seat].name if event.has("seat") else ""
	match event.kind:
		"start": return "第 %d 手 · %s 为庄家" % [event.hand, host.game.seats[event.button].name]
		"blind": return "%s 下盲注 %s" % [name_text, host._money(event.amount)]
		"action":
			var text = name_text + " " + host.ACTIONS[event.action]
			if event.action == "raise": text += "到 " + host._money(event.to)
			elif event.action == "call": text += " " + host._money(event.paid)
			if event.all_in: text += "（全押）"
			return text
		"street": return "%s  %s" % [host.PHASES[event.phase], host._cards_text(event.board)]
		"refund": return "%s 收回未被跟注的 %s" % [name_text, host._money(event.amount)]
		"finish": return "摊牌结算" if event.showdown else "弃牌结束 · 分配底池"
	return ""
