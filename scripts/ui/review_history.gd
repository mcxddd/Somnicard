extends VBoxContainer
## Depends on host: _open_entry, practice_tools, practice_entry, _select_portrait_tab, analysis_view, record_id_label, _stop_play, live_mode, frames, back, replay_page, title, portrait_tabs, is_visible_in_tree, portrait, use_bb, units, training_store, add_child.
var host
const UI = preload("res://scripts/ui/style.gd")
const HistoryFilter = preload("res://scripts/poker/history_filter.gd")
const History = preload("res://scripts/poker/history.gd")
const TouchScroll = preload("res://scripts/ui/touch_scroll.gd")
const CardView = preload("res://scripts/ui/card_view.gd")
const Segmented = preload("res://scripts/ui/segmented.gd")
const PAGE_SIZE = 25
var page: int = 0
var filenames: Array = []
var entries: Array = []
var history_list: ItemList
var history_status: Label
## Real-game totals for the hands the current filters select.
var stats_box: VBoxContainer
var empty_art: TextureRect
var previous_page: Button
var next_page: Button
var history_scroll
var list_offset: int = 0
var history_restore_generation: int = 0
var history_cards: VBoxContainer
var open_button: Button
var history_directory: String = History.DIRECTORY
var history_catalog: Array = []
var all_filenames: Array = []
var scan_cursor: int = -1
var search: LineEdit
var filter_button: Button
var filter_panel: VBoxContainer
var filter_sheet
var active_row: HBoxContainer
var active_label: Label
var filters: Dictionary = {}
var filter_timer: Timer
var reset_filters: Button


func build() -> void:
	stats_box = VBoxContainer.new()
	self.add_child(stats_box)
	history_status = UI.label("", 18, UI.MUTED)
	history_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	self.add_child(history_status)
	empty_art = UI.art(preload("res://assets/art/empty-history.png"), 170)
	self.add_child(empty_art)
	empty_art.hide()
	_build_history_filters()
	history_list = ItemList.new()
	history_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history_list.add_theme_font_size_override("font_size", 21)
	history_list.add_theme_constant_override("v_separation", 18)
	history_list.add_theme_stylebox_override("panel", UI.surface(Color("10252d"), 12, 12))
	for state in ["selected", "selected_focus"]: history_list.add_theme_stylebox_override(state, UI.surface(Color("22584d"), 8, 8))
	history_list.add_theme_color_override("font_color", UI.TEXT)
	history_list.item_activated.connect(host._open_entry)
	self.add_child(history_list)
	history_scroll = TouchScroll.new()
	history_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	history_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	self.add_child(history_scroll)
	history_cards = VBoxContainer.new()
	history_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_cards.add_theme_constant_override("separation", 10)
	history_scroll.add_child(history_cards)
	history_scroll.hide()
	var paging = HBoxContainer.new()
	paging.add_theme_constant_override("separation", 14)
	self.add_child(paging)
	previous_page = UI.button("上一页", func(): page -= 1; list_offset = 0; _fill_history())
	next_page = UI.button("下一页", func(): page += 1; list_offset = 0; _fill_history())
	paging.add_child(previous_page)
	paging.add_child(next_page)
	open_button = UI.button("打开选中牌局", func():
		if not history_list.get_selected_items().is_empty(): host._open_entry(history_list.get_selected_items()[0]), UI.GREEN)
	open_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paging.add_child(open_button)

func show_history() -> void:
	if host.practice_tools != null:
		host.practice_tools.hide()
		host.practice_entry.hide()
	host._select_portrait_tab(false)
	host.analysis_view.coach_avatar.hide()
	host.record_id_label.hide()
	host._stop_play()
	host.analysis_view.job = null
	host.live_mode = false
	host.frames = []
	host.back.hide()
	host.units.show()
	self.show()
	host.replay_page.hide()
	host.title.text = "历史牌局"
	host.portrait_tabs.hide()
	all_filenames = History.files(history_directory)
	history_catalog.clear()
	filenames.clear()
	entries.clear()
	history_list.clear()
	UI.clear(history_cards)
	scan_cursor = 0
	_scan_history()

func _fill_history() -> void:
	var selected: int = history_list.get_selected_items()[0] if not history_list.get_selected_items().is_empty() else 0
	history_list.clear()
	UI.clear(history_cards)
	entries.clear()
	previous_page.disabled = page == 0
	next_page.disabled = (page + 1) * PAGE_SIZE >= filenames.size()
	history_status.text = "暂无历史牌局。完成一手后会自动保存；换桌和重启应用后仍可复盘。" if filenames.is_empty() else "共 %d 手 · 第 %d / %d 页 · 选中牌局后打开；损坏的文件不会影响其他记录。" % [filenames.size(), page + 1, ceili(float(filenames.size()) / PAGE_SIZE)]
	for i in range(page * PAGE_SIZE, mini((page + 1) * PAGE_SIZE, filenames.size())):
		var loaded = History.read_record(history_directory.path_join(filenames[i]))
		entries.append(loaded)
		var label: String = filenames[i]
		if loaded.has("record"):
			label = _record_label(loaded.record, filenames[i])
		else: label += "  · 无法读取"
		history_list.add_item(label)
		var entry_index = entries.size() - 1
		var card = _history_card(loaded.get("record", {}), label, func():
			if history_scroll.can_activate():
				list_offset = history_scroll.scroll_vertical
				history_list.select(entry_index)
				host._open_entry(entry_index))
		history_cards.add_child(card)
	history_restore_generation += 1
	_restore_history_offset.call_deferred(history_restore_generation, list_offset)
	if history_list.item_count > 0: history_list.select(mini(selected, history_list.item_count - 1))
	if not filenames.is_empty(): history_status.text = "找到 %d / %d 手 · 第 %d / %d 页" % [filenames.size(), all_filenames.size(), page + 1, ceili(float(filenames.size()) / PAGE_SIZE)]
	elif not all_filenames.is_empty(): history_status.text = "没有符合条件的牌局。可清空搜索或重置筛选。"

func _restore_history_offset(generation: int, target: int) -> void:
	# The scrollbar range settles only after the rebuilt card containers have laid out.
	await get_tree().process_frame
	await get_tree().process_frame
	if generation == history_restore_generation and host.is_visible_in_tree() and self.visible and history_scroll.pointer == -2:
		history_scroll.reset_scroll(target)

## One hand in the list: your two cards, table and time, and the result in colour.
## The full label (with the hand ID) stays in `text`, drawn transparent, for search and tests.
func _history_card(record: Dictionary, label: String, callback: Callable) -> Button:
	# One line of hidden text, so the button height comes from the visible layout.
	var card = UI.button(label.replace("\n", " · "), callback, UI.CARD, 84)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.focus_mode = Control.FOCUS_NONE
	card.tooltip_text = label
	card.clip_text = true
	for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		card.add_theme_color_override(color, Color.TRANSPARENT)
	var inset = MarginContainer.new()
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: inset.add_theme_constant_override("margin_" + edge, 12)
	card.add_child(inset)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	inset.add_child(row)
	var hole = HistoryFilter.hero_hole(record) if not record.is_empty() else []
	var cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 3)
	cards.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cards)
	for i in range(2):
		var face = CardView.new()
		face.custom_minimum_size = Vector2(36, 50)
		face.motion = false
		cards.add_child(face)
		face.set_card(hole[i] if hole.size() == 2 else -1, false, false)
	var lines = VBoxContainer.new()
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(lines)
	var parts = label.split("\n")
	var players = record.get("starting_stacks", []).size() if record.get("starting_stacks") is Array else 0
	var heading = UI.label(("%d 人桌 · " % players if players > 0 else "") + ("第 %d 手" % int(record.hand) if History._integer(record.get("hand"), 1, 100000000) else "牌局"), UI.SIZE_BODY, UI.TEXT)
	lines.add_child(heading)
	var detail = [_short_date(str(record.get("saved_at", parts[0] if parts.size() > 0 else "")))]
	if record.get("events") is Array and record.events.any(func(e): return e is Dictionary and e.get("kind") == "finish" and e.get("showdown") == true): detail.append("摊牌")
	if host.training_store != null and not record.is_empty():
		var m = host.training_store.mark(History.hand_id(record))
		if m.star: detail.append("★ 收藏")
		if m.pending: detail.append("待复习")
	if record.is_empty(): detail = ["无法读取"]
	lines.add_child(UI.label(" · ".join(detail.filter(func(d): return not d.is_empty())), UI.SIZE_CAPTION, UI.MUTED))
	var net_text = ""
	for part in parts:
		if part.begins_with("净变化 "): net_text = part.trim_prefix("净变化 ")
	if not net_text.is_empty():
		var tint = UI.SUCCESS if net_text.begins_with("+") else UI.TEXT if net_text.begins_with("0") else UI.DANGER
		var result = UI.label(net_text, UI.SIZE_HEADING, tint)
		result.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(result)
	for node in [inset, row, cards, lines]: _pass(node)
	return card

func _pass(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control: child.mouse_filter = Control.MOUSE_FILTER_IGNORE

## "2026-11-02 23:34:38" → "今天 23:34" or "11-02 23:34".
func _short_date(stamp: String) -> String:
	if stamp.length() < 16 or not stamp.substr(0, 4).is_valid_int(): return stamp.left(16)
	var day = stamp.left(10)
	var clock = stamp.substr(11, 5)
	if day == Time.get_date_string_from_system(): return "今天 " + clock
	return stamp.substr(5, 5) + " " + clock

func _record_label(record: Dictionary, filename: String) -> String:
	if not record.get("starting_stacks") is Array: return filename + " · 格式待校验"
	var date: String = str(record.get("saved_at", "")).left(30)
	if date.is_empty():
		var stamp = filename.get_slice("-", 0)
		if stamp.is_valid_int() and int(stamp) > 0 and int(stamp) < 4102444800:
			date = Time.get_datetime_string_from_unix_time(int(stamp) + int(Time.get_time_zone_from_system().bias) * 60).replace("T", " ")
		else: date = filename.left(35)
	var hand_text: String = str(int(record.hand)) if History._integer(record.get("hand"), 1, 100000000) else "?"
	var label = "%s%s%d 人桌 · 第 %s 手" % [date, "\n" if host.portrait else "    ·    ", record.starting_stacks.size(), hand_text]
	var result = record.get("result")
	if result is Dictionary and result.get("payouts") is Dictionary and result.get("contributions") is Array and not result.contributions.is_empty():
		var paid = result.payouts.get("0", result.payouts.get(0))
		var contributed = result.contributions[0]
		if History._integer(paid, 0, 900000000) and History._integer(contributed, 0, 100000000) and History._integer(record.get("big_blind"), 1, 1000000):
			var net: int = int(paid) - int(contributed)
			label += ("\n净变化 " if host.portrait else "    ·    净变化 ") + ("+" if net > 0 else "") + UI.money(net, int(record.big_blind), host.use_bb)
	label += ("\n" if host.portrait else " · ") + "ID " + History.hand_id(record)
	if host.training_store != null:
		var m = host.training_store.mark(History.hand_id(record))
		if m.star or m.pending: label += " · " + ("★ 收藏 " if m.star else "") + ("待复习" if m.pending else "")
	return label

func _build_history_filters() -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	self.add_child(row)
	self.move_child(row, 0)
	search = LineEdit.new()
	search.placeholder_text = "搜索牌局 ID 或日期"
	search.clear_button_enabled = true
	search.custom_minimum_size.y = 48
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(search)
	filter_button = UI.outline("筛选", func(): filter_sheet.open("筛选牌局"))
	row.add_child(filter_button)
	# The active conditions in one line under the search box, with a one-tap clear.
	active_row = HBoxContainer.new()
	active_row.add_theme_constant_override("separation", 8)
	self.add_child(active_row)
	self.move_child(active_row, 1)
	active_label = UI.caption("")
	active_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	active_row.add_child(active_label)
	active_row.add_child(UI.link("清除", _reset_history_filters))
	active_row.hide()
	filter_sheet = preload("res://scripts/ui/sheet.gd").new()
	filter_sheet.preferred_height = 760
	host.add_child(filter_sheet)
	filter_panel = VBoxContainer.new()
	filter_panel.add_theme_constant_override("separation", 6)
	filter_sheet.content.add_child(filter_panel)
	# Short labels: each group is a row of chips, "全部" first.
	var labels = {
		"players": ["人数", ["全部", "2", "3", "4", "5", "6", "7", "8", "9"]],
		"result": ["结果", ["全部", "净赢", "净输", "持平"]],
		"days": ["时间", ["全部", "今天", "近 7 天", "近 30 天"]],
		"ending": ["结束方式", ["全部", "有摊牌", "无摊牌"]],
		"action": ["我的行动", ["全部", "全押过", "加注过"]],
		"saved": ["标记", ["全部", "已收藏", "待复习"]],
		"tag": ["标签", ["全部"] + preload("res://scripts/poker/training_store.gd").TAGS],
		"sort": ["排序", ["最近", "底池最大", "亏损最多"]]}
	for key in labels:
		filter_panel.add_child(UI.label(labels[key][0], UI.SIZE_CAPTION, UI.MUTED))
		var picker = Segmented.new()
		for label in labels[key][1]: picker.add_item(label)
		filters[key] = picker
		filter_panel.add_child(picker)
		picker.item_selected.connect(func(_value): _filters_changed())
	# Six tags do not fit one row; let the tag chips wrap onto a second line.
	var tag_picker = filters.tag
	var tag_flow = HFlowContainer.new()
	tag_flow.add_theme_constant_override("h_separation", 4)
	tag_flow.add_theme_constant_override("v_separation", 4)
	filter_panel.add_child(tag_flow)
	filter_panel.move_child(tag_flow, tag_picker.get_index())
	for button in tag_picker.buttons:
		button.size_flags_horizontal = Control.SIZE_FILL
		button.reparent(tag_flow)
	tag_picker.hide()
	reset_filters = UI.outline("重置全部条件", _reset_history_filters)
	reset_filters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_sheet.footer.add_child(reset_filters)
	var done = UI.button("查看结果", func(): filter_sheet.close(), UI.GREEN)
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_sheet.footer.add_child(done)
	filter_timer = Timer.new()
	filter_timer.one_shot = true
	filter_timer.wait_time = 0.18
	host.add_child(filter_timer)
	filter_timer.timeout.connect(_filters_changed)
	search.text_changed.connect(func(_text): filter_timer.start())
	search.text_submitted.connect(func(_text):
		filter_timer.stop()
		search.release_focus()
		DisplayServer.virtual_keyboard_hide()
		_filters_changed())

func _filter_values() -> Dictionary:
	return {"query": search.text, "players": 0 if filters.players.selected == 0 else filters.players.selected + 1,
		"result": filters.result.selected, "days": [0, 1, 7, 30][filters.days.selected],
		"ending": filters.ending.selected, "action": filters.action.selected, "sort": filters.sort.selected}

func _reset_history_filters() -> void:
	search.text = ""
	for picker in filters.values(): picker.select(0)
	_filters_changed()

func _filters_changed() -> void:
	page = 0
	list_offset = 0
	history_scroll.reset_scroll()
	var chosen: Array = []
	for key in filters:
		if filters[key].selected > 0:
			var text = filters[key].get_item_text(filters[key].selected)
			chosen.append(text + " 人桌" if key == "players" else text)
	filter_button.text = "筛选" + (" · %d" % chosen.size() if not chosen.is_empty() else "")
	active_label.text = "已筛选：" + " · ".join(chosen)
	active_row.visible = not chosen.is_empty()
	if scan_cursor < 0: _apply_history_filter()

func _scan_history() -> void:
	var deadline = Time.get_ticks_usec() + 3000
	var handled = 0
	while scan_cursor < all_filenames.size() and handled < 8 and Time.get_ticks_usec() < deadline:
		var file: String = all_filenames[scan_cursor]
		history_catalog.append(HistoryFilter.summary(History.read_record(history_directory.path_join(file)), file))
		scan_cursor += 1
		handled += 1
	previous_page.disabled = true
	next_page.disabled = true
	history_status.text = "正在整理记录 %d / %d…" % [scan_cursor, all_filenames.size()]
	if scan_cursor >= all_filenames.size():
		scan_cursor = -1
		_apply_history_filter()

func _apply_history_filter() -> void:
	var selected_catalog: Array = history_catalog
	if host.training_store != null:
		selected_catalog = history_catalog.filter(func(item):
			var m = host.training_store.mark(item.id)
			if filters.saved.selected == 1 and not m.star: return false
			if filters.saved.selected == 2 and not m.pending: return false
			if filters.tag.selected > 0 and filters.tag.get_item_text(filters.tag.selected) not in m.tags: return false
			return true)
	filenames = HistoryFilter.select(selected_catalog, _filter_values(), Time.get_date_string_from_system())
	_update_stats(selected_catalog)
	page = mini(page, maxi(0, ceili(float(filenames.size()) / PAGE_SIZE) - 1))
	_fill_history()

func _update_stats(catalog: Array) -> void:
	var chosen = {}
	for file in filenames: chosen[file] = true
	var hands = 0
	var net = 0.0
	var vpip = 0
	var pfr = 0
	for item in catalog:
		if not chosen.has(item.file) or not item.valid_result: continue
		hands += 1
		net += float(item.net) / item.big_blind
		vpip += int(item.vpip)
		pfr += int(item.pfr)
	UI.clear(stats_box)
	if hands > 0: stats_box.add_child(UI.stat_row([[str(hands), "手"], ["%+.1f" % net, "净变化 BB", UI.SUCCESS if net > 0 else UI.DANGER if net < 0 else UI.TEXT], ["%.0f%%" % (100.0 * vpip / hands), "主动入池"], ["%.0f%%" % (100.0 * pfr / hands), "翻前加注"]]))
	empty_art.visible = all_filenames.is_empty()
