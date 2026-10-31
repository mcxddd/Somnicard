extends VBoxContainer
## One training decision: answer first, read the analysis, then optionally play the branch out.
## Depends on host: store, use_bb, difficulty, opponent_profiles, speed, status, units, close_button,
## hub_scroll, hub_tabs, notes, replay_requested, open_hub, _review_branch, _label, _picker.
const UI = preload("res://scripts/ui/style.gd")
const History = preload("res://scripts/poker/history.gd")
const Practice = preload("res://scripts/poker/practice.gd")
const Advisor = preload("res://scripts/poker/advisor.gd")
const Teaching = preload("res://scripts/poker/teaching.gd")
const Profiles = preload("res://scripts/poker/opponent_profiles.gd")
const Bot = preload("res://scripts/poker/local_bot.gd")
const TableView = preload("res://scripts/ui/table_view.gd")
const Scroll = preload("res://scripts/ui/touch_scroll.gd")
var host
var case_profiles: Array = []
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
var details_expanded = false
var detail_button: Button
var branch_review_button: Button
var summary: Label
var branch_paused = false
var pause_button: Button
var answer_actions: HBoxContainer

func build() -> void:
	prompt = host._label("", 16, UI.GOLD)
	add_child(prompt)
	table_view = TableView.new()
	table_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(table_view)
	table_view.set_portrait(true)
	table_view.custom_minimum_size = Vector2(0, 300)
	body_scroll = Scroll.new()
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.size_flags_stretch_ratio = 0.85
	add_child(body_scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	body_scroll.add_child(body)
	mode_picker = host._picker(["重打：重新采样未知牌", "重打：保留原牌"], body)
	pause_button = UI.button("暂停重打", func(): branch_paused = not branch_paused; _persist(); _render_case())
	body.add_child(pause_button)
	mode_picker.item_selected.connect(func(_i): _persist(); _render_case())
	sizing = VBoxContainer.new()
	body.add_child(sizing)
	sizing.add_child(host._label("加到（本轮总投入）", 16))
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
	add_child(action_row)
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
	feedback = host._label("", 20, UI.GOLD)
	answer_area.add_child(feedback)
	summary = host._label("", 18, UI.TEXT)
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
		if answer.has("attempt"): host.store.set_unclear(answer.attempt, v))
	answer_area.add_child(unclear)
	continue_button = UI.button("用我的选择继续打", begin_branch, UI.GREEN, 52)
	answer_area.add_child(continue_button)
	answer_area.add_child(UI.button("查看原牌局回放", func():
		host.store.seen(History.hand_id(current.record))
		host.replay_requested.emit(current.record)))
	branch_review_button = UI.button("回放 / 对比重打分支", func(): host._review_branch(branch_id))
	answer_area.add_child(branch_review_button)
	next_button = UI.button("下一个局面", next_case, UI.GREEN, 52)
	answer_actions = HBoxContainer.new()
	add_child(answer_actions)
	continue_button.reparent(answer_actions)
	answer_actions.add_child(next_button)
	for b in [continue_button, next_button]: b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	continue_button.text = "继续重打"
	body.add_child(UI.button("收藏 / 备注", func(): host.notes.edit(host.store, History.hand_id(current.record))))

func start(items: Array) -> void:
	queue = items
	cursor = 0
	_load_case()

func _load_case(saved: Dictionary = {}) -> void:
	host.units.select(1 if host.use_bb else 0)
	details_expanded = false
	current = queue[cursor]
	var original = Practice.new(current.record, int(current.point), "original")
	if not original.error.is_empty():
		host.status.text = original.error
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
	case_profiles = Profiles.snapshot(host.opponent_profiles, game.seats.size(), host.difficulty)
	# Replay a historical decision using the setup known at that action boundary.
	var archived_profiles = Profiles.record_snapshot(current.record, game.events.size())
	if not archived_profiles.is_empty(): case_profiles = Profiles.snapshot(archived_profiles, game.seats.size(), host.difficulty)
	if saved.get("opponents") is Array: case_profiles = Profiles.snapshot(Profiles.normalize(saved.opponents), game.seats.size(), host.difficulty)
	for id in range(1, game.seats.size()):
		var p = case_profiles[id - 1]
		bots[id] = Bot.new(-1, p.aggression, p.difficulty)
		game.seats[id]["style"] = bots[id].style_name()
	mode_picker.select(int(saved.get("mode", 0)))
	host.show()
	host.hub_scroll.hide()
	host.hub_tabs.hide()
	host.close_button.text = "‹ 训练室"
	show()
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
		for a in host.store.data.attempts:
			if a.id == answer.get("attempt"): unclear.set_pressed_no_signal(a.unclear)
	body_scroll.reset_scroll()
	_persist()
	_render_case()

func resume_set() -> void:
	var saved: Dictionary = host.store.data.session
	if not saved.get("queue") is Array or saved.queue.is_empty() or not History._integer(saved.get("cursor"), 0, saved.queue.size() - 1):
		host.status.text = "没有可恢复的练习。"
		return
	for c in saved.queue:
		if not c is Dictionary or not c.get("record") is Dictionary or not History._integer(c.get("point"), 0, 1000) or History.replay(c.record).has("error"):
			host.status.text = "练习进度校验失败；可以重新开始一组。"
			return
	queue = saved.queue.duplicate(true)
	cursor = int(saved.cursor)
	_load_case(saved)

func _sync_amount() -> void:
	if game == null or game.actor != 0: return
	var l = game.legal_actions(0)
	var divisor: float = game.big_blind if host.use_bb else 1
	amount.min_value = minf(l.min_raise_to, l.max_raise_to) / divisor
	amount.max_value = l.max_raise_to / divisor
	amount.step = 1.0 / divisor
	amount.suffix = "BB" if host.use_bb else "筹码"
	amount.get_line_edit().virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL if host.use_bb else LineEdit.KEYBOARD_TYPE_NUMBER
	amount.value = amount.min_value

func _quick(fraction: float) -> void:
	if game == null or game.actor != 0: return
	var l = game.legal_actions(0)
	var target: int = l.max_raise_to if fraction < 0 else l.min_raise_to if fraction == 0 else game.current_bet + roundi((game.pot_size() + l.call_amount) * fraction)
	target = clampi(target, mini(l.min_raise_to, l.max_raise_to), l.max_raise_to)
	amount.value = float(target) / (game.big_blind if host.use_bb else 1)

func submit(action: String) -> void:
	if game == null or game.actor != 0 or builder != null or host.notes.visible or branch_paused: return
	if not playing and not answer.is_empty(): return
	amount.apply()
	var l = game.legal_actions(0)
	if action == "check_call": action = "check" if l.check else "call"
	var target = roundi(amount.value * (game.big_blind if host.use_bb else 1)) if action == "raise" else 0
	if playing:
		var err = game.act(0, action, target)
		if not err.is_empty():
			host.status.text = err
			return
		bot_wait = host.speed
		_after_action()
	else:
		# Validate the proposed action on an isolated copy; keep the teaching view unchanged.
		var check = Practice.prefix(current.record, int(current.point))
		var err = check.game.act(0, action, target)
		if not err.is_empty():
			host.status.text = err
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
	host.status.text = "正在准备重打局面…"
	_render_case()

func _after_action() -> void:
	if game.phase == "complete" and branch_id.is_empty():
		var record = game.completed_record()
		record["opponents"] = case_profiles.duplicate(true)
		record["bot_version"] = Bot.VERSION
		branch_id = host.store.save_branch(record, History.hand_id(current.record), int(current.point), "sampled" if mode_picker.selected == 0 else "original")
	_sync_amount()
	_persist()
	_render_case()

func next_case() -> void:
	if answer.is_empty() or job != null: return
	cursor += 1
	if cursor >= queue.size():
		host.store.data.session = {}
		host.store.save()
		host.open_hub()
		host.status.text = "本组已完成。可以回看最近练习，或选择新的主题。"
	else: _load_case()

func _persist() -> void:
	if current.is_empty() or host.store == null: return
	host.store.data.session = {"queue": queue, "cursor": cursor, "answer": answer, "mode": mode_picker.selected, "playing": playing, "branch_id": branch_id, "opponents": case_profiles.duplicate(true)}
	if playing and game != null: host.store.data.session.branch_record = game.record_state()
	host.store.save()

func _render_case() -> void:
	if game == null or not visible: return
	var use_bb = host.use_bb
	table_view.custom_minimum_size.y = 580 if game.seats.size() >= 6 else 440
	for id in bots: game.seats[id]["style"] = bots[id].style_name()
	table_view.update_table(game.view_for(0), use_bb)
	var mode_text = "未知牌重新采样" if mode_picker.selected == 0 else "保留原牌 · 可能已知道结果"
	prompt.text = "%d / %d · %s\n%s" % [cursor + 1, queue.size(), current.topic, mode_text]
	if not current.record.get("fixture", false) or host.store.mark(History.hand_id(current.record)).seen: prompt.text += " · 来自已看过的历史"
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
	host.status.text = host.store.error if not host.store.error.is_empty() else "练习分支 · 独立于原牌局" if playing else "已作答 · 可查看理由或继续重打" if not answer.is_empty() else "先选择操作，再看教练"

func _process(delta: float) -> void:
	if not host.visible or host.store == null or not visible: return
	if builder != null:
		var until = Time.get_ticks_usec() + 4000
		while not builder.ready and builder.error.is_empty() and Time.get_ticks_usec() < until: builder.step()
		if not builder.error.is_empty():
			host.status.text = builder.error
			builder = null
		elif builder.ready:
			game = builder.game
			builder = null
			var err = game.act(0, answer.action, int(answer.amount))
			if not err.is_empty():
				host.status.text = err
				return
			playing = true
			bot_wait = host.speed
			_after_action()
	if job != null:
		var deadline = Time.get_ticks_usec() + 4000
		while not job.is_done() and Time.get_ticks_usec() < deadline: job.step(4)
		if job.is_done():
			analysis = job.result()
			job = null
			if analysis.has("error"):
				host.status.text = analysis.error
				analysis = {}
				return
			if not answer.has("attempt"):
				answer.attempt = host.store.add_attempt(History.hand_id(current.record), int(current.point), current.topic, answer.action, int(answer.amount), Practice.feedback(decision_view, analysis, answer.action, int(answer.amount)))
			_persist()
			_render_case()
	if playing and not branch_paused and game != null and game.actor > 0 and not host.notes.visible:
		bot_wait -= delta
		if bot_wait <= 0:
			var choice = bots[game.actor].choose(game.view_for(game.actor))
			var err = game.act(game.actor, choice.action, choice.get("amount", 0))
			if not err.is_empty():
				host.status.text = err
				playing = false
				return
			bot_wait = host.speed
			_after_action()

func _units_changed(index: int) -> void:
	var chips = roundi(amount.value * (game.big_blind if host.use_bb and game != null else 1))
	host.use_bb = index == 1
	_sync_amount()
	if game != null and game.actor == 0: amount.value = float(chips) / (game.big_blind if host.use_bb else 1)
	_render_case()

func suspend() -> void:
	if playing:
		branch_paused = true
		_persist()
		_render_case()
