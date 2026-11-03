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
var hole_cards: Array = []
var avatar: Button
var panel: PanelContainer
var headline: Label
var metrics: Label
var figures: HBoxContainer
var reason: Label
## "What they might hold": one line per live opponent from the range model.
var reads: Label
var reads_box: PanelContainer
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
	panel = UI.panel(UI.CARD, 18, 14)
	add_child(panel)
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	# Header: who is talking and a way out. Settings and the full analysis sit at the bottom.
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	var title = UI.label("教练建议", UI.SIZE_BODY, UI.GOLD)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	var scope = UI.label("离线近似", UI.SIZE_CAPTION, UI.MUTED)
	scope.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scope.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(scope)
	row.add_child(_link("收起", collapse))
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
	headline.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	decision.add_child(headline)
	figures = HBoxContainer.new()
	figures.add_theme_constant_override("separation", 8)
	content.add_child(figures)
	metrics = UI.caption("")
	content.add_child(metrics)
	progress = UI.progress(0)
	content.add_child(progress)
	# An inset card under the figures: what each live opponent might hold.
	reads_box = PanelContainer.new()
	reads_box.add_theme_stylebox_override("panel", UI.surface(Color("0f2328"), 10, 8, Color("24414a")))
	content.add_child(reads_box)
	var reads_column = VBoxContainer.new()
	reads_column.add_theme_constant_override("separation", 2)
	reads_box.add_child(reads_column)
	reads_column.add_child(UI.label("对手可能拿着", UI.SIZE_CAPTION, UI.GOLD))
	reads = UI.label("", UI.SIZE_CAPTION + 1, UI.TEXT)
	reads.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reads.add_theme_color_override("font_color", Color("cfe3dc"))
	reads_column.add_child(reads)
	reason = UI.body("")
	reason.add_theme_font_size_override("font_size", UI.SIZE_BODY - 2)
	reason.add_theme_color_override("font_color", UI.TEXT.darkened(0.12))
	content.add_child(reason)
	var links = HBoxContainer.new()
	links.add_theme_constant_override("separation", 8)
	col.add_child(links)
	var details = _link("完整分析 ›", func(): details_requested.emit())
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	links.add_child(details)
	links.add_child(_link("教练设置", func(): settings_requested.emit()))
	panel.hide()

## A quiet text button for secondary actions inside the panel.
func _link(text: String, callback: Callable) -> Button:
	return UI.outline(text, callback, UI.BUTTON_S) if text == "收起" else UI.link(text, callback)

func configure(values: Dictionary) -> void:
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
	panel.size = Vector2(size.x - 24, minf(340 if detailed else 290, maxf(180, dock_y - board_bottom - 16)))
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
	if avatar != null: avatar.thinking = job != null
	if headline == null or not expanded: return
	progress.visible = job != null
	UI.clear(figures)
	figures.hide()
	reads_box.hide()
	metrics.show()
	if job != null:
		headline.text = "正在分析你的决策…"
		metrics.text = job.progress_text()
		reason.text = "只使用你的底牌与已公开的信息。可以收起或直接行动。"
		progress.value = float(job.samples) / job.target
	elif analysis.is_empty() or analysis.has("error"):
		headline.text = "轮到你时提供建议"
		metrics.text = ""
		metrics.hide()
		reason.text = analysis.get("error", "你也可以随时在设置中关闭教练或调整提示方式。")
	else:
		headline.text = "建议" + {"fold": "弃牌", "check": "过牌", "call": "跟注", "raise": "加注到 "}.get(analysis.action, "")
		if analysis.action == "raise": headline.text += UI.money(analysis.amount, view.big_blind, use_bb)
		if analysis.action == "call": headline.text += " " + UI.money(analysis.cost, view.big_blind, use_bb)
		# Key numbers as figures; the caption under them says how firm the estimate is.
		var items = [["%.0f%%" % (analysis.pot_equity * 100), "预计分池份额", UI.GOLD]]
		if analysis.cost > 0: items.append(["%.0f%%" % (analysis.odds * 100), "跟注回本门槛", UI.TEXT])
		else: items.append(["%.0f%%" % (analysis.win * 100), "预计胜率", UI.TEXT])
		for item in items: figures.add_child(UI.stat(item[0], item[1], item[2]))
		figures.show()
		reads.text = read_lines(view, analysis)
		reads_box.visible = not reads.text.is_empty()
		if reads_box.visible and detailed: reads.text += "
" + calibration_text()
		var teaching = Teaching.explain(view, analysis, use_bb)
		metrics.text = teaching.status
		reason.text = teaching.summary + ("\n\n" + teaching.context + "\n\n" + teaching.focus if detailed else "")

## One line per live opponent (two at most): made-hand groups after the flop,
## how concentrated the range is before it, and the likeliest starting hands.
static func read_lines(snapshot: Dictionary, result: Dictionary) -> String:
	var lines: Array = []
	for summary in result.get("ranges", []).slice(0, 2):
		var name_text = str(snapshot.seats[summary.seat].name)
		var top = " ".join(summary.top.slice(0, 3).map(func(t): return t.hand))
		var b: Dictionary = summary.get("buckets", {})
		var line: String
		if not b.is_empty():
			line = "%s：强牌 %.0f%% · 中等 %.0f%% · 听牌 %.0f%% · 空气 %.0f%%" % [name_text, b.strong * 100, b.medium * 100, b.draw * 100, b.air * 100]
		else:
			line = "%s：范围集中在约 %.0f%% 的起手牌" % [name_text, 100.0 * summary.effective_combos / maxf(1.0, summary.available_combos)]
		lines.append(line + "｜常见 " + top + ("（入门对手，范围放宽）" if summary.get("loose", false) else ""))
	return "\n".join(lines)

## Measured read accuracy against the shipped bots (tools/benchmarks/range_calibration.gd --publish).
static func calibration_text() -> String:
	var path = "res://data/range-calibration.json"
	if not FileAccess.file_exists(path): return ""
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary: return ""
	var parts: Array = []
	for level in range(3):
		parts.append("%s %.0f%%" % [["入门", "标准", "进阶"][level], data.levels[level].coverage50 * 100])
	return "读牌实测：真实底牌落在“最可能的一半”里的比例（理想 50%）：" + " · ".join(parts) + "。只针对本游戏电脑，不代表真人。"
