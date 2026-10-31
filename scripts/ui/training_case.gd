extends VBoxContainer
## One training decision: read the spot, answer, then a graded result card with the full reasoning.
## Optionally play the hand out with the chosen action against resampled unknown cards.
## Depends on host: store, use_bb, difficulty, opponent_profiles, speed, status, units, close_button,
## hub, hub_scroll, open_hub, _review_branch, _label.
const UI = preload("res://scripts/ui/style.gd")
const History = preload("res://scripts/poker/history.gd")
const Practice = preload("res://scripts/poker/practice.gd")
const Advisor = preload("res://scripts/poker/advisor.gd")
const Teaching = preload("res://scripts/poker/teaching.gd")
const Feedback = preload("res://scripts/poker/decision_feedback.gd")
const Ranges = preload("res://scripts/poker/range_model.gd")
const Profiles = preload("res://scripts/poker/opponent_profiles.gd")
const Store = preload("res://scripts/poker/training_store.gd")
const Hub = preload("res://scripts/ui/training_hub.gd")
const Bot = preload("res://scripts/poker/local_bot.gd")
const TableView = preload("res://scripts/ui/table_view.gd")
const Scroll = preload("res://scripts/ui/touch_scroll.gd")
const ACTIONS = {"fold": "弃牌", "call": "跟注", "check": "过牌", "raise": "加到"}
var host
var case_profiles: Array = []
var table_view
var prompt: Label
var situation: Label
var body_scroll
var body: VBoxContainer
var action_row: HBoxContainer
var fold: Button
var call: Button
var raise: Button
var amount: SpinBox
var sizing: VBoxContainer
var result_card: PanelContainer
var grade_label: Label
var compare_label: Label
var detail: RichTextLabel
var branch_button: Button
var branch_review_button: Button
var feedback: Label
var pause_button: Button
var next_button: Button
var queue: Array = []
var cursor = 0
var results: Array = []
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
var branch_paused = false
## The amount panel opens on the first raise press; the second press submits it.
var sizing_open = false

func build() -> void:
	prompt = host._label("", 18, UI.GOLD)
	add_child(prompt)
	situation = host._label("", 16, UI.TEXT)
	add_child(situation)
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
	sizing = VBoxContainer.new()
	body.add_child(sizing)
	sizing.add_child(host._label("加到（本轮总投入）", 16))
	amount = SpinBox.new()
	amount.custom_minimum_size.y = 48
	amount.value_changed.connect(func(_value): if sizing.visible: _render_case())
	sizing.add_child(amount)
	var quick = HBoxContainer.new()
	sizing.add_child(quick)
	for choice in [["最小", 0.0], ["半池", 0.5], ["满池", 1.0], ["全押", -1.0]]:
		var button = UI.button(choice[0], _quick.bind(choice[1]))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		quick.add_child(button)
	result_card = UI.panel(Color("13292f"), 12, 14)
	body.add_child(result_card)
	var card = VBoxContainer.new()
	card.add_theme_constant_override("separation", 8)
	result_card.add_child(card)
	grade_label = host._label("", 24, UI.GOLD)
	card.add_child(grade_label)
	compare_label = host._label("", 18, UI.TEXT)
	card.add_child(compare_label)
	detail = RichTextLabel.new()
	detail.fit_content = true
	detail.scroll_active = false
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_theme_font_size_override("normal_font_size", 18)
	detail.bbcode_enabled = true
	card.add_child(detail)
	feedback = host._label("", 18, UI.GOLD)
	body.add_child(feedback)
	pause_button = UI.button("暂停", func(): branch_paused = not branch_paused; _persist(); _render_case())
	body.add_child(pause_button)
	branch_button = _link("用这个选择打完这手 ›", begin_branch)
	body.add_child(branch_button)
	branch_review_button = _link("回放并对比原牌局 ›", func(): host._review_branch(branch_id))
	body.add_child(branch_review_button)
	action_row = HBoxContainer.new()
	add_child(action_row)
	fold = UI.button("弃牌", submit.bind("fold"))
	call = UI.button("过牌", submit.bind("check_call"), UI.GREEN)
	raise = UI.button("加注", _press_raise)
	for b in [fold, call, raise]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 56
		action_row.add_child(b)
	next_button = UI.button("下一题", next_case, UI.GREEN, 56)
	add_child(next_button)

func _link(text: String, action: Callable) -> Button:
	var link = UI.button(text, action, Color("10252d"), 44)
	link.alignment = HORIZONTAL_ALIGNMENT_LEFT
	link.add_theme_color_override("font_color", UI.GOLD)
	return link

func start(items: Array) -> void:
	queue = items
	cursor = 0
	results.clear()
	_load_case()

func _load_case(saved: Dictionary = {}) -> void:
	host.units.select(1 if host.use_bb else 0)
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
	sizing_open = false
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
	host.show()
	host.hub_scroll.hide()
	host.close_button.text = "‹ 训练室"
	show()
	amount.value = 0
	_sync_amount()
	if not answer.is_empty():
		job = Advisor.new(decision_view)
		job.solver_budget_ms = 8000
		if saved.get("playing", false) and saved.get("branch_record") is Dictionary:
			var resumed = History.replay(saved.branch_record, false)
			if not resumed.has("error"):
				game = resumed.game
				playing = true
				branch_paused = true
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
	results = saved.get("results", []).duplicate(true) if saved.get("results") is Array else []
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

func _press_raise() -> void:
	if not sizing_open:
		sizing_open = true
		_render_case()
		return
	submit("raise")

func submit(action: String) -> void:
	if game == null or game.actor != 0 or builder != null or branch_paused: return
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

## Play the hand out with the chosen action. Unknown cards are always resampled, so the
## original result cannot leak into the branch.
func begin_branch() -> void:
	if answer.is_empty() or job != null or playing or builder != null: return
	builder = Practice.new(current.record, int(current.point), "sampled")
	host.status.text = "正在发未知牌…"
	_render_case()

func _after_action() -> void:
	if game.phase == "complete" and branch_id.is_empty():
		var record = game.completed_record()
		record["opponents"] = case_profiles.duplicate(true)
		record["bot_version"] = Bot.VERSION
		branch_id = host.store.save_branch(record, History.hand_id(current.record), int(current.point), "sampled")
	sizing_open = false
	_sync_amount()
	_persist()
	_render_case()

func next_case() -> void:
	if answer.is_empty() or job != null or builder != null: return
	cursor += 1
	if cursor >= queue.size():
		host.store.data.session = {}
		host.store.save()
		var finished = results.duplicate(true)
		host.open_hub()
		host.hub.show_summary(finished)
	else: _load_case()

func _persist() -> void:
	if current.is_empty() or host.store == null: return
	host.store.data.session = {"queue": queue, "cursor": cursor, "answer": answer, "mode": 0, "playing": playing, "branch_id": branch_id, "opponents": case_profiles.duplicate(true), "results": results.duplicate(true)}
	if playing and game != null: host.store.data.session.branch_record = game.record_state()
	host.store.save()

func _situation(view: Dictionary) -> String:
	var money = func(value): return UI.money(int(value), view.big_blind, host.use_bb)
	var street = {"preflop": "翻牌前", "flop": "翻牌", "turn": "转牌", "river": "河牌"}.get(view.phase, "")
	var facing = "需跟注 %s" % money.call(view.legal.call_amount) if view.legal.get("call_amount", 0) > 0 else "没人下注，轮到你"
	return "%d 人桌 · 你在 %s · %s · 底池 %s · %s" % [view.seats.size(), Ranges.position(view, 0), street, money.call(view.pot), facing]

func _action_text(action: String, value: int) -> String:
	return ACTIONS.get(action, action) + (" " + UI.money(value, decision_view.big_blind, host.use_bb) if action == "raise" else "")

func _render_case() -> void:
	if game == null or not visible: return
	var use_bb = host.use_bb
	table_view.custom_minimum_size.y = 560 if game.seats.size() >= 6 else 420
	for id in bots: game.seats[id]["style"] = bots[id].style_name()
	table_view.update_table(game.view_for(0), use_bb)
	var dots = ""
	for i in range(queue.size()): dots += "● " if i <= cursor else "○ "
	prompt.text = "%s %d/%d · %s" % [dots.strip_edges(), cursor + 1, queue.size(), Store.topic_name(current.topic)]
	situation.text = _situation(decision_view)
	var answered = not answer.is_empty()
	var can_act = (playing or not answered) and game.actor == 0 and builder == null and not branch_paused
	var l = game.legal_actions(0)
	action_row.visible = can_act
	sizing.visible = can_act and sizing_open and l.get("raise", false)
	raise.disabled = not l.get("raise", false)
	raise.text = "确认加到 %s" % UI.money(roundi(amount.value * (game.big_blind if use_bb else 1)), game.big_blind, use_bb) if sizing.visible else "加注"
	call.text = "过牌" if l.get("check", false) else "跟注 " + UI.money(l.get("call_amount", 0), game.big_blind, use_bb)
	result_card.visible = answered and not playing
	branch_button.visible = answered and not playing and builder == null and not analysis.is_empty()
	branch_review_button.visible = playing and game.phase == "complete" and not branch_id.is_empty()
	pause_button.visible = playing and game.phase != "complete"
	pause_button.text = "继续" if branch_paused else "暂停"
	next_button.visible = answered and not can_act
	next_button.disabled = job != null or builder != null
	next_button.text = "完成本组" if cursor + 1 == queue.size() else "下一题"
	feedback.visible = playing or builder != null
	if builder != null: feedback.text = "正在发未知牌…"
	elif playing and game.phase != "complete":
		feedback.text = "已暂停" if branch_paused else "轮到你继续行动" if game.actor == 0 else "电脑思考中…"
	elif playing:
		var net: int = game.seats[0].stack - int(current.record.starting_stacks[0])
		var r = current.record.result
		var original_net: int = int(r.payouts.get("0", r.payouts.get(0, 0))) - int(r.contributions[0])
		feedback.text = "这手打完 · 净变化 %s（原牌局 %s）\n未知牌重新发过，这只是一次样本，不代表哪种打法长期更好。" % [UI.money(net, game.big_blind, use_bb), UI.money(original_net, game.big_blind, use_bb)]
	if job != null:
		grade_label.text = "正在分析…"
		grade_label.add_theme_color_override("font_color", UI.GOLD)
		compare_label.text = "你：" + _action_text(answer.action, int(answer.amount))
		detail.text = "只根据当时已知的信息计算。"
	elif not analysis.is_empty():
		var compared = Feedback.compare(decision_view, analysis, answer.action, int(answer.amount), use_bb)
		var g = Hub.GRADES[Store.grade(compared.label)]
		grade_label.text = "%s %s" % [g[0], g[1]]
		grade_label.add_theme_color_override("font_color", g[2])
		compare_label.text = "你：%s    建议：%s" % [_action_text(answer.action, int(answer.amount)), _action_text(analysis.action, int(analysis.amount))]
		if compared.has("loss"): compare_label.text += "\n比模型最优少约 " + ("%.2f BB" % (compared.loss / game.big_blind) if use_bb else "%.0f 筹码" % compared.loss)
		var words = Teaching.explain(decision_view, analysis, use_bb)
		var plain = func(text): return str(text).replace("[", "[lb]")
		detail.text = "[b]%s[/b]\n%s\n\n%s\n\n[b]详细理由[/b]\n%s" % [plain.call(compared.label), plain.call(words.summary), plain.call(compared.text), plain.call(words.details)] + "\n\n[color=#a4b9b4]%s · 不同选择值得讨论，不等于已确认的错误。[/color]" % plain.call(words.status)
	host.status.text = host.store.error

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
				var label = Practice.feedback(decision_view, analysis, answer.action, int(answer.amount))
				answer.attempt = host.store.add_attempt(History.hand_id(current.record), int(current.point), current.topic, answer.action, int(answer.amount), label)
				results.append({"topic": current.topic, "feedback": label})
			_persist()
			_render_case()
	if playing and not branch_paused and game != null and game.actor > 0:
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
