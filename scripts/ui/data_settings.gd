extends VBoxContainer
## Backup operations are immediate file actions, independent of settings drafts.
const UI = preload("res://scripts/ui/style.gd")
const Backup = preload("res://scripts/poker/training_backup.gd")
const History = preload("res://scripts/poker/history.gd")
var store
var history_directory = History.DIRECTORY
var dialog: FileDialog
var writing = false
var status: Label
var export_button: Button
var import_button: Button

func _ready() -> void:
	add_theme_constant_override("separation", 14)
	var note = UI.label("把牌局和学习记录带走", 24, UI.GOLD)
	add_child(note)
	var description = UI.label("备份包含完整牌局（含隐藏底牌）、收藏、备注、课程进度、训练记录和重打分支。\n\n导入会合并，已有同名牌局优先保留。设备设置、AI 服务与密钥、陪练配置和当前普通牌桌进度不包含在这个备份中。", 19, UI.MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(description)
	export_button = UI.button("导出备份文件", open_file.bind(true), UI.GREEN, 58)
	import_button = UI.button("导入备份文件", open_file.bind(false), Color("243a40"), 58)
	add_child(export_button)
	add_child(import_button)
	status = UI.label("文件操作立即执行，无需点“保存设置”。请妥善保管备份。", 17, UI.MUTED)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	dialog = FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.filters = PackedStringArray(["*.json ; Somnicard 备份"])
	dialog.file_selected.connect(file_selected)
	add_child(dialog)

func open_file(write: bool) -> void:
	if store == null: return
	writing = write
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if write else FileDialog.FILE_MODE_OPEN_FILE
	dialog.current_file = "somnicard-backup-" + Time.get_date_string_from_system() + ".json" if write else ""
	dialog.popup_centered_ratio(0.9)

func file_selected(path: String) -> void:
	if writing:
		var error = Backup.export_file(path, store, history_directory)
		status.text = "备份已导出。" if error.is_empty() else error
	else:
		var result = Backup.import_file(path, store, history_directory)
		status.text = result.error if result.has("error") else "已合并 %d 手牌局；已有同名记录保留。" % result.added
