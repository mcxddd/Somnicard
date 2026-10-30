extends VBoxContainer
signal clear_requested
signal navigated(detail: bool)
const UI = preload("res://scripts/ui/style.gd")
const Trace = preload("res://scripts/ai/trace_log.gd")
var entries: Array = []
var dialogue: Array = []
var hand = 0
var complete = false
var seat = -1
var tab = 0
var limit = 20
var body: VBoxContainer
var note: Label

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var row = HBoxContainer.new()
	add_child(row)
	for pair in [["桌边发言", 0], ["API 请求", 1]]:
		var button = UI.button(pair[0], func(): tab = pair[1]; _render())
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
	note = UI.label("", 16, UI.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	add_child(body)
	hide()

func open(logs: Array, lines: Array, current_hand: int, ended: bool, actor: int) -> void:
	entries = logs
	dialogue = lines.filter(func(line): return line.get("seat", -1) == actor)
	hand = current_hand
	complete = ended
	seat = actor
	tab = 1 if not entries.is_empty() else 0
	limit = 20
	_render()
	show()

func _label(text: String, color: Color = UI.TEXT) -> Label:
	var label = UI.label(text, 18, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(label)
	return label

func _render() -> void:
	navigated.emit(false)
	UI.clear(body)
	if tab == 0:
		note.text = "本手该对手的公开发言；点气泡也能回到这里。"
		if dialogue.is_empty(): _label("这手暂时还没有发言。", UI.MUTED)
		for line in dialogue: _label("“%s”\n行动步骤 %d" % [line.text, line.event])
		return
	note.text = "仅保留本次牌桌最近 160 次请求（最多 2 MB），退出或新建牌桌后清除。密钥与内部推理不记录。本手内容在结束后解锁。"
	if entries.is_empty(): _label("这位对手还没有请求记录。", UI.MUTED)
	for i in range(entries.size() - 1, maxi(-1, entries.size() - limit - 1), -1):
		var entry = entries[i]
		var context = entry.get("context", {})
		var phase = {"preflop": "翻牌前", "flop": "翻牌", "turn": "转牌", "river": "河牌", "complete": "结束"}.get(context.get("phase", ""), "")
		var kind = "发言" if context.get("purpose") == "speech" else "决策"
		var state = {"pending": "请求中", "complete": "已回复", "error": "失败", "retrying": "自动重试", "cancelled": "已取消"}.get(entry.get("state", ""), "未知")
		var button = UI.button("第 %d 手 · %s · %s · %s\n%s · 尝试 %d  ›" % [context.get("hand", 0), phase, kind, state, entry.get("model", ""), entry.get("attempt", 1)], func(): _detail(entry), Color("21343d"), 76)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 17)
		body.add_child(button)
	if entries.size() > limit:
		body.add_child(UI.button("查看更多请求", func(): limit += 20; _render()))
	if not entries.is_empty():
		body.add_child(UI.button("清空本桌请求记录", func(): clear_requested.emit(); entries.clear(); _render()))

func _detail(entry: Dictionary) -> void:
	navigated.emit(true)
	UI.clear(body)
	body.add_child(UI.button("‹ 返回请求列表", _render))
	_label("%s\n%s\n第 %d 次尝试 · 生成上限 %d tokens · 耗时 %s" % [entry.get("model", ""), entry.get("url", ""), entry.get("attempt", 1), entry.get("limit", 0), "%.2f 秒" % (entry.get("elapsed_ms", 0) / 1000.0) if entry.has("elapsed_ms") else "尚未结束"], UI.GOLD)
	var reported: Dictionary = entry.get("usage", {})
	_label("HTTP：%s · 结束原因：%s\n输入 %s / 输出 %s / 推理 %s tokens" % [str(entry.get("http_status", "未知")), str(entry.get("finish_reason", "未报告")), str(reported.get("input_tokens", "未知")), str(reported.get("output_tokens", "未知")), str(reported.get("reasoning_tokens", "未知"))], UI.MUTED)
	if not str(entry.get("error", "")).is_empty(): _label(entry.error, UI.GOLD)
	if not str(entry.get("outcome", "")).is_empty(): _label(entry.outcome, UI.GOLD)
	if not Trace.unlocked(entry, hand, complete):
		_label("本手还没结束，发送内容与回复暂时隐藏。结束后再次点击该对手查看。", UI.GOLD)
		return
	_label("发送到 API 的内容", UI.GOLD)
	_text(JSON.stringify(entry.get("request", {}), "  "))
	_label("模型的可见回复", UI.GOLD)
	_text(str(entry.get("response", "")) if not str(entry.get("response", "")).is_empty() else "没有返回可见回复。")
	body.add_child(UI.button("复制本条脱敏记录", func(): DisplayServer.clipboard_set(JSON.stringify(entry, "  "))))

func _text(text: String) -> void:
	var label = RichTextLabel.new()
	label.fit_content = true
	label.scroll_active = false
	label.selection_enabled = true
	label.add_theme_font_size_override("normal_font_size", 17)
	label.text = text
	body.add_child(label)
