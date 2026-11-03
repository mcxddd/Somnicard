extends SceneTree
const Table = preload("res://scripts/poker/table.gd")
const Bot = preload("res://scripts/poker/local_bot.gd")
const Sizing = preload("res://scripts/ui/bet_sizing.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func verify(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	ui.smoke_mode = true
	verify(ui.home.visible and not ui.screen.lobby.visible and ui.game == null, "initial home does not start hidden game")
	ui._open_lobby()
	verify(ui.screen.fold_button.focus_mode == Control.FOCUS_NONE and ui.screen.start_button.has_focus(), "lobby traps keyboard focus")
	for count in [2, 6]:
		ui.screen.preset_buttons[count].pressed.emit()
		verify(ui.selected_count == count and ui.screen.count_picker.selected == count - 2, "preset synchronizes custom count")
	# Every count must be selectable through the actual dropdown, not just an API.
	var completed_hands = 0
	for count in range(2, 7):
		ui._open_lobby()
		ui.screen.count_picker.select(count - 2)
		ui.screen.count_picker.item_selected.emit(count - 2)
		ui.screen.depth_picker.select(1)
		ui.screen.start_button.pressed.emit()
		if ui.confirmation.visible: ui.confirmation.accept_button.pressed.emit()
		verify(not ui.screen.lobby.visible and ui.game.seats.size() == count and ui.bots.size() == count - 1, "custom table starts correct number of bots")
		for id in ui.bots: ui.bots[id] = Bot.new(count * 100 + id, (id - 1) % 3)
		await process_frame
		await process_frame
		_check_geometry(ui, count)
		for hand in range(3):
			var total = ui.game.chip_total()
			var steps = 0
			while ui.game.phase != "complete" and steps < 300:
				if ui.game.actor == 0: ui.screen.call_button.pressed.emit()
				else: ui._bot_step()
				if ui.confirmation.visible: ui.confirmation.accept_button.pressed.emit()
				verify(ui.game.chip_total() == total, "multiway UI conserves chips")
				steps += 1
				await process_frame
			verify(ui.game.phase == "complete" and ui.screen.next_button.visible, "human + bots finish complete hand")
			await process_frame
			_check_geometry(ui, count)
			completed_hands += 1
			if hand < 2:
				ui.screen.next_button.pressed.emit()
				if ui.confirmation.visible: ui.confirmation.accept_button.pressed.emit()
	# Modal, pause and queued callbacks cannot change the old hand.
	ui._start_table(6)
	var old_game = ui.game
	var before = ui.game.view_for(0)
	ui._open_lobby()
	ui._select_count(6)
	ui._bot_step()
	ui._human_action("fold")
	ui._next_hand()
	verify(ui.game == old_game and ui.game.view_for(0) == before, "opening/change selection preserves active hand")
	ui.screen.cancel_button.pressed.emit()
	verify(ui.game == old_game and ui.player_count == 6, "cancel restores original table")
	verify(ui.screen.fold_button.focus_mode != Control.FOCUS_NONE, "cancel restores keyboard navigation")
	ui.screen.pause_button.pressed.emit()
	ui._bot_step()
	verify(ui.game.view_for(0) == before and ui.bot_timer.is_stopped(), "pause prevents bot step")
	ui.screen.pause_button.pressed.emit()
	# BB/amount/slider must preserve exact integer-chip targets and never auto-bet.
	ui._start_table(2)
	before = ui.game.view_for(0)
	ui.bet.quick_bb(2.5)
	verify(ui.bet.selected_raise == 25 and ui.game.view_for(0) == before, "2.5 BB selects 25 without submitting")
	ui.screen.unit_picker.select(0)
	ui.screen.unit_picker.item_selected.emit(0)
	verify(ui.screen.amount_input.value == 25 and ui.bet.selected_raise == 25, "switch to chips preserves amount")
	verify(ui.screen.amount_input.get_line_edit().virtual_keyboard_type == LineEdit.KEYBOARD_TYPE_NUMBER, "chip amounts open a digit keypad")
	ui.screen.unit_picker.select(1)
	ui.screen.unit_picker.item_selected.emit(1)
	verify(is_equal_approx(ui.screen.amount_input.value, 2.5) and ui.bet.selected_raise == 25, "switch back to BB preserves amount")
	verify(ui.screen.amount_input.get_line_edit().virtual_keyboard_type == LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL, "BB amounts open a decimal keypad")
	ui.screen.amount_slider.value = 37
	verify(ui.bet.selected_raise == 37 and is_equal_approx(ui.screen.amount_input.value, 3.7), "slider and BB input synchronized")
	ui.screen.minus_button.pressed.emit()
	verify(ui.bet.selected_raise == 27, "minus one BB")
	ui.screen.plus_button.pressed.emit()
	verify(ui.bet.selected_raise == 37, "plus one BB")
	ui.bet.quick_bb(0.2)
	verify(ui.bet.selected_raise == 20 and ui.screen.amount_note.text.contains("合法范围"), "preset under minimum is explained")
	ui.bet.quick_bb(999)
	verify(ui.bet.selected_raise == 1000, "preset over stack clamped")
	ui.screen.amount_input.get_line_edit().text = "2.5"
	ui.screen.raise_button.pressed.emit()
	verify(ui.game.current_bet == 25 and ui.game.seats[0].street_bet == 25, "fresh typed BB commits exact chip target")
	ui.game.act(1, "raise", 75)
	ui._refresh()
	before = ui.game.view_for(0)
	ui.screen.quick_buttons[6].pressed.emit()
	verify(ui.bet.selected_raise == 150 and ui.game.view_for(0) == before, "half-pot button computes after-call pot without betting")
	ui.screen.quick_buttons[7].pressed.emit()
	verify(ui.bet.selected_raise == 225, "full-pot button computes legal raise-to")
	# Facing a bet, half-pot is computed after calling, not as half the old pot.
	var view = {"current_bet": 20, "pot": 100, "legal": {"raise": true, "to_call": 20, "min_raise_to": 40, "max_raise_to": 500}}
	verify(Sizing.from_pot(0.5, view) == 80, "half-pot raise includes call")
	verify(Sizing.from_bb(2.5, 10, view.legal) == 40, "BB helper respects min raise")
	# A short all-in must remain selectable even below the normal minimum raise.
	ui.game = Table.new([200, 200, 35])
	ui.game.start_hand(0)
	ui.game.act(0, "raise", 30)
	ui.game.act(1, "call")
	ui.game.act(2, "all_in")
	ui._refresh()
	verify(ui.screen.raise_button.disabled and ui.screen.quick_buttons.all(func(b): return b.disabled), "no raise shortcuts when action is not reopened")
	ui.game = Table.new([15, 100])
	ui.game.start_hand(0)
	ui.bet.decision_key = ""
	ui._refresh()
	ui.bet.quick_bb(3)
	verify(ui.bet.selected_raise == 15 and not ui.screen.raise_button.disabled, "short all-in remains available")
	ui.screen.raise_button.pressed.emit()
	if ui.confirmation.visible: ui.confirmation.accept_button.pressed.emit()
	verify(ui.game.seats[0].stack == 0, "short all-in preset submits legally")
	# Start a real 6-seat timer chain, then verify modal cancellation resumes it.
	ui._start_table(6)
	ui.smoke_mode = false
	ui.prefs.speed_index = 2
	ui._schedule_bot()
	ui._open_lobby()
	before = ui.game.view_for(0)
	await create_timer(0.4).timeout
	verify(ui.game.view_for(0) == before, "modal stops an already scheduled timer")
	ui._close_lobby()
	await create_timer(0.65).timeout
	verify(ui.game.events.size() > before.events.size(), "closing modal resumes actual bot timer")
	ui.bot_timer.stop()
	ui.smoke_mode = true
	# Confirm chosen depth is used for ALL players, and a table reset is explicit.
	ui._open_lobby()
	ui._select_count(6)
	ui.screen.depth_picker.select(2)
	ui.screen.start_button.pressed.emit()
	verify(ui.confirmation.visible, "table reset requires confirmation")
	ui.confirmation.accept_button.pressed.emit()
	verify(ui.game.chip_total() == 12000 and ui.starting_bb == 200, "200 BB table starts correct total")
	print("MULTIPLAYER_UI: %d hands, %d checks, %d failures" % [completed_hands, checks, failures])
	quit(0 if failures == 0 else 1)

func _check_geometry(ui, count: int) -> void:
	verify(ui.screen.table_view.seat_nodes.size() == count, "seat widget count")
	var area = Rect2(Vector2.ZERO, ui.screen.table_view.size)
	for i in range(count):
		var rect = ui.screen.table_view.seat_nodes[i].panel.get_rect()
		verify(area.encloses(rect), "seat stays inside felt area")
		verify(not rect.intersects(ui.screen.table_view.center.get_rect()), "seat does not cover public cards")
		for j in range(i + 1, count):
			verify(not rect.intersects(ui.screen.table_view.seat_nodes[j].panel.get_rect()), "seat panels do not overlap")
