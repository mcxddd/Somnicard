extends ColorRect
signal closed
signal replay_requested(record: Dictionary)
const UI = preload("res://scripts/ui/style.gd")
const History = preload("res://scripts/poker/history.gd")
const Practice = preload("res://scripts/poker/practice.gd")
const Advisor = preload("res://scripts/poker/advisor.gd")
const Teaching = preload("res://scripts/poker/teaching.gd")
const Profiles = preload("res://scripts/poker/opponent_profiles.gd")
const Bot = preload("res://scripts/poker/local_bot.gd")
const TableView = preload("res://scripts/ui/table_view.gd")
const Scroll = preload("res://scripts/ui/touch_scroll.gd")
const UnitSwitch = preload("res://scripts/ui/unit_switch.gd")
const Notes = preload("res://scripts/ui/hand_notes.gd")
var store
var history_directory = History.DIRECTORY
var use_bb = true
var difficulty = 1
var opponent_profiles: Array = Profiles.normalize([])
var case_profiles: Array = []
var speed = 0.65
var hub_tabs: HBoxContainer
var hub_pages: Array = []
var hub_buttons: Array = []
var hub_page: int = 0
var return_text: String = "‹ 返回"
var hub: VBoxContainer
var hub_scroll
var case_page: VBoxContainer
var status: Label
var report: Label
var topic_picker: OptionButton
var source_picker: OptionButton
var stats_seats: OptionButton
var stats_days: OptionButton
var start_button: Button
var resume_button: Button
var branch_picker: OptionButton
var recommended_list: VBoxContainer
var recent_list: VBoxContainer
var close_button: Button
var table_view
var mode_picker: OptionButton
var prompt: Label
var body_scroll
var body: VBoxContainer
var action_row: HBoxContainer
var fold: Button
var call: Button
var raise: Button
var amount: SpinBox
var sizing: VBoxContainer
var feedback: Label
var detail: RichTextLabel
var answer_area: VBoxContainer
var continue_button: Button
var next_button: Button
var unclear: CheckButton
var notes
var candidates: Array = []
var records: Array = []
var scan_files: Array = []
var scan_cursor = -1
var queue: Array = []
var cursor = 0
var current: Dictionary = {}
var builder
var game
var decision_view: Dictionary = {}
var answer: Dictionary = {}
var analysis: Dictionary = {}
var job
var playing = false
var branch_id = ""
var bot_wait = 0.0
var bots: Dictionary = {}
var exporting = false
var units
var details_expanded = false
var detail_button: Button
var branch_review_button: Button
var summary: Label
var branch_paused = false
var pause_button: Button
var answer_actions: HBoxContainer

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
	hub = VBoxContainer.new()
	hub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hub.add_theme_constant_override("separation", 14)
	hub_scroll.add_child(hub)
	for i in range(3):
		var page = VBoxContainer.new()
		page.add_theme_constant_override("separation", 14)
		hub.add_child(page)
		hub_pages.append(page)
	hub_pages[0].add_child(_label("从一个决定开始", 28, UI.GOLD))
	hub_pages[0].add_child(_label("每组最多 5 个局面。先选择，再看理由；需要时换种打法继续打完。", 18))
	topic_picker = _picker(["主题：全部", "翻前入池", "面对下注", "加注尺度", "河牌判断"], hub_pages[0])
	source_picker = _picker(["来源：全部", "我的收藏", "待复习", "我的历史", "固定练习", "教练建议复盘", "尚未练过的局面"], hub_pages[0])
	start_button = UI.button("开始一组练习", start_set, UI.GREEN, 56)
	hub_pages[0].add_child(start_button)
	resume_button = UI.button("继续未完成的练习", resume_set)
	hub_pages[0].add_child(resume_button)
	hub_pages[0].add_child(_label("最近值得回看的决定", 22, UI.GOLD))
	recommended_list = VBoxContainer.new()
	hub_pages[0].add_child(recommended_list)
	hub_pages[2].add_child(_label("练习与对局概览", 23, UI.GOLD))
	var stats = HBoxContainer.new()
	hub_pages[2].add_child(stats)
	stats_seats = _picker(["桌型：全部", "2 人", "3 人", "4 人", "5 人", "6 人", "7 人", "8 人", "9 人"], stats)
	stats_days = _picker(["时间：全部", "今天", "近 7 天", "近 30 天"], stats)
	stats_seats.item_selected.connect(func(_i): _report())
	stats_days.item_selected.connect(func(_i): _report())
	report = _label("", 18)
	hub_pages[2].add_child(report)
	hub_pages[1].add_child(_label("最近练习 · 可再次作答", 22, UI.GOLD))
	recent_list = VBoxContainer.new()
	hub_pages[1].add_child(recent_list)
	branch_picker = _picker(["选择已保存的重打分支"], hub_pages[1])
	branch_picker.item_selected.connect(_open_branch)
	case_page = VBoxContainer.new()
	case_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(case_page)
	prompt = _label("", 16, UI.GOLD)
	case_page.add_child(prompt)
	table_view = TableView.new()
	table_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	case_page.add_child(table_view)
	table_view.set_portrait(true)
	table_view.custom_minimum_size = Vector2(0, 300)
	body_scroll = Scroll.new()
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.size_flags_stretch_ratio = 0.85
	case_page.add_child(body_scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	body_scroll.add_child(body)
	mode_picker = _picker(["重打：重新采样未知牌", "重打：保留原牌"], body)
	pause_button = UI.button("暂停重打", func(): branch_paused = not branch_paused; _persist(); _render_case())
	body.add_child(pause_button)
	mode_picker.item_selected.connect(func(_i): _persist(); _render_case())
	sizing = VBoxContainer.new()
	body.add_child(sizing)
	sizing.add_child(_label("加到（本轮总投入）", 16))
	amount = SpinBox.new()
	amount.custom_minimum_size.y = 48
	sizing.add_child(amount)
	var quick = HBoxContainer.new()
	sizing.add_child(quick)
	for choice in [["最小", 0.0], ["半池", 0.5], ["满池", 1.0], ["全押", -1.0]]:
		var button = UI.button(choice[0], _quick.bind(choice[1]))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		quick.add_child(button)
	action_row = HBoxContainer.new()
	case_page.add_child(action_row)
	fold = UI.button("弃牌", submit.bind("fold"))
	call = UI.button("过牌", submit.bind("check_call"), UI.GREEN)
	raise = UI.button("加注", submit.bind("raise"))
	for b in [fold, call, raise]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 56
		action_row.add_child(b)
	answer_area = VBoxContainer.new()
	answer_area.add_theme_constant_override("separation", 10)
	body.add_child(answer_area)
	feedback = _label("", 20, UI.GOLD)
	answer_area.add_child(feedback)
	summary = _label("", 18, UI.TEXT)
	answer_area.add_child(summary)
	detail_button = UI.button("展开具体理由", func():
		details_expanded = not details_expanded
		_render_case())
	answer_area.add_child(detail_button)
	detail = RichTextLabel.new()
	detail.fit_content = true
	detail.scroll_active = false
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_theme_font_size_override("normal_font_size", 19)
	answer_area.add_child(detail)
	unclear = CheckButton.new()
	unclear.text = "还没理解 · 加入待复习"
	unclear.custom_minimum_size.y = 48
	unclear.toggled.connect(func(v):
		if answer.has("attempt"): store.set_unclear(answer.attempt, v))
	answer_area.add_child(unclear)
	continue_button = UI.button("用我的选择继续打", begin_branch, UI.GREEN, 52)
	answer_area.add_child(continue_button)
	answer_area.add_child(UI.button("查看原牌局回放", func():
		store.seen(History.hand_id(current.record))
		replay_requested.emit(current.record)))
	branch_review_button = UI.button("回放 / 对比重打分支", func(): _review_branch(branch_id))
	answer_area.add_child(branch_review_button)
	next_button = UI.button("下一个局面", next_case, UI.GREEN, 52)
	answer_actions = HBoxContainer.new()
	case_page.add_child(answer_actions)
	continue_button.reparent(answer_actions)
	answer_actions.add_child(next_button)
	for b in [continue_button, next_button]: b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	continue_button.text = "继续重打"
	body.add_child(UI.button("收藏 / 备注", func(): notes.edit(store, History.hand_id(current.record))))
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
	for i in range(hub_pages.size()):
		hub_pages[i].visible = i == index
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
	job = null
	builder = null
	playing = false
	game = null
	start_button.disabled = true
	resume_button.visible = not store.data.session.is_empty()
	candidates.clear()
	records.clear()
	for r in Practice.fixtures(): _add_record(r)
	scan_files = History.files(history_directory)
	scan_cursor = 0
	_scan()

func _add_record(r: Dictionary) -> void:
	var rebuilt = History.replay(r)
	if rebuilt.has("error"): return
	if not r.get("fixture", false): records.append(r)
	for p in Practice.points(rebuilt):
		candidates.append({"record": r, "point": p.point, "topic": p.topic})

func _scan() -> void:
	var deadline = Time.get_ticks_usec() + 4000
	while scan_cursor < scan_files.size() and Time.get_ticks_usec() < deadline:
		var r = History.read_record(history_directory.path_join(scan_files[scan_cursor]))
		scan_cursor += 1
		if not r.has("error"): _add_record(r.record)
	status.text = "整理可练习局面 %d / %d" % [scan_cursor, scan_files.size()]
	if scan_cursor >= scan_files.size():
		scan_cursor = -1
		status.text = store.error if not store.error.is_empty() else "离线训练 · 练习输赢不计入对局统计"
		start_button.disabled = false
		_report()
		_recent()

func start_set() -> void:
	if scan_cursor >= 0: return
	var picked: Array = []
	for c in candidates:
		if topic_picker.selected > 0 and c.topic != topic_picker.get_item_text(topic_picker.selected): continue
		var fixed: bool = c.record.get("fixture", false)
		var m = store.mark(History.hand_id(c.record))
		if source_picker.selected == 1 and not m.star: continue
		if source_picker.selected == 2 and not m.pending: continue
		if source_picker.selected == 3 and fixed: continue
		if source_picker.selected == 4 and not fixed: continue
		if source_picker.selected == 5 and not store.data.get("decisions", {}).has(History.hand_id(c.record) + ":" + str(c.point)): continue
		if source_picker.selected == 6 and store.data.attempts.any(func(a): return a.hand == History.hand_id(c.record) and a.point == c.point): continue
		picked.append(c)
	if picked.is_empty():
		status.text = "当前条件没有局面。可选择固定练习，或先收藏一手历史牌局。"
		return
	var counts = {}
	for a in store.data.attempts:
		var key: String = a.hand + ":" + str(a.point)
		counts[key] = counts.get(key, 0) + 1
	picked.shuffle()
	picked.sort_custom(func(a, b): return counts.get(History.hand_id(a.record) + ":" + str(a.point), 0) < counts.get(History.hand_id(b.record) + ":" + str(b.point), 0))
	queue = picked.slice(0, 5)
	cursor = 0
	_load_case()

func open_case(record: Dictionary, point: int) -> void:
	queue = [{"record": record.duplicate(true), "point": point, "topic": "决策练习"}]
	cursor = 0
	_load_case()

func _load_case(saved: Dictionary = {}) -> void:
	units.select(1 if use_bb else 0)
	details_expanded = false
	current = queue[cursor]
	var original = Practice.new(current.record, int(current.point), "original")
	if not original.error.is_empty():
		status.text = original.error
		return
	game = original.game
	decision_view = game.view_for(0)
	current.topic = Practice.topic(decision_view)
	answer = saved.get("answer", {}).duplicate(true)
	analysis = {}
	branch_id = saved.get("branch_id", "")
	playing = false
	branch_paused = false
	builder = null
	job = null
	bots.clear()
	case_profiles = Profiles.snapshot(opponent_profiles, game.seats.size(), difficulty)
	# Replay a historical decision using the setup known at that action boundary.
	var archived_profiles = Profiles.record_snapshot(current.record, game.events.size())
	if not archived_profiles.is_empty(): case_profiles = Profiles.snapshot(archived_profiles, game.seats.size(), difficulty)
	if saved.get("opponents") is Array: case_profiles = Profiles.snapshot(Profiles.normalize(saved.opponents), game.seats.size(), difficulty)
	for id in range(1, game.seats.size()):
		var p = case_profiles[id - 1]
		bots[id] = Bot.new(-1, p.aggression, p.difficulty)
		game.seats[id]["style"] = bots[id].style_name()
	mode_picker.select(int(saved.get("mode", 0)))
	show()
	hub_scroll.hide()
	hub_tabs.hide()
	close_button.text = "‹ 训练室"
	case_page.show()
	amount.value = 0
	_sync_amount()
	unclear.set_pressed_no_signal(false)
	if not answer.is_empty():
		job = Advisor.new(decision_view)
		job.solver_budget_ms = 8000
		if saved.get("playing", false) and saved.get("branch_record") is Dictionary:
			var resumed = History.replay(saved.branch_record, false)
			if not resumed.has("error"):
				game = resumed.game
				playing = true
				branch_paused = true
		for a in store.data.attempts:
			if a.id == answer.get("attempt"): unclear.set_pressed_no_signal(a.unclear)
	body_scroll.reset_scroll()
	_persist()
	_render_case()

func resume_set() -> void:
	var saved: Dictionary = store.data.session
	if not saved.get("queue") is Array or saved.queue.is_empty() or not History._integer(saved.get("cursor"), 0, saved.queue.size() - 1):
		status.text = "没有可恢复的练习。"
		return
	for c in saved.queue:
		if not c is Dictionary or not c.get("record") is Dictionary or not History._integer(c.get("point"), 0, 1000) or History.replay(c.record).has("error"):
			status.text = "练习进度校验失败；可以重新开始一组。"
			return
	queue = saved.queue.duplicate(true)
	cursor = int(saved.cursor)
	_load_case(saved)

func _sync_amount() -> void:
	if game == null or game.actor != 0: return
	var l = game.legal_actions(0)
	var divisor: float = game.big_blind if use_bb else 1
	amount.min_value = minf(l.min_raise_to, l.max_raise_to) / divisor
	amount.max_value = l.max_raise_to / divisor
	amount.step = 1.0 / divisor
	amount.suffix = "BB" if use_bb else "筹码"
	amount.get_line_edit().virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL if use_bb else LineEdit.KEYBOARD_TYPE_NUMBER
	amount.value = amount.min_value

func _quick(fraction: float) -> void:
	if game == null or game.actor != 0: return
	var l = game.legal_actions(0)
	var target: int = l.max_raise_to if fraction < 0 else l.min_raise_to if fraction == 0 else game.current_bet + roundi((game.pot_size() + l.call_amount) * fraction)
	target = clampi(target, mini(l.min_raise_to, l.max_raise_to), l.max_raise_to)
	amount.value = float(target) / (game.big_blind if use_bb else 1)

func submit(action: String) -> void:
	if game == null or game.actor != 0 or builder != null or notes.visible or branch_paused: return
	if not playing and not answer.is_empty(): return
	amount.apply()
	var l = game.legal_actions(0)
	if action == "check_call": action = "check" if l.check else "call"
	var target = roundi(amount.value * (game.big_blind if use_bb else 1)) if action == "raise" else 0
	if playing:
		var err = game.act(0, action, target)
		if not err.is_empty():
			status.text = err
			return
		bot_wait = speed
		_after_action()
	else:
		# Validate the proposed action on an isolated copy; keep the teaching view unchanged.
		var check = Practice.prefix(current.record, int(current.point))
		var err = check.game.act(0, action, target)
		if not err.is_empty():
			status.text = err
			return
		answer = {"action": action, "amount": target}
		job = Advisor.new(decision_view)
		job.solver_budget_ms = 8000
		_persist()
		_render_case()
	body_scroll.reset_scroll()

func begin_branch() -> void:
	if answer.is_empty() or job != null or playing or builder != null: return
	builder = Practice.new(current.record, int(current.point), "sampled" if mode_picker.selected == 0 else "original")
	status.text = "正在准备重打局面…"
	_render_case()

func _after_action() -> void:
	if game.phase == "complete" and branch_id.is_empty():
		var record = game.completed_record()
		record["opponents"] = case_profiles.duplicate(true)
		record["bot_version"] = Bot.VERSION
		branch_id = store.save_branch(record, History.hand_id(current.record), int(current.point), "sampled" if mode_picker.selected == 0 else "original")
	_sync_amount()
	_persist()
	_render_case()

func next_case() -> void:
	if answer.is_empty() or job != null: return
	cursor += 1
	if cursor >= queue.size():
		store.data.session = {}
		store.save()
		open_hub()
		status.text = "本组已完成。可以回看最近练习，或选择新的主题。"
	else: _load_case()

func _persist() -> void:
	if current.is_empty() or store == null: return
	store.data.session = {"queue": queue, "cursor": cursor, "answer": answer, "mode": mode_picker.selected, "playing": playing, "branch_id": branch_id, "opponents": case_profiles.duplicate(true)}
	if playing and game != null: store.data.session.branch_record = game.record_state()
	store.save()

func _render_case() -> void:
	if game == null or not case_page.visible: return
	table_view.custom_minimum_size.y = 580 if game.seats.size() >= 6 else 440
	for id in bots: game.seats[id]["style"] = bots[id].style_name()
	table_view.update_table(game.view_for(0), use_bb)
	var mode_text = "未知牌重新采样" if mode_picker.selected == 0 else "保留原牌 · 可能已知道结果"
	prompt.text = "%d / %d · %s\n%s" % [cursor + 1, queue.size(), current.topic, mode_text]
	if not current.record.get("fixture", false) or store.mark(History.hand_id(current.record)).seen: prompt.text += " · 来自已看过的历史"
	pause_button.visible = playing and game.phase != "complete"
	pause_button.text = "继续重打" if branch_paused else "暂停重打"
	var can_answer = (playing or answer.is_empty()) and game.actor == 0 and builder == null and not branch_paused
	var l = game.legal_actions(0)
	action_row.visible = can_answer
	sizing.visible = can_answer and l.get("raise", false)
	raise.disabled = not l.get("raise", false)
	call.text = "过牌" if l.get("check", false) else "跟注 " + UI.money(l.get("call_amount", 0), game.big_blind, use_bb)
	mode_picker.disabled = playing or builder != null
	branch_review_button.visible = playing and game.phase == "complete" and not branch_id.is_empty()
	answer_area.visible = not answer.is_empty()
	answer_actions.visible = not answer.is_empty()
	detail.visible = details_expanded and not playing and not analysis.is_empty()
	detail_button.visible = not playing and not analysis.is_empty()
	detail_button.text = "收起具体理由" if details_expanded else "展开具体理由"
	continue_button.visible = not playing and builder == null
	continue_button.disabled = job != null or analysis.is_empty()
	unclear.visible = not analysis.is_empty()
	next_button.disabled = job != null or builder != null
	next_button.text = "完成本组" if cursor + 1 == queue.size() else "下一个局面"
	if playing and game.phase != "complete":
		feedback.text = "重打已暂停" if branch_paused else "轮到你继续行动" if game.actor == 0 else "电脑思考中…"
		summary.text = "重打进行中。电脑根据自己的信息行动，后续动作不必与原牌局相同。"
	elif playing:
		var net: int = game.seats[0].stack - int(current.record.starting_stacks[0])
		var r = current.record.result
		var original: int = int(r.payouts.get("0", r.payouts.get(0, 0))) - int(r.contributions[0])
		feedback.text = "分支已完成 · 净变化 " + UI.money(net, game.big_blind, use_bb)
		summary.text = "原牌局净变化：%s\n当前模式：%s\n\n这是一次样本，不代表哪种打法长期更好。分支已单独保存，不计入真实对局统计。" % [UI.money(original, game.big_blind, use_bb), mode_text]
	elif job != null:
		feedback.text = "已提交选择，正在分析…"
		summary.text = "只根据当时已知的信息计算。"
	elif not analysis.is_empty():
		var words = Teaching.explain(decision_view, analysis, use_bb)
		var verdict = Practice.feedback(decision_view, analysis, answer.action, int(answer.amount))
		feedback.text = verdict + " · 你的选择：" + {"fold": "弃牌", "call": "跟注", "check": "过牌", "raise": "加到"}.get(answer.action, answer.action) + (UI.money(int(answer.amount), game.big_blind, use_bb) if answer.action == "raise" else "")
		summary.text = words.status + "\n" + words.summary + "\n\n" + preload("res://scripts/poker/decision_feedback.gd").compare(decision_view, analysis, answer.action, int(answer.amount), use_bb).text
		detail.text = words.details + "\n\n不同选择值得讨论，不等于已确认的错误。"
	status.text = store.error if not store.error.is_empty() else "练习分支 · 独立于原牌局" if playing else "已作答 · 可查看理由或继续重打" if not answer.is_empty() else "先选择操作，再看教练"

func _process(delta: float) -> void:
	if not visible or store == null: return
	if hub_scroll.visible and scan_cursor >= 0: _scan()
	if not case_page.visible: return
	if builder != null:
		var until = Time.get_ticks_usec() + 4000
		while not builder.ready and builder.error.is_empty() and Time.get_ticks_usec() < until: builder.step()
		if not builder.error.is_empty():
			status.text = builder.error
			builder = null
		elif builder.ready:
			game = builder.game
			builder = null
			var err = game.act(0, answer.action, int(answer.amount))
			if not err.is_empty():
				status.text = err
				return
			playing = true
			bot_wait = speed
			_after_action()
	if job != null:
		var deadline = Time.get_ticks_usec() + 4000
		while not job.is_done() and Time.get_ticks_usec() < deadline: job.step(4)
		if job.is_done():
			analysis = job.result()
			job = null
			if analysis.has("error"):
				status.text = analysis.error
				analysis = {}
				return
			if not answer.has("attempt"):
				answer.attempt = store.add_attempt(History.hand_id(current.record), int(current.point), current.topic, answer.action, int(answer.amount), Practice.feedback(decision_view, analysis, answer.action, int(answer.amount)))
			_persist()
			_render_case()
	if playing and not branch_paused and game != null and game.actor > 0 and not notes.visible:
		bot_wait -= delta
		if bot_wait <= 0:
			var choice = bots[game.actor].choose(game.view_for(game.actor))
			var err = game.act(game.actor, choice.action, choice.get("amount", 0))
			if not err.is_empty():
				status.text = err
				playing = false
				return
			bot_wait = speed
			_after_action()

func _report() -> void:
	var r = store.report()
	var hands = 0
	var vpip = 0
	var pfr = 0
	var net = 0.0
	var days: int = [0, 1, 7, 30][stats_days.selected]
	var today = Time.get_date_string_from_system()
	var cutoff = Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_datetime_string(today)) - maxi(0, days - 1) * 86400).left(10)
	for record in records:
		if stats_seats.selected > 0 and record.starting_stacks.size() != stats_seats.selected + 1: continue
		var day = str(record.get("saved_at", "")).left(10)
		if days > 0 and (day < cutoff or day > today): continue
		if record.starting_stacks[0] <= 0: continue
		hands += 1
		var actions = record.events.filter(func(e): return e.kind == "action" and e.seat == 0 and e.phase == "preflop")
		vpip += int(actions.any(func(e): return e.action in ["call", "raise"]))
		pfr += int(actions.any(func(e): return e.action == "raise"))
		net += float(record.result.payouts.get("0", record.result.payouts.get(0, 0)) - record.result.contributions[0]) / record.big_blind
	var lines: Array = ["训练累计 %d 次 · %d 个不同局面" % [r.attempts, r.positions], "建议主题：" + r.suggested]
	for topic in r.topics:
		var t = r.topics[topic]
		lines.append("%s：%d 次 · 待理解 %d · 不同选择 %d" % [topic, t.total, t.unclear, t.different])
	var recent_attempts: Array = store.data.attempts.slice(maxi(0, store.data.attempts.size() - 10))
	var recent_positions = {}
	for attempt in recent_attempts: recent_positions[attempt.hand + ":" + str(attempt.point)] = true
	lines.append("\n最近 %d 次练习 · %d 个不同局面 · 自标待理解 %d 次" % [recent_attempts.size(), recent_positions.size(), recent_attempts.filter(func(a): return a.unclear).size()])
	lines.append("重复作答反映熟悉程度；建议换同主题的新局面检查理解，不按短期盈亏或与单一推荐相同来判定进步。")
	lines.append("\n所选真实对局样本 %d 手 · 净变化 %+.1f BB" % [hands, net])
	lines.append("主动入池 VPIP %.1f%% · 翻前加注 PFR %.1f%%" % [100.0 * vpip / maxi(1, hands), 100.0 * pfr / maxi(1, hands)] if hands else "完成真实对局后显示统计。")
	lines.append("VPIP 不含被动交盲注；PFR 统计翻前主动加注。以上不是实力评分，短期输赢不能证明打法好坏。")
	report.text = "\n".join(lines)

func _recent() -> void:
	UI.clear(recommended_list)
	for d in store.suggested_decisions().slice(0, 5):
		var row = _label(d.topic + " · " + d.verdict + "\n" + d.reason, 17)
		recommended_list.add_child(row)
		for record in records:
			if History.hand_id(record) == d.hand:
				recommended_list.add_child(UI.button("回到这个决策 · " + d.hand, func(): open_case(record, int(d.point))))
				break
		var same_topic = d.topic
		recommended_list.add_child(UI.button("练习同主题的新局面", func():
			for i in range(1, topic_picker.item_count):
				if topic_picker.get_item_text(i) == same_topic: topic_picker.select(i)
			source_picker.select(6)
			start_set()))
	if recommended_list.get_child_count() == 0: recommended_list.add_child(_label("完成对局后整理关键决策；待讨论不代表操作有错。", 17))
	UI.clear(recent_list)
	var attempts: Array = store.data.attempts
	if attempts.is_empty(): recent_list.add_child(_label("还没有练习记录。到“开始练习”完成第一个局面，作答会自动保存在这里。", 18))
	for i in range(attempts.size() - 1, maxi(-1, attempts.size() - 11), -1):
		var a = attempts[i]
		var label = "%s · %s%s\n%s · %s" % [a.topic, a.feedback, " · 待理解" if a.unclear else "", a.date.left(16), {"fold": "弃牌", "call": "跟注", "check": "过牌", "raise": "加注"}.get(a.action, a.action)]
		var b = UI.button(label, func():
			for c in candidates:
				if History.hand_id(c.record) == a.hand and c.point == a.point:
					open_case(c.record, int(c.point))
					return
			status.text = "原牌局不在本机，请先恢复包含它的备份。", Color("183039"), 64)
		recent_list.add_child(b)
	branch_picker.clear()
	branch_picker.add_item("查看已保存的重打分支")
	for id in store.data.branches:
		var b = store.data.branches[id]
		branch_picker.add_item("%s · %s" % [str(b.get("date", "")).left(16), "重新采样" if b.mode == "sampled" else "原牌"])
		branch_picker.set_item_metadata(branch_picker.item_count - 1, id)

func _open_branch(index: int) -> void:
	if index == 0: return
	_review_branch(branch_picker.get_item_metadata(index))

func _review_branch(id: String) -> void:
	if not store.data.branches.has(id): return
	var b = store.data.branches[id]
	var original: Dictionary = {}
	if not current.is_empty() and History.hand_id(current.record) == b.source: original = current.record
	else:
		for c in candidates:
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
		_persist()
		open_hub()
	else:
		hide()
		closed.emit()

func _units_changed(index: int) -> void:
	var chips = roundi(amount.value * (game.big_blind if use_bb and game != null else 1))
	use_bb = index == 1
	_sync_amount()
	if game != null and game.actor == 0: amount.value = float(chips) / (game.big_blind if use_bb else 1)
	_render_case()

func suspend() -> void:
	if playing:
		branch_paused = true
		_persist()
		_render_case()
