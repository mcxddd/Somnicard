extends VBoxContainer
## Depends on host: _select_portrait_tab, _toggle_coach, add_child, next_decision, frames, index, _hero_decision, live_mode, ACTIONS, _money, use_bb, _precise_money, _stop_play, visible, points_picker, decision_points, training_store, current_record, teaching_changed, open_replay, title, comparison_button.
var host
const UI = preload("res://scripts/ui/style.gd")
const History = preload("res://scripts/poker/history.gd")
const Feedback = preload("res://scripts/poker/decision_feedback.gd")
const Teaching = preload("res://scripts/poker/teaching.gd")
const Advisor = preload("res://scripts/poker/advisor.gd")
const Eval = preload("res://scripts/poker/evaluator.gd")
const TouchScroll = preload("res://scripts/ui/touch_scroll.gd")
const RangeGrid = preload("res://scripts/ui/range_grid.gd")
const Card = preload("res://scripts/ui/card_view.gd")
const CoachAvatar = preload("res://scripts/ui/coach_avatar.gd")
var refine_button: Button
var refine_pending
var refine_pending_key = ""
var coach_avatar: Button
var overlay_close: Button
var live_teaching: bool = true
var review_teaching: bool = true
var teaching_toggle: Button
var method_label: Label
var reason_label: Label
var strategy_label: Label
var strategy_rows: VBoxContainer
var strategy_rows_key: String = ""
var range_button: Button
var range_box: VBoxContainer
var range_picker: OptionButton
var range_note: Label
var range_selection: Label
var range_grid
var cancel_analysis: Button
var analysis_next: Button
var context_cards: Array = []
var context_row: HBoxContainer
var cache: Dictionary = {}
var job
var job_key: String = ""
var analysis: Dictionary = {}
var event_label: Label
var details: RichTextLabel
var analyze_button: Button
var analysis_summary: VBoxContainer
var recommendation: Label
var equity_label: Label
var equity_bar: ProgressBar
var metric_label: Label
var expanded_details: bool = false
var detail_toggle: Button
var analysis_scroll: ScrollContainer
var details_column: VBoxContainer
var odds_bar: ProgressBar
var comparison_label: Label
const Practice = preload("res://scripts/poker/practice.gd")
var comparisons: Array = []
var comparison_index = 0


func build() -> void:
	var overlay_heading = HBoxContainer.new()
	self.add_child(overlay_heading)
	var overlay_title = UI.label("牌桌教练 · 近似", 18, UI.GOLD)
	overlay_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_heading.add_child(overlay_title)
	detail_toggle = UI.button("详解", func():
		expanded_details = not expanded_details
		analysis_scroll.reset_scroll()
		_render_details(), Color("243a40"), 44)
	overlay_heading.add_child(detail_toggle)
	overlay_close = UI.button("收起", func(): host._select_portrait_tab(false), Color("243a40"), 44)
	overlay_heading.add_child(overlay_close)
	coach_avatar = CoachAvatar.new()
	coach_avatar.pressed.connect(host._toggle_coach)
	host.add_child(coach_avatar)
	analysis_scroll = TouchScroll.new()
	analysis_scroll.follow_focus = true
	analysis_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	analysis_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	self.add_child(analysis_scroll)
	var right = VBoxContainer.new()
	details_column = right
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	analysis_scroll.add_child(right)
	var teaching_row = HBoxContainer.new()
	teaching_row.add_theme_constant_override("separation", 8)
	right.add_child(teaching_row)
	teaching_toggle = UI.button("", _toggle_teaching)
	teaching_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	teaching_row.add_child(teaching_toggle)
	analysis_next = UI.button("下个决策 ›", host.next_decision)
	teaching_row.add_child(analysis_next)
	event_label = UI.label("", 21, UI.GOLD)
	event_label.custom_minimum_size = Vector2(294, 78)
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(event_label)
	context_row = HBoxContainer.new()
	context_row.add_theme_constant_override("separation", 7)
	right.add_child(context_row)
	for i in range(7):
		if i == 2:
			var space = Control.new()
			space.custom_minimum_size.x = 10
			context_row.add_child(space)
		var card = Card.new()
		card.custom_minimum_size = Vector2(48 if i < 2 else 43, 66)
		context_cards.append(card)
		context_row.add_child(card)
	analyze_button = UI.button("分析这个决策", _analyze, UI.GREEN)
	right.add_child(analyze_button)
	cancel_analysis = UI.button("停止计算", func(): job = null; analysis = {}; _render_details())
	right.add_child(cancel_analysis)
	refine_button = UI.button("精细河牌分析 · 每次最多 20 秒", _refine, UI.GREEN)
	right.add_child(refine_button)
	analysis_summary = VBoxContainer.new()
	analysis_summary.add_theme_constant_override("separation", 6)
	right.add_child(analysis_summary)
	recommendation = UI.label("", 25, UI.GOLD)
	recommendation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context_row.add_child(recommendation)
	recommendation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in range(context_cards.size()):
		context_cards[i].visible = i < 2
		context_cards[i].custom_minimum_size = Vector2(38, 54)
	context_row.get_child(2).hide()
	right.move_child(context_row, 0)
	right.move_child(analysis_summary, 1)
	teaching_toggle.reparent(overlay_heading)
	overlay_heading.move_child(teaching_toggle, 1)
	teaching_toggle.size_flags_horizontal = Control.SIZE_FILL
	teaching_toggle.custom_minimum_size.y = 44
	teaching_row.hide()
	method_label = UI.label("范围推断 · 离线教学", 16, UI.MUTED)
	method_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	analysis_summary.add_child(method_label)
	reason_label = UI.label("", 19, UI.TEXT)
	reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	analysis_summary.add_child(reason_label)
	equity_label = UI.label("", 29, UI.TEXT)
	analysis_summary.add_child(equity_label)
	equity_bar = ProgressBar.new()
	equity_bar.show_percentage = false
	equity_bar.custom_minimum_size.y = 12
	equity_bar.add_theme_stylebox_override("background", UI.surface(Color("2c4148"), 3, 0))
	equity_bar.add_theme_stylebox_override("fill", UI.surface(UI.GOLD, 3, 0))
	analysis_summary.add_child(equity_bar)
	metric_label = UI.label("", 15, UI.MUTED)
	metric_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	analysis_summary.add_child(metric_label)
	comparison_label = UI.label("", 19, UI.GOLD)
	comparison_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	analysis_summary.add_child(comparison_label)
	odds_bar = ProgressBar.new()
	odds_bar.custom_minimum_size.y = 12
	odds_bar.show_percentage = false
	odds_bar.add_theme_stylebox_override("fill", UI.surface(UI.BLUE, 4, 0))
	analysis_summary.add_child(odds_bar)
	# Lead with the decision and its price/equity comparison; explanations follow.
	analysis_summary.move_child(equity_label, 0)
	analysis_summary.move_child(comparison_label, 1)
	analysis_summary.move_child(reason_label, 2)
	equity_label.add_theme_font_size_override("font_size", 22)
	reason_label.add_theme_font_size_override("font_size", 18)
	comparison_label.add_theme_font_size_override("font_size", 17)
	strategy_rows = VBoxContainer.new()
	strategy_rows.add_theme_constant_override("separation", 6)
	analysis_summary.add_child(strategy_rows)
	strategy_label = UI.label("", 18, UI.GOLD)
	strategy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	analysis_summary.add_child(strategy_label)
	range_button = UI.button("展开对手范围 ▾", func():
		if not analysis_scroll.can_activate(): return
		range_box.visible = not range_box.visible
		range_button.text = "收起对手范围 ▴" if range_box.visible else "展开对手范围 ▾")
	right.add_child(range_button)
	range_box = VBoxContainer.new()
	range_box.add_theme_constant_override("separation", 10)
	right.add_child(range_box)
	range_picker = OptionButton.new()
	range_picker.custom_minimum_size.y = 52
	range_picker.item_selected.connect(_select_range)
	range_box.add_child(range_picker)
	range_note = UI.label("", 18, UI.TEXT)
	range_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	range_box.add_child(range_note)
	range_grid = RangeGrid.new()
	range_grid.selected.connect(_range_hand_selected)
	range_box.add_child(range_grid)
	# Keep the selected probability outside the scrolling body, so inspecting
	# lower rows never requires scrolling back past the grid (or changes layout).
	range_selection = UI.label("轻点格子查看占比 · 滑动仅滚动", 17, UI.GOLD)
	range_selection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	range_selection.custom_minimum_size.y = 48
	range_selection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	self.add_child(range_selection)
	range_box.visibility_changed.connect(func(): range_selection.visible = range_box.visible)
	var legend = UI.label("颜色越亮，单个组合权重越高。点击格子看概率。\n上三角同花，下三角不同花，对角线对子。\n位置与行动似然是经验模型，未经真实人群校准。", 16, UI.MUTED)
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	range_box.add_child(legend)
	range_box.hide()
	details = RichTextLabel.new()
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.fit_content = true
	details.bbcode_enabled = true
	details.scroll_active = false
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_theme_font_size_override("normal_font_size", 18)
	details.add_theme_color_override("default_color", UI.TEXT)
	right.add_child(details)
	right.move_child(details, 2)

func _render_details() -> void:
	var view: Dictionary = host.frames[host.index].view
	var enabled = teaching_enabled()
	var fine_strategy: Dictionary = analysis.get("strategy", {})
	refine_button.visible = enabled and host._hero_decision() and view.phase == "river" and job == null and (fine_strategy.get("supported", false) or fine_strategy.get("preparing", false)) and (fine_strategy.get("precision", 0) == 0 or fine_strategy.get("budget_limited", false))
	refine_button.text = "继续精细计算 · 追加最多 20 秒" if refine_pending != null and refine_pending_key == Advisor.cache_key(view) else "精细河牌分析 · 每次最多 20 秒"
	teaching_toggle.text = "教学" + (" · 开" if enabled else " · 关")
	teaching_toggle.add_theme_stylebox_override("normal", UI.surface(UI.GREEN if enabled else Color("243a40"), 9, 12))
	analysis_next.visible = not host.live_mode
	analyze_button.visible = enabled and host._hero_decision() and analysis.is_empty() and job == null
	analyze_button.disabled = not host._hero_decision() or job != null
	cancel_analysis.visible = job != null
	analysis_summary.visible = enabled and job == null and not analysis.is_empty() and not analysis.has("error")
	recommendation.visible = analysis_summary.visible
	detail_toggle.visible = analysis_summary.visible
	detail_toggle.text = "简览" if expanded_details else "详解"
	details.visible = not analysis_summary.visible or expanded_details
	for extra in [method_label, equity_bar, metric_label, strategy_rows, strategy_label, odds_bar]: extra.hide()
	range_button.visible = analysis_summary.visible and expanded_details
	if not range_button.visible: range_box.hide()
	if job != null:
		details.text = job.progress_text() + "\n可随时停止、切换步骤或返回。"
		return
	if enabled and not analysis.is_empty():
		if analysis.has("error"):
			details.text = analysis.error
			return
		var suggestion: String = host.ACTIONS[analysis.action]
		if analysis.action == "raise": suggestion += "到 " + host._money(analysis.amount)
		recommendation.text = "建议你" + suggestion
		var teaching = Teaching.explain(view, analysis, host.use_bb)
		reason_label.text = teaching.summary
		if not host.live_mode: reason_label.text += _decision_feedback()
		equity_label.text = "预计分池份额 %.1f%%" % (analysis.pot_equity * 100)
		equity_bar.value = analysis.pot_equity * 100
		comparison_label.text = "跟注 %s · 回本门槛 %.1f%%" % [host._money(analysis.cost), analysis.odds * 100] if analysis.cost > 0 else "现在可以免费过牌"
		details.text = teaching.details + "\n\n" + Practice.reliability(analysis)
		for heading in ["这手牌的处境", "需要注意什么", "换一种打法会怎样", "下一步怎么观察", "本手练习重点"]:
			details.text = details.text.replace(heading, "[b][color=#e5c17a]" + heading + "[/color][/b]")
		var strategy: Dictionary = analysis.get("strategy", {})
		method_label.visible = true
		method_label.text = teaching.status
		strategy_rows.visible = expanded_details and strategy.get("supported", false)
		strategy_label.visible = expanded_details
		if strategy.get("supported", false):
			strategy_label.text = "模型内可利用度 ε：%s / 目标 %s\n%s\n表中 EV 是当前牌力档位的未来净值，不是精确底牌的收益；未达目标时频率只供观察。" % [host._precise_money(strategy.exploitability), host._precise_money(strategy.tolerance), strategy.reason]
		else: strategy_label.text = strategy.get("reason", "当前仅提供经验建议。")
		_render_strategy_rows(strategy)
	elif view.phase == "complete":
		var lines: Array = ["本手净变化（已扣投入）"]
		for seat in view.seats:
			var paid: int = view.result.payouts.get(seat.id, 0)
			lines.append("%s  %s" % [seat.name, host._money(paid - int(view.result.contributions[seat.id]))])
		for p in range(view.result.pots.size()):
			var pot = view.result.pots[p]
			lines.append("\n%s %s" % ["主池" if p == 0 else "边池 %d" % p, host._money(pot.amount)])
			for id in pot.shares: lines.append("%s 分得 %s" % [view.seats[id].name, host._money(pot.shares[id])])
		for id in view.result.ranks:
			var rank = view.result.ranks[id]
			var cards: Array = []
			for card in rank.cards: cards.append(Eval.card_text(card))
			lines.append("\n%s · %s\n%s" % [view.seats[id].name, rank.name, " ".join(cards)])
		details.text = "\n".join(lines)
	elif not enabled:
		details.text = "教学已关闭。你仍可查看行动、回放和摊牌结果。上方开关仅影响当前教学模式，另一模式的设置独立保留。"
	else:
		details.text = "先想一想：对手可能持有哪些牌？你的跟注门槛是多少？\n\n点击“分析这个决策”查看基于当时信息的胜率、操作建议与原因。" if host._hero_decision() else "逐步查看发牌与每次下注。点击“我的下个决策”可跳到你的操作之前，再计算建议。"
		details.text += "\n\n回放在你的决策点自动暂停。公共牌只随步骤揭示，对手底牌仅在实际摊牌时显示。\n\n右上角可随时切换 BB / 筹码；1 BB = %d 筹码。" % view.big_blind

func _analyze() -> void:
	if job != null: return
	if not host._hero_decision() or not teaching_enabled(): return
	host._select_portrait_tab(true)
	host._stop_play()
	job_key = Advisor.cache_key(host.frames[host.index].view)
	if cache.has(job_key):
		analysis = cache[job_key]
		_fill_ranges()
		_render_details()
		return
	job = Advisor.new(host.frames[host.index].view)
	job.solver_budget_ms = 8000
	analyze_button.disabled = true
	_render_details()

func _process(_delta: float) -> void:
	if not host.visible or job == null: return
	var deadline = Time.get_ticks_usec() + 4500
	while not job.is_done() and Time.get_ticks_usec() < deadline: job.step(4)
	if job.is_done():
		analysis = job.result()
		if job.precision == 1:
			refine_pending = job if job.solver_timed_out else null
			refine_pending_key = Advisor.cache_key(host.frames[host.index].view)
		if cache.size() >= 100: cache.erase(cache.keys()[0])
		cache[job_key] = analysis
		job = null
		_fill_ranges()
		if not host.live_mode and host.points_picker != null:
			for n in range(host.decision_points.size()):
				if host.decision_points[n].frame != host.index: continue
				var e = host.frames[host.index + 1].event
				var label = host.points_picker.get_item_text(n + 1)
				var note = Practice.feedback(host.frames[host.index].view, analysis, e.action, int(e.to))
				if host.training_store != null:
					var assessment = Feedback.compare(host.frames[host.index].view, analysis, e.action, int(e.to), host.use_bb)
					host.training_store.remember_decision(History.hand_id(host.current_record), host.decision_points[n].point, host.decision_points[n].topic, note, assessment.scored, assessment.text)
				if note in ["边缘决策", "不同选择"] and not label.contains(note): host.points_picker.set_item_text(n + 1, label + " · " + note)
		analyze_button.disabled = false
	_render_details()

func teaching_enabled() -> bool:
	return live_teaching if host.live_mode else review_teaching

func _render_strategy_rows(strategy: Dictionary) -> void:
	var key = JSON.stringify(strategy) + str(host.use_bb)
	if key == strategy_rows_key: return
	strategy_rows_key = key
	for child in strategy_rows.get_children():
		strategy_rows.remove_child(child)
		child.queue_free()
	if not strategy.get("supported", false): return
	var rows: Array = [["可选打法", "参考比例", "模型 EV"]]
	for choice in strategy.frequencies:
		var action_text: String = host.ACTIONS[choice.action]
		if choice.action == "raise": action_text += "到 " + host._money(choice.amount)
		rows.append([action_text, "%.1f%%" % (choice.frequency * 100), host._precise_money(choice.ev)])
	for i in range(rows.size()):
		var row = HBoxContainer.new()
		strategy_rows.add_child(row)
		for col in range(3):
			var label = UI.label(rows[i][col], 16 if i == 0 else 19, UI.MUTED if i == 0 else UI.GOLD)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.size_flags_stretch_ratio = 1.35 if col == 0 else 1.0
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if col == 0 else HORIZONTAL_ALIGNMENT_RIGHT
			label.text_direction = Control.TEXT_DIRECTION_LTR
			row.add_child(label)

func _decision_feedback() -> String:
	# Read the subsequent recorded choice ONLY for feedback after analysis.
	# This never enters Advisor, its seed, cache key or range observations.
	for i in range(host.index + 1, host.frames.size()):
		var event: Dictionary = host.frames[i].event
		if event.get("kind", "") == "action" and event.get("seat", -1) == 0:
			var actual: String = host.ACTIONS.get(event.action, event.action)
			if event.action == "raise": actual += "到 " + host._money(event.to)
			var compared = Feedback.compare(host.frames[host.index].view, analysis, event.action, int(event.to), host.use_bb)
			return "\n\n当时选择：" + actual + " · " + compared.label + "\n" + compared.text
		if host.frames[i].decision: break
	return ""

func set_teaching(live: bool, replay: bool) -> void:
	live_teaching = live
	review_teaching = replay
	if not teaching_enabled():
		job = null
		analysis = {}
	if teaching_toggle != null and not host.frames.is_empty(): _render_details()

func _toggle_teaching() -> void:
	if host.live_mode: live_teaching = not live_teaching
	else: review_teaching = not review_teaching
	job = null
	analysis = {}
	range_box.hide()
	_render_details()
	host.teaching_changed.emit(host.live_mode, teaching_enabled())

func _fill_ranges() -> void:
	if range_picker == null: return
	range_picker.clear()
	for item in analysis.get("ranges", []): range_picker.add_item("%s · %s" % [host.frames[host.index].view.seats[item.seat].name, item.position])
	if range_picker.item_count > 0: _select_range(0)

func _select_range(value: int) -> void:
	var item = analysis.ranges[value]
	range_picker.select(value)
	range_grid.set_range(item.classes, item.class_counts)
	range_selection.text = "%s · 轻点格子查看占比\n滑动仅滚动，不改变选择" % host.frames[host.index].view.seats[item.seat].name
	var candidates: Array = []
	for candidate in item.top.slice(0, 3): candidates.append(candidate.hand)
	range_note.text = "已观察到 %d 次行动，候选手牌中包括 %s。\n这是当时可能持牌的估计，不是对手实际底牌。" % [item.actions, "、".join(candidates)]

func _range_hand_selected(hand: String, mass: float) -> void:
	if range_picker.selected < 0 or range_picker.selected >= analysis.get("ranges", []).size(): return
	var item = analysis.ranges[range_picker.selected]
	range_selection.text = "%s · %s · %.2f%%\n手牌类别占比，不是胜率 · s 同花 / o 不同花" % [host.frames[host.index].view.seats[item.seat].name, hand, mass * 100]


func open_comparison(versions: Array, selected: int, bb: bool) -> void:
	var chosen: Array = versions.duplicate(true)
	var rebuilt = History.replay(chosen[selected].record)
	if rebuilt.has("error"): return
	host.open_replay(rebuilt, bb)
	comparisons = chosen
	comparison_index = selected
	host.title.text = chosen[selected].label
	host.comparison_button.show()
	host.comparison_button.text = "切换到" + chosen[1 - selected].label

func _refine() -> void:
	if not host._hero_decision() or not teaching_enabled() or job != null: return
	host._stop_play()
	job_key = Advisor.cache_key(host.frames[host.index].view) + ":fine"
	if refine_pending != null and refine_pending_key == Advisor.cache_key(host.frames[host.index].view):
		job = refine_pending
		job.solver_started_ms = Time.get_ticks_msec()
		job.solver_timed_out = false
		analysis = {}
		_render_details()
		return
	if cache.has(job_key):
		analysis = cache[job_key]
		_render_details()
		return
	job = Advisor.new(host.frames[host.index].view, 2400, true, 1)
	job.solver_budget_ms = 20000
	analysis = {}
	_render_details()
