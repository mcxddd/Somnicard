extends VBoxContainer
## Seat selector + one editor avoids eight tall forms in a portrait screen.
signal changed
const Names = preload("res://scripts/poker/player_names.gd")
var seat_names: Array = Names.normalize([])
var name_edit: LineEdit
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
	add_child(UI.label("名字 · 牌桌显示", 18, UI.MUTED))
	name_edit = LineEdit.new()
	name_edit.max_length = 12
	name_edit.custom_minimum_size.y = 52
	add_child(name_edit)
	name_edit.text_changed.connect(func(value): seat_names[selected - 1] = value; changed.emit())
	level = _option("决策能力", ["跟随默认难度", "入门", "标准", "进阶"])
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
	local_note = UI.label("激进 ≠ 更强：主要改变下注、加注和诈唬倾向；偏被动更常过牌、跟注。实测强弱依次为入门、标准、进阶。没有真人对照数据，不能换算成真人段位。\n\n应用后从下一次电脑决策生效；已发生的行动不变。", 17, UI.MUTED)
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
	selected = clampi(id, 1, count - 1)
	_render()

func _render() -> void:
	for id in range(1, 9):
		var button = roster.get_child(id - 1)
		button.visible = id < count
		var p = Profiles.resolve(profiles, id, default_level)
		button.text = "%s\n%s" % [seat_names[id - 1], Profiles.label(p)]
		button.add_theme_stylebox_override("normal", UI.surface(Color("3d423a") if id == selected else Color("263540"), 8, 10, UI.GOLD if id == selected else Color.TRANSPARENT))
	heading.text = "座位 %d · %s" % [selected, seat_names[selected - 1]]
	name_edit.text = seat_names[selected - 1]
	level.select(profiles[selected - 1].difficulty + 1)
	aggression.select(profiles[selected - 1].aggression)
	description.text = Profiles.DESCRIPTIONS[Profiles.resolve(profiles, selected, default_level).difficulty]
