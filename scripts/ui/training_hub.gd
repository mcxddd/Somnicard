extends VBoxContainer
## Training room home: one start button, per-topic mastery, the last set's summary and history.
## Depends on host: store, history_directory, status, case_page, open_case, _label.
const UI = preload("res://scripts/ui/style.gd")
const History = preload("res://scripts/poker/history.gd")
const Practice = preload("res://scripts/poker/practice.gd")
const Store = preload("res://scripts/poker/training_store.gd")
const TOPIC_ICONS = {"翻前入池": "topic-preflop", "面对下注": "topic-facing", "主动下注": "topic-betting", "河牌判断": "topic-river"}
const GRADES = {"good": ["✓", "好的选择", Color("7cd7b7")], "ok": ["≈", "可以接受", Color("dec488")], "miss": ["✗", "偏离建议", Color("f2a3a9")], "unscored": ["·", "不评分", Color("a4b9b4")]}
var host
var home_page: VBoxContainer
var records_page: VBoxContainer
var summary_box: VBoxContainer
var today_title: Label
var today_note: Label
var start_button: Button
var topic_rows: VBoxContainer
## Answered / recent mastery / due figures; empty until the first answer.
var overview: VBoxContainer
var records_list: VBoxContainer
var candidates: Array = []
var records: Array = []
var scan_files: Array = []
var scan_cursor = -1
## Set when a course or topic row asks for a set before the history scan has finished.
var pending_topic = ""
var last_results: Array = []

func build() -> void:
	home_page = VBoxContainer.new()
	home_page.add_theme_constant_override("separation", 14)
	add_child(home_page)
	summary_box = VBoxContainer.new()
	summary_box.add_theme_constant_override("separation", 8)
	home_page.add_child(summary_box)
	var today = UI.card("hero")
	home_page.add_child(today)
	var today_column = VBoxContainer.new()
	today_column.add_theme_constant_override("separation", 10)
	today.add_child(today_column)
	today_title = UI.title("今天 · 5 题")
	today_column.add_child(today_title)
	today_note = UI.caption("")
	today_column.add_child(today_note)
	start_button = UI.primary("开始练习", func(): start_set())
	today_column.add_child(start_button)
	overview = VBoxContainer.new()
	home_page.add_child(overview)
	home_page.add_child(UI.heading("各主题掌握情况"))
	home_page.add_child(UI.caption("点一个主题，只练这个主题。"))
	topic_rows = VBoxContainer.new()
	topic_rows.add_theme_constant_override("separation", 8)
	home_page.add_child(topic_rows)
	home_page.add_child(UI.entry("练习记录", "按日期查看做过的题，可以再练一次", show_records, "history"))
	home_page.add_child(UI.caption("练习结果不计入对局统计。建议来自本机模型：河牌限定双人抽象求解，其余为范围与价格估算，不是完整 GTO。"))
	records_page = VBoxContainer.new()
	records_page.add_theme_constant_override("separation", 10)
	add_child(records_page)
	records_page.add_child(UI.heading("练习记录"))
	records_page.add_child(UI.caption("点一题再练一次。"))
	records_list = VBoxContainer.new()
	records_list.add_theme_constant_override("separation", 8)
	records_page.add_child(records_list)
	records_page.hide()

func open() -> void:
	show_home()
	start_button.disabled = true
	candidates.clear()
	records.clear()
	for r in Practice.fixtures(): _add_record(r)
	scan_files = History.files(host.history_directory)
	scan_cursor = 0
	_scan()

func show_home() -> void:
	host.close_button.text = host.return_text
	records_page.hide()
	home_page.show()
	if scan_cursor < 0: refresh()

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
	host.status.text = "正在整理可练习局面 %d / %d" % [scan_cursor, scan_files.size()]
	if scan_cursor >= scan_files.size():
		scan_cursor = -1
		host.status.text = host.store.error
		start_button.disabled = false
		refresh()
		if not pending_topic.is_empty():
			var topic = pending_topic
			pending_topic = ""
			start_set(topic)

func _process(_delta: float) -> void:
	if host.visible and host.store != null and host.hub_scroll.visible and scan_cursor >= 0: _scan()

## Rebuild the home page from the store; nothing here asks the player to configure anything.
func refresh() -> void:
	var store = host.store
	var session: Dictionary = store.data.session
	var due: int = store.review_due().size()
	var rates: Dictionary = store.mastery()
	if not session.is_empty():
		today_title.text = "上次的练习还没做完"
		today_note.text = "从第 %d / %d 题继续。" % [int(session.cursor) + 1, session.queue.size()]
		start_button.text = "继续练习"
	else:
		today_title.text = "今天 · 5 题"
		var weakest = ""
		var lowest = 2.0
		for topic in Store.TOPICS:
			if rates[topic].rate >= 0 and rates[topic].rate < lowest:
				lowest = rates[topic].rate
				weakest = topic
		if due > 0: today_note.text = "其中 %d 题是之前做错、该复习的局面，其余按你最弱的主题挑选。" % mini(due, 2)
		elif not weakest.is_empty(): today_note.text = "优先挑你最弱的主题：%s。题目来自你打过的牌局，不够时用内置局面。" % weakest
		else: today_note.text = "先作答，再看建议和理由。题目来自你打过的牌局，不够时用内置局面。"
		start_button.text = "再来一组" if not last_results.is_empty() else "开始练习"
	UI.clear(overview)
	var answered: int = store.data.attempts.size()
	if answered > 0:
		var scored = 0
		var kept = 0
		for topic in Store.TOPICS:
			scored += rates[topic].scored
			kept += rates[topic].kept
		overview.add_child(UI.stat_row([[str(answered), "练过的题"], ["%d%%" % roundi(100.0 * kept / scored) if scored > 0 else "—", "近期掌握率", UI.GOLD], [str(due), "待复习", UI.DANGER if due > 0 else UI.TEXT]]))
	UI.clear(topic_rows)
	for topic in Store.TOPICS:
		var r: Dictionary = rates[topic]
		var line = "还没练过"
		if r.rate >= 0: line = "掌握 %d%% · 练过 %d 题" % [roundi(r.rate * 100), r.attempts]
		var row = UI.entry(topic, line, func(): start_set(topic), TOPIC_ICONS[topic])
		row.set_progress(r.rate)
		topic_rows.add_child(row)

## Start a set. The selection is automatic; a topic only narrows it.
func start_set(topic: String = "") -> void:
	var store = host.store
	if scan_cursor >= 0:
		pending_topic = topic if not topic.is_empty() else pending_topic
		return
	if topic.is_empty() and not store.data.session.is_empty():
		host.case_page.resume_set()
		return
	var picked: Array = store.pick(candidates, Store.topic_name(topic))
	if picked.is_empty():
		host.status.text = "这个主题暂时没有可练的局面。先打几手牌，或换个主题。"
		return
	last_results.clear()
	host.case_page.start(picked)

## Shown on the home page after a set ends; the start button becomes "再来一组".
func show_summary(results: Array) -> void:
	last_results = results.duplicate(true)
	UI.clear(summary_box)
	if scan_cursor < 0: refresh()
	if results.is_empty(): return
	summary_box.add_child(UI.art(preload("res://assets/art/practice-complete.png"), 130))
	var counts = {"good": 0, "ok": 0, "miss": 0, "unscored": 0}
	for r in results: counts[Store.grade(r.feedback)] += 1
	summary_box.add_child(UI.heading("本组完成"))
	var figures: Array = []
	for grade in ["good", "ok", "miss"]: figures.append([str(counts[grade]), GRADES[grade][1], GRADES[grade][2]])
	if counts.unscored > 0: figures.append([str(counts.unscored), GRADES.unscored[1], GRADES.unscored[2]])
	summary_box.add_child(UI.stat_row(figures))
	for i in range(results.size()):
		var r: Dictionary = results[i]
		var g = GRADES[Store.grade(r.feedback)]
		var line = host._label("%d. %s  %s %s%s" % [i + 1, Store.topic_name(r.topic), g[0], g[1], " → 已加入复习" if Store.grade(r.feedback) == "miss" else ""], 18, UI.TEXT)
		line.add_theme_color_override("font_color", g[2])
		summary_box.add_child(line)

func show_records() -> void:
	home_page.hide()
	records_page.show()
	host.close_button.text = "‹ 训练室"
	host.hub_scroll.reset_scroll()
	UI.clear(records_list)
	var attempts: Array = host.store.data.attempts
	if attempts.is_empty():
		records_list.add_child(UI.art(preload("res://assets/art/empty-practice.png"), 170))
		records_list.add_child(host._label("还没有练习记录。完成第一题后会出现在这里。", 18))
		return
	var day = ""
	for i in range(attempts.size() - 1, maxi(-1, attempts.size() - 41), -1):
		var a: Dictionary = attempts[i]
		if str(a.date).left(10) != day:
			day = str(a.date).left(10)
			records_list.add_child(host._label(day, 16, UI.MUTED))
		var g = GRADES[Store.grade(a.feedback)]
		var action = {"fold": "弃牌", "call": "跟注", "check": "过牌", "raise": "加注"}.get(a.action, a.action)
		var row = UI.button("%s %s · %s\n%s · 你选择%s" % [g[0], Store.topic_name(a.topic), g[1], str(a.date).substr(11, 5), action], func():
			for c in candidates:
				if History.hand_id(c.record) == a.hand and int(c.point) == int(a.point):
					host.open_case(c.record, int(c.point))
					return
			host.status.text = "原牌局不在本机，无法再练这一题。", Color("17313a"), 68)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		records_list.add_child(row)
