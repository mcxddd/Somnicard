extends ColorRect
signal closed
signal destination(name: String)
const UI = preload("res://scripts/ui/style.gd")
const DOWNLOAD = "https://somnicard.nightricecake.com/"
## Help sections in a fixed order (the table's help button opens section 1).
## Each section: title, one-line summary, then [question, answer] pairs shown as expandable cards.
const TOPIC_ICONS = ["help-start", "help-table", "help-coach", "help-opponents", "help-privacy", "help-install", "help-about"]
const TOPICS = [
	["开始使用", "先玩、先学，还是先练", [
		["我该从哪里开始？", "已经熟悉规则：主界面点“开始新局”，选人数和筹码就能玩。\n刚接触德州：从学习路线第 1 课开始，每课 5 个局面，先选再看理由。\n想专门练决定：训练室点“开始练习”，每组 5 题。"],
		["需要联网或注册吗？", "不需要。游戏完全离线，没有账号、广告和数据上传。用的是虚拟筹码，没有充值、提现或现金奖品。"]]],
	["牌桌与操作", "下注、单位和暂停", [
		["“加到”是什么意思？", "“加到”是你这一轮的总投入，不是在已有下注上再加多少。比如本轮已投入 10，选“加到 30”，实际再扣 20。"],
		["快捷按钮会直接下注吗？", "不会。最小、2.5 BB、半池这些按钮只填金额，要再点“加注到 …”才真正下注。"],
		["BB 和筹码有什么区别？", "本桌盲注 5 / 10，1 BB = 10 筹码。右上角切换只改变显示方式，不改变实际投入。"],
		["为什么全押要再确认？", "防止误触。不需要的话，可以在“设置 → 牌桌与操作”里关闭。"],
		["切到后台会怎样？", "牌局自动暂停，回来后点“继续”才接着打，不会错过行动。"],
		["能看到对手的牌吗？", "只有摊牌时才公开没弃牌玩家的底牌。点座位可以看对方的筹码和本轮投入。"],
		["牌局会自动保存吗？", "会。每次操作后自动保存，重启后在主界面点“恢复上次牌桌”继续。开新桌会替换当前牌桌，已完成的牌局记录都会保留。"],
		["电脑上有快捷键吗？", "F 弃牌，空格 过牌或跟注，R 输入金额，P 暂停，Esc 返回上一层。"]]],
	["教练与复盘", "建议从哪来、怎么看", [
		["教练的建议是怎么算的？", "只用你能看到的信息：你的底牌、公共牌、公开行动和筹码。教练先根据对手的行动估计他们可能的牌（范围），再算你的分池份额和跟注价格。只剩两人的河牌，会额外做一次简化的 GTO 求解（CFR）。"],
		["建议一定是对的吗？", "不一定。翻牌到转牌是估算；河牌求解只考虑几种下注尺寸，也不是完整的多人 GTO。两个选择很接近时，选哪个都不算错。把建议当成参考，重点是想清楚自己的理由。"],
		["输了是不是就打错了？", "不是。单手输赢很受发牌影响。评价一个决定，要看当时的价格和对手可能的牌，而不是最后的结果。"],
		["怎么复盘一手牌？", "一手结束后点“复盘本手”，或从主界面进“牌局复盘”。可以逐步回放、拖动时间轴，或直接跳到你的决策点看分析。"]]],
	["电脑与训练", "对手有多强、训练怎么出题", [
		["电脑对手有多强？", "分入门、标准、进阶三档，同牌对比测试里依次更强。档位只表示决策逻辑，不对应真人段位。每个座位都可以在“设置 → 电脑对手”里单独调整难度和风格。"],
		["训练室怎么出题？", "每组 5 题自动挑选：先复习之前偏离建议的局面，再从你掌握度最低的主题出新局面，优先用你自己打过的牌局。点某个主题，就只练那个主题。"],
		["评级是什么意思？", "好的选择：和建议一致，或属于混合打法里的一种。\n可以接受：选择很接近，或方向对但金额不同。\n偏离建议：和建议不同，这道题之后会再出现，连续两次（隔天）不再偏离才算掌握。"],
		["“用这个选择打完这手”是什么？", "用你选的操作继续和电脑把这手打完。没公开的牌会重新发，所以结果只是一次样本，不说明哪种打法长期更好，也不计入对局统计。"]]],
	["隐私与数据", "记录只在本机", [
		["我的记录存在哪？", "只存在这台手机上。卸载应用或清除应用数据会删除全部记录。"],
		["怎么备份和迁移？", "在“设置 → 数据与备份”导出备份文件，换手机或重装后在同一位置导入。备份包含完整牌局（包括对手底牌）、学习和训练记录，请妥善保管。设备设置和正在进行的牌桌不在备份里。"]]],
	["安装与问题排查", "更新、安装失败和反馈", [
		["怎么更新？", "从官网或 GitHub 下载新版，直接覆盖安装，记录会保留。"],
		["安装失败怎么办？", "检查系统版本、剩余空间和下载是否完整，以及手机上有没有同包名但签名不同的旧版本。如果需要卸载旧版，一定先导出备份。"],
		["下载停住了？", "重新打开下载页再下一次。页面提供文件大小和 SHA-256，可以核对文件是否完整。"],
		["怎么反馈问题？", "点下方“复制诊断摘要”（只含版本、系统和屏幕信息，不会自动发送），再附上操作步骤、能否重复出现和截图。"]]],
	["关于 Somnicard", "你的私人扑克练习室", [
		["这是一款什么游戏？", "竖屏德州扑克练习游戏，支持 2–9 人，有本地电脑对手、牌桌教练、逐手复盘、训练室和学习路线。"],
		["不包含什么？", "没有锦标赛规则（死庄、盲注升级）、账号、排行榜和真人对战。练习帮助理解决策，不保证现实中的收益。"],
		["美术和许可", "代码和素材按 MIT 许可发布；部分插画和图标由 AI 生成。Godot 引擎和第三方组件的许可可在下方查看。"]]]
]
var body: VBoxContainer
var scroll
var title: Label
var back_button: Button
var topic = -1
var status: Label

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
	title = UI.label("帮助与关于", 27, UI.GOLD)
	header.add_child(title)
	scroll = preload("res://scripts/ui/touch_scroll.gd").new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	scroll.add_child(body)
	status = UI.label("", 16, UI.MUTED)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	hide()

func open() -> void:
	show()
	_overview()
	back_button.grab_focus()

func _label(value: String, font: int = 20, tint: Color = UI.TEXT) -> void:
	var label = UI.label(value, font, tint)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(label)

func _button(text: String, callback: Callable) -> void:
	var button = UI.button(text, func():
		if scroll.can_activate(): callback.call(), Color("1b3039"), 60)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(button)

func _overview() -> void:
	topic = -1
	UI.clear(body)
	title.text = "帮助与关于"
	body.add_child(UI.heading("SOMNICARD  " + str(ProjectSettings.get_setting("application/config/version"))))
	body.add_child(UI.caption("选一个主题，点问题展开答案。"))
	for i in range(TOPICS.size()):
		var index = i
		# Each topic has its own icon once the artwork exists; until then the shared one.
		var icon_name = TOPIC_ICONS[i] if ResourceLoader.exists("res://assets/icons/%s.png" % TOPIC_ICONS[i]) else "help"
		body.add_child(UI.entry(TOPICS[i][0], TOPICS[i][1], func():
			if scroll.can_activate(): show_topic(index), icon_name))
	_button("引擎与第三方许可", _licenses)
	_button("官网 · 下载与版本说明 ↗", func(): OS.shell_open(DOWNLOAD))
	_button("复制诊断摘要", func():
		DisplayServer.clipboard_set(diagnostics())
		status.text = "已复制版本与系统摘要；请另附复现步骤。")
	status.text = "游戏不联网；官网链接由外部浏览器打开。"
	scroll.reset_scroll()

func show_topic(index: int) -> void:
	if index < 0 or index >= TOPICS.size(): return
	topic = index
	UI.clear(body)
	title.text = TOPICS[index][0]
	body.add_child(UI.caption(TOPICS[index][1]))
	var pairs: Array = TOPICS[index][2]
	for i in range(pairs.size()): body.add_child(_question(pairs[i][0], pairs[i][1], i == 0))
	if index == 0: _button("去学习路线", func(): destination.emit("academy"))
	if index == 4 or index == 5: _button("打开数据与备份", func(): destination.emit("data"))
	scroll.reset_scroll()
	status.text = ""

## A question card; tapping the question shows or hides its answer.
func _question(question: String, answer: String, expanded: bool) -> PanelContainer:
	var card = UI.card()
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)
	var header = UI.button("", func(): pass, UI.CARD, 52)
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for state in ["normal", "hover", "pressed"]: header.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	header.add_theme_font_size_override("font_size", UI.SIZE_BODY + 1)
	column.add_child(header)
	var reply = UI.body(answer)
	reply.add_theme_color_override("font_color", UI.TEXT.darkened(0.08))
	column.add_child(reply)
	var render = func():
		header.text = ("－  " if reply.visible else "＋  ") + question
	reply.visible = expanded
	render.call()
	header.pressed.connect(func():
		if not scroll.can_activate(): return
		reply.visible = not reply.visible
		render.call())
	return card

func _licenses() -> void:
	topic = TOPICS.size()
	UI.clear(body)
	title.text = "开源许可"
	_label(Engine.get_license_text(), 17)
	for component in Engine.get_copyright_info():
		_label(str(component.get("name", "")), 20, UI.GOLD)
		for part in component.get("parts", []):
			_label("\n".join(part.get("copyright", [])) + "\n" + str(part.get("license", "")), 15, UI.MUTED)
	for name in Engine.get_license_info(): _label(name + "\n" + str(Engine.get_license_info()[name]), 15, UI.MUTED)
	scroll.reset_scroll()

static func diagnostics() -> String:
	return "Somnicard %s\nOS: %s %s\nEngine: %s\nRenderer: %s\nDisplay: %s\n\n复现步骤：\n预期结果：\n实际结果：" % [ProjectSettings.get_setting("application/config/version"), OS.get_name(), OS.get_version(), Engine.get_version_info().string, ProjectSettings.get_setting("rendering/renderer/rendering_method"), DisplayServer.window_get_size()]

func back_action() -> void:
	if topic >= 0: _overview()
	else:
		hide()
		closed.emit()
