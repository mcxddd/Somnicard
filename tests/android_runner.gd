extends Node
## Runs only in the separate com.somnicard.audit APK, never in the shipped game.
const Vault = preload("res://scripts/ai/vault.gd")
const Services = preload("res://scripts/ai/services.gd")
const History = preload("res://scripts/poker/history.gd")
var checks = 0
var failures: Array = []
var shots: Array = []
var profiles: Array = Services.normalize([{ "id": "default", "remember": true, "service": {"endpoint": "https://emulator.invalid/v1", "model": "audit"}}])
var secret = "ANDROID_EMULATOR_DUMMY_ONLY"
var watch_ui
var watching_back = false
func _notification(what: int) -> void:
	if watching_back and what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_GO_BACK_REQUEST]:
		print("BACK_OBSERVED notification=", what, " selector=", watch_ui.settings.ai_page.model_sheet.visible, " page=", watch_ui.settings.current_page)
func _input(event: InputEvent) -> void:
	if watching_back and event is InputEventKey:
		print("BACK_OBSERVED key=", event.keycode, " pressed=", event.pressed, " selector=", watch_ui.settings.ai_page.model_sheet.visible, " page=", watch_ui.settings.current_page)
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
func wait_client(client) -> void:
	var deadline = Time.get_ticks_msec() + 15000
	while client.busy and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	verify(not client.busy, "HTTP completes within test deadline")
	if client.busy: client.cancel()
func marker(name: String) -> void:
	var deadline = Time.get_ticks_msec() + 90000
	while not FileAccess.file_exists("user://" + name) and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	verify(FileAccess.file_exists("user://" + name), "host performed " + name)
func swipe_points(scroll: Control, upwards: bool) -> Array:
	var rect = scroll.get_global_rect()
	var scale = Vector2(DisplayServer.window_get_size()) / get_viewport().get_visible_rect().size
	var x = roundi(rect.get_center().x * scale.x)
	var from_y = rect.position.y + rect.size.y * (0.8 if upwards else 0.2)
	var to_y = rect.position.y + rect.size.y * (0.2 if upwards else 0.8)
	return [x, roundi(from_y * scale.y), x, roundi(to_y * scale.y)]
func _ready() -> void:
	await get_tree().create_timer(1).timeout
	if FileAccess.file_exists("user://vault-relaunch.json"):
		var old = History.read_record("user://android-audit.json").get("record", {})
		checks = old.get("checks", 0); failures = old.get("failures", []); shots = old.get("screenshots", [])
		if old.get("stage") == "awaiting_relaunch":
			verify(Vault.load_keys(profiles).get("default") == secret, "Keystore survives force-stop and relaunch")
			report("awaiting_tamper")
			return
		verify(Vault.load_keys(profiles).is_empty(), "GCM tampering is rejected after external ciphertext mutation")
		profiles[0].remember = false
		verify(Vault.save(profiles, {}) == "" and Vault.load_keys(profiles).is_empty(), "disabling remember deletes saved key")
		report("complete")
		return
	verify(OS.get_name() == "Android", "running on Android runtime")
	verify(Engine.has_singleton("SomnicardVault"), "native Keystore plugin is loaded")
	verify(Vault.save(profiles, {"default": secret}) == "", "native encrypt and save succeeds")
	verify(Vault.load_keys(profiles).get("default") == secret, "native decrypt returns original dummy key")
	var changed = profiles.duplicate(true)
	changed[0].service.endpoint = "https://other.invalid/v1"
	verify(Vault.load_keys(changed).is_empty(), "endpoint binding rejects wrong origin")
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
	ui.review._analyze()
	while ui.review.job != null: await get_tree().process_frame
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
	ui.settings._select_page(4)
	verify(ui.settings.opponent_editor.name_edit.is_visible_in_tree(), "local rename field visible")
	await shot("settings-opponents")
	ui.settings.cancel()
	# The host mock is exposed only through adb reverse; credentials are dummy strings.
	ui.ai_service = ui.AIConfig.service({"endpoint": "http://127.0.0.1:18948/v1", "model": "model-a", "speech": true})
	ui.ai_profiles = Services.normalize([{ "id": "default", "service": ui.ai_service }, {"id": "second", "service": {"endpoint": "http://127.0.0.1:18948/v1", "model": "model-b"}}])
	ui.ai_keys = {"default": "DUMMY_A", "second": "DUMMY_B"}
	for i in range(5):
		ui.ai_seats[i].enabled = true
		ui.ai_seats[i].service_id = "second" if i % 2 else "default"
	ui._start_table(6)
	ui.bot_timer.stop()
	var moves = 0
	while ui.game.phase != "complete" and moves < 100:
		if ui.game.actor == 0: ui._human_action("check_call", 0, true)
		else:
			ui._bot_step()
			await wait_client(ui.ai_client)
			if ui.speech_client.busy: await wait_client(ui.speech_client)
		ui.bot_timer.stop()
		if not ui.ai_error.is_empty(): verify(false, "mock online decision: " + ui.ai_error); break
		moves += 1
	verify(ui.game.phase == "complete" and ui.game.chip_total() == 6000, "six-seat multi-model game completes on Android")
	verify(not ui.ai_dialogue.is_empty(), "public table talk arrives through Android network")
	await shot("online-showdown")
	verify(not ui.ai_trace.for_seat(1).is_empty(), "Android network records requests by seat")
	verify(not JSON.stringify(ui.ai_trace.entries).contains("DUMMY_"), "Android trace contains no dummy credentials")
	ui._seat_details(1)
	verify(ui.ai_inspector.visible and ui.ai_inspector.complete, "completed Android hand unlocks inspector")
	await shot("seat-request-history")
	ui.info_sheet.close()
	# A deliberately truncated reasoning fixture exercises the real Android HTTP path.
	ui.ai_profiles[0].service.model = "reasoning-fixture"
	ui._start_table(2)
	ui.bot_timer.stop()
	if ui.game.actor == 0: ui.game.act(0, "call")
	ui._request_ai()
	await wait_client(ui.ai_client)
	ui.bot_timer.stop()
	verify(ui.ai_error.is_empty(), "truncated generation recovers automatically on Android")
	var logs = ui.ai_trace.for_seat(1)
	verify(logs.any(func(e): return e.state == "retrying" and e.finish_reason == "length") and logs.any(func(e): return e.state == "complete" and e.limit == 16384), "Android captures both attempts and larger budget")
	ui.speech_client.cancel()
	ui._seat_details(1)
	ui.ai_inspector._detail(logs.back())
	verify(not ui.ai_inspector.complete, "live Android hand keeps messages locked")
	await shot("seat-request-locked")
	ui.info_sheet.close()
	for count in [6, 9]:
		ui._start_table(count)
		ui.bot_timer.stop()
		await settle()
		ui.ai_dialogue = [{"seat": 1, "event": ui.game.events.size(), "text": "这一下够狠啊，想把我赶走可没那么容易。"}]
		ui._refresh()
		ui.bot_timer.stop()
		verify(ui.table_view.speech_bubble.visible, "seat bubble visible on Android %d players" % count)
		verify(not ui.ai_bar.visible, "speech does not add bottom text box")
		await shot("speech-%d" % count)
	ui._open_settings()
	ui.settings._select_page(6)
	var page = ui.settings.ai_page
	page.models = []
	for i in range(90): page.models.append({"id": "model-%03d" % i, "name": "测试模型 %03d" % i, "api": "chat"})
	page._render_models()
	page._open_models()
	await shot("model-selector")
	var selection: String = page.model.text
	report("awaiting_model_up", {"swipe": swipe_points(page.model_sheet.scroll, true)})
	await marker("model-up")
	verify(page.model_sheet.visible and page.model_sheet.scroll.scroll_vertical > 100 and page.model.text == selection, "native finger upward scroll without selecting")
	var after_up: int = page.model_sheet.scroll.scroll_vertical
	await shot("model-scrolled-up")
	report("awaiting_model_down", {"swipe": swipe_points(page.model_sheet.scroll, false)})
	await marker("model-down")
	verify(page.model_sheet.scroll.scroll_vertical < after_up and page.model.text == selection, "native finger downward scroll without selecting")
	page.model_search.text = "032"
	page.model_search.text_changed.emit("032")
	await settle()
	var at: Vector2 = page.model_rows.get_child(0).get_global_rect().get_center()
	var scale = Vector2(DisplayServer.window_get_size()) / get_viewport().get_visible_rect().size
	report("awaiting_model_tap", {"tap": [roundi(at.x * scale.x), roundi(at.y * scale.y)]})
	await marker("model-tap")
	verify(page.model.text == "model-032" and not page.model_sheet.visible, "native finger tap chooses searched model")
	page._open_models()
	await settle()
	watch_ui = ui
	watching_back = true
	report("awaiting_model_back")
	await marker("model-back")
	verify(not page.model_sheet.visible and ui.settings.visible and ui.settings.current_page == 6, "native Android back closes only model selector (selector=%s settings=%s page=%s)" % [page.model_sheet.visible, ui.settings.visible, ui.settings.current_page])
	report("awaiting_category_back")
	await marker("category-back")
	verify(ui.settings.visible and ui.settings.current_page == -1, "second distinct native back returns to categories once")
	watching_back = false
	ui.settings.cancel()
	History.save({"ready": true}, "vault-relaunch.json", "user://")
	report("awaiting_relaunch")
