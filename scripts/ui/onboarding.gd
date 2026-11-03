extends ColorRect
## A three-page introduction shown once on a fresh install. Back or Skip dismisses it.
signal finished
const UI = preload("res://scripts/ui/style.gd")
const MARKER = "user://onboarded"
var page = 0
var pages: Array = []
var dots: Label
var next_button: Button
var skip_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = UI.BACKGROUND
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]: margin.add_theme_constant_override("margin_" + edge, 24)
	for edge in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 28)
	add_child(margin)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)
	var stage = VBoxContainer.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(stage)
	pages = [_welcome(), _paths(), _coach()]
	for p in pages: stage.add_child(p)
	dots = UI.label("", 20, UI.GOLD, true)
	column.add_child(dots)
	next_button = UI.primary("下一步", advance)
	column.add_child(next_button)
	skip_button = UI.secondary("跳过", finish)
	column.add_child(skip_button)
	hide()

func _page(art: String, heading: String, text: String) -> VBoxContainer:
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	if not art.is_empty(): box.add_child(UI.art(load(art), 200))
	var title = UI.title(heading)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var body = UI.body(text)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_color_override("font_color", UI.TEXT.darkened(0.1))
	box.add_child(body)
	return box

func _welcome() -> VBoxContainer:
	return _page("res://assets/art/home-hero.png", "你的私人扑克练习室", "和电脑对手打德州扑克，随时暂停。\n完全离线，使用虚拟筹码，记录只存在你的手机里。")

func _paths() -> VBoxContainer:
	var box = _page("", "从哪里开始？", "按你现在的情况选一个，之后随时可以换。")
	for spec in [["learn", "刚接触德州", "学习路线：12 课，每课 5 个局面，先选再看理由"], ["settings-table", "已经会玩", "开始新局：2–6 人，对手强度可以调"], ["train", "想打得更好", "训练室：每组 5 题，先作答，再看评级和理由"]]:
		var card = UI.card("inset")
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		card.add_child(row)
		var picture = UI.icon(spec[0], 40)
		if picture != null:
			picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(picture)
		var lines = VBoxContainer.new()
		lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lines.add_child(UI.label(spec[1], UI.SIZE_BODY + 1, UI.TEXT))
		lines.add_child(UI.caption(spec[2]))
		row.add_child(lines)
		box.add_child(card)
	return box

func _coach() -> VBoxContainer:
	return _page("res://assets/art/coach.png", "牌桌上的教练", "轮到你时，点右下角的教练，看建议和理由。\n先自己想一想再看，更容易发现差别。\n打完一手，还可以点“复盘本手”回看关键决定。")

## True on a fresh install only. Existing players (any saved hand or preferences) are marked as done.
static func needed(history_directory: String) -> bool:
	if FileAccess.file_exists(MARKER): return false
	var has_history = DirAccess.dir_exists_absolute(history_directory) and not DirAccess.get_files_at(history_directory).is_empty()
	if FileAccess.file_exists("user://preferences.cfg") or has_history:
		mark_done()
		return false
	return true

static func mark_done() -> void:
	var file = FileAccess.open(MARKER, FileAccess.WRITE)
	if file != null: file.store_string("1")

func open() -> void:
	page = 0
	_render()
	show()
	next_button.grab_focus()

func advance() -> void:
	if page >= pages.size() - 1:
		finish()
		return
	page += 1
	_render()

func finish() -> void:
	mark_done()
	hide()
	finished.emit()

func back_action() -> void:
	finish()

func _render() -> void:
	for i in range(pages.size()): pages[i].visible = i == page
	var marks: Array = []
	for i in range(pages.size()): marks.append("●" if i == page else "○")
	dots.text = "  ".join(marks)
	next_button.text = "开始使用" if page == pages.size() - 1 else "下一步"
	skip_button.visible = page < pages.size() - 1
