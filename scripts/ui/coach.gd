extends Control
signal settings_requested
signal details_requested
signal review_requested
const UI = preload("res://scripts/ui/style.gd")
const Teaching = preload("res://scripts/poker/teaching.gd")
const Advisor = preload("res://scripts/poker/advisor.gd")
const Avatar = preload("res://scripts/ui/coach_avatar.gd")
const Card = preload("res://scripts/ui/card_view.gd")
const TouchScroll = preload("res://scripts/ui/touch_scroll.gd")
var ai_entry: Button
var hole_cards: Array = []
var avatar: Button
var panel: PanelContainer
var headline: Label
var metrics: Label
var reason: Label
var progress: ProgressBar
var scroll: ScrollContainer
var job
var analysis: Dictionary = {}
var view: Dictionary = {}
var key: String = ""
var expanded: bool = false
var use_bb: bool = true
var detailed: bool = false
var left_side: bool = false
var automatic: bool = false
var four_color: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar = Avatar.new()
	avatar.pressed.connect(toggle)
	add_child(avatar)
	panel = UI.panel(Color("152f36"), 18, 14)
	add_child(panel)
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	var row = HBoxContainer.new()
	col.add_child(row)
	var title = UI.label("教练 · 离线近似", 18, UI.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(UI.button("设置", func(): settings_requested.emit(), Color("243a40"), 44))
	row.add_child(UI.button("详解", func(): details_requested.emit(), Color("243a40"), 44))
	row.add_child(UI.button("收起", collapse, Color("243a40"), 44))
	scroll = TouchScroll.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	var decision = HBoxContainer.new()
	decision.add_theme_constant_override("separation", 8)
	content.add_child(decision)
	for i in range(2):
		var card = Card.new()
		card.custom_minimum_size = Vector2(38, 54)
		card.motion = false
		decision.add_child(card)
		hole_cards.append(card)
	headline = UI.label("轮到你时提供建议", 24, UI.TEXT)
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	headline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	decision.add_child(headline)
	metrics = UI.label("", 17, UI.GOLD)
	metrics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(metrics)
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 8
	progress.show_percentage = false
	content.add_child(progress)
	reason = UI.label("", 17, UI.MUTED)
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(reason)
	ai_entry = UI.button("AI 讲解 / 提问 ›", func(): details_requested.emit(), UI.GREEN, 44)
	content.add_child(ai_entry)
	ai_entry.hide()
	panel.hide()

func configure(values: Dictionary) -> void:
	ai_entry.visible = values.get("ai_live_coach", false)
	detailed = values.get("coach_detail", 0) == 1
	left_side = values.get("coach_side", 1) == 0
	automatic = values.get("coach_auto", false)
	four_color = values.get("four_color", false)
	if not values.get("live_teaching", true): collapse()
	_render()

func sync(snapshot: Dictionary, bb: bool, enabled: bool, available: bool) -> void:
	use_bb = bb
	visible = enabled and available
	if not visible:
		collapse()
		return
	view = snapshot
	avatar.tooltip_text = "复盘刚结束的牌局" if snapshot.phase == "complete" else "打开 / 收起牌桌教练"
	for i in range(2): hole_cards[i].set_card(snapshot.seats[0].hole[i] if snapshot.seats[0].hole.size() == 2 else -2, four_color)
	var next_key: String = str(snapshot.hand) + ":" + str(snapshot.events.size())
	if key != next_key:
		key = next_key
		job = null
		analysis = {}
		if snapshot.actor != 0 or snapshot.phase == "complete": collapse()
		elif automatic: expand()
		elif expanded: _start()
	_render()

func place(table_rect: Rect2, dock_y: float, board_bottom: float) -> void:
	avatar.position = Vector2(table_rect.position.x + 4 if left_side else table_rect.end.x - 76, table_rect.end.y - 82)
	avatar.size = Vector2(72, 78)
	# Bound the sheet below the real board; long explanations scroll inside it.
	panel.size = Vector2(size.x - 24, minf(300 if detailed else 216, maxf(180, dock_y - board_bottom - 16)))
	panel.position = Vector2(12, maxf(table_rect.position.y, dock_y - panel.size.y - 8))

func toggle() -> void:
	if not view.is_empty() and view.phase == "complete":
		review_requested.emit()
		return
	if expanded: collapse()
	else: expand()

func expand() -> void:
	if not view.is_empty() and view.phase == "complete":
		review_requested.emit()
		return
	expanded = true
	panel.show()
	scroll.reset_scroll()
	if analysis.is_empty() and job == null: _start()
	_render()

func collapse() -> void:
	expanded = false
	job = null
	if panel != null: panel.hide()

func _start() -> void:
	if not view.is_empty() and view.actor == 0 and not view.legal.is_empty():
		job = Advisor.new(view)
		job.solver_budget_ms = 6000

func _process(_delta: float) -> void:
	if not is_visible_in_tree() or not expanded or job == null: return
	var deadline = Time.get_ticks_usec() + 3500
	while not job.is_done() and Time.get_ticks_usec() < deadline: job.step(4)
	if job.is_done():
		analysis = job.result()
		job = null
	_render()

func _render() -> void:
	if headline == null or not expanded: return
	progress.visible = job != null
	if job != null:
		headline.text = "正在分析你的决策…"
		metrics.text = job.progress_text()
		reason.text = "只使用你的底牌与已公开的信息。可以收起或直接行动。"
		progress.value = 100.0 * job.samples / job.target
	elif analysis.is_empty() or analysis.has("error"):
		headline.text = "轮到你时提供建议"
		metrics.text = ""
		reason.text = analysis.get("error", "你也可以随时在设置中关闭教练或调整提示方式。")
	else:
		headline.text = "建议" + {"fold": "弃牌", "check": "过牌", "call": "跟注", "raise": "加注到 "}.get(analysis.action, "")
		if analysis.action == "raise": headline.text += UI.money(analysis.amount, view.big_blind, use_bb)
		if analysis.action == "call": headline.text += " " + UI.money(analysis.cost, view.big_blind, use_bb)
		metrics.text = "预计分池份额 %.0f%% · 跟注门槛 %.0f%%" % [analysis.pot_equity * 100, analysis.odds * 100] if analysis.cost > 0 else "预计胜率 %.0f%% · 平局 %.0f%%" % [analysis.win * 100, analysis.tie * 100]
		progress.value = analysis.pot_equity * 100
		var teaching = Teaching.explain(view, analysis, use_bb)
		reason.text = teaching.status + "\n" + teaching.summary + ("\n\n" + teaching.context + "\n\n" + teaching.focus if detailed else "")
