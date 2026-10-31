extends ColorRect
## The app's stable starting point. Table setup is a separate destination.
signal destination(name: String)
const UI = preload("res://scripts/ui/style.gd")
const Scroll = preload("res://scripts/ui/touch_scroll.gd")
const Card = preload("res://scripts/ui/card_view.gd")
var primary: Button
var new_table: Button
var session_note: Label
var status: Label
var scroll
var entries: Dictionary = {}
var learning: Button
var learning_note: Label

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
	var hero = UI.panel(Color("163c37"), 24, 22)
	body.add_child(hero)
	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 9)
	hero.add_child(inner)
	inner.add_child(UI.label("每一手，都更明白", 32, UI.TEXT))
	inner.add_child(_label("自由对战 · 即时教练 · 回到关键决定", 17))
	var art = Control.new()
	art.custom_minimum_size.y = 104
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(art)
	for i in range(3):
		var card = Card.new()
		card.card_id = [49, 24, 12][i]
		card.motion = false
		card.size = Vector2(62, 88)
		card.pivot_offset = card.size / 2
		card.rotation = (i - 1) * 0.16
		art.add_child(card)
		art.resized.connect(func(): card.position = Vector2(art.size.x / 2 - 31 + (i - 1) * 44, 4 + absi(i - 1) * 8))
	session_note = _label("2–9 人电脑对战 · 对手强度可调", 18)
	inner.add_child(session_note)
	primary = UI.button("开始新局  →", func(): destination.emit("play"), UI.GREEN, 66)
	inner.add_child(primary)
	new_table = UI.button("另开一张牌桌", func(): destination.emit("new"), Color("214840"), 50)
	inner.add_child(new_table)
	learning = UI.button("学习路线  ›", func():
		if scroll.can_activate(): destination.emit("academy"), Color("263b42"), 72)
	learning.alignment = HORIZONTAL_ALIGNMENT_LEFT
	learning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(learning)
	entries["academy"] = learning
	learning_note = _label("", 17)
	body.add_child(learning_note)
	body.add_child(UI.label("今天，练好一个决定", 21, UI.GOLD))
	var paths = HBoxContainer.new()
	paths.add_theme_constant_override("separation", 14)
	body.add_child(paths)
	for spec in [["training", "训练室", "专注一个决定\n先作答，再看讲解", "01"], ["history", "牌局复盘", "回到真实牌局\n回放、收藏与重打", "02"]]:
		var button = _entry(spec[0], spec[1], spec[2], spec[3])
		paths.add_child(button)
		entries[spec[0]] = button
	status = _label("虚拟筹码 · 记录保存在本机", 16)
	body.add_child(status)
	var utility = HBoxContainer.new()
	utility.add_theme_constant_override("separation", 12)
	column.add_child(utility)
	for spec in [["settings", "设置"], ["help", "帮助与关于"]]:
		var b = UI.button(spec[1], func(): destination.emit(spec[0]), Color("172a32"), 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		utility.add_child(b)
		entries[spec[0]] = b
	column.add_child(UI.label("SOMNICARD  " + str(ProjectSettings.get_setting("application/config/version")), 13, UI.MUTED, true))
	hide()

func _label(text: String, font_size: int) -> Label:
	var label = UI.label(text, font_size, UI.MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _entry(id: String, title: String, description: String, number: String) -> Button:
	var b = UI.button("", func():
		if scroll.can_activate(): destination.emit(id), Color("162a33"), 136)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inset = MarginContainer.new()
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: inset.add_theme_constant_override("margin_" + edge, 14)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inset)
	var c = VBoxContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_theme_constant_override("separation", 8)
	inset.add_child(c)
	for label in [UI.label(number + "  /", 13, UI.GOLD), UI.label(title + "  ›", 23), _label(description, 16)]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(label)
	b.tooltip_text = title + "：" + description.replace("\n", "，")
	return b

func update_session(active: bool, saved: bool, detail: String) -> void:
	primary.text = "继续对局  →" if active else "恢复上次牌桌  →" if saved else "开始新局  →"
	new_table.visible = active or saved
	session_note.text = detail if active else "上次牌桌已保存在本机，恢复后保持暂停。" if saved else "2–9 人电脑对战 · 对手强度可调"
	status.text = "当前牌桌已保留，回到牌桌后继续。" if active else "虚拟筹码 · 记录保存在本机"

func update_learning(data: Dictionary) -> void:
	var academy = preload("res://scripts/product/academy.gd")
	var p = academy.progress(data)
	var pending = academy.missed(data)
	var detail = "有 %d 道错题待复习" % pending.size() if not pending.is_empty() else "基础路线已完成，随时温习" if p.lessons == academy.LESSONS.size() else "接着学：" + academy.LESSONS[p.next].title
	learning.text = "学习路线 · %d/%d 课  ›\n%s" % [p.lessons, academy.LESSONS.size(), detail]
	learning_note.text = "今日主题练习 %d/3 · %s" % [mini(p.today, 3), "今日目标已完成，休息一下也很好。" if p.today >= 3 else "先作答，再看教练。按自己的节奏来。"]
