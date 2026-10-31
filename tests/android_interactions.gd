extends Node
## Native touch-driven scenarios in the isolated audit app. Fixtures only prepare state.
const History = preload("res://scripts/poker/history.gd")
var ui
var checks = 0
var failures: Array = []
var steps: Array = []
var serial = 0

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("INTERACTION_FAIL: " + label)

func settle() -> void:
	for i in range(12): await get_tree().process_frame

func report(stage: String, extra: Dictionary = {}) -> void:
	var data = {"stage": stage, "checks": checks, "failures": failures, "steps": steps, "sequence": serial}
	data.merge(extra)
	History.save(data, "interactions.json", "user://")

func action(label: String, commands: Array) -> void:
	serial += 1
	steps.append(label)
	report("input", {"commands": commands})
	var marker = "user://interaction-%d" % serial
	var deadline = Time.get_ticks_msec() + 90000
	while not FileAccess.file_exists(marker) and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	verify(FileAccess.file_exists(marker), "native input completed: " + label)
	await settle()

func pixel(point: Vector2) -> Array:
	var scale = Vector2(DisplayServer.window_get_size()) / get_viewport().get_visible_rect().size
	return [roundi(point.x * scale.x), roundi(point.y * scale.y)]

func tap(control: Control, label: String, times: int = 1) -> void:
	await settle()
	verify(control.is_visible_in_tree() and get_viewport().get_visible_rect().encloses(control.get_global_rect()), "reachable: " + label)
	var at = pixel(control.get_global_rect().get_center())
	var commands: Array = []
	for i in range(times): commands.append({"kind": "tap", "at": at})
	await action(label, commands)

func swipe(scroll: Control, upwards: bool, label: String) -> void:
	var r = scroll.get_global_rect()
	await action(label, [{"kind": "swipe", "from": pixel(Vector2(r.get_center().x, r.position.y + r.size.y * (0.8 if upwards else 0.2))), "to": pixel(Vector2(r.get_center().x, r.position.y + r.size.y * (0.2 if upwards else 0.8)))}])

func back(label: String) -> void:
	await action(label, [{"kind": "back"}])

func reveal(scroll: ScrollContainer, control: Control) -> void:
	# Categories and filtered lists relayout on the next frame before scrolling.
	await settle()
	scroll.ensure_control_visible(control)
	await settle()
	verify(scroll.get_global_rect().intersection(control.get_global_rect()).has_area(), "target intersects scroller")

func _ready() -> void:
	await get_tree().create_timer(1).timeout
	ui = load("res://scenes/main.tscn").instantiate()
	add_child(ui)
	ui.smoke_mode = true
	ui.bot_timer.stop()
	ui._open_home()
	await settle()
	# Actual home -> lobby -> cancel, then settings draft cancellation / application.
	await tap(ui.home.primary, "home opens new table")
	verify(ui.screen.lobby.visible and ui.game == null, "lobby does not deal prematurely")
	await tap(ui.screen.preset_buttons[6], "choose six players")
	verify(ui.selected_count == 6, "six-player preset selected")
	await tap(ui.screen.cancel_button, "cancel new table")
	verify(ui.home.visible and not ui.screen.lobby.visible and ui.game == null, "cancel keeps empty home")
	await tap(ui.home.entries.settings, "home opens settings")
	await tap(ui.settings.tabs[1], "open display category")
	var original: bool = ui.prefs.four_color
	await reveal(ui.settings.scroll, ui.settings.controls.four_color)
	await tap(ui.settings.controls.four_color, "change draft four-color")
	verify(ui.settings.values().four_color != original and ui.prefs.four_color == original, "draft does not apply before save")
	await tap(ui.settings.cancel_button, "discard display draft")
	verify(ui.prefs.four_color == original and ui.home.visible, "cancel restores original")
	await tap(ui.home.entries.settings, "reopen settings")
	await tap(ui.settings.tabs[1], "reopen display")
	await reveal(ui.settings.scroll, ui.settings.controls.four_color)
	await tap(ui.settings.controls.four_color, "change display again")
	await tap(ui.settings.apply_button, "save display")
	verify(ui.prefs.four_color != original and not ui.settings.visible, "save applies display")
	# Learning is a real native-touch path, with persisted completion and layered back.
	await tap(ui.home.learning, "open learning route")
	await tap(ui.learning_center.body.get_child(4), "choose pricing lesson")
	verify(ui.learning_center.lesson == 2 and ui.learning_center.question == 0, "intended lesson selected")
	await tap(ui.learning_center.answer_buttons[0], "try incorrect pricing answer")
	verify(not ui.learning_center.answered and ui.learning_center.next_button.disabled, "wrong answer explains without awarding completion")
	await reveal(ui.learning_center.scroll, ui.learning_center.answer_buttons[1])
	await tap(ui.learning_center.answer_buttons[1], "choose correct pricing answer")
	await tap(ui.learning_center.next_button, "pricing next question")
	await tap(ui.learning_center.answer_buttons[2], "choose river fold answer")
	await tap(ui.learning_center.next_button, "pricing final question")
	await tap(ui.learning_center.answer_buttons[0], "choose equity realization answer")
	for q in range(ui.learning_center.question + 1, preload("res://scripts/product/academy.gd").LESSONS[2].questions.size()):
		await tap(ui.learning_center.next_button, "pricing next question %d" % q)
		await tap(ui.learning_center.answer_buttons[preload("res://scripts/product/academy.gd").LESSONS[2].questions[q].correct], "choose pricing answer %d" % q)
	await tap(ui.learning_center.next_button, "complete pricing lesson")
	verify(preload("res://scripts/product/academy.gd").progress(ui.training_store.data).lessons == 1, "one course completed without inflating progress")
	await back("lesson back to route")
	await back("route back to home")
	verify(ui.home.visible and not ui.learning_center.visible and ui.home.learning.text.contains("1/%d" % preload("res://scripts/product/academy.gd").LESSONS.size()), "home reflects saved learning progress")
	await tap(ui.home.entries.help, "open help center")
	await tap(ui.support_center.body.get_child(6), "open privacy topic")
	verify(ui.support_center.topic == 4, "privacy opens separately")
	await swipe(ui.support_center.scroll, true, "privacy upward")
	verify(ui.support_center.scroll.scroll_vertical > 0 or ui.support_center.scroll.get_global_rect().grow(2).encloses(ui.support_center.body.get_global_rect()), "privacy either fits in full or scrolls")
	await back("privacy back to help index")
	await reveal(ui.support_center.scroll, ui.support_center.body.get_child(9))
	await tap(ui.support_center.body.get_child(9), "open full license attributions")
	await swipe(ui.support_center.scroll, true, "license details upward")
	verify(ui.support_center.scroll.scroll_vertical > 0, "long help content scrolls upward")
	var license_scroll = ui.support_center.scroll.scroll_vertical
	await swipe(ui.support_center.scroll, false, "license details downward")
	verify(ui.support_center.scroll.scroll_vertical < license_scroll, "long help content scrolls downward")
	await back("licenses back to help index")
	await back("help back to home")
	verify(ui.home.visible and not ui.support_center.visible, "help restores home")
	# Start via the visible buttons; no hidden game action shortcut.
	await tap(ui.home.primary, "open lobby again")
	await tap(ui.screen.preset_buttons[6], "choose six again")
	await tap(ui.screen.start_button, "deal six-player table")
	verify(ui.game.seats.size() == 6 and not ui.home.visible and not ui.screen.lobby.visible, "table started by touch")
	var total = ui.game.chip_total()
	var before_events = ui.game.events.size()
	await tap(ui.screen.unit_picker.buttons[0], "show chip amount")
	verify(not ui.prefs.use_bb, "amount unit selected")
	await tap(ui.screen.unit_picker.buttons[1], "show BB")
	verify(ui.prefs.use_bb and ui.game.events.size() == before_events and ui.game.chip_total() == total, "unit switching preserves game")
	# Repeated seat configuration must not stack controls or lose target.
	for repeat in range(4):
		var seat = repeat % 2 + 1
		await tap(ui.screen.table_view.seat_nodes[seat].panel, "open seat %d iteration %d" % [seat, repeat])
		verify(ui.screen.info_sheet.visible and ui.info_opponent_id == seat, "details selects intended seat")
		verify(ui.screen.info_sheet.content.get_children().filter(func(c): return c is Button and c.text == "配置这位对手").size() == 1, "exactly one configure button")
		await tap(ui.screen.info_opponent_button, "configure selected opponent")
		verify(ui.settings.visible and ui.settings.current_page == 3 and ui.settings.opponent_editor.selected == seat, "editor targets same opponent")
		await tap(ui.settings.cancel_button, "cancel opponent edit")
		verify(not ui.settings.visible and not ui.screen.info_sheet.visible, "cancel returns to table")
	verify(ui.game.events.size() == before_events, "configuration navigation did not advance hand")
	# Heads-up human actions, quick sizing and all-in guard.
	ui._start_table(2)
	if ui.game.actor != 0: ui.game.act(ui.game.actor, "call")
	ui._refresh()
	before_events = ui.game.events.size()
	await tap(ui.screen.bet_open_button, "open raise panel")
	verify(ui.screen.bet_sheet.visible, "raise panel opened")
	await tap(ui.screen.quick_buttons[2], "select 2.5 BB sizing")
	verify(ui.bet.selected_raise == 25, "quick size sets 25 chips")
	await tap(ui.screen.bet_sheet.close_button, "close sizing without placing bet")
	await tap(ui.screen.unit_picker.buttons[0], "switch amount at table header")
	await tap(ui.screen.bet_open_button, "reopen sizing in chip amounts")
	verify(ui.bet.selected_raise == 25 and not ui.prefs.use_bb, "unit conversion keeps raise amount")
	await tap(ui.screen.all_in_button, "request all-in")
	verify(ui.confirmation.visible and ui.game.events.size() == before_events, "all-in waits for confirmation")
	await tap(ui.confirmation.cancel_button, "cancel all-in")
	verify(not ui.confirmation.visible and ui.game.events.size() == before_events, "cancel all-in preserves chips and action")
	await tap(ui.screen.call_button, "rapid double call", 2)
	verify(ui.game.events.size() == before_events + 1 and ui.game.actor == 1, "double call executes only once")
	await tap(ui.screen.pause_button, "pause table")
	verify(ui.paused and ui.screen.call_button.disabled, "pause disables human action")
	await tap(ui.screen.pause_button, "resume table")
	verify(not ui.paused, "resume restores table")
	# OS background/resume is tested separately on the unmodified production APK.
	# Opponent fixtures check/call; every human decision uses Android touch.
	var moves = 0
	while ui.game.phase != "complete" and moves < 30:
		if ui.game.actor == 0: await tap(ui.screen.call_button, "human check/call street %s" % ui.game.phase)
		else:
			var legal = ui.game.legal_actions(ui.game.actor)
			ui.game.act(ui.game.actor, "check" if legal.check else "call")
			ui._refresh()
		moves += 1
	verify(ui.game.phase == "complete" and ui.game.result.showdown and ui.game.chip_total() == 2000, "touch-driven human hand reaches showdown")
	await tap(ui.coach.avatar, "finished hand coach opens replay")
	verify(ui.review.visible and not ui.review.frames.is_empty(), "coach opens finished hand replay")
	ui.review.seek(0)
	await settle()
	await tap(ui.review.next, "replay next step")
	verify(ui.review.index == 1, "replay advances once")
	await tap(ui.review.prev, "replay previous step")
	verify(ui.review.index == 0, "replay returns once")
	await tap(ui.review.mine, "jump to my decision")
	if ui.review.analysis_panel.visible: await tap(ui.review.analysis_view.overlay_close, "collapse automatically opened teaching")
	await tap(ui.review.analysis_view.coach_avatar, "open decision teaching")
	var deadline = Time.get_ticks_msec() + 20000
	while ui.review.analysis_view.job != null and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	verify(not ui.review.analysis_view.analysis.is_empty(), "teaching produces current-decision analysis")
	await tap(ui.review.analysis_view.detail_toggle, "expand teaching details")
	await swipe(ui.review.analysis_view.analysis_scroll, true, "teaching details upward")
	var detail_offset = ui.review.analysis_view.analysis_scroll.scroll_vertical
	verify(detail_offset > 0, "teaching upward drag moves content")
	await swipe(ui.review.analysis_view.analysis_scroll, false, "teaching details downward")
	verify(ui.review.analysis_view.analysis_scroll.scroll_vertical < detail_offset, "teaching downward drag moves content")
	await reveal(ui.review.analysis_view.analysis_scroll, ui.review.analysis_view.range_button)
	await tap(ui.review.analysis_view.range_button, "expand opponent ranges")
	await reveal(ui.review.analysis_view.analysis_scroll, ui.review.analysis_view.range_grid)
	var visible_grid: Rect2 = ui.review.analysis_view.range_grid.get_global_rect().intersection(ui.review.analysis_view.analysis_scroll.get_global_rect())
	var hand_before: String = ui.review.analysis_view.range_grid.selected_hand
	await action("drag across range grid", [{"kind": "swipe", "from": pixel(Vector2(visible_grid.get_center().x, visible_grid.end.y - 12)), "to": pixel(Vector2(visible_grid.get_center().x, visible_grid.position.y + 12))}])
	verify(ui.review.analysis_view.range_grid.selected_hand == hand_before, "range drag does not select a hand")
	await tap(ui.review.analysis_view.overlay_close, "collapse teaching overlay")
	await tap(ui.review.close_button, "close replay")
	verify(not ui.review.visible and ui.game.phase == "complete", "replay preserves completed game")
	# A long history fixture stays inside the isolated audit application's files.
	var record = ui.game.completed_record()
	for i in range(35): verify(History.save(record, "touch-%03d.json" % i) == OK, "prepare history fixture %d" % i)
	ui._open_history()
	while ui.review.history_page.scan_cursor >= 0: await get_tree().process_frame
	await settle()
	await swipe(ui.review.history_page.history_scroll, true, "history list upward")
	var history_offset = ui.review.history_page.history_scroll.scroll_vertical
	verify(history_offset > 0 and ui.review.history_page.visible, "history drag scrolls without opening record")
	await swipe(ui.review.history_page.history_scroll, false, "history list downward")
	verify(ui.review.history_page.history_scroll.scroll_vertical < history_offset and ui.review.history_page.visible, "history downward scroll does not open record")
	await tap(ui.review.history_page.next_page, "history next page")
	verify(ui.review.history_page.page == 1, "history page advances")
	await tap(ui.review.history_page.previous_page, "history previous page")
	verify(ui.review.history_page.page == 0, "history page returns")
	await tap(ui.review.history_page.search, "focus history search")
	await action("type history filename search", [{"kind": "text", "value": "touch-007"}])
	await get_tree().create_timer(0.6).timeout
	verify(ui.review.history_page.filenames.size() == 1 and ui.review.history_page.filenames[0] == "touch-007.json", "native typed search finds exact hand")
	await tap(ui.review.history_page.history_cards.get_child(0), "open searched history hand")
	verify(ui.review.replay_page.visible and not ui.review.frames.is_empty(), "selected history opens valid replay")
	await tap(ui.review.close_button, "leave searched replay")
	ui._open_settings()
	ui.settings._select_page(4)
	ui.settings.data_page.dialog.use_native_dialog = false
	ui.settings.data_page.dialog.popup_centered_ratio(0.9)
	await back("backup dialog back")
	await back("settings category back")
	verify(ui.settings.visible and ui.settings.current_page == -1, "second back returns category list")
	await tap(ui.settings.cancel_button, "cancel settings draft")
	await settle()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://interactions-final.png")
	report("complete")
	print("ANDROID_INTERACTIONS: ", checks, " checks, ", failures.size(), " failures, ", steps.size(), " native input steps")
