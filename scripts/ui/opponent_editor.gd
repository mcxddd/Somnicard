extends VBoxContainer
## Seat selector + one editor avoids eight tall forms in a portrait screen.
signal changed
const Names = preload("res://scripts/poker/player_names.gd")
var seat_names: Array = Names.normalize([])
var name_edit: LineEdit
const UI = preload("res://scripts/ui/style.gd")
const Evaluation = preload("res://scripts/poker/opponent_evaluation.gd")
const Profiles = preload("res://scripts/poker/opponent_profiles.gd")
const Segmented = preload("res://scripts/ui/segmented.gd")
const Avatar = preload("res://scripts/ui/seat_avatar.gd")
var profiles: Array = Profiles.normalize([])
var count: int = 2
var default_level: int = 1
var selected: int = 1
var roster: GridContainer
var level
var aggression
var heading: Label
var portrait
var bio: Label
var avatars: Array = []
var description: Label
var local_note: Label
var evidence_toggle: Button

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	add_child(UI.caption("点一位对手，再设置决策能力和风格。减少人数时，暂时离桌的座位配置仍会保留。"))
	roster = GridContainer.new()
	roster.columns = 5
	roster.add_theme_constant_override("h_separation", 10)
	roster.add_theme_constant_override("v_separation", 10)
	add_child(roster)
	for id in range(1, 6):
		var button = UI.button("", func():
			var parent_scroll = get_parent().get_parent().get_parent()
			if not parent_scroll.has_method("can_activate") or parent_scroll.can_activate(): select(id), UI.CARD, 96)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.x = 0
		button.clip_text = true
		# Portrait over name; the text stays for tests and tooltips but is not drawn.
		for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: button.add_theme_color_override(color, Color.TRANSPARENT)
		var column = VBoxContainer.new()
		column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(column)
		var avatar = Avatar.new()
		avatar.custom_minimum_size = Vector2(40, 40)
		avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(avatar)
		var caption = UI.label("", UI.SIZE_CAPTION, UI.TEXT, true)
		caption.clip_text = true
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(caption)
		avatars.append([avatar, caption])
		roster.add_child(button)
	# The selected opponent: portrait, name and one line of character.
	var card = UI.card("inset")
	add_child(card)
	var who = HBoxContainer.new()
	who.add_theme_constant_override("separation", 14)
	card.add_child(who)
	portrait = Avatar.new()
	portrait.custom_minimum_size = Vector2(72, 72)
	who.add_child(portrait)
	var lines = VBoxContainer.new()
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	who.add_child(lines)
	heading = UI.label("", UI.SIZE_HEADING, UI.GOLD)
	lines.add_child(heading)
	bio = UI.caption("")
	lines.add_child(bio)
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
	add_child(UI.secondary("所有座位的难度跟随默认", func():
		for p in profiles: p.difficulty = -1
		_render()
		changed.emit()))
	local_note = UI.label("激进 ≠ 更强：主要改变下注、加注和诈唬倾向；偏被动更常过牌、跟注。实测强弱依次为入门、标准、进阶。没有真人对照数据，不能换算成真人段位。\n\n应用后从下一次电脑决策生效；已发生的行动不变。", 17, UI.MUTED)
	local_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(local_note)
	var evidence = UI.label(Evaluation.TEXT, 17, UI.MUTED)
	evidence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	evidence_toggle = UI.link("查看实测牌力与适用范围 ▾", func(): evidence.visible = not evidence.visible)
	evidence_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(evidence_toggle)
	add_child(evidence)
	evidence.hide()
	_render()

func _option(title: String, choices: Array):
	add_child(UI.label(title, 18, UI.MUTED))
	var picker = Segmented.new()
	for choice in choices: picker.add_item(choice)
	add_child(picker)
	return picker

func fill(raw: Variant, players: int, fallback: int) -> void:
	profiles = Profiles.normalize(raw)
	count = clampi(players, 2, 6)
	default_level = clampi(fallback, 0, 2)
	selected = clampi(selected, 1, count - 1)
	if is_node_ready(): _render()

func select(id: int) -> void:
	selected = clampi(id, 1, count - 1)
	_render()

func _render() -> void:
	for id in range(1, 6):
		var button = roster.get_child(id - 1)
		button.visible = id < count
		var p = Profiles.resolve(profiles, id, default_level)
		button.text = "%s\n%s" % [seat_names[id - 1], Profiles.label(p)]
		var ring = UI.surface(UI.HERO if id == selected else UI.CARD, UI.BUTTON_RADIUS, 6, UI.GOLD if id == selected else Color("2a4048"))
		ring.set_border_width_all(2 if id == selected else 1)
		button.add_theme_stylebox_override("normal", ring)
		avatars[id - 1][0].setup(id, seat_names[id - 1])
		avatars[id - 1][0].active = id == selected
		avatars[id - 1][1].text = seat_names[id - 1]
	heading.text = "座位 %d · %s" % [selected, seat_names[selected - 1]]
	portrait.setup(selected, seat_names[selected - 1])
	bio.text = Names.BIOS[selected - 1] + "\n" + Profiles.label(Profiles.resolve(profiles, selected, default_level))
	name_edit.text = seat_names[selected - 1]
	level.select(profiles[selected - 1].difficulty + 1)
	aggression.select(profiles[selected - 1].aggression)
	description.text = Profiles.DESCRIPTIONS[Profiles.resolve(profiles, selected, default_level).difficulty]
