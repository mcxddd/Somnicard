extends SceneTree
var checks = 0
var failures = 0
func _initialize() -> void: call_deferred("run")
func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + message)
func settle() -> void:
	for i in range(12): await process_frame
func run() -> void:
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	ui.smoke_mode = true
	root.size = Vector2i(360, 640)
	ui._start_table(6)
	ui._open_settings()
	ui.settings._select_page(4)
	ui.settings.data_page.dialog.use_native_dialog = false
	ui.settings.data_page.dialog.popup_centered_ratio(0.9)
	await settle()
	ui.modals.system_back(1000)
	ui.modals.system_back(1174)
	verify(ui.settings.current_page == 4, "duplicate Android 16 notification does not pop another level")
	ui.modals.system_back(1400)
	verify(ui.settings.current_page == -1, "next normal back press is accepted after duplicate interval")
	ui.queue_free()
	await process_frame
	print("BACK_DEDUPE_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
