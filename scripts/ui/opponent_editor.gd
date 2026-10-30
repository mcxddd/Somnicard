extends VBoxContainer
## Seat selector + one editor avoids eight tall forms in a portrait screen.
signal changed
signal name_requested(seat: int)
signal selection_changed
var service_picker: OptionButton
var service_profiles: Array = []
var generate_name: Button
var name_status: Label
var name_choices: VBoxContainer
const AIConfig = preload("res://scripts/ai/config.gd")
var ai_seats: Array = AIConfig.seats([])
var companions: Dictionary = {}
var controller: OptionButton
var companion_picker: OptionButton
var companion_ids: Array = []
var ai_fields: VBoxContainer
var name_edit: LineEdit
var persona_edit: LineEdit
var save_companion: Button
var memory_label: Label
const UI = preload("res://scripts/ui/style.gd")
const Evaluation = preload("res://scripts/poker/opponent_evaluation.gd")
const Profiles = preload("res://scripts/poker/opponent_profiles.gd")
var profiles: Array = Profiles.normalize([])
var count: int = 2
var default_level: int = 1
var selected: int = 1
var roster: GridContainer
var level: OptionButton
var aggression: OptionButton
var heading: Label
var description: Label
var local_note: Label
var evidence_toggle: Button

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var intro = UI.label("选择座位，再分别设置决策能力与风格。减少人数时，暂时离桌的座位配置仍会保留。", 18, UI.MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(intro)
	roster = GridContainer.new()
	roster.columns = 2
	roster.add_theme_constant_override("h_separation", 10)
	roster.add_theme_constant_override("v_separation", 10)
	add_child(roster)
	for id in range(1, 9):
		var button = UI.button("", func():
			var parent_scroll = get_parent().get_parent().get_parent()
			if not parent_scroll.has_method("can_activate") or parent_scroll.can_activate(): select(id), Color("263540"), 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 16)
		roster.add_child(button)
	heading = UI.label("", 24, UI.GOLD)
	add_child(heading)
	controller = _option("对手来源", ["本地电脑 · 无需联网", "在线 AI · 使用配置的模型"])
	controller.item_selected.connect(func(index): ai_seats[selected - 1].enabled = index == 1; _render(); changed.emit())
	add_child(UI.label("名字 · 牌桌显示", 18, UI.MUTED))
	name_edit = LineEdit.new()
	name_edit.max_length = 12
	name_edit.custom_minimum_size.y = 52
	add_child(name_edit)
	name_edit.text_changed.connect(func(value): ai_seats[selected - 1].name = value; changed.emit())
	ai_fields = VBoxContainer.new()
	ai_fields.add_theme_constant_override("separation", 10)
	add_child(ai_fields)
	ai_fields.add_child(UI.label("使用的模型档案", 18, UI.MUTED))
	service_picker = OptionButton.new()
	service_picker.fit_to_longest_item = false
	service_picker.custom_minimum_size.y = 52
	ai_fields.add_child(service_picker)
	service_picker.item_selected.connect(func(index):
		if index >= service_profiles.size(): return
		ai_seats[selected - 1].service_id = service_profiles[index].id
		selection_changed.emit()
		changed.emit())
	companion_picker = OptionButton.new()
	companion_picker.custom_minimum_size.y = 52
	ai_fields.add_child(UI.label("身份与记忆", 18, UI.MUTED))
	ai_fields.add_child(companion_picker)
	companion_picker.item_selected.connect(_choose_companion)
	generate_name = UI.button("AI 生成昵称 · 一次请求", func(): name_requested.emit(selected), UI.GREEN)
	ai_fields.add_child(generate_name)
	name_status = UI.label("可直接改名，或让当前模型生成带有自身特色的名字。", 17, UI.MUTED)
	name_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ai_fields.add_child(name_status)
	name_choices = VBoxContainer.new()
	ai_fields.add_child(name_choices)
	persona_edit = LineEdit.new()
	persona_edit.max_length = 120
	persona_edit.custom_minimum_size.y = 52
	ai_fields.add_child(UI.label("性格与说话风格", 18, UI.MUTED))
	ai_fields.add_child(persona_edit)
	persona_edit.text_changed.connect(func(value): ai_seats[selected - 1].persona = value; changed.emit())
	memory_label = UI.label("", 17, UI.MUTED)
	memory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ai_fields.add_child(memory_label)
	save_companion = UI.button("保存为长期陪练（随设置保存）", func():
		ai_seats[selected - 1].companion_id = "new:%d" % selected
		_render()
		changed.emit(), UI.GREEN)
	ai_fields.add_child(save_companion)
	level = _option("决策能力", ["跟随默认难度", "入门", "标准", "进阶（实验）"])
	aggression = _option("行动风格", Profiles.STYLES)
	level.item_selected.connect(func(index): profiles[selected - 1].difficulty = index - 1; _render(); changed.emit())
	aggression.item_selected.connect(func(index): profiles[selected - 1].aggression = index; _render(); changed.emit())
	description = UI.label("", 18, UI.TEXT)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(description)
	add_child(UI.button("所有座位的难度跟随默认", func():
		for p in profiles: p.difficulty = -1
		_render()
		changed.emit()))
	local_note = UI.label("激进 ≠ 更强：主要改变下注、加注和诈唬倾向；偏被动更常过牌、跟注。实测支持入门较弱；标准与进阶尚未稳定分出高下。进阶为实验档。没有真人对照数据，不能换算成真人段位。\n\n应用后从下一次电脑决策生效；已发生的行动不变。", 17, UI.MUTED)
	local_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(local_note)
	var evidence = UI.label(Evaluation.TEXT, 17, UI.MUTED)
	evidence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	evidence_toggle = UI.button("查看实测牌力与适用范围 ▾", func(): evidence.visible = not evidence.visible)
	add_child(evidence_toggle)
	add_child(evidence)
	evidence.hide()
	_render()

func _option(title: String, choices: Array) -> OptionButton:
	add_child(UI.label(title, 18, UI.MUTED))
	var picker = OptionButton.new()
	picker.custom_minimum_size.y = 52
	for choice in choices: picker.add_item(choice)
	add_child(picker)
	return picker

func fill(raw: Variant, players: int, fallback: int) -> void:
	profiles = Profiles.normalize(raw)
	count = clampi(players, 2, 9)
	default_level = clampi(fallback, 0, 2)
	selected = clampi(selected, 1, count - 1)
	if is_node_ready(): _render()

func select(id: int) -> void:
	selection_changed.emit()
	clear_names()
	selected = clampi(id, 1, count - 1)
	_render()

func _render() -> void:
	for id in range(1, 9):
		var button = roster.get_child(id - 1)
		button.visible = id < count
		var p = Profiles.resolve(profiles, id, default_level)
		button.text = "%s\n%s" % [ai_seats[id - 1].name, "在线 AI · " + Profiles.LEVELS[p.difficulty] if ai_seats[id - 1].enabled else Profiles.label(p)]
		button.add_theme_stylebox_override("normal", UI.surface(Color("3d423a") if id == selected else Color("263540"), 8, 10, UI.GOLD if id == selected else Color.TRANSPARENT))
	heading.text = "座位 %d · %s" % [selected, ai_seats[selected - 1].name]
	var ai = ai_seats[selected - 1]
	controller.select(1 if ai.enabled else 0)
	ai_fields.visible = ai.enabled
	_render_services()
	name_edit.text = ai.name
	persona_edit.text = ai.persona
	companion_picker.clear()
	companion_picker.add_item("临时对手 · 本次开桌记忆")
	companion_ids = [""]
	for id in companions:
		companion_picker.add_item(companions[id].name + " · 长期陪练")
		companion_ids.append(id)
	companion_picker.select(maxi(0, companion_ids.find(ai.companion_id)))
	save_companion.visible = ai.companion_id == ""
	memory_label.text = "保存设置后创建陪练档案。" if ai.companion_id.begins_with("new:") else ("重开桌清空记忆，连续下一手保留。" if ai.companion_id == "" else "长期陪练：完成的牌局会自动更新记忆；档案在 AI 服务与陪练中管理。")
	level.select(profiles[selected - 1].difficulty + 1)
	aggression.select(profiles[selected - 1].aggression)
	local_note.visible = not ai.enabled
	evidence_toggle.visible = not ai.enabled
	if ai.enabled: get_child(get_child_count() - 1).hide()
	description.text = "在线 AI：入门偏宽松与跟注，标准考虑位置和赔率，进阶尝试范围与多街规划。档位是模型的打法目标，尚未实测排序；激进程度单独控制。" if ai.enabled else Profiles.DESCRIPTIONS[Profiles.resolve(profiles, selected, default_level).difficulty]

func fill_ai(raw: Variant, library: Dictionary) -> void:
	ai_seats = AIConfig.seats(raw)
	companions = library.duplicate(true)
	if is_node_ready(): _render()

func _choose_companion(index: int) -> void:
	var id = companion_ids[index]
	if id == "":
		ai_seats[selected - 1].companion_id = ""
	else:
		var p = companions[id]
		ai_seats[selected - 1] = AIConfig.seats([p])[0]
		profiles[selected - 1] = {"difficulty": p.difficulty, "aggression": p.aggression}
	_render()
	changed.emit()

func clear_names() -> void:
	for child in name_choices.get_children():
		name_choices.remove_child(child)
		child.queue_free()

func offer_names(names: Array, seat: int) -> void:
	clear_names()
	for candidate in names:
		var button = UI.button(candidate + " · 使用", func():
			if selected != seat: return
			ai_seats[seat - 1].name = candidate
			_render()
			clear_names()
			name_status.text = "已选昵称，保存设置后生效；仍可手动修改。"
			changed.emit())
		name_choices.add_child(button)

func set_services(profiles_list: Array) -> void:
	service_profiles = profiles_list.duplicate(true)
	if service_picker != null: _render_services()

func _render_services() -> void:
	service_picker.clear()
	var chosen = -1
	for p in service_profiles:
		service_picker.add_item(p.label + " · " + p.service.model)
		if p.id == ai_seats[selected - 1].service_id: chosen = service_picker.item_count - 1
	if chosen < 0:
		service_picker.add_item("档案未配置，请到 AI 服务添加")
		chosen = service_picker.item_count - 1
	service_picker.select(chosen)
