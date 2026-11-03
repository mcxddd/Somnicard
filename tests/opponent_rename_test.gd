extends SceneTree
const Table = preload("res://scripts/poker/table.gd")
const History = preload("res://scripts/poker/history.gd")
var checks = 0
var failures = 0
func _initialize() -> void: call_deferred("run")
func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + message)
func run() -> void:
	var game = Table.new([1000, 1000, 1000, 1000, 1000, 1000], 5, 10, 112)
	game.start_hand(0)
	var names = []
	for seat in game.seats:
		verify(not seat.name.begins_with("电脑") and not seat.name.is_empty() and seat.name not in names, "offline seats start with distinct names")
		names.append(seat.name)
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	ui.smoke_mode = true
	verify(not quit_on_go_back, "Android back does not automatically terminate the SceneTree")
	ui._start_table(6)
	ui._open_settings()
	ui.settings._select_page(3)
	ui._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	verify(ui.settings.visible and ui.settings.current_page == -1, "Android back returns from setting detail to categories")
	ui.settings._select_page(3)
	var editor = ui.settings.opponent_editor
	editor.select(1)
	verify(editor.name_edit.is_visible_in_tree(), "local opponents expose rename without online fields")
	for i in range(8): await process_frame
	ui.settings._layout(280)
	for i in range(8): await process_frame
	ui.settings._reveal_editor(editor.name_edit)
	for i in range(8): await process_frame
	verify(ui.settings.panel.get_rect().end.y <= ui.settings.size.y - 280, "settings panel avoids keyboard including footer: %s / %s" % [ui.settings.panel.get_rect(), ui.settings.size])
	verify(ui.settings.scroll.get_global_rect().grow(1).encloses(editor.name_edit.get_global_rect()), "focused editor scrolls above keyboard")
	ui.settings._layout(0)
	editor.name_edit.text = "阿北"
	editor.name_edit.text_changed.emit("阿北")
	ui.settings.cancel()
	verify(ui.game.seats[1].name != "阿北", "cancelled local rename stays a draft")
	ui._open_settings()
	ui.settings._select_page(3)
	editor.select(1)
	editor.name_edit.text = "阿北"
	editor.name_edit.text_changed.emit("阿北")
	ui._apply_settings(ui.settings.values())
	verify(ui.game.seats[1].name == "阿北", "saving rename updates local table without enabling network")
	ui.settings.cancel()
	while ui.game.phase != "complete": ui.game.act(ui.game.actor, "check" if ui.game.legal_actions(ui.game.actor).check else "call")
	var replay = History.replay(ui.game.completed_record())
	verify(not replay.has("error") and replay.game.seats[1].name == "阿北", "replay preserves renamed local identity")
	ui._next_hand()
	var Preferences = preload("res://scripts/ui/preferences.gd")
	var path = "user://names-migration-112.cfg"
	var legacy = ConfigFile.new()
	legacy.set_value("ai", "seats", [{"name": "  阿北\n  "}])
	legacy.save(path)
	var migrated = Preferences.load_values(path)
	verify(migrated.seat_names == ["阿北", "阿岚", "米洛", "青禾", "诺亚", "橙子", "阿澈", "星野"], "legacy seat names migrate with original defaults")
	DirAccess.remove_absolute(path)
	ui.queue_free()
	await process_frame
	print("OPPONENT_RENAME_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
