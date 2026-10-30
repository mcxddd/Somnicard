extends SceneTree
const Table = preload("res://scripts/poker/table.gd")
const Preferences = preload("res://scripts/ui/preferences.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("_run")

func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	_test_preferences()
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	ui.smoke_mode = true
	ui._open_lobby()
	ui._open_settings()
	verify(ui.lobby.visible and ui.settings.visible and ui.settings.cancel_button.has_focus(), "settings opens over lobby with focus")
	verify(ui.start_button.focus_mode == Control.FOCUS_NONE, "lobby controls blocked under settings")
	var initial = ui._settings_values()
	ui.settings.controls.felt.select(1)
	ui.settings.controls.felt.item_selected.emit(1)
	verify(not ui.settings.apply_button.disabled and ui.felt_theme == 0, "draft changes do not apply early")
	ui._back()
	verify(ui._settings_values() == initial and ui.lobby.visible and ui.start_button.has_focus(), "back discards settings draft and restores lobby")
	ui._start_table(2)
	ui.amount_input.get_line_edit().text = "3.7"
	var before = ui.game.view_for(0)
	ui._open_settings()
	verify(ui.selected_raise == 37, "typed amount preserved when opening settings")
	ui._human_action("fold")
	ui._next_hand()
	ui._bot_step()
	ui._toggle_pause()
	verify(ui.game.view_for(0) == before and not ui.paused, "settings blocks gameplay and keyboard pause")
	ui.settings.controls.bb.select(0)
	ui.settings.controls.speed.select(2)
	ui.settings.controls.felt.select(1)
	ui.settings.controls.four_color.button_pressed = true
	ui.settings.controls.motion.button_pressed = false
	ui.settings.controls.fast_fold.button_pressed = false
	ui.settings.controls.sidebar.button_pressed = false
	ui.settings.controls.confirm_all_in.button_pressed = false
	ui.settings.apply_button.pressed.emit()
	verify(not ui.settings.visible and not ui.use_bb and ui.speed_index == 2 and ui.felt_theme == 1, "apply closes and commits selected settings")
	verify(ui.selected_raise == 37 and ui.amount_input.value == 37 and ui.game.view_for(0) == before, "unit apply keeps exact target and game")
	verify(ui.table_view.four_color and ui.review.table_view.four_color and not ui.table_view.motion, "table and review share visuals")
	verify(not ui.fast_fold.button_pressed and not ui.sidebar.visible and not ui.confirm_all_in, "all toggles take effect")
	var applied = ui._settings_values()
	ui._open_settings()
	verify(ui.settings.values() == applied and ui.settings.apply_button.disabled, "reopen reads applied state")
	ui.settings._fill(ui.settings.DEFAULTS)
	ui.settings._changed()
	verify(ui._settings_values() == applied, "restore defaults only changes draft")
	ui.settings.cancel_button.pressed.emit()
	verify(ui._settings_values() == applied, "cancel defaults preserves applied state")
	ui._toggle_pause()
	ui._open_settings()
	ui.settings.cancel()
	verify(ui.paused and ui.bot_timer.is_stopped(), "already paused table stays paused")
	ui._toggle_pause()
	# New-table editing and confirmation have independent cancel paths.
	var old_game = ui.game
	ui._open_lobby()
	ui._select_count(9)
	ui.depth_picker.select(2)
	ui.start_button.pressed.emit()
	verify(ui.confirmation.visible and ui.game == old_game, "reset waits for confirmation")
	verify(ui.confirmation.cancel_button.has_focus() and ui.start_button.focus_mode == Control.FOCUS_NONE, "confirmation is top focus scope")
	ui._back()
	verify(ui.lobby.visible and not ui.confirmation.visible and ui.game.view_for(0) == before, "cancel reset preserves hand")
	ui._close_lobby()
	verify(ui.selected_count == 2 and ui.starting_bb == 100 and ui.depth_picker.selected == 1, "closing table setup discards count/depth draft")
	ui._open_lobby()
	ui._select_count(6)
	ui.depth_picker.select(0)
	ui.start_button.pressed.emit()
	ui.confirmation.accept_button.pressed.emit()
	verify(ui.player_count == 6 and ui.game.chip_total() == 3000 and ui.starting_bb == 50, "confirmed reset applies exact draft")
	# Every all-in route is protected, and confirming cannot submit twice.
	ui.confirm_all_in = true
	for route in ["all_in", "raise", "call"]:
		ui.game = Table.new([100, 100], 5, 10, 10)
		ui.game.start_hand(0)
		if route == "call":
			ui.game.act(0, "call")
			ui.game.act(1, "all_in")
		ui.paused = false
		ui._refresh()
		before = ui.game.view_for(0)
		ui._human_action(route, 100 if route == "raise" else 0)
		verify(ui.confirmation.visible and ui.game.view_for(0) == before, route + " protected")
		ui._human_action("fold")
		verify(ui.game.view_for(0) == before, "background action blocked by confirmation")
		ui.confirmation.cancel_button.pressed.emit()
		verify(ui.game.view_for(0) == before, "cancel all-in leaves money and cards intact")
		ui._human_action(route, 100 if route == "raise" else 0)
		ui.confirmation.accept_button.pressed.emit()
		verify(ui.game.events.size() > before.events.size() and not ui.confirmation.visible, "confirmed all-in executes")
		var after = ui.game.view_for(0)
		ui.confirmation.accept_button.pressed.emit()
		verify(ui.game.view_for(0) == after, "duplicate confirmation does not replay action")
	ui._start_table(2)
	ui.confirm_all_in = false
	ui.all_in_button.pressed.emit()
	verify(not ui.confirmation.visible and ui.game.seats[0].stack == 0, "protection can be disabled")
	# A pending callback must be invalidated if the underlying decision changes.
	ui._start_table(2)
	ui.confirm_all_in = true
	ui.all_in_button.pressed.emit()
	ui.game.act(0, "call")
	before = ui.game.view_for(0)
	ui.confirmation.accept_button.pressed.emit()
	verify(ui.game.view_for(0) == before, "stale confirmation cannot affect a later actor")
	ui._start_table(2)
	# Fixed runout: hero's ace-high heart flush wins; the refill test cannot tie.
	var opening = [0, 12, 1, 25, 2, 13, 15, 17, 3, 19, 4, 21]
	ui.game = Table.new([1000, 1000])
	ui.game.start_hand(0, opening + range(52).filter(func(card): return card not in opening))
	ui._refresh()
	ui.all_in_button.pressed.emit()
	before = ui.game.view_for(0)
	ui.smoke_mode = false
	ui._notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT)
	ui.smoke_mode = true
	verify(ui.paused and not ui.confirmation.visible and ui.game.view_for(0) == before, "background cancels pending action and pauses without betting")
	ui.paused = false
	ui.game.act(0, "all_in")
	ui.game.act(1, "call")
	ui._refresh()
	# Whichever seat wins, a winner-takes-all heads-up table needs explicit refill.
	ui._next_hand()
	verify(ui.confirmation.visible and ui.game.phase == "complete", "refill is protected like every other reset")
	ui.confirmation.cancel()
	verify(ui.game.phase == "complete", "cancel refill preserves settlement")
	ui._next_hand()
	ui.confirmation.accept_button.pressed.emit()
	verify(ui.game.phase == "preflop" and ui.game.chip_total() == ui.starting_bb * 20, "confirmed refill starts fresh table")
	ui._start_table(9)
	ui.smoke_mode = false
	ui.speed_index = 2
	ui._schedule_bot()
	ui._open_settings()
	before = ui.game.view_for(0)
	await create_timer(0.4).timeout
	verify(ui.game.view_for(0) == before and ui.bot_timer.is_stopped(), "settings stops real bot timer")
	ui.settings.cancel()
	await create_timer(0.65).timeout
	verify(ui.game.events.size() > before.events.size(), "closing settings resumes bot timer")
	ui.bot_timer.stop()
	ui.smoke_mode = true
	# Larger card artwork remains inside every seat, with no hidden card metadata.
	for count in [2, 6, 9]:
		ui._start_table(count)
		await process_frame
		await process_frame
		for seat in ui.table_view.seat_nodes:
			for card in seat.cards:
				if card.visible: verify(seat.panel.get_global_rect().encloses(card.get_global_rect()), "visible card artwork fits seat")
		for id in range(1, count):
			for card in ui.table_view.seat_nodes[id].cards: verify(card.card_id == -1, "card back never contains opponent card id")
	ui._open_history()
	verify(ui.review.close_button.text == "返回牌桌", "history return label matches origin")
	ui.review.close()
	ui._open_lobby()
	ui._open_history()
	verify(ui.review.close_button.text == "返回选桌", "nested history return label matches origin")
	ui._notification(Control.NOTIFICATION_WM_GO_BACK_REQUEST)
	verify(ui.lobby.visible and not ui.review.visible, "Android back dismisses top modal only")
	ui.queue_free()
	await process_frame
	print("EXPERIENCE_TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_preferences() -> void:
	var path = "user://__settings-test-%d.cfg" % Time.get_ticks_usec()
	var old = ConfigFile.new()
	old.set_value("ui", "bb", false)
	old.set_value("ui", "speed", 2)
	old.set_value("table", "players", 9)
	old.set_value("table", "depth", 200)
	old.save(path)
	var loaded = Preferences.load_values(path, true)
	verify(not loaded.bb and loaded.speed == 2 and loaded.players == 9 and loaded.depth == 200, "old v1 preferences migrate")
	verify(loaded.confirm_all_in and loaded.sidebar, "new settings receive defaults")
	loaded.felt = 1
	loaded.four_color = true
	loaded.motion = false
	verify(Preferences.save_values(loaded, path) == OK, "atomic preference overwrite")
	verify(Preferences.load_values(path) == loaded, "all settings persist across reload")
	old.set_value("ui", "felt", "broken")
	old.set_value("ui", "speed", 900)
	old.set_value("ui", "bb", "false")
	old.set_value("table", "depth", -100)
	old.save(path)
	loaded = Preferences.load_values(path)
	verify(loaded.felt == 0 and loaded.speed == 2 and loaded.bb and loaded.depth == 100, "malformed preferences use bounded defaults")
	DirAccess.remove_absolute(path)
