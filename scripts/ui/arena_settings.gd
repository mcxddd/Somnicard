extends VBoxContainer
const UI = preload("res://scripts/ui/style.gd")
const Arena = preload("res://scripts/poker/arena.gd")
var arena
var source: OptionButton
var style: OptionButton
var blocks: OptionButton
var output: Label
var result: Label
var resume_button: Button
var start_button: Button
var export_dialog: FileDialog
var published: Label

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_note("独立牌力评测", 24)
	_note("同一牌序轮换座位，覆盖 2 / 6 / 9 人与 50 / 100 / 200 BB，对手为冻结的本地标准策略。每手重置筹码，无抽水。结果不换算真人段位。")
	add_child(UI.button("查看本版已完成的本地实测", func(): published.visible = not published.visible, UI.GREEN))
	published = UI.label(_published_summary(), 17, UI.TEXT)
	published.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(published)
	published.hide()
	source = _picker("评测对象", ["本地 · 入门", "本地 · 标准", "本地 · 进阶"])
	style = _picker("行动风格", ["均衡", "偏被动", "偏激进"])
	blocks = _picker("独立牌序数量", ["16 组 · 816 手", "64 组 · 3264 手", "256 组 · 13056 手"])
	start_button = UI.button("开始新评测", _start, UI.GREEN)
	add_child(start_button)
	resume_button = UI.button("继续 / 暂停", _resume)
	add_child(resume_button)
	output = UI.label("", 17, UI.GOLD)
	output.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(output)
	result = UI.label("", 17, UI.TEXT)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(result)
	add_child(UI.button("导出评测报告", func():
		if not arena.data.is_empty(): export_dialog.popup_centered_ratio(0.9)))
	export_dialog = FileDialog.new()
	export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.use_native_dialog = true
	export_dialog.filters = PackedStringArray(["*.json ; 牌力评测报告"])
	export_dialog.current_file = "somnicard-evaluation.json"
	export_dialog.file_selected.connect(func(path):
		var file = FileAccess.open(path, FileAccess.WRITE)
		if file == null: output.text = "无法写入报告"; return
		file.store_string(JSON.stringify(arena.report(), "\t"))
		output.text = "报告已导出，不包含牌局底牌。")
	add_child(export_dialog)
	arena = Arena.new()
	add_child(arena)
	arena.changed.connect(_render)
	if DisplayServer.get_name() != "headless" and "--capture-test" not in OS.get_cmdline_user_args(): arena.load_saved()
	else: arena.path = ""
	visibility_changed.connect(func():
		if not is_visible_in_tree(): arena.pause())
	_render()

func _note(text: String, font_size: int = 18) -> void:
	var label = UI.label(text, font_size, UI.MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)

func _picker(label: String, choices: Array) -> OptionButton:
	_note(label)
	var picker = OptionButton.new()
	picker.custom_minimum_size.y = 52
	picker.fit_to_longest_item = false
	for choice in choices: picker.add_item(choice)
	add_child(picker)
	return picker

func _start() -> void:
	# Starting a replacement requires a separate explicit press after pausing.
	if not arena.data.is_empty() and not arena.report().completed and start_button.text != "确认替换当前评测":
		arena.pause(); start_button.text = "确认替换当前评测"; return
	start_button.text = "开始新评测"
	arena.start({"level": source.selected, "style": style.selected, "blocks": [16, 64, 256][blocks.selected]})

func _resume() -> void:
	if arena.running: arena.pause()
	else: arena.resume()

func _render() -> void:
	resume_button.disabled = arena.data.is_empty() or arena.report().completed
	resume_button.text = "暂停评测" if arena.running else "继续评测"
	output.text = arena.status
	if arena.data.is_empty(): return
	output.text += "\n已完成 %d / %d 手" % [arena.data.cursor, arena.plan.size()]
	var r = arena.report()
	var lines: Array = ["有效决策 %d / %d" % [r.valid_decisions, r.decisions], "决策耗时中位数 %.2f 秒 · P95 %.2f 秒" % [r.latency_p50_ms / 1000.0, r.latency_p95_ms / 1000.0]]
	for group in r.groups:
		var g = r.groups[group]
		var b = g.behavior
		lines.append("\n%s · %d 个完整牌序块\n%+.1f BB/100%s\nVPIP %.1f%% · PFR %.1f%%" % [group, g.blocks, g.bb100, "，95%% 区间 [%+.1f, %+.1f]" % [g.low, g.high] if g.interval_available else "，样本不足", 100.0 * b.vpip / maxi(1, b.hands), 100.0 * b.pfr / maxi(1, b.hands)])
	lines.append("区间按独立牌序块计算，短期结果不用于排名。")
	result.text = "\n".join(lines)

func _published_summary() -> String:
	var evidence = preload("res://scripts/poker/evidence111.gd").DATA
	var lines: Array = ["1.11.0 · 已完成 %s 手\n三档均衡：各桌型/深度 128 个独立牌序块；两种偏向风格：9 人 / 100 BB，各 32 块。" % evidence.hands, "\n均衡风格净收益 BB/100（括号为 95% 区间）："]
	for level_id in range(3):
		lines.append("\n" + ["入门", "标准", "进阶"][level_id])
		var r: Dictionary = evidence.reports["level%d-style0" % level_id]
		for depth in [50, 100, 200]:
			for count in [2, 6, 9]:
				var group = "%d人/%dBB" % [count, depth]
				var g: Dictionary = r.groups[group]
				lines.append("%s：%+.1f [%+.1f, %+.1f]" % [group, g.bb100, g.low, g.high])
	lines.append("\n风格实测（9 人 / 100 BB · VPIP / PFR）：")
	for level_id in range(3):
		for style_id in range(3):
			var b: Dictionary = evidence.reports["level%d-style%d" % [level_id, style_id]].groups["9人/100BB"].behavior
			lines.append("%s · %s：%.1f%% / %.1f%%" % [["入门", "标准", "进阶"][level_id], ["均衡", "偏被动", "偏激进"][style_id], 100.0 * b.vpip / b.hands, 100.0 * b.pfr / b.hands])
	lines.append("\n进阶相对标准的配对区间在本次多数场景包含零，尚不能认定普遍更强。档位表示决策逻辑，不是已验证的真人段位。范围、牌序和标准对手都会影响结果；风格样本更少。")
	return "\n".join(lines)
