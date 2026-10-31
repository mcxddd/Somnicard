extends VBoxContainer
## Training room landing pages: practice setup, recent attempts and statistics.
## Depends on host: store, history_directory, status, case_page, open_case, _review_branch, _label, _picker.
const UI = preload("res://scripts/ui/style.gd")
const History = preload("res://scripts/poker/history.gd")
const Practice = preload("res://scripts/poker/practice.gd")
var host
var hub_pages: Array = []
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
var candidates: Array = []
var records: Array = []
var scan_files: Array = []
var scan_cursor = -1

func build() -> void:
	for i in range(3):
		var page = VBoxContainer.new()
		page.add_theme_constant_override("separation", 14)
		add_child(page)
		hub_pages.append(page)
	hub_pages[0].add_child(host._label("从一个决定开始", 28, UI.GOLD))
	hub_pages[0].add_child(host._label("每组最多 5 个局面。先选择，再看理由；需要时换种打法继续打完。", 18))
	topic_picker = host._picker(["主题：全部", "翻前入池", "面对下注", "加注尺度", "河牌判断"], hub_pages[0])
	source_picker = host._picker(["来源：全部", "我的收藏", "待复习", "我的历史", "固定练习", "教练建议复盘", "尚未练过的局面"], hub_pages[0])
	start_button = UI.button("开始一组练习", start_set, UI.GREEN, 56)
	hub_pages[0].add_child(start_button)
	resume_button = UI.button("继续未完成的练习", func(): host.case_page.resume_set())
	hub_pages[0].add_child(resume_button)
	hub_pages[0].add_child(host._label("最近值得回看的决定", 22, UI.GOLD))
	recommended_list = VBoxContainer.new()
	hub_pages[0].add_child(recommended_list)
	hub_pages[2].add_child(host._label("练习与对局概览", 23, UI.GOLD))
	var stats = HBoxContainer.new()
	hub_pages[2].add_child(stats)
	stats_seats = host._picker(["桌型：全部", "2 人", "3 人", "4 人", "5 人", "6 人", "7 人", "8 人", "9 人"], stats)
	stats_days = host._picker(["时间：全部", "今天", "近 7 天", "近 30 天"], stats)
	stats_seats.item_selected.connect(func(_i): _report())
	stats_days.item_selected.connect(func(_i): _report())
	report = host._label("", 18)
	hub_pages[2].add_child(report)
	hub_pages[1].add_child(host._label("最近练习 · 可再次作答", 22, UI.GOLD))
	recent_list = VBoxContainer.new()
	hub_pages[1].add_child(recent_list)
	branch_picker = host._picker(["选择已保存的重打分支"], hub_pages[1])
	branch_picker.item_selected.connect(_open_branch)

func open() -> void:
	start_button.disabled = true
	resume_button.visible = not host.store.data.session.is_empty()
	candidates.clear()
	records.clear()
	for r in Practice.fixtures(): _add_record(r)
	scan_files = History.files(host.history_directory)
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
		var r = History.read_record(host.history_directory.path_join(scan_files[scan_cursor]))
		scan_cursor += 1
		if not r.has("error"): _add_record(r.record)
	host.status.text = "整理可练习局面 %d / %d" % [scan_cursor, scan_files.size()]
	if scan_cursor >= scan_files.size():
		scan_cursor = -1
		host.status.text = host.store.error if not host.store.error.is_empty() else "离线训练 · 练习输赢不计入对局统计"
		start_button.disabled = false
		_report()
		_recent()

func _process(_delta: float) -> void:
	if host.visible and host.store != null and host.hub_scroll.visible and scan_cursor >= 0: _scan()

func start_set() -> void:
	if scan_cursor >= 0: return
	var store = host.store
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
		host.status.text = "当前条件没有局面。可选择固定练习，或先收藏一手历史牌局。"
		return
	var counts = {}
	for a in store.data.attempts:
		var key: String = a.hand + ":" + str(a.point)
		counts[key] = counts.get(key, 0) + 1
	picked.shuffle()
	picked.sort_custom(func(a, b): return counts.get(History.hand_id(a.record) + ":" + str(a.point), 0) < counts.get(History.hand_id(b.record) + ":" + str(b.point), 0))
	host.case_page.start(picked.slice(0, 5))

func _report() -> void:
	var store = host.store
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
	var store = host.store
	UI.clear(recommended_list)
	for d in store.suggested_decisions().slice(0, 5):
		var row = host._label(d.topic + " · " + d.verdict + "\n" + d.reason, 17)
		recommended_list.add_child(row)
		for record in records:
			if History.hand_id(record) == d.hand:
				recommended_list.add_child(UI.button("回到这个决策 · " + d.hand, func(): host.open_case(record, int(d.point))))
				break
		var same_topic = d.topic
		recommended_list.add_child(UI.button("练习同主题的新局面", func():
			for i in range(1, topic_picker.item_count):
				if topic_picker.get_item_text(i) == same_topic: topic_picker.select(i)
			source_picker.select(6)
			start_set()))
	if recommended_list.get_child_count() == 0: recommended_list.add_child(host._label("完成对局后整理关键决策；待讨论不代表操作有错。", 17))
	UI.clear(recent_list)
	var attempts: Array = store.data.attempts
	if attempts.is_empty(): recent_list.add_child(host._label("还没有练习记录。到“开始练习”完成第一个局面，作答会自动保存在这里。", 18))
	for i in range(attempts.size() - 1, maxi(-1, attempts.size() - 11), -1):
		var a = attempts[i]
		var label = "%s · %s%s\n%s · %s" % [a.topic, a.feedback, " · 待理解" if a.unclear else "", a.date.left(16), {"fold": "弃牌", "call": "跟注", "check": "过牌", "raise": "加注"}.get(a.action, a.action)]
		var b = UI.button(label, func():
			for c in candidates:
				if History.hand_id(c.record) == a.hand and c.point == a.point:
					host.open_case(c.record, int(c.point))
					return
			host.status.text = "原牌局不在本机，请先恢复包含它的备份。", Color("183039"), 64)
		recent_list.add_child(b)
	branch_picker.clear()
	branch_picker.add_item("查看已保存的重打分支")
	for id in store.data.branches:
		var b = store.data.branches[id]
		branch_picker.add_item("%s · %s" % [str(b.get("date", "")).left(16), "重新采样" if b.mode == "sampled" else "原牌"])
		branch_picker.set_item_metadata(branch_picker.item_count - 1, id)

func _open_branch(index: int) -> void:
	if index == 0: return
	host._review_branch(branch_picker.get_item_metadata(index))
