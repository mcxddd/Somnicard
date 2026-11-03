extends ColorRect
## The app's stable starting point. Table setup is a separate destination.
signal destination(name: String)
const UI = preload("res://scripts/ui/style.gd")
const Scroll = preload("res://scripts/ui/touch_scroll.gd")
var primary: Button
var new_table: Button
var session_note: Label
var status: Label
var scroll
var entries: Dictionary = {}
var learning
var learning_note: Label
var recent: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color("0b1920")
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 22)
	add_child(margin)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var head = HBoxContainer.new()
	column.add_child(head)
	var brand = HBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.add_theme_constant_override("separation", 10)
	head.add_child(brand)
	var mark = TextureRect.new()
	mark.texture = load("res://assets/logo-mark.svg")
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.custom_minimum_size = Vector2(34 * mark.texture.get_width() / float(mark.texture.get_height()), 34)
	brand.add_child(mark)
	var wordmark = TextureRect.new()
	wordmark.texture = load("res://assets/wordmark.svg")
	wordmark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wordmark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wordmark.custom_minimum_size = Vector2(22 * wordmark.texture.get_width() / float(wordmark.texture.get_height()), 22)
	brand.add_child(wordmark)
	head.add_child(UI.label("私人练习室", 16, UI.MUTED))
	scroll = Scroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	var hero = UI.card("hero")
	body.add_child(hero)
	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	hero.add_child(inner)
	inner.add_child(UI.title("每一手，都更明白"))
	inner.add_child(UI.caption("自由对战 · 即时教练 · 回到关键决定"))
	inner.add_child(UI.art(preload("res://assets/art/home-hero.png"), 150))
	session_note = UI.caption("2–6 人电脑对战 · 对手强度可调")
	inner.add_child(session_note)
	primary = UI.primary("开始新局  →", func(): destination.emit("play"), 64)
	inner.add_child(primary)
	new_table = UI.secondary("另开一张牌桌", func(): destination.emit("new"), 50)
	inner.add_child(new_table)
	body.add_child(UI.heading("今天，练好一个决定"))
	learning = UI.entry("学习路线", "", func():
		if scroll.can_activate(): destination.emit("academy"), "learn")
	body.add_child(learning)
	entries["academy"] = learning
	learning_note = UI.caption("")
	body.add_child(learning_note)
	var paths = HBoxContainer.new()
	paths.add_theme_constant_override("separation", 12)
	body.add_child(paths)
	for spec in [["training", "训练室", "先作答，再看评级和理由", "train"], ["history", "牌局复盘", "回放、收藏与重打", "review"]]:
		var id: String = spec[0]
		var button = UI.entry(spec[1], spec[2], func():
			if scroll.can_activate(): destination.emit(id), spec[3], true)
		paths.add_child(button)
		entries[id] = button
	# Filled by update_recent(): how the last hands and practice went.
	recent = VBoxContainer.new()
	recent.add_theme_constant_override("separation", 8)
	body.add_child(recent)
	status = UI.caption("虚拟筹码 · 记录保存在本机")
	body.add_child(status)
	var utility = HBoxContainer.new()
	utility.add_theme_constant_override("separation", 12)
	column.add_child(utility)
	for spec in [["settings", "设置"], ["help", "帮助与关于"]]:
		var b = UI.secondary(spec[1], func(): destination.emit(spec[0]), 54)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		utility.add_child(b)
		entries[spec[0]] = b
	column.add_child(UI.label("SOMNICARD  " + str(ProjectSettings.get_setting("application/config/version")), 13, UI.MUTED, true))
	hide()

func update_session(active: bool, saved: bool, detail: String) -> void:
	primary.text = "继续对局  →" if active else "恢复上次牌桌  →" if saved else "开始新局  →"
	new_table.visible = active or saved
	session_note.text = detail if active else "上次牌桌已保存在本机，恢复后保持暂停。" if saved else "2–6 人电脑对战 · 对手强度可调"
	status.text = "当前牌桌已保留，回到牌桌后继续。" if active else "虚拟筹码 · 记录保存在本机"

## summary: {hands, net_bb, vpip, mastery (-1 when unknown), streak}.
func update_recent(summary: Dictionary) -> void:
	UI.clear(recent)
	recent.add_child(UI.heading("最近表现"))
	var hands: int = summary.get("hands", 0)
	if hands == 0 and summary.get("mastery", -1.0) < 0:
		recent.add_child(UI.caption("打完几手、做几道训练题后，这里会显示你最近的表现。"))
		return
	var net: float = summary.get("net_bb", 0.0)
	var items: Array = []
	if hands > 0:
		items.append(["%+.1f" % net, "近 %d 手 BB" % hands, UI.SUCCESS if net > 0 else UI.DANGER if net < 0 else UI.TEXT])
		items.append(["%.0f%%" % (100.0 * summary.get("vpip", 0.0)), "主动入池"])
	var mastery: float = summary.get("mastery", -1.0)
	items.append(["%.0f%%" % (100 * mastery) if mastery >= 0 else "—", "训练掌握率"])
	recent.add_child(UI.stat_row(items))
	var streak: int = summary.get("streak", 0)
	recent.add_child(UI.caption("已连续 %d 天打牌或练习，保持节奏。" % streak if streak >= 2 else "今天也来练一手吧。" if streak == 0 else "今天已经练过了。"))

func update_learning(data: Dictionary) -> void:
	var academy = preload("res://scripts/product/academy.gd")
	var p = academy.progress(data)
	var pending = academy.missed(data)
	var detail = "有 %d 道错题待复习" % pending.size() if not pending.is_empty() else "基础路线已完成，随时温习" if p.lessons == academy.LESSONS.size() else "接着学：" + academy.LESSONS[p.next].title
	learning.set_lines("学习路线 · %d/%d 课" % [p.lessons, academy.LESSONS.size()], detail)
	learning_note.text = "今天的 3 题目标完成了，休息一下也很好。" if p.today >= 3 else "今天已练 %d / 3 题，先作答，再看教练。" % p.today
