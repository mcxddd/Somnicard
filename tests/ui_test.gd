extends SceneTree
const Table = preload("res://scripts/poker/table.gd")
var failures: int = 0
var checks: int = 0

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
	ui.bot_timer.stop()
	ui._start_table(2)
	ui.screen.unit_picker.select(0)
	ui._unit_changed(0)
	verify(not ui.screen.call_button.disabled and ui.screen.call_button.text == "跟注\n5", "initial human controls")
	# A freshly typed value must be committed even without pressing Enter first.
	ui.screen.amount_input.get_line_edit().text = "60"
	ui.screen.raise_button.pressed.emit()
	verify(ui.game.current_bet == 60 and ui.game.seats[0].street_bet == 60, "typed raise uses street total")
	verify(ui.screen.call_button.disabled and ui.screen.raise_button.disabled, "input locked during bot turn")
	ui.game.act(1, "call")
	ui._refresh()
	verify(ui.game.phase == "flop" and ui.game.actor == 1, "human raise and bot call reach flop")
	var steps = 0
	while ui.game.phase != "complete" and steps < 100:
		if ui.game.actor == 0:
			ui.screen.call_button.pressed.emit()
		else:
			var legal = ui.game.legal_actions(ui.game.actor)
			ui.game.act(ui.game.actor, "check" if legal.check else "call")
			ui._refresh()
		steps += 1
	verify(ui.game.phase == "complete" and ui.game.result.showdown and ui.game.chip_total() == 2000, "UI showdown settles")
	verify(ui.screen.next_button.visible and not ui.screen.fold_button.visible, "settlement controls")
	# Check actual serialization and replay, then remove only this test's own record.
	ui.smoke_mode = false
	ui.storage.saved_hand = -1
	ui.storage.session_id = "__test_%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	ui.storage.save_record()
	var path = "user://hands/%s-%04d.json" % [ui.storage.session_id, ui.game.hand_number]
	verify(FileAccess.file_exists(path), "completed record written")
	if FileAccess.file_exists(path):
		var record = JSON.parse_string(FileAccess.get_file_as_string(path))
		verify(record is Dictionary and record.deck.size() == 52, "saved JSON is complete")
		if record is Dictionary:
			# JSON decodes all numbers as floats; normalize card IDs at the persistence boundary.
			var replay = Table.new(record.starting_stacks, int(record.small_blind), int(record.big_blind))
			verify(replay.start_hand(int(record.button), record.deck.map(func(c): return int(c))) == "", "saved deck reloads")
			for event in record.events:
				if event.kind == "action":
					verify(replay.act(int(event.seat), event.action, int(event.to)) == "", "saved action replays")
			verify(JSON.parse_string(JSON.stringify(replay.result)) == record.result, "saved replay has identical settlement")
		verify(DirAccess.remove_absolute(path) == OK, "remove only the test record")
	ui.smoke_mode = true
	ui.screen.next_button.pressed.emit()
	verify(ui.game.hand_number == 2 and ui.game.button == 1, "next hand rotates button")
	ui.game.act(1, "call")
	ui._refresh()
	ui.screen.fold_button.pressed.emit()
	verify(ui.game.phase == "complete" and not ui.game.result.showdown, "fold button ends hand")
	# Real bot timer path, not just direct engine calls.
	ui.screen.next_button.pressed.emit()
	ui.smoke_mode = false
	ui.screen.call_button.pressed.emit()
	verify(not ui.bot_timer.is_stopped(), "bot timer scheduled")
	await create_timer(1.5).timeout
	verify(ui.game.events.any(func(e): return e.kind == "action" and e.seat == 1), "bot responds via timer")
	ui.bot_timer.stop()
	ui.smoke_mode = true
	# All-in button must run to showdown when called.
	ui.game = Table.new([1000, 1000])
	ui.game.start_hand(0)
	ui._refresh()
	ui.screen.all_in_button.pressed.emit()
	verify(ui.confirmation.visible and ui.game.seats[0].stack == 995, "all-in waits for explicit confirmation")
	ui.confirmation.accept_button.pressed.emit()
	verify(ui.game.seats[0].stack == 0 and ui.game.actor == 1, "all-in button commits stack")
	ui.game.act(1, "call")
	ui._refresh()
	verify(ui.game.phase == "complete" and ui.game.result.pot == 2000, "all-in runs all streets")
	print("UI_INTEGRATION: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
