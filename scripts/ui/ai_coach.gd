extends VBoxContainer
const UI = preload("res://scripts/ui/style.gd")
const Client = preload("res://scripts/ai/client.gd")
const Services = preload("res://scripts/ai/services.gd")
const Protocol = preload("res://scripts/ai/coach_protocol.gd")
var client
var settings: Dictionary = {}
var data: Dictionary = {}
var fingerprint = ""
var request_fingerprint = ""
var dialogue: Array = []
var question: LineEdit
var answer: Label
var status: Label
var ask_button: Button
var quick: GridContainer
var current_question = ""
var enabled = false
var more: Button
var questions: VBoxContainer

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	add_child(UI.label("AI 教练 · 按需讲解", 19, UI.GOLD))
	ask_button = UI.button("解释这次建议", func(): ask("为什么推荐这个操作？请结合当前手牌与对手行动解释。"), UI.GREEN)
	add_child(ask_button)
	status = UI.label("主动提问才调用模型。数值以本地分析为准。", 16, UI.MUTED)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	answer = UI.label("", 18, UI.TEXT)
	answer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(answer)
	more = UI.button("追问 / 常见问题 ›", func(): questions.visible = not questions.visible)
	add_child(more)
	questions = VBoxContainer.new()
	questions.add_theme_constant_override("separation", 8)
	add_child(questions)
	questions.hide()
	quick = GridContainer.new()
	quick.columns = 2
	questions.add_child(quick)
	for q in ["为什么不跟注？", "为什么不加注？", "下注尺度怎么选？", "对手激进怎么办？"]:
		var b = UI.button(q, func(): ask(q))
		b.add_theme_font_size_override("font_size", 16)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		quick.add_child(b)
	question = LineEdit.new()
	question.placeholder_text = "问问这次决策…"
	question.max_length = 300
	question.custom_minimum_size.y = 48
	question.text_submitted.connect(ask)
	questions.add_child(question)
	questions.add_child(UI.button("发送问题", func(): ask(question.text)))
	client = Client.new()
	add_child(client)
	client.finished.connect(_received)
	visibility_changed.connect(func():
		if not is_visible_in_tree(): stop())
	hide()

func configure(values: Dictionary) -> void:
	stop()
	settings = values.duplicate(true)
	# Do not retain unrelated opponent identity/memory or settings in this widget.
	for k in settings.keys():
		if k not in ["ai_profiles", "ai_service", "ai_keys", "ai_key", "coach_service_id", "ai_live_coach", "ai_review_coach"]: settings.erase(k)
	dialogue.clear()
	answer.text = ""
	fingerprint = ""

func sync(view: Dictionary, analysis: Dictionary, live: bool, step_id: String) -> void:
	enabled = settings.get("ai_live_coach" if live else "ai_review_coach", false)
	visible = enabled and not analysis.is_empty() and not analysis.has("error") and view.actor == 0
	if not visible:
		stop()
		return
	var next = Protocol.context(view, analysis)
	var stamp = (step_id + JSON.stringify(next)).sha256_text()
	if stamp != fingerprint:
		stop()
		data = next
		fingerprint = stamp
		dialogue.clear()
		answer.text = ""
		question.text = ""
		questions.hide()
		status.text = "依据当前步骤 · 不读取后续结果。主动提问才调用模型。"

func ask(text: String) -> void:
	if client.busy:
		stop()
		return
	if not enabled or data.is_empty() or not is_visible_in_tree() or text.strip_edges().is_empty(): return
	if dialogue.size() >= 12:
		status.text = "本决策已完成多轮问答，请切换到其他决策继续练习。"
		return
	var id = str(settings.get("coach_service_id", "default"))
	var service = Services.resolve(settings.get("ai_profiles", []), id, settings.get("ai_service", {}))
	var key = str(settings.get("ai_keys", {}).get(id, settings.get("ai_key", "") if id == "default" else ""))
	current_question = text.strip_edges().left(300)
	request_fingerprint = fingerprint
	ask_button.text = "取消讲解"
	status.text = "教练正在解释 · 可以取消，不影响本地建议"
	question.release_focus()
	questions.hide()
	client.send(service, key, Protocol.messages(data, current_question, dialogue))

func stop() -> void:
	if client != null:
		if client.busy: status.text = "已取消讲解，本地分析仍可查看。"
		client.cancel()
	request_fingerprint = ""
	if ask_button != null: ask_button.text = "解释这次建议"

func _received(result: Dictionary) -> void:
	if request_fingerprint != fingerprint or not is_visible_in_tree(): return
	ask_button.text = "重新讲解"
	request_fingerprint = ""
	var parsed = result if result.has("error") else Protocol.parse(result.content, data.local_analysis.action)
	if parsed.has("error"):
		status.text = parsed.error
		return
	dialogue.append({"question": current_question, "answer": parsed.answer})
	answer.text = "你的问题：" + current_question + "\n\n推荐理由\n" + parsed.answer.reason + "\n\n换一种打法\n" + parsed.answer.alternative + "\n\n下一步观察\n" + parsed.answer.next
	status.text = "AI 补充解释 · 不作为新的胜率或 GTO 计算结果"
