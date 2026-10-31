extends Node
## Runs only in the separate com.somnicard.audit APK, never in the shipped game.
const History = preload("res://scripts/poker/history.gd")
var checks = 0
var failures: Array = []
var shots: Array = []
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("ANDROID_AUDIT_FAIL: " + label)
func settle() -> void:
	for i in range(12): await get_tree().process_frame
func shot(label: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	var path = "user://audit-" + label + ".png"
	verify(get_viewport().get_texture().get_image().save_png(path) == OK, "capture " + label)
	shots.append(path)
func report(stage: String, extra: Dictionary = {}) -> void:
	var data = {"stage": stage, "checks": checks, "failures": failures, "screenshots": shots, "platform": OS.get_name(), "version": OS.get_version(), "renderer": RenderingServer.get_video_adapter_name()}
	data.merge(extra)
	History.save(data, "android-audit.json", "user://")
	print("ANDROID_AUDIT: ", stage, " checks=", checks, " failures=", failures.size())
func marker(name: String) -> void:
	var deadline = Time.get_ticks_msec() + 90000
	while not FileAccess.file_exists("user://" + name) and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	verify(FileAccess.file_exists("user://" + name), "host performed " + name)
func _ready() -> void:
	await get_tree().create_timer(1).timeout
	verify(OS.get_name() == "Android", "running on Android runtime")
	var ui = load("res://scenes/main.tscn").instantiate()
	add_child(ui)
	ui.smoke_mode = true
	ui.bot_timer.stop()
	ui._open_home()
	await shot("home")
	for count in range(2, 10):
		ui._start_table(count)
		ui.bot_timer.stop()
		verify(ui.game.seats.size() == count, "table size %d" % count)
		verify(ui.game.seats.all(func(s): return not s.name.begins_with("电脑")), "named local seats")
		var total = ui.game.chip_total()
		var moves = 0
		while ui.game.phase != "complete" and moves < 150:
			var actor: int = ui.game.actor
			var legal: Dictionary = ui.game.legal_actions(actor)
			verify(ui.game.act(actor, "check" if legal.check else "call") == "", "legal street action")
			verify(ui.game.chip_total() == total, "chip conservation")
			ui._refresh(); ui.bot_timer.stop()
			if count in [2, 6, 9] and ui.game.phase == "flop" and ui.game.actor == 0: await shot("%d-flop" % count)
			moves += 1
		verify(ui.game.phase == "complete" and ui.game.result.showdown, "all streets and showdown")
		verify(not History.replay(ui.game.completed_record()).has("error"), "completed history replay")
		if count in [2, 6, 9]: await shot("%d-showdown" % count)
	ui._review_current_hand()
	await shot("review")
	ui.review.seek(3)
	ui.review.analysis_view._analyze()
	while ui.review.analysis_view.job != null: await get_tree().process_frame
	verify(ui.review.frames.size() > 0, "review analysis completes")
	ui.review.hide()
	ui._open_training()
	while ui.training.scan_cursor >= 0: await get_tree().process_frame
	ui.training.start_set()
	verify(ui.training.game != null, "training opens a playable decision")
	await shot("training")
	ui.training.hide()
	ui._open_settings()
	for page in range(ui.settings.CATEGORIES.size()):
		ui.settings._select_page(page)
		await settle()
		verify(get_viewport().get_visible_rect().grow(1).encloses(ui.settings.apply_button.get_global_rect()), "settings save button reachable")
	ui.settings._select_page(3)
	verify(ui.settings.opponent_editor.name_edit.is_visible_in_tree(), "local rename field visible")
	await shot("settings-opponents")
	ui.settings._select_page(4)
	ui.settings.data_page.dialog.use_native_dialog = false
	ui.settings.data_page.dialog.popup_centered_ratio(0.9)
	report("awaiting_export_back")
	await marker("export-back")
	report("awaiting_category_back")
	await marker("category-back")
	verify(ui.settings.visible and ui.settings.current_page == -1, "second distinct native back returns to categories once")
	ui.settings.cancel()
	report("complete")
