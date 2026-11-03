extends SceneTree
const Store = preload("res://scripts/poker/training_store.gd")
const History = preload("res://scripts/poker/history.gd")
var checks = 0
var failures = 0

func _initialize() -> void: call_deferred("run")
func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + message)
func settle() -> void:
	for i in range(8): await process_frame
func fits(c: Control, message: String) -> void:
	verify(root.get_visible_rect().grow(1).encloses(c.get_global_rect()), message + str(c.get_global_rect()))

func run() -> void:
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	ui.smoke_mode = true
	await settle()
	verify(ui.home.visible and not ui.screen.lobby.visible and ui.game == null, "launch shows home without a hidden game")
	verify(ui.home.primary.has_focus() and ui.screen.call_button.focus_mode == Control.FOCUS_NONE, "home owns keyboard focus")
	for screen in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(412, 915), Vector2i(1280, 800)]:
		root.size = screen
		await settle()
		fits(ui.home.primary, "home primary fits ")
		for c in ui.home.entries.values(): fits(c, "home destination fits ")
		verify(ui.screen.safe_root.size.x <= 540.1, "desktop keeps the portrait surface")
		ui.home.primary.pressed.emit()
		await settle()
		verify(ui.screen.lobby.visible and ui.home.visible, "new table is a child of home")
		ui._select_count(6)
		ui.screen.depth_picker.select(3)
		ui.screen.depth_picker.item_selected.emit(3)
		verify(ui.screen.lobby_note.text.contains("6 人桌") and ui.screen.lobby_note.text.contains("200 BB"), "table summary reflects count and depth")
		fits(ui.screen.start_button, "table start remains visible ")
		fits(ui.screen.cancel_button, "table back remains visible ")
		ui.modals.back()
		verify(not ui.screen.lobby.visible and ui.home.visible and ui.game == null, "cancel setup returns home without dealing")
		ui.home.entries.settings.pressed.emit()
		await settle()
		verify(ui.settings.index_page.visible and ui.settings.current_page == -1, "settings starts at category index")
		for i in range(ui.settings.CATEGORIES.size()):
			ui.settings.scroll.released_at = -1000
			ui.settings.tabs[i].pressed.emit()
			await settle()
			verify(ui.settings.pages[i].visible and not ui.settings.index_page.visible, "category opens exactly one page")
			verify(ui.settings.pages.filter(func(p): return p.visible).size() == 1, "only one settings detail is visible")
			fits(ui.settings.back_button, "category back fits ")
			fits(ui.settings.apply_button, "settings save fits ")
			fits(ui.settings.cancel_button, "settings cancel fits ")
			ui.modals.back()
			verify(ui.settings.visible and ui.settings.index_page.visible, "back in a category goes up one level")
		ui.modals.back()
		verify(ui.home.visible and not ui.settings.visible and ui.home.primary.has_focus(), "leaving settings restores home focus")
	# Drafts survive category navigation; cancelling the editor discards them.
	ui.home.entries.settings.pressed.emit()
	var original = ui._settings_values()
	ui.settings._select_page(1)
	ui.settings.controls.felt.select(1 - ui.prefs.felt_theme)
	ui.settings.controls.felt.item_selected.emit(1 - ui.prefs.felt_theme)
	ui.modals.back()
	ui.settings._select_page(2)
	verify(ui.settings.values().felt != original.felt and ui._settings_values() == original, "category navigation preserves unapplied draft only")
	ui.settings.cancel_button.pressed.emit()
	verify(ui._settings_values() == original and not ui.settings.visible, "cancel discards entire settings draft")
	# All main destinations return to their origin, including help without a table.
	for route in ["history", "help", "training"]:
		ui.home.entries[route].pressed.emit()
		verify(ui.support_center.visible if route == "help" else ui.training.visible if route == "training" else ui.review.visible, "home opens " + route)
		if route == "training":
			while ui.training.hub.scan_cursor >= 0: await process_frame
			verify(ui.training.hub.home_page.visible and not ui.training.hub.records_page.visible and not ui.training.hub.start_button.disabled, "training opens on its single home page")
		elif route == "history": verify(ui.review.close_button.text == "返回主界面", "review destination labels its origin")
		ui.modals.back()
		verify(ui.home.visible and not ui.training.visible and not ui.review.visible, "destination returns home")
	# Returning home keeps the actual hand and blocks all table actions.
	ui._start_table(6)
	var before = ui.game.record_state()
	ui._open_menu()
	ui.screen.menu_sheet.content.get_child(6).pressed.emit()
	verify(ui.home.visible and ui.home.primary.text.contains("继续") and ui.home.new_table.visible, "table menu returns to resumable home")
	ui._bot_step()
	ui._human_action("fold")
	verify(ui.game.record_state() == before and ui.bot_timer.is_stopped(), "home freezes table without losing progress")
	ui.home.new_table.pressed.emit()
	ui._select_count(6)
	ui.screen.start_button.pressed.emit()
	verify(ui.confirmation.visible and ui.game.record_state() == before, "starting another table still requires confirmation")
	ui.modals.back()
	ui.modals.back()
	ui.home.primary.pressed.emit()
	verify(not ui.home.visible and not ui.screen.lobby.visible and ui.game.record_state() == before, "continue restores exact table after cancelling reset")
	ui.paused = true
	ui._open_home()
	ui.home.primary.pressed.emit()
	verify(ui.paused, "home round trip preserves manual pause")
	# Backup UI uses the same validated file format, independent of settings drafts.
	var data = ui.settings.data_page
	var temp = "user://nav-backup-" + str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(temp)
	data.store = Store.new("")
	data.history_directory = temp
	data.writing = true
	data.file_selected(temp.path_join("backup.json"))
	verify(FileAccess.file_exists(temp.path_join("backup.json")) and data.status.text == "备份已导出。", "data settings export a real backup file")
	data.writing = false
	data.file_selected(temp.path_join("backup.json"))
	verify(data.status.text.contains("已合并"), "data settings import accepted backup")
	var invalid = FileAccess.open(temp.path_join("bad.json"), FileAccess.WRITE)
	invalid.store_string("{}")
	invalid.close()
	data.file_selected(temp.path_join("bad.json"))
	verify(not data.status.text.contains("已合并"), "data settings show invalid backup error")
	for name in DirAccess.get_files_at(temp): DirAccess.remove_absolute(temp.path_join(name))
	DirAccess.remove_absolute(temp)
	ui._open_home()
	ui.modals.back()
	verify(ui.confirmation.visible and ui.home.visible, "back from home protects against accidental exit")
	ui.confirmation.cancel()
	verify(ui.home.visible and ui.game.record_state() == before, "cancel exit keeps current table")
	# Exercise the real timer chain, including a bot that is next to act.
	ui._start_table(6)
	ui.smoke_mode = false
	ui._schedule_bot()
	verify(not ui.bot_timer.is_stopped(), "bot timer starts at live table")
	ui._open_home()
	before = ui.game.record_state()
	await create_timer(0.8).timeout
	verify(ui.game.record_state() == before and ui.bot_timer.is_stopped(), "actual timer cannot advance a table behind home")
	ui.home.primary.pressed.emit()
	await create_timer(0.8).timeout
	verify(ui.game.events.size() > before.events.size(), "continuing from home resumes actual bot actions")
	ui.smoke_mode = true
	ui.bot_timer.stop()
	ui.queue_free()
	await process_frame
	print("NAVIGATION_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
