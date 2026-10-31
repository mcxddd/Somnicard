extends ColorRect
signal practice_requested(record: Dictionary, point: int)
signal closed
signal units_changed(use_bb: bool)
signal teaching_changed(live: bool, enabled: bool)
const UI = preload("res://scripts/ui/style.gd")
const UnitSwitch = preload("res://scripts/ui/unit_switch.gd")
const HistoryFilter = preload("res://scripts/poker/history_filter.gd")
const History = preload("res://scripts/poker/history.gd")
const Feedback = preload("res://scripts/poker/decision_feedback.gd")
const Teaching = preload("res://scripts/poker/teaching.gd")
const Advisor = preload("res://scripts/poker/advisor.gd")
const TableView = preload("res://scripts/ui/table_view.gd")
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
const PHASES = {"preflop": "翻牌前", "flop": "翻牌", "turn": "转牌", "river": "河牌", "complete": "结算"}
const ACTIONS = {"fold": "弃牌", "check": "过牌", "call": "跟注", "raise": "加注"}
const PAGE_SIZE = 25
var use_bb: bool = true
var frames: Array = []
var index: int = 0
var page: int = 0
var filenames: Array = []
var entries: Array = []
var live_mode: bool = false
var cache: Dictionary = {}
var job
var job_key: String = ""
var analysis: Dictionary = {}
var title: Label
var units
var back: Button
var history_page: VBoxContainer
var help_page: VBoxContainer
var help_text: RichTextLabel
var help_copy: String
var replay_page: HBoxContainer
var history_list: ItemList
var history_status: Label
var previous_page: Button
var next_page: Button
var table_view
var slider: HSlider
var position_label: Label
var event_label: Label
var details: RichTextLabel
var analyze_button: Button
var prev: Button
var next: Button
var play: Button
var mine: Button
var street: OptionButton
var timer: Timer
var close_button: Button
var analysis_summary: VBoxContainer
var recommendation: Label
var equity_label: Label
var equity_bar: ProgressBar
var metric_label: Label
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
var expanded_details: bool = false
var detail_toggle: Button
var replay_event: Label
var analysis_scroll: ScrollContainer
var details_column: VBoxContainer
var selected_seat: int = -1
var margin: MarginContainer
var history_scroll
var list_offset: int = 0
var history_restore_generation: int = 0
var record_id_label: Label
var odds_bar: ProgressBar
var comparison_label: Label
var history_cards: VBoxContainer
var open_button: Button
var history_directory: String = History.DIRECTORY
var history_catalog: Array = []
var all_filenames: Array = []
var scan_cursor: int = -1
var search: LineEdit
var filter_button: Button
var filter_panel: VBoxContainer
var filters: Dictionary = {}
var filter_timer: Timer
var reset_filters: Button
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
var comparisons: Array = []
var comparison_index = 0
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
	back = UI.button("‹ 历史列表", show_history)
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
	close_button = UI.button("返回练习", close)
	header.add_child(close_button)
	history_page = VBoxContainer.new()
	history_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history_page.add_theme_constant_override("separation", 14)
	column.add_child(history_page)
	history_status = UI.label("", 18, UI.MUTED)
	history_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	history_page.add_child(history_status)
	_build_history_filters()
	history_list = ItemList.new()
	history_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history_list.add_theme_font_size_override("font_size", 21)
	history_list.add_theme_constant_override("v_separation", 18)
	history_list.add_theme_stylebox_override("panel", UI.surface(Color("10252d"), 12, 12))
	for state in ["selected", "selected_focus"]: history_list.add_theme_stylebox_override(state, UI.surface(Color("22584d"), 8, 8))
	history_list.add_theme_color_override("font_color", UI.TEXT)
	history_list.item_activated.connect(_open_entry)
	history_page.add_child(history_list)
	history_scroll = TouchScroll.new()
	history_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	history_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history_page.add_child(history_scroll)
	history_cards = VBoxContainer.new()
	history_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_cards.add_theme_constant_override("separation", 10)
	history_scroll.add_child(history_cards)
	history_scroll.hide()
	var paging = HBoxContainer.new()
	paging.add_theme_constant_override("separation", 14)
	history_page.add_child(paging)
	previous_page = UI.button("上一页", func(): page -= 1; list_offset = 0; _fill_history())
	next_page = UI.button("下一页", func(): page += 1; list_offset = 0; _fill_history())
	paging.add_child(previous_page)
	paging.add_child(next_page)
	open_button = UI.button("打开选中牌局", func():
		if not history_list.get_selected_items().is_empty(): _open_entry(history_list.get_selected_items()[0]), UI.GREEN)
	open_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paging.add_child(open_button)
	help_page = VBoxContainer.new()
	help_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(help_page)
	help_text = RichTextLabel.new()
	help_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	help_text.add_theme_font_size_override("normal_font_size", 22)
	help_text.add_theme_color_override("default_color", UI.TEXT)
	help_text.text = "SOMNICARD 1.12 · 德州扑克练习\n\n1. 主界面点击“开始新局”，选择 2–9 人和初始筹码，再配置电脑对手。你固定坐在下方；其余都是独立电脑。每手结算后点击“下一手”继续。\n\n2. BB 是大盲单位。本桌盲注为 5 / 10，1 BB = 10 筹码；右上角切换单位不会改变实际金额。“加到”指本轮总投入，不是额外投入。\n\n3. BB、底池比例与滑条只填写金额，点击加注后才提交。半池加注按跟注后的底池计算；全押默认需要再次确认，可在设置中关闭。\n\n4. 点击牌桌悬浮教练头像，在同一界面查看建议与原因，随时收起或直接行动；设置可关闭教练、自动提示或改变头像位置。设置中的对局教学与复盘教学分别开关，教学页也可即时切换。范围来自公开行动与经验似然。限定剩两人的河牌支持多尺度与有效全押的抽象 CFR，可主动进行精细分析并分段继续计算，展示参考比例、模型净值与误差；复盘比较实际选择，未覆盖尺寸不评分。其余场景提供经验建议；不是完整 GTO。\n\n5. 完成的牌局自动保存。从主界面“牌局复盘”或牌桌菜单进入历史，点击一手牌即可打开。可逐步回放、拖动时间轴、跳转下注轮次，或跳到“我的下个决策”。回放会在你的决策点暂停。\n\n6. 分析只使用当时自己的底牌、公共牌、公开行动和筹码。平局会按分池比例计入权益；有边池时只计算你有资格争夺的部分。输赢不等于操作质量。\n\n7. 当前桌在操作后自动保存，重启后可在主界面“恢复上次牌桌”，再点“继续”。牌桌菜单中的“返回主界面”会保留当前进度。后台会自动暂停。新开桌替换当前存档，已完成历史保留；卸载应用或清除数据可能删除记录。\n\n训练室：从主界面或牌桌“更多”进入，选择主题和来源，每组最多 5 个局面。先作答再看讲解，可用所选操作继续与电脑打完；重打有保留原牌和重新采样未知牌两种模式，分支独立保存。复盘“工具”可收藏、备注、跳转决策或练习此处。训练室分为“开始练习、练习记录、表现统计”。本地备份移到“设置 → 数据与备份”，导入导出是立即执行的文件操作，不需要保存设置。\n\n手机和电脑统一竖屏。底部“加注”打开金额面板，收起不会下注；“更多”包含设置、历史、记录。多人桌点座位查看详情，摊牌之前不公开对手底牌。复盘点击悬浮教练头像，在牌桌上展开分析；下方回放控制始终保留。\n\n设置：主界面“设置”或牌桌“更多 → 牌桌设置”。先选择分类，再修改具体选项；分类间返回保留草稿，点击“保存设置”才生效，“取消修改”放弃草稿。支持对局节奏、弃牌快进、两种配色、BB 单位、四色花色、发牌动效与全押保护。\n\n桌面快捷键：F 弃牌，空格过牌 / 跟注，R 输入金额，P 暂停；Esc / 安卓返回键返回上一层；主界面再次返回会确认退出。\n\n牌力评测：设置 → 牌力评测，查看本版 21,312 手实测，或单独测试本地电脑；支持暂停、继续与导出。结果不换算真人段位，默认不自动运行。训练室会整理待讨论决策，可回到原局或选择同主题尚未练过的局面。\n\n当前范围：虚拟筹码、本地电脑对战、复盘与训练；没有账户或支付。多人连续牌局采用移动庄家的练习规则，不包含完整锦标赛死庄与盲注升级。\n\n引擎与许可\nGodot Engine — https://godotengine.org/license/\n源代码：https://github.com/godotengine/godot\n\n" + Engine.get_license_text()
	help_page.add_child(help_text)
	help_copy = help_text.text
	help_page.add_child(UI.button("查看引擎第三方组件许可", func():
		var lines: Array = ["Godot 第三方组件版权与许可"]
		for component in Engine.get_copyright_info():
			lines.append("\n" + component.name)
			for part in component.parts:
				lines.append("\n".join(part.copyright))
				lines.append("License: " + part.license)
		var licenses = Engine.get_license_info()
		for name in licenses: lines.append("\n" + name + "\n" + licenses[name])
		help_text.text = "\n".join(lines)
		help_text.scroll_to_line(0)))
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
	var panel = UI.panel(Color("142b32"), 16, 16)
	analysis_panel = panel
	panel.custom_minimum_size.x = 326
	add_child(panel)
	var overlay_column = VBoxContainer.new()
	overlay_column.add_theme_constant_override("separation", 8)
	panel.add_child(overlay_column)
	var overlay_heading = HBoxContainer.new()
	overlay_column.add_child(overlay_heading)
	var overlay_title = UI.label("牌桌教练 · 近似", 18, UI.GOLD)
	overlay_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_heading.add_child(overlay_title)
	detail_toggle = UI.button("详解", func():
		expanded_details = not expanded_details
		analysis_scroll.reset_scroll()
		_render_details(), Color("243a40"), 44)
	overlay_heading.add_child(detail_toggle)
	overlay_close = UI.button("收起", func(): _select_portrait_tab(false), Color("243a40"), 44)
	overlay_heading.add_child(overlay_close)
	coach_avatar = CoachAvatar.new()
	coach_avatar.pressed.connect(_toggle_coach)
	add_child(coach_avatar)
	analysis_scroll = TouchScroll.new()
	analysis_scroll.follow_focus = true
	analysis_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	analysis_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_column.add_child(analysis_scroll)
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
	analysis_next = UI.button("下个决策 ›", next_decision)
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
	overlay_column.add_child(range_selection)
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
		open_comparison(comparisons, 1 - comparison_index, use_bb))
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
			if teaching_enabled(): _analyze())
	practice_tools.add_child(points_picker)
	practice_tools.hide()
	notes = Notes.new()
	add_child(notes)
	notes.saved.connect(func():
		if scan_cursor < 0 and history_page.visible: _apply_history_filter())

func open_history(bb: bool) -> void:
	use_bb = bb
	units.select(1 if bb else 0)
	show()
	show_history()
	close_button.grab_focus()

func show_history() -> void:
	if practice_tools != null:
		practice_tools.hide()
		practice_entry.hide()
	_select_portrait_tab(false)
	coach_avatar.hide()
	record_id_label.hide()
	_stop_play()
	job = null
	live_mode = false
	frames = []
	back.hide()
	history_page.show()
	help_page.hide()
	replay_page.hide()
	title.text = "历史牌局"
	portrait_tabs.hide()
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
		var card = UI.button(label, func():
			if history_scroll.can_activate():
				list_offset = history_scroll.scroll_vertical
				history_list.select(entry_index)
				_open_entry(entry_index), Color("17313a"), 136)
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.focus_mode = Control.FOCUS_NONE
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.add_theme_font_size_override("font_size", 20)
		card.clip_text = true
		card.tooltip_text = label
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
	if generation == history_restore_generation and is_visible_in_tree() and history_page.visible and history_scroll.pointer == -2:
		history_scroll.reset_scroll(target)

func _record_label(record: Dictionary, filename: String) -> String:
	if not record.get("starting_stacks") is Array: return filename + " · 格式待校验"
	var date: String = str(record.get("saved_at", "")).left(30)
	if date.is_empty():
		var stamp = filename.get_slice("-", 0)
		if stamp.is_valid_int() and int(stamp) > 0 and int(stamp) < 4102444800:
			date = Time.get_datetime_string_from_unix_time(int(stamp) + int(Time.get_time_zone_from_system().bias) * 60).replace("T", " ")
		else: date = filename.left(35)
	var hand_text: String = str(int(record.hand)) if History._integer(record.get("hand"), 1, 100000000) else "?"
	var label = "%s%s%d 人桌 · 第 %s 手" % [date, "\n" if portrait else "    ·    ", record.starting_stacks.size(), hand_text]
	var result = record.get("result")
	if result is Dictionary and result.get("payouts") is Dictionary and result.get("contributions") is Array and not result.contributions.is_empty():
		var paid = result.payouts.get("0", result.payouts.get(0))
		var contributed = result.contributions[0]
		if History._integer(paid, 0, 900000000) and History._integer(contributed, 0, 100000000) and History._integer(record.get("big_blind"), 1, 1000000):
			var net: int = int(paid) - int(contributed)
			label += ("\n净变化 " if portrait else "    ·    净变化 ") + ("+" if net > 0 else "") + UI.money(net, int(record.big_blind), use_bb)
	label += ("\n" if portrait else " · ") + "ID " + History.hand_id(record)
	if training_store != null:
		var m = training_store.mark(History.hand_id(record))
		if m.star or m.pending: label += " · " + ("★ 收藏 " if m.star else "") + ("待复习" if m.pending else "")
	return label

func _open_entry(entry: int) -> void:
	if entry < 0 or entry >= entries.size(): return
	var loaded = entries[entry]
	if loaded.has("error"):
		history_status.text = loaded.error
		return
	var rebuilt = History.replay(loaded.record)
	if rebuilt.has("error"):
		history_status.text = "无法打开这手牌：" + rebuilt.error + "。可以选择其他记录继续练习。"
		return
	open_replay(rebuilt, use_bb)

func open_replay(rebuilt: Dictionary, bb: bool) -> void:
	comparisons = []
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
	expanded_details = false
	record_id_label.text = "ID " + History.hand_id(rebuilt.record)
	record_id_label.show()
	use_bb = bb
	units.select(1 if bb else 0)
	frames = rebuilt.frames
	history_page.hide()
	help_page.hide()
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
	expanded_details = true
	record_id_label.hide()
	use_bb = bb
	units.select(1 if bb else 0)
	frames = [{"view": view.duplicate(true), "event": {"kind": "decision", "seat": 0}, "decision": true}]
	history_page.hide()
	help_page.hide()
	replay_page.show()
	back.hide()
	title.text = "当前决策 · 练习提示"
	_select_portrait_tab(true)
	show()
	seek(0)
	_analyze()
	close_button.grab_focus()

func close() -> void:
	_stop_play()
	job = null
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
	if analysis_selected and _hero_decision() and teaching_enabled() and analysis.is_empty(): _analyze()

func open_help(bb: bool) -> void:
	open_history(bb)
	history_page.hide()
	replay_page.hide()
	help_page.show()
	help_text.text = help_copy
	help_text.scroll_to_line(0)
	title.text = "玩法帮助 · 关于"
	portrait_tabs.hide()
	analysis_panel.hide()
	coach_avatar.hide()

func set_units(bb: bool) -> void:
	use_bb = bb
	units.select(1 if bb else 0)
	if not frames.is_empty(): _render()
	elif history_page.visible and scan_cursor < 0:
		list_offset = history_scroll.scroll_vertical
		_fill_history()

func seek(value: int, stop: bool = true) -> void:
	if frames.is_empty(): return
	if stop: _stop_play()
	index = clampi(value, 0, frames.size() - 1)
	selected_seat = -1
	analysis_scroll.reset_scroll()
	job = null
	analysis = {}
	if _hero_decision() and teaching_enabled(): analysis = cache.get(Advisor.cache_key(frames[index].view), {})
	range_box.hide()
	range_button.text = "展开对手范围 ▾"
	_fill_ranges()
	_render()
	if analysis_selected and _hero_decision() and teaching_enabled() and analysis.is_empty(): _analyze()

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
	event_label.hide()
	event_label.text = _describe(frame.event, view)
	context_row.visible = _hero_decision()
	if _hero_decision():
		event_label.text = "%s · 底池 %s\n你的手牌 / 当时公共牌" % [PHASES.get(view.phase, ""), _money(view.pot)]
		for i in range(7):
			var cards: Array = view.seats[0].hole if i < 2 else view.board
			var offset = i if i < 2 else i - 2
			context_cards[i].set_card(cards[offset] if offset < cards.size() else -2, table_view.four_color, false)
	replay_event.text = event_label.text.replace("\n", " · ")
	analyze_button.disabled = not _hero_decision() or job != null
	_render_details()

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

func _render_details() -> void:
	var view: Dictionary = frames[index].view
	var enabled = teaching_enabled()
	var fine_strategy: Dictionary = analysis.get("strategy", {})
	refine_button.visible = enabled and _hero_decision() and view.phase == "river" and job == null and (fine_strategy.get("supported", false) or fine_strategy.get("preparing", false)) and (fine_strategy.get("precision", 0) == 0 or fine_strategy.get("budget_limited", false))
	refine_button.text = "继续精细计算 · 追加最多 20 秒" if refine_pending != null and refine_pending_key == Advisor.cache_key(view) else "精细河牌分析 · 每次最多 20 秒"
	teaching_toggle.text = "教学" + (" · 开" if enabled else " · 关")
	teaching_toggle.add_theme_stylebox_override("normal", UI.surface(UI.GREEN if enabled else Color("243a40"), 9, 12))
	analysis_next.visible = not live_mode
	analyze_button.visible = enabled and _hero_decision() and analysis.is_empty() and job == null
	analyze_button.disabled = not _hero_decision() or job != null
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
		var suggestion: String = ACTIONS[analysis.action]
		if analysis.action == "raise": suggestion += "到 " + _money(analysis.amount)
		recommendation.text = "建议你" + suggestion
		var teaching = Teaching.explain(view, analysis, use_bb)
		reason_label.text = teaching.summary
		if not live_mode: reason_label.text += _decision_feedback()
		equity_label.text = "预计分池份额 %.1f%%" % (analysis.pot_equity * 100)
		equity_bar.value = analysis.pot_equity * 100
		comparison_label.text = "跟注 %s · 回本门槛 %.1f%%" % [_money(analysis.cost), analysis.odds * 100] if analysis.cost > 0 else "现在可以免费过牌"
		details.text = teaching.details + "\n\n" + Practice.reliability(analysis)
		for heading in ["这手牌的处境", "需要注意什么", "换一种打法会怎样", "下一步怎么观察", "本手练习重点"]:
			details.text = details.text.replace(heading, "[b][color=#e5c17a]" + heading + "[/color][/b]")
		var strategy: Dictionary = analysis.get("strategy", {})
		method_label.visible = true
		method_label.text = teaching.status
		strategy_rows.visible = expanded_details and strategy.get("supported", false)
		strategy_label.visible = expanded_details
		if strategy.get("supported", false):
			strategy_label.text = "模型内可利用度 ε：%s / 目标 %s\n%s\n表中 EV 是当前牌力档位的未来净值，不是精确底牌的收益；未达目标时频率只供观察。" % [_precise_money(strategy.exploitability), _precise_money(strategy.tolerance), strategy.reason]
		else: strategy_label.text = strategy.get("reason", "当前仅提供经验建议。")
		_render_strategy_rows(strategy)
	elif view.phase == "complete":
		var lines: Array = ["本手净变化（已扣投入）"]
		for seat in view.seats:
			var paid: int = view.result.payouts.get(seat.id, 0)
			lines.append("%s  %s" % [seat.name, _money(paid - int(view.result.contributions[seat.id]))])
		for p in range(view.result.pots.size()):
			var pot = view.result.pots[p]
			lines.append("\n%s %s" % ["主池" if p == 0 else "边池 %d" % p, _money(pot.amount)])
			for id in pot.shares: lines.append("%s 分得 %s" % [view.seats[id].name, _money(pot.shares[id])])
		for id in view.result.ranks:
			var rank = view.result.ranks[id]
			var cards: Array = []
			for card in rank.cards: cards.append(Eval.card_text(card))
			lines.append("\n%s · %s\n%s" % [view.seats[id].name, rank.name, " ".join(cards)])
		details.text = "\n".join(lines)
	elif not enabled:
		details.text = "教学已关闭。你仍可查看行动、回放和摊牌结果。上方开关仅影响当前教学模式，另一模式的设置独立保留。"
	else:
		details.text = "先想一想：对手可能持有哪些牌？你的跟注门槛是多少？\n\n点击“分析这个决策”查看基于当时信息的胜率、操作建议与原因。" if _hero_decision() else "逐步查看发牌与每次下注。点击“我的下个决策”可跳到你的操作之前，再计算建议。"
		details.text += "\n\n回放在你的决策点自动暂停。公共牌只随步骤揭示，对手底牌仅在实际摊牌时显示。\n\n右上角可随时切换 BB / 筹码；1 BB = %d 筹码。" % view.big_blind

func _analyze() -> void:
	if job != null: return
	if not _hero_decision() or not teaching_enabled(): return
	_select_portrait_tab(true)
	_stop_play()
	job_key = Advisor.cache_key(frames[index].view)
	if cache.has(job_key):
		analysis = cache[job_key]
		_fill_ranges()
		_render_details()
		return
	job = Advisor.new(frames[index].view)
	job.solver_budget_ms = 8000
	analyze_button.disabled = true
	_render_details()

func _process(_delta: float) -> void:
	if visible and history_page.visible and scan_cursor >= 0: _scan_history()
	_layout_overlay()
	if not visible or job == null: return
	var deadline = Time.get_ticks_usec() + 4500
	while not job.is_done() and Time.get_ticks_usec() < deadline: job.step(4)
	if job.is_done():
		analysis = job.result()
		if job.precision == 1:
			refine_pending = job if job.solver_timed_out else null
			refine_pending_key = Advisor.cache_key(frames[index].view)
		if cache.size() >= 100: cache.erase(cache.keys()[0])
		cache[job_key] = analysis
		job = null
		_fill_ranges()
		if not live_mode and points_picker != null:
			for n in range(decision_points.size()):
				if decision_points[n].frame != index: continue
				var e = frames[index + 1].event
				var label = points_picker.get_item_text(n + 1)
				var note = Practice.feedback(frames[index].view, analysis, e.action, int(e.to))
				if training_store != null:
					var assessment = Feedback.compare(frames[index].view, analysis, e.action, int(e.to), use_bb)
					training_store.remember_decision(History.hand_id(current_record), decision_points[n].point, decision_points[n].topic, note, assessment.scored, assessment.text)
				if note in ["边缘决策", "不同选择"] and not label.contains(note): points_picker.set_item_text(n + 1, label + " · " + note)
		analyze_button.disabled = false
	_render_details()

func teaching_enabled() -> bool:
	return live_teaching if live_mode else review_teaching

func _render_strategy_rows(strategy: Dictionary) -> void:
	var key = JSON.stringify(strategy) + str(use_bb)
	if key == strategy_rows_key: return
	strategy_rows_key = key
	for child in strategy_rows.get_children():
		strategy_rows.remove_child(child)
		child.queue_free()
	if not strategy.get("supported", false): return
	var rows: Array = [["可选打法", "参考比例", "模型 EV"]]
	for choice in strategy.frequencies:
		var action_text: String = ACTIONS[choice.action]
		if choice.action == "raise": action_text += "到 " + _money(choice.amount)
		rows.append([action_text, "%.1f%%" % (choice.frequency * 100), _precise_money(choice.ev)])
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
	for i in range(index + 1, frames.size()):
		var event: Dictionary = frames[i].event
		if event.get("kind", "") == "action" and event.get("seat", -1) == 0:
			var actual: String = ACTIONS.get(event.action, event.action)
			if event.action == "raise": actual += "到 " + _money(event.to)
			var compared = Feedback.compare(frames[index].view, analysis, event.action, int(event.to), use_bb)
			return "\n\n当时选择：" + actual + " · " + compared.label + "\n" + compared.text
		if frames[i].decision: break
	return ""

func set_teaching(live: bool, replay: bool) -> void:
	live_teaching = live
	review_teaching = replay
	if not teaching_enabled():
		job = null
		analysis = {}
	if teaching_toggle != null and not frames.is_empty(): _render_details()

func _toggle_teaching() -> void:
	if live_mode: live_teaching = not live_teaching
	else: review_teaching = not review_teaching
	job = null
	analysis = {}
	range_box.hide()
	_render_details()
	teaching_changed.emit(live_mode, teaching_enabled())

func _fill_ranges() -> void:
	if range_picker == null: return
	range_picker.clear()
	for item in analysis.get("ranges", []): range_picker.add_item("%s · %s" % [frames[index].view.seats[item.seat].name, item.position])
	if range_picker.item_count > 0: _select_range(0)

func _select_range(value: int) -> void:
	var item = analysis.ranges[value]
	range_picker.select(value)
	range_grid.set_range(item.classes, item.class_counts)
	range_selection.text = "%s · 轻点格子查看占比\n滑动仅滚动，不改变选择" % frames[index].view.seats[item.seat].name
	var candidates: Array = []
	for candidate in item.top.slice(0, 3): candidates.append(candidate.hand)
	range_note.text = "已观察到 %d 次行动，候选手牌中包括 %s。\n这是当时可能持牌的估计，不是对手实际底牌。" % [item.actions, "、".join(candidates)]

func _range_hand_selected(hand: String, mass: float) -> void:
	if range_picker.selected < 0 or range_picker.selected >= analysis.get("ranges", []).size(): return
	var item = analysis.ranges[range_picker.selected]
	range_selection.text = "%s · %s · %.2f%%\n手牌类别占比，不是胜率 · s 同花 / o 不同花" % [frames[index].view.seats[item.seat].name, hand, mass * 100]


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
	event_label.custom_minimum_size = Vector2(0 if portrait else 294, 36)
	if title.get_parent() != (column if portrait else header): title.reparent(column if portrait else header)
	if portrait:
		column.move_child(title, 1)
		column.move_child(portrait_tabs, 2)
	else: header.move_child(title, 1)
	title.add_theme_font_size_override("font_size", 22 if portrait else 26)
	history_list.add_theme_font_size_override("font_size", 19 if portrait else 21)
	history_list.max_text_lines = 2 if portrait else 1
	history_list.visible = not portrait
	history_scroll.visible = portrait
	open_button.visible = not portrait
	_select_portrait_tab(analysis_selected)
	if history_page.visible and visible and scan_cursor < 0:
		list_offset = history_scroll.scroll_vertical
		_fill_history()

func _select_portrait_tab(analyze: bool) -> void:
	analysis_selected = analyze
	portrait_tabs.hide()
	left.show()
	analysis_panel.visible = replay_page.visible and analyze
	coach_avatar.visible = replay_page.visible and not analyze
	if analyze: _stop_play()
	else: job = null
	_layout_overlay()

func _layout_overlay() -> void:
	if coach_avatar == null or not replay_page.visible: return
	var table_rect = table_view.get_global_rect()
	coach_avatar.position = table_rect.end - global_position - Vector2(78, 82)
	coach_avatar.size = Vector2(72, 78)
	# Keep the actual community cards visible even on the shortest portrait screens.
	var below_board = table_rect.end.y - table_view.board_row.get_global_rect().end.y - 8
	analysis_panel.size = Vector2(size.x - 24, minf(340 if expanded_details else 270, maxf(180, below_board)))
	analysis_panel.position = Vector2(12, table_rect.end.y - global_position.y - analysis_panel.size.y)

func _show_seat(id: int) -> void:
	if frames.is_empty(): return
	_stop_play()
	var seat = frames[index].view.seats[id]
	selected_seat = id
	event_label.show()
	details_column.move_child(event_label, 0)
	event_label.text = table_view.seat_nodes[id].panel.tooltip_text
	var cards: Array = []
	for card in seat.hole: cards.append(Eval.card_text(card))
	event_label.text += "\n底牌：" + (" ".join(cards) if not cards.is_empty() else "当时未公开")
	_select_portrait_tab(true)

func _build_history_filters() -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	history_page.add_child(row)
	history_page.move_child(row, 0)
	search = LineEdit.new()
	search.placeholder_text = "搜索牌局 ID 或日期"
	search.clear_button_enabled = true
	search.custom_minimum_size.y = 48
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(search)
	filter_button = UI.button("筛选", func(): filter_panel.visible = not filter_panel.visible)
	row.add_child(filter_button)
	filter_panel = VBoxContainer.new()
	filter_panel.add_theme_constant_override("separation", 8)
	history_page.add_child(filter_panel)
	history_page.move_child(filter_panel, 1)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	filter_panel.add_child(grid)
	var labels = {
		"players": ["人数：全部", "2 人桌", "3 人桌", "4 人桌", "5 人桌", "6 人桌", "7 人桌", "8 人桌", "9 人桌"],
		"result": ["结果：全部", "净赢", "净输", "不输不赢"],
		"days": ["时间：全部", "今天", "近 7 天", "近 30 天"],
		"ending": ["结束：全部", "有摊牌", "无摊牌"],
		"action": ["我的行动：全部", "我曾全押", "我曾加注"],
		"sort": ["排序：最近", "底池最大（BB）", "亏损最多（BB）"],
		"saved": ["标记：全部", "已收藏", "待复习"],
		"tag": ["标签：全部"] + preload("res://scripts/poker/training_store.gd").TAGS}
	for key in labels:
		var picker = OptionButton.new()
		picker.custom_minimum_size = Vector2(0, 48)
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		picker.fit_to_longest_item = false
		for label in labels[key]: picker.add_item(label)
		filters[key] = picker
		grid.add_child(picker)
		picker.item_selected.connect(func(_value): _filters_changed())
	reset_filters = UI.button("重置全部条件", _reset_history_filters)
	filter_panel.add_child(reset_filters)
	filter_panel.hide()
	filter_timer = Timer.new()
	filter_timer.one_shot = true
	filter_timer.wait_time = 0.18
	add_child(filter_timer)
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
	var count = 0
	for key in filters:
		if filters[key].selected > 0: count += 1
	filter_button.text = "筛选" + (" · %d" % count if count > 0 else "")
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
	if training_store != null:
		selected_catalog = history_catalog.filter(func(item):
			var m = training_store.mark(item.id)
			if filters.saved.selected == 1 and not m.star: return false
			if filters.saved.selected == 2 and not m.pending: return false
			if filters.tag.selected > 0 and filters.tag.get_item_text(filters.tag.selected) not in m.tags: return false
			return true)
	filenames = HistoryFilter.select(selected_catalog, _filter_values(), Time.get_date_string_from_system())
	page = mini(page, maxi(0, ceili(float(filenames.size()) / PAGE_SIZE) - 1))
	_fill_history()

func open_comparison(versions: Array, selected: int, bb: bool) -> void:
	var chosen: Array = versions.duplicate(true)
	var rebuilt = History.replay(chosen[selected].record)
	if rebuilt.has("error"): return
	open_replay(rebuilt, bb)
	comparisons = chosen
	comparison_index = selected
	title.text = chosen[selected].label
	comparison_button.show()
	comparison_button.text = "切换到" + chosen[1 - selected].label

func _refine() -> void:
	if not _hero_decision() or not teaching_enabled() or job != null: return
	_stop_play()
	job_key = Advisor.cache_key(frames[index].view) + ":fine"
	if refine_pending != null and refine_pending_key == Advisor.cache_key(frames[index].view):
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
	job = Advisor.new(frames[index].view, 2400, true, 1)
	job.solver_budget_ms = 20000
	analysis = {}
	_render_details()
