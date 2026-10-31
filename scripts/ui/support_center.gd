extends ColorRect
signal closed
signal destination(name: String)
const UI = preload("res://scripts/ui/style.gd")
const DOWNLOAD = "https://mygit.nightricecake.com/downloads/somnicard/"
const TOPICS = [
	["开始使用", "先打一手，还是先学一点？", "已经熟悉规则：主页 → 开始新局，选择人数和筹码即可离线游玩。\n\n刚接触德州：从学习路线开始，每课三个局面，先选择再看理由。所有课程均可直接进入。\n\n练习一个主题：训练室先独立作答，再查看分析，也可以从这个决定继续打完。"],
	["牌桌与操作", "操作前看清这三个数", "剩余筹码：你还可以投入多少。\n当前下注：每个座位旁显示本轮已经投入的数量。\n底池：牌桌中间显示本手累积底池。\n\n加注面板显示的是“本轮加注到”的总额。快捷按钮只填金额，确认加注后才执行。顶部切换 BB / 筹码不会改变实际投入。全押默认再次确认。\n\n点座位查看玩家详情；只有实际摊牌才展示未弃牌对手底牌。后台自动暂停，回来后手动继续。"],
	["教练与复盘", "把决定与结果分开", "对局中点击教练头像查看当前决定的建议，或在设置中选择先行动再看讲解。对局与复盘教学可以分别关闭。\n\n结算后点击教练即可复盘这一手。历史支持搜索、桌型和结果等筛选、收藏与备注；回放在原牌桌显示决策分析。\n\n胜率是相对于估计范围的分池份额。不是对手底牌的真相。CFR 只覆盖限定双人河牌抽象，不是完整多人 GTO；相近估值和未覆盖尺寸不要过度评分。"],
	["电脑与评测", "本地对手，实测数据", "电脑对手可逐座位设置名字、决策难度和激进程度，所有决策在本机完成。\n\n设置 → 电脑对手，可查看本版已完成的本地实测。结果不换算真人段位。"],
	["隐私与数据", "所有记录留在本机", "游戏不联网，所有记录只保存在本机。无需账户，没有广告或自动上传的使用统计。\n\n本地备份包含完整牌局及隐藏底牌、学习路线、训练与备注，请妥善保管。设备设置和正在进行的普通牌桌不包含在学习备份中。卸载应用或清除数据会删除本机记录。"],
	["安装与问题排查", "更新前先备份", "从官网下载适配的 APK。更新前可在设置 → 数据与备份导出记录；同包名、同签名的较高版本可以覆盖安装。正式版与早期调试版的迁移方式以下载页说明为准。\n\n安装失败：检查 Android 版本、剩余空间、下载是否完整，以及是否有同包名但不同签名的旧安装。不要先卸载再想起备份。\n\n下载停住：尝试重新打开下载页，用浏览器重新下载；页面提供文件大小与 SHA-256 校验信息。\n\n遇到问题：记录具体操作、是否可重复、机型和截图。下方诊断摘要只含版本、系统和显示信息，可自行附给提供安装包的人；不会自动发送。"],
	["关于 Somnicard", "你的私人扑克练习室", "虚拟筹码，无充值、提现或现金奖品。支持 2–9 人练习桌，本地电脑对手、学习路线、训练和逐手复盘。\n\n本版不是完整锦标赛模拟器，也不包含账号和排行榜。电脑档位与短期赢率不能换算成真人段位。\n\n扑克训练应帮助理解不确定性，不能保证现实收益。按自己的节奏练习，随时暂停。\n\n美术组件与提示音由本项目制作。引擎及第三方组件许可可单独查看。"]
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
	_label("SOMNICARD  " + str(ProjectSettings.get_setting("application/config/version")), 25, UI.GOLD)
	_label("从一个问题开始。", 20, UI.MUTED)
	for i in range(TOPICS.size()): _button(TOPICS[i][0] + "  ›", show_topic.bind(i))
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
	_label(TOPICS[index][1], 27, UI.GOLD)
	_label(TOPICS[index][2])
	if index == 0: _button("去学习路线", func(): destination.emit("academy"))
	if index == 4 or index == 5: _button("打开数据与备份", func(): destination.emit("data"))
	scroll.reset_scroll()
	status.text = ""

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
