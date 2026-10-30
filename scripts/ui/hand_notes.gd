extends "res://scripts/ui/sheet.gd"
const Store = preload("res://scripts/poker/training_store.gd")
signal saved
var store
var hand: String
var starred: CheckButton
var pending: CheckButton
var note: TextEdit
var tags: Dictionary = {}
var status: Label

func _ready() -> void:
	super._ready()
	starred = CheckButton.new()
	starred.text = "收藏这手牌"
	starred.custom_minimum_size.y = 48
	content.add_child(starred)
	pending = CheckButton.new()
	pending.text = "加入待复习"
	pending.custom_minimum_size.y = 48
	content.add_child(pending)
	var grid = GridContainer.new()
	grid.columns = 2
	content.add_child(grid)
	for tag in Store.TAGS:
		var b = UI.button(tag, func(): pass)
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tags[tag] = b
		grid.add_child(b)
	note = TextEdit.new()
	note.custom_minimum_size.y = 140
	note.placeholder_text = "当时为什么犹豫？下次想观察什么？（最多 2000 字）"
	note.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	content.add_child(note)
	status = UI.label("", 16, UI.MUTED)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status)
	content.add_child(UI.button("保存标记与备注", _save, UI.GREEN))

func edit(value, id: String) -> void:
	store = value
	hand = id
	var m = store.mark(id)
	starred.button_pressed = m.star
	pending.button_pressed = m.pending
	note.text = m.note
	for tag in tags: tags[tag].button_pressed = tag in m.tags
	status.text = "ID " + id
	open("收藏与备注")

func _save() -> void:
	if note.text.length() > 2000:
		status.text = "备注最多 2000 字，请缩短后保存。"
		return
	var m = store.mark(hand)
	m.star = starred.button_pressed
	m.pending = pending.button_pressed
	m.note = note.text
	m.tags = tags.keys().filter(func(t): return tags[t].button_pressed)
	if not store.set_mark(hand, m):
		status.text = store.error
		return
	DisplayServer.virtual_keyboard_hide()
	close()
	saved.emit()
