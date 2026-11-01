extends ColorRect
signal closed
signal practice_requested(topic: String)
const UI = preload("res://scripts/ui/style.gd")
const Academy = preload("res://scripts/product/academy.gd")
var store
var scroll
var body: VBoxContainer
var title: Label
var subtitle: Label
var back_button: Button
var next_button: Button
var lesson = -1
var question = 0
var answer_buttons: Array = []
var feedback: Label
var answered = false
var review_queue: Array = []
var review_cursor = 0
var question_attempted = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = UI.BACKGROUND
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 20)
	add_child(margin)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	var header = HBoxContainer.new()
	column.add_child(header)
	back_button = UI.button("‹ 返回", back_action)
	header.add_child(back_button)
	title = UI.label("学习路线", 28, UI.GOLD)
	header.add_child(title)
	subtitle = UI.label("", 18, UI.MUTED)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(subtitle)
	scroll = preload("res://scripts/ui/touch_scroll.gd").new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	scroll.add_child(body)
	next_button = UI.button("", _next, UI.GREEN, 60)
	column.add_child(next_button)
	hide()

func open() -> void:
	if store == null: return
	show()
	_overview()
	back_button.grab_focus()

func _text(value: String, size: int = 21, tint: Color = UI.TEXT) -> Label:
	var label = UI.label(value, size, tint)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(label)
	return label

func _overview() -> void:
	lesson = -1
	review_queue.clear()
	UI.clear(body)
	title.text = "学习路线"
	var progress = Academy.progress(store.data)
	subtitle.text = "按自己的节奏学，随时返回牌桌。"
	var pending = Academy.missed(store.data)
	body.add_child(UI.stat_row([["%d/%d" % [progress.lessons, Academy.LESSONS.size()], "已学完的课"], ["%d/%d" % [progress.questions, Academy.question_ids().size()], "掌握的知识点", UI.GOLD], [str(pending.size()), "待复习错题", UI.DANGER if not pending.is_empty() else UI.TEXT]]))
	_text("从看懂一手牌，到讲清一个决定。", 25)
	_text("每课几个局面，先选择，再看理由。学习进度保存在本机，也包含在学习记录备份中。", 17, UI.MUTED)
	if not pending.is_empty():
		body.add_child(UI.entry("错题复习 · %d 题" % pending.size(), "把做错的题再做一遍，答对后移出", func():
			if scroll.can_activate(): start_review(), "review-mistakes"))
	for i in range(Academy.LESSONS.size()):
		var course = Academy.LESSONS[i]
		var correct = 0
		for q in range(course.questions.size()):
			if store.data.get("academy", {}).get(course.id + ":" + str(q), {}).get("correct", false): correct += 1
		var finished = correct == course.questions.size()
		var button = UI.entry("%02d  %s" % [i + 1, course.title], ("已完成 · " if finished else "%d / %d · " % [correct, course.questions.size()]) + course.subtitle, func():
			if scroll.can_activate(): start_lesson(i), "lesson-done" if finished else "lesson")
		body.add_child(button)
	next_button.text = "进入主题训练" if progress.lessons == Academy.LESSONS.size() else "继续学习 · " + Academy.LESSONS[progress.next].title
	next_button.disabled = false
	scroll.reset_scroll()

func start_lesson(index: int) -> void:
	if index < 0 or index >= Academy.LESSONS.size(): return
	review_queue.clear()
	lesson = index
	question = 0
	_render_question()

func start_review() -> void:
	review_queue = Academy.missed(store.data).slice(0, 5)
	if review_queue.is_empty():
		_overview()
		return
	review_cursor = 0
	_review_question()

func _review_question() -> void:
	var id: String = review_queue[review_cursor]
	for i in range(Academy.LESSONS.size()):
		if Academy.LESSONS[i].id == id.get_slice(":", 0):
			lesson = i
			break
	question = int(id.get_slice(":", 1))
	_render_question()

func _render_question() -> void:
	UI.clear(body)
	answer_buttons.clear()
	answered = false
	question_attempted = false
	var course = Academy.LESSONS[lesson]
	var item = course.questions[question]
	title.text = "错题复习" if not review_queue.is_empty() else course.title
	subtitle.text = "第 %d / %d 个局面 · %s" % [review_cursor + 1, review_queue.size(), course.title] if not review_queue.is_empty() else "第 %d / %d 个局面 · %s" % [question + 1, course.questions.size(), course.subtitle]
	_text("先想一想", 17, UI.GOLD)
	_text(item.prompt, 25)
	for i in range(item.choices.size()):
		var button = UI.button(["A", "B", "C"][i] + "   " + item.choices[i], func():
			if scroll.can_activate(): choose(i), Color("1d343e"), 76)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		body.add_child(button)
		answer_buttons.append(button)
	feedback = _text("选好后会显示具体理由。", 19, UI.MUTED)
	if not review_queue.is_empty(): next_button.text = "下一题" if review_cursor < review_queue.size() - 1 else "完成复习"
	else: next_button.text = "下一题" if question < course.questions.size() - 1 else "完成本课"
	next_button.disabled = true
	scroll.reset_scroll()

func choose(index: int) -> void:
	if answered: return
	var result = Academy.answer(store, lesson, question, index, not review_queue.is_empty() and not question_attempted)
	if result.has("error"): return
	question_attempted = true
	answered = result.correct
	feedback.text = ("判断正确\n\n" if result.correct else "换个角度想一想\n\n") + result.reason
	if not result.saved: feedback.text += "\n\n进度暂未写入磁盘：" + store.error
	feedback.add_theme_color_override("font_color", UI.TEXT if result.correct else UI.GOLD)
	for i in range(answer_buttons.size()):
		answer_buttons[i].disabled = result.correct or i == index
	next_button.disabled = not result.correct
	if result.correct: next_button.grab_focus()
	scroll.ensure_control_visible(feedback)

func _next() -> void:
	if lesson < 0:
		var progress = Academy.progress(store.data)
		if progress.lessons == Academy.LESSONS.size(): practice_requested.emit("翻前入池")
		else: start_lesson(progress.next)
	elif answered:
		if not review_queue.is_empty():
			if review_cursor < review_queue.size() - 1:
				review_cursor += 1
				_review_question()
			else: _overview()
		elif question < Academy.LESSONS[lesson].questions.size() - 1:
			question += 1
			_render_question()
		else:
			var topic: String = Academy.LESSONS[lesson].topic
			UI.clear(body)
			title.text = "这一课，掌握了"
			subtitle.text = "%s · %d 个知识点已完成" % [Academy.LESSONS[lesson].title, Academy.LESSONS[lesson].questions.size()]
			_text("把理解带到真实决定里。", 27, UI.GOLD)
			_text("下一步可以做一组「%s」练习：先选择操作，再查看教练建议。结果可能有模型误差，重点是说清自己的理由。" % topic)
			body.add_child(UI.button("练习 · " + topic, func():
				if scroll.can_activate(): practice_requested.emit(topic), UI.GREEN, 66))
			body.add_child(UI.button("返回学习路线", _overview, Color("243a40"), 60))
			next_button.disabled = true
			next_button.text = "本课已完成"
			scroll.reset_scroll()

func back_action() -> void:
	if lesson >= 0: _overview()
	else:
		hide()
		closed.emit()
