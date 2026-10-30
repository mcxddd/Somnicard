extends SceneTree
const Trace = preload("res://scripts/ai/trace_log.gd")
var checks = 0
var failures = 0
func _initialize() -> void: call_deferred("run")
func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + message)
func settle() -> void:
	for i in range(12): await process_frame
func pointer(at: Vector2, pressed: bool, touch: bool) -> void:
	var e = InputEventScreenTouch.new() if touch else InputEventMouseButton.new()
	if not touch: e.button_index = MOUSE_BUTTON_LEFT
	e.position = at
	e.pressed = pressed
	root.push_input(e, true)
func swipe(at: Vector2, delta: Vector2, touch: bool) -> void:
	pointer(at, true, touch)
	for i in range(1, 7):
		var e = InputEventScreenDrag.new() if touch else InputEventMouseMotion.new()
		if not touch: e.button_mask = MOUSE_BUTTON_MASK_LEFT
		e.position = at + delta * i / 6
		e.relative = delta / 6
		root.push_input(e, true)
	pointer(at + delta, false, touch)
func text_in(node: Node) -> String:
	var text = str(node.text) if node is Label or node is RichTextLabel else ""
	for child in node.get_children(): text += text_in(child)
	return text
func run() -> void:
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	ui.smoke_mode = true
	root.size = Vector2i(360, 640)
	ui._start_table(6)
	ui._open_settings()
	ui.settings._select_page(6)
	var page = ui.settings.ai_page
	page.models = []
	for i in range(200): page.models.append({"id": "model-%03d" % i, "name": "测试模型 %03d" % i, "api": "messages" if i == 32 else "chat"})
	page._render_models()
	page._open_models()
	await settle()
	verify(page.model_sheet.visible and not ui.settings.scroll.is_processing_input(), "selector owns gestures exclusively")
	verify(page.model_rows.get_child_count() == 61, "large catalog renders in bounded batches")
	var selection = page.model.text
	for touch in [true, false]:
		page.model_sheet.scroll.reset_scroll()
		page.model_sheet.scroll.released_at = -1000
		await settle()
		var at: Vector2 = page.model_sheet.scroll.get_global_rect().get_center()
		swipe(at, Vector2(0, -140), touch)
		verify(page.model_sheet.scroll.scroll_vertical > 80 and page.model_sheet.visible and page.model.text == selection, "upward drag scrolls without selecting touch=%s" % touch)
		var before: int = page.model_sheet.scroll.scroll_vertical
		swipe(at, Vector2(0, 100), touch)
		verify(page.model_sheet.scroll.scroll_vertical < before and page.model.text == selection, "downward drag scrolls without selecting touch=%s" % touch)
	page.model_search.text = "032"
	page.model_search.text_changed.emit("032")
	await settle()
	verify(page.filtered.size() == 1 and page.model_rows.get_child_count() == 1, "model search includes IDs and names")
	page.model_sheet.scroll.released_at = -1000
	page.model_rows.get_child(0).pressed.emit()
	verify(page.model.text == "model-032" and page.selected_api == "messages" and not page.model_sheet.visible, "tap commits correct model and protocol")
	verify(ui.settings.scroll.is_processing_input(), "outer scrolling restored on selection")
	page._open_models()
	ui._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	verify(page.model_sheet.visible and ui.settings.current_page == 6, "temporary focus loss cancels networking without closing selector")
	ui._back()
	verify(not page.model_sheet.visible and ui.settings.visible and ui.settings.current_page == 6, "Android back closes selector first")
	page._open_models()
	ui._system_back(1000)
	verify(not page.model_sheet.visible and ui.settings.current_page == 6, "first platform back closes model picker")
	ui._system_back(1174)
	verify(ui.settings.current_page == 6, "duplicate Android 16 notification does not pop another level")
	ui._system_back(1400)
	verify(ui.settings.current_page == -1, "next normal back press is accepted after duplicate interval")
	ui.settings.cancel()
	# A bubble must fit the table and stay clear of every important surface.
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844)]:
		root.size = dimensions
		await settle()
		for count in range(2, 10):
			ui._start_table(count)
			ui.bot_timer.stop()
			await settle()
			var table = ui.table_view
			for seat in range(1, count):
				table.clear_speech()
				table.sync_speech([{"seat": seat, "event": ui.game.events.size(), "text": "这一下够狠啊，想把我赶走可没那么容易。"}])
				await settle()
				var bubble = table.speech_bubble
				var rect: Rect2 = bubble.get_global_rect()
				verify(bubble.visible and table.get_global_rect().encloses(rect), "bubble fits %s seats=%d speaker=%d" % [dimensions, count, seat])
				for node in table.seat_nodes:
					verify(not rect.intersects(node.panel.get_global_rect()), "bubble avoids seat cards and stacks")
					if node.bet.visible: verify(not rect.intersects(node.bet.get_global_rect()), "bubble avoids wagers")
				verify(not rect.intersects(table.board_row.get_global_rect()), "bubble avoids community cards")
				var until: int = table.speech_until
				table.sync_speech([{"seat": seat, "event": ui.game.events.size(), "text": "这一下够狠啊，想把我赶走可没那么容易。"}])
				verify(table.speech_until == until, "refresh does not restart bubble lifetime")
	ui.table_view.speech_until = 1
	ui.table_view._process(0.1)
	verify(not ui.table_view.speech_bubble.visible, "bubble expires automatically")
	ui.table_view.sync_speech([{"seat": "bad", "event": "bad", "text": "malformed"}])
	verify(not ui.table_view.speech_bubble.visible, "malformed imported speech safely ignored")
	var trace = Trace.new()
	var entry = {"id": "1", "context": {"seat": 1, "hand": ui.game.hand_number}, "state": "complete", "request": {"messages": [{"content": "PRIVATE_HOLE_SENTINEL KEY_SENTINEL"}], "api_key": "KEY_SENTINEL"}, "response": "PRIVATE_REPLY_SENTINEL Bearer KEY_SENTINEL", "reasoning_content": "PRIVATE_REASONING_SENTINEL"}
	trace.append(entry, ["KEY_SENTINEL"])
	verify(not JSON.stringify(trace.entries).contains("KEY_SENTINEL") and not JSON.stringify(trace.entries).contains("PRIVATE_REASONING_SENTINEL"), "trace scrubs credentials and hidden reasoning")
	trace.append(entry)
	verify(trace.entries.size() == 1, "attempt updates replace pending record without duplication")
	ui.ai_trace = trace
	ui.ai_seats[0].enabled = true
	ui._seat_details(1)
	ui.ai_inspector._detail(trace.entries[0])
	verify(not text_in(ui.ai_inspector).contains("PRIVATE_HOLE_SENTINEL") and not text_in(ui.ai_inspector).contains("PRIVATE_REPLY_SENTINEL"), "live inspector blocks prompts and replies with private cards")
	ui.info_sheet.close()
	while ui.game.phase != "complete": ui.game.act(ui.game.actor, "check" if ui.game.legal_actions(ui.game.actor).check else "call")
	ui._refresh()
	ui._seat_details(1)
	ui.ai_inspector._detail(trace.entries[0])
	verify(text_in(ui.ai_inspector).contains("PRIVATE_HOLE_SENTINEL") and text_in(ui.ai_inspector).contains("PRIVATE_REPLY_SENTINEL"), "completed hand unlocks full sent messages and visible response")
	verify(not JSON.stringify(ui._ai_session_state()).contains("PRIVATE_HOLE_SENTINEL"), "traces do not enter saved table or backups")
	ui.info_sheet.close()
	for i in range(210): trace.append({"id": str(i), "context": {"seat": i % 2 + 1, "hand": 1}, "request": {}, "response": "x".repeat(32768)})
	verify(trace.entries.size() <= 160 and JSON.stringify(trace.entries).to_utf8_buffer().size() <= Trace.MAX_BYTES, "retention bounded by count and bytes")
	verify(trace.for_seat(1).all(func(e): return e.context.seat == 1), "seat history never mixes opponents")
	ui._start_table(2)
	verify(ui.ai_trace.entries.is_empty() and not ui.table_view.speech_bubble.visible, "new table clears traces and old speech")
	ui.queue_free()
	await process_frame
	print("VERSION113_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
