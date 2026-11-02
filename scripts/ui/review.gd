extends ColorRect
signal practice_requested(record: Dictionary, point: int)
signal closed
signal units_changed(use_bb: bool)
signal teaching_changed(live: bool, enabled: bool)
const UI = preload("res://scripts/ui/style.gd")
const UnitSwitch = preload("res://scripts/ui/unit_switch.gd")
const History = preload("res://scripts/poker/history.gd")
const Advisor = preload("res://scripts/poker/advisor.gd")
const TableView = preload("res://scripts/ui/table_view.gd")
const Eval = preload("res://scripts/poker/evaluator.gd")
const PHASES = {"preflop": "翻牌前", "flop": "翻牌", "turn": "转牌", "river": "河牌", "complete": "结算"}
const ACTIONS = {"fold": "弃牌", "check": "过牌", "call": "跟注", "raise": "加注"}
var use_bb: bool = true
var frames: Array = []
var index: int = 0
var live_mode: bool = false
var title: Label
var units
var back: Button
var history_page
var analysis_view
var replay_page: HBoxContainer
var table_view
var slider: HSlider
var position_label: Label
var prev: Button
var next: Button
var play: Button
var mine: Button
var street: OptionButton
var timer: Timer
var close_button: Button
var portrait: bool = false
var column: VBoxContainer
var header: HBoxContainer
var left: VBoxContainer
var analysis_panel: PanelContainer
var transport: GridContainer
var portrait_tabs: HBoxContainer
var replay_tab: Button
var analysis_tab: Button
var analysis_selected: bool = false
var replay_event: Label
var selected_seat: int = -1
var margin: MarginContainer
var record_id_label: Label
const Profiles = preload("res://scripts/poker/opponent_profiles.gd")
const Practice = preload("res://scripts/poker/practice.gd")
const Notes = preload("res://scripts/ui/hand_notes.gd")
var training_store
var current_record: Dictionary = {}
var practice_tools: VBoxContainer
var practice_button: Button
var points_picker: OptionButton
var decision_points: Array = []
var notes
var practice_sheet
var practice_entry: Button
var comparison_button: Button


func _ready() -> void:
	color = Color("0b1c23")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 20)
	add_child(margin)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	back = UI.outline("‹ 历史列表", func(): history_page.show_history())
	header.add_child(back)
	title = UI.label("牌局复盘", 26, UI.TEXT)
	title.clip_text = true
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	record_id_label = UI.label("", 15, UI.MUTED)
	column.add_child(record_id_label)
	record_id_label.hide()
	units = UnitSwitch.new()
	units.custom_minimum_size = Vector2(110, 48)
	units.item_selected.connect(func(value): set_units(value == 1); units_changed.emit(use_bb))
	header.add_child(units)
	close_button = UI.outline("返回练习", close)
	header.add_child(close_button)
	history_page = preload("res://scripts/ui/review_history.gd").new()
	history_page.host = self
	history_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history_page.add_theme_constant_override("separation", 14)
	column.add_child(history_page)
	history_page.build()
	replay_page = HBoxContainer.new()
	replay_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	replay_page.add_theme_constant_override("separation", 16)
	column.add_child(replay_page)
	left = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	replay_page.add_child(left)
	table_view = TableView.new()
	table_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(table_view)
	position_label = UI.label("", 18, UI.GOLD)
	position_label.clip_text = true
	left.add_child(position_label)
	slider = HSlider.new()
	slider.custom_minimum_size.y = 36
	slider.step = 1
	slider.value_changed.connect(func(value): seek(int(value)))
	left.add_child(slider)
	transport = GridContainer.new()
	transport.columns = 5
	transport.add_theme_constant_override("h_separation", 8)
	transport.add_theme_constant_override("v_separation", 8)
	transport.add_theme_constant_override("separation", 8)
	left.add_child(transport)
	prev = UI.button("‹ 上一步", func(): seek(index - 1))
	play = UI.button("播放", _toggle_play)
	next = UI.button("下一步 ›", func(): seek(index + 1))
	mine = UI.button("我的下个决策", next_decision, UI.GREEN)
	for button in [prev, play, next, mine]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		transport.add_child(button)
	street = OptionButton.new()
	street.custom_minimum_size = Vector2(106, 48)
	for text in PHASES.values(): street.add_item(text)
	street.item_selected.connect(_jump_street)
	transport.add_child(street)
	var panel = UI.panel(UI.CARD, 18, 14)
	analysis_panel = panel
	panel.custom_minimum_size.x = 326
	add_child(panel)
	analysis_view = preload("res://scripts/ui/review_analysis.gd").new()
	analysis_view.host = self
	analysis_view.add_theme_constant_override("separation", 8)
	panel.add_child(analysis_view)
	analysis_view.build()
	timer = Timer.new()
	timer.wait_time = 0.9
	timer.timeout.connect(func():
		seek(index + 1, false)
		if index == frames.size() - 1 or _hero_decision(): _stop_play())
	add_child(timer)
	portrait_tabs = HBoxContainer.new()
	portrait_tabs.add_theme_constant_override("separation", 12)
	column.add_child(portrait_tabs)
	column.move_child(portrait_tabs, 1)
	replay_tab = UI.button("牌桌回放", _select_portrait_tab.bind(false))
	analysis_tab = UI.button("决策分析", _select_portrait_tab.bind(true))
	for tab in [replay_tab, analysis_tab]:
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		portrait_tabs.add_child(tab)
	portrait_tabs.hide()
	replay_event = UI.label("", 17, UI.MUTED)
	replay_event.clip_text = true
	left.add_child(replay_event)
	left.move_child(replay_event, 2)
	replay_event.hide()
	table_view.seat_selected.connect(_show_seat)
	_build_practice_tools()
	hide()

func _build_practice_tools() -> void:
	practice_sheet = preload("res://scripts/ui/sheet.gd").new()
	add_child(practice_sheet)
	practice_entry = UI.button("工具", func(): practice_sheet.open("收藏、练习与关键决策"))
	header.add_child(practice_entry)
	header.move_child(practice_entry, 1)
	practice_entry.hide()
	practice_tools = VBoxContainer.new()
	practice_tools.add_theme_constant_override("separation", 6)
	practice_sheet.content.add_child(practice_tools)
	practice_tools.add_child(UI.button("标记", func():
		practice_sheet.close()
		if training_store != null: notes.edit(training_store, History.hand_id(current_record))))
	practice_button = UI.button("练习此处", func():
		for p in decision_points:
			if p.frame == index:
				_stop_play()
				practice_sheet.close()
				practice_requested.emit(current_record, p.point)
				return)
	practice_tools.add_child(practice_button)
	comparison_button = UI.button("切换原局 / 重打", func():
		practice_sheet.close()
		analysis_view.open_comparison(analysis_view.comparisons, 1 - analysis_view.comparison_index, use_bb))
	practice_tools.add_child(comparison_button)
	comparison_button.hide()
	points_picker = OptionButton.new()
	points_picker.fit_to_longest_item = false
	points_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	points_picker.custom_minimum_size.y = 48
	points_picker.item_selected.connect(func(i):
		if i > 0:
			practice_sheet.close()
			seek(decision_points[i - 1].frame)
			_select_portrait_tab(true)
			if analysis_view.teaching_enabled(): analysis_view._analyze())
	practice_tools.add_child(points_picker)
	# The hand ID is reference detail; it lives with the tools rather than under the title.
	record_id_label.reparent(practice_tools)
	practice_tools.hide()
	notes = Notes.new()
	add_child(notes)
	notes.saved.connect(func():
		if history_page.scan_cursor < 0 and history_page.visible: history_page._apply_history_filter())

func open_history(bb: bool) -> void:
	use_bb = bb
	units.select(1 if bb else 0)
	show()
	history_page.show_history()
	close_button.grab_focus()

func _open_entry(entry: int) -> void:
	if entry < 0 or entry >= history_page.entries.size(): return
	var loaded = history_page.entries[entry]
	if loaded.has("error"):
		history_page.history_status.text = loaded.error
		return
	var rebuilt = History.replay(loaded.record)
	if rebuilt.has("error"):
		history_page.history_status.text = "无法打开这手牌：" + rebuilt.error + "。可以选择其他记录继续练习。"
		return
	open_replay(rebuilt, use_bb)

func open_replay(rebuilt: Dictionary, bb: bool) -> void:
	analysis_view.comparisons = []
	if comparison_button != null: comparison_button.hide()
	live_mode = false
	current_record = rebuilt.record.duplicate(true)
	decision_points = Practice.points(rebuilt)
	if practice_tools != null:
		practice_tools.show()
		practice_entry.show()
		points_picker.clear()
		points_picker.add_item("关键决策")
		for p in decision_points:
			points_picker.add_item("%s · %s" % [PHASES[p.view.phase], " / ".join(p.tags) if not p.tags.is_empty() else p.topic])
	if training_store != null: training_store.seen(History.hand_id(current_record))
	analysis_view.expanded_details = false
	record_id_label.text = "牌局 ID " + History.hand_id(rebuilt.record)
	record_id_label.show()
	use_bb = bb
	units.select(1 if bb else 0)
	# The replay header keeps only list, tools and return; units follow the table menu.
	units.hide()
	frames = rebuilt.frames
	history_page.hide()
	replay_page.show()
	back.show()
	title.text = "%d 人桌 · 第 %d 手 · 复盘" % [rebuilt.record.starting_stacks.size(), rebuilt.record.hand]
	_select_portrait_tab(false)
	show()
	seek(0)

func open_live(view: Dictionary, bb: bool) -> void:
	if practice_tools != null:
		practice_tools.hide()
		practice_entry.hide()
	live_mode = true
	analysis_view.expanded_details = true
	record_id_label.hide()
	use_bb = bb
	units.select(1 if bb else 0)
	units.hide()
	frames = [{"view": view.duplicate(true), "event": {"kind": "decision", "seat": 0}, "decision": true}]
	history_page.hide()
	replay_page.show()
	back.hide()
	title.text = "当前决策 · 练习提示"
	_select_portrait_tab(true)
	show()
	seek(0)
	analysis_view._analyze()
	close_button.grab_focus()

func close() -> void:
	_stop_play()
	analysis_view.job = null
	hide()
	closed.emit()

func back_action() -> void:
	if practice_sheet != null and practice_sheet.visible:
		practice_sheet.close()
		return
	if notes != null and notes.visible:
		notes.close()
		return
	if analysis_selected: _select_portrait_tab(false)
	else: close()

func _toggle_coach() -> void:
	_select_portrait_tab(not analysis_selected)
	if analysis_selected and _hero_decision() and analysis_view.teaching_enabled() and analysis_view.analysis.is_empty(): analysis_view._analyze()

func set_units(bb: bool) -> void:
	use_bb = bb
	units.select(1 if bb else 0)
	if not frames.is_empty(): _render()
	elif history_page.visible and history_page.scan_cursor < 0:
		history_page.list_offset = history_page.history_scroll.scroll_vertical
		history_page._fill_history()

func seek(value: int, stop: bool = true) -> void:
	if frames.is_empty(): return
	if stop: _stop_play()
	index = clampi(value, 0, frames.size() - 1)
	selected_seat = -1
	analysis_view.analysis_scroll.reset_scroll()
	analysis_view.job = null
	analysis_view.analysis = {}
	if _hero_decision() and analysis_view.teaching_enabled(): analysis_view.analysis = analysis_view.cache.get(Advisor.cache_key(frames[index].view), {})
	analysis_view.range_box.hide()
	analysis_view.range_button.text = "展开对手范围 ▾"
	analysis_view._fill_ranges()
	_render()
	if analysis_selected and _hero_decision() and analysis_view.teaching_enabled() and analysis_view.analysis.is_empty(): analysis_view._analyze()

func _hero_decision() -> bool:
	return not frames.is_empty() and frames[index].decision and frames[index].view.actor == 0 and not frames[index].view.legal.is_empty()

func next_decision() -> void:
	for step in range(1, frames.size() + 1):
		var candidate = (index + step) % frames.size()
		if frames[candidate].decision and frames[candidate].view.actor == 0:
			seek(candidate)
			return

func _jump_street(value: int) -> void:
	var phase = PHASES.keys()[value]
	for i in range(frames.size()):
		if frames[i].view.phase == phase:
			seek(i)
			return
	street.select(PHASES.keys().find(frames[index].view.phase))

func _toggle_play() -> void:
	if not timer.is_stopped(): _stop_play()
	else:
		if index == frames.size() - 1: seek(0)
		timer.start()
		play.text = "暂停" if portrait else "暂停回放"

func _stop_play() -> void:
	if timer == null: return
	timer.stop()
	play.text = "播放"

func _render() -> void:
	if practice_tools != null: practice_button.disabled = not _hero_decision()
	var frame = frames[index]
	var view: Dictionary = frame.view.duplicate(true)
	transport.visible = not live_mode
	slider.visible = not live_mode
	position_label.visible = not live_mode
	if not live_mode:
		var profiles = Profiles.record_snapshot(current_record, view.events.size())
		if not profiles.is_empty():
			for seat in view.seats:
				if seat.id > 0: seat["style"] = Profiles.label(Profiles.resolve(profiles, seat.id, 1))
	table_view.update_table(view, use_bb)
	position_label.text = "%d / %d · %s" % [index + 1, frames.size(), _describe(frame.event, view).replace("\n", " · ")]
	position_label.tooltip_text = position_label.text
	slider.set_block_signals(true)
	slider.max_value = frames.size() - 1
	slider.value = index
	slider.set_block_signals(false)
	slider.editable = not live_mode
	prev.disabled = index == 0
	next.disabled = index == frames.size() - 1
	play.disabled = live_mode
	mine.disabled = live_mode or not frames.any(func(f): return f.decision and f.view.actor == 0)
	street.disabled = live_mode
	street.select(PHASES.keys().find(view.phase))
	for i in range(PHASES.size()): street.set_item_disabled(i, not frames.any(func(f): return f.view.phase == PHASES.keys()[i]))
	analysis_view.event_label.hide()
	analysis_view.event_label.text = _describe(frame.event, view)
	analysis_view.context_row.visible = _hero_decision()
	if _hero_decision():
		analysis_view.event_label.text = "%s · 底池 %s\n你的手牌 / 当时公共牌" % [PHASES.get(view.phase, ""), _money(view.pot)]
		for i in range(7):
			var cards: Array = view.seats[0].hole if i < 2 else view.board
			var offset = i if i < 2 else i - 2
			analysis_view.context_cards[i].set_card(cards[offset] if offset < cards.size() else -2, table_view.four_color, false)
	replay_event.text = analysis_view.event_label.text.replace("\n", " · ")
	analysis_view.analyze_button.disabled = not _hero_decision() or analysis_view.job != null
	analysis_view._render_details()

func _describe(event: Dictionary, view: Dictionary) -> String:
	var name_text: String = view.seats[int(event.seat)].name if event.has("seat") else ""
	match event.kind:
		"decision": return name_text + "的决策点\n操作发生前的信息"
		"start": return "发出两张底牌\n对手底牌保持隐藏"
		"blind": return name_text + " 下盲注 " + _money(event.amount)
		"action": return name_text + " " + ACTIONS[event.action] + ("到 " + _money(event.to) if event.action == "raise" else " " + _money(event.paid) if event.action == "call" else "") + (" · 全押" if event.all_in else "")
		"street": return "发出" + PHASES[view.phase] + "公共牌"
		"refund": return name_text + " 收回未跟注筹码 " + _money(event.amount)
		"finish": return "摊牌结算" if event.showdown else "对手弃牌 · 直接结算"
	return ""

func _precise_money(value: float) -> String:
	return "%.3f BB" % (value / frames[index].view.big_blind) if use_bb else "%.2f 筹码" % value

func _money(value: int) -> String:
	return UI.money(value, frames[index].view.big_blind, use_bb)

func _process(_delta: float) -> void:
	if visible and history_page.visible and history_page.scan_cursor >= 0: history_page._scan_history()
	_layout_overlay()

func set_portrait(value: bool) -> void:
	portrait = value
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 12 if portrait else 20)
	table_view.set_portrait(value)
	transport.columns = 5
	mine.text = "我的决策" if portrait else "我的下个决策"
	prev.text = "‹" if portrait else "‹ 上一步"
	next.text = "›" if portrait else "下一步 ›"
	prev.tooltip_text = "上一步"
	next.tooltip_text = "下一步"
	back.text = "‹ 列表" if portrait else "‹ 历史列表"
	replay_event.hide()
	analysis_panel.custom_minimum_size.x = 0 if portrait else 326
	analysis_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if portrait else Control.SIZE_FILL
	analysis_view.event_label.custom_minimum_size = Vector2(0 if portrait else 294, 36)
	if title.get_parent() != (column if portrait else header): title.reparent(column if portrait else header)
	if portrait:
		column.move_child(title, 1)
		column.move_child(portrait_tabs, 2)
	else: header.move_child(title, 1)
	title.add_theme_font_size_override("font_size", 22 if portrait else 26)
	history_page.history_list.add_theme_font_size_override("font_size", 19 if portrait else 21)
	history_page.history_list.max_text_lines = 2 if portrait else 1
	history_page.history_list.visible = not portrait
	history_page.history_scroll.visible = portrait
	history_page.open_button.visible = not portrait
	_select_portrait_tab(analysis_selected)
	if history_page.visible and visible and history_page.scan_cursor < 0:
		history_page.list_offset = history_page.history_scroll.scroll_vertical
		history_page._fill_history()

func _select_portrait_tab(analyze: bool) -> void:
	analysis_selected = analyze
	portrait_tabs.hide()
	left.show()
	analysis_panel.visible = replay_page.visible and analyze
	analysis_view.coach_avatar.visible = replay_page.visible and not analyze
	if analyze: _stop_play()
	else: analysis_view.job = null
	_layout_overlay()

func _layout_overlay() -> void:
	if analysis_view.coach_avatar == null or not replay_page.visible: return
	var table_rect = table_view.get_global_rect()
	analysis_view.coach_avatar.position = table_rect.end - global_position - Vector2(78, 82)
	analysis_view.coach_avatar.size = Vector2(72, 78)
	# Keep the actual community cards visible even on the shortest portrait screens.
	var below_board = table_rect.end.y - table_view.board_row.get_global_rect().end.y - 8
	analysis_panel.size = Vector2(size.x - 24, minf(340 if analysis_view.expanded_details else 270, maxf(180, below_board)))
	analysis_panel.position = Vector2(12, table_rect.end.y - global_position.y - analysis_panel.size.y)

func _show_seat(id: int) -> void:
	if frames.is_empty(): return
	_stop_play()
	var seat = frames[index].view.seats[id]
	selected_seat = id
	analysis_view.event_label.show()
	analysis_view.details_column.move_child(analysis_view.event_label, 0)
	analysis_view.event_label.text = table_view.seat_nodes[id].panel.tooltip_text
	var cards: Array = []
	for card in seat.hole: cards.append(Eval.card_text(card))
	analysis_view.event_label.text += "\n底牌：" + (" ".join(cards) if not cards.is_empty() else "当时未公开")
	_select_portrait_tab(true)
