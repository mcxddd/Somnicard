extends SceneTree
const Table = preload("res://scripts/poker/table.gd")
const History = preload("res://scripts/poker/history.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("_run")
func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func settle() -> void:
	for i in range(10): await process_frame
func passive(game) -> void:
	while game.phase != "complete":
		var legal = game.legal_actions(game.actor)
		game.act(game.actor, "check" if legal.check else "call")

func _run() -> void:
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	ui.smoke_mode = true
	for resolution in [Vector2i(360, 640), Vector2i(412, 915)]:
		root.size = resolution
		await settle()
		for count in range(2, 10):
			ui._start_table(count)
			verify(ui.game.button == 0 and ui.game.small_blind_seat == (0 if count == 2 else 1) and ui.game.big_blind_seat == (1 if count == 2 else 2), "initial button and blinds " + str(count))
			verify(ui.game.actor == (0 if count == 2 else 3 % count), "preflop first actor " + str(count))
			for id in range(count):
				var node = ui.table_view.seat_nodes[id]
				verify(node.badge.visible == (id == ui.game.button), "only dealer has D badge")
				verify(node.blind.visible == (id in [ui.game.small_blind_seat, ui.game.big_blind_seat]), "only blind seats have blind badge")
				verify(node.name.text == ui.game.seats[id].name, "names have no position suffix")
				if id > 0: verify(node.cards.all(func(c): return c.visible and c.card_id == -1), "active opponent has visible safe backs")
			# Display stress fixture: every seat has an amount, without changing engine state.
			var snapshot = ui.game.view_for(0)
			for seat in snapshot.seats: seat.street_bet = 125
			ui.table_view.update_table(snapshot, true)
			await settle()
			var table = ui.table_view
			for id in range(count):
				var marker = table.seat_nodes[id].bet
				verify(marker.visible and marker.amount == 125 and marker.text == "12.5 BB" and marker.value_label.text == "12.5" and marker.unit_label.text == "BB", "bet amount reflects street in BB")
				verify(marker.get_global_rect().encloses(marker.value_label.get_global_rect()) and marker.get_global_rect().encloses(marker.unit_label.get_global_rect()), "decimal BB number and unit fit without clipping")
				var rect: Rect2 = marker.get_global_rect()
				verify(table.get_global_rect().encloses(rect), "bet within table")
				for seat in table.seat_nodes: verify(not rect.intersects(seat.panel.get_global_rect()), "%d bet %d avoids seat" % [count, id])
				for card in table.board_row.get_children(): verify(not rect.intersects(card.get_global_rect()), "%d bet %d avoids board" % [count, id])
				var label = table.pot_label
				var text_rect: Rect2 = label.get_content_rect()
				text_rect.position += label.global_position
				verify(not rect.intersects(text_rect), "%d bet %d avoids pot number" % [count, id])
				for other in range(id + 1, count): verify(not rect.intersects(table.seat_nodes[other].bet.get_global_rect()), "%d bet markers separate" % count)
			ui.table_view.update_table(snapshot, false)
			verify(table.seat_nodes[0].bet.value_label.text == "125" and table.seat_nodes[0].bet.unit_label.text == "筹码", "bet amount switches to exact chips")
			# Small blind fractions and the full nine-player bankroll remain exact and legible.
			for chips in [0, 5, 18000]:
				for bb_mode in [false, true]:
					for seat in snapshot.seats:
						seat.street_bet = chips
						seat.stack = chips
					snapshot.pot = chips
					table.update_table(snapshot, bb_mode)
					await settle()
					for seat in table.seat_nodes:
						for display in [seat.stack, seat.bet, table.pot_label]:
							verify(display.amount == chips and display.use_bb == bb_mode, "amount rendering preserves chips and units")
							for part in [display.value_label, display.unit_label]:
								verify(display.get_global_rect().grow(0.5).encloses(part.get_global_rect()), "exact number and unit fit " + display.role + " " + str(chips) + " " + str(display.get_global_rect()) + " / " + str(part.get_global_rect()))
					verify(table.seat_nodes[0].stack.value_label.text == ("1,800" if bb_mode else "18,000") if chips == 18000 else true, "large amounts use exact thousands groups")
			while ui.game.phase == "preflop":
				var legal = ui.game.legal_actions(ui.game.actor)
				ui.game.act(ui.game.actor, "check" if legal.check else "call")
			ui._refresh()
			verify(ui.game.actor == 1 and ui.game.seats.all(func(s): return s.street_bet == 0), "postflop starts clockwise after dealer and resets street bets")
			verify(table.seat_nodes.all(func(s): return not s.bet.visible), "new street clears markers but preserves pot")
			verify(ui.game.pot_size() == count * 10, "central pot retains previous contributions")
			passive(ui.game)
			ui._refresh()
			verify(table.seat_nodes.all(func(s): return not s.bet.visible and s.stack.visible), "settlement keeps remaining stacks, clears wagers")
			verify(table.seat_nodes.all(func(s): return s.cards.all(func(c): return c.visible and c.card_id >= 0)), "all showdown hands visible")
			ui._next_hand()
			verify(ui.game.button == 1, "dealer advances clockwise")
	# Sparse table: blind roles skip out-of-play seats.
	var sparse = Table.new([1000, 0, 1000, 1000])
	sparse.start_hand(0)
	verify(sparse.small_blind_seat == 2 and sparse.big_blind_seat == 3, "empty seat skipped by blinds")
	ui._start_table(6)
	var before_units = ui.game.record_state()
	ui.unit_picker.buttons[0].pressed.emit()
	verify(not ui.prefs.use_bb and ui.unit_picker.selected == 0 and ui.game.record_state() == before_units, "segmented chip selector preserves game")
	ui.unit_picker.buttons[1].pressed.emit()
	verify(ui.prefs.use_bb and ui.unit_picker.selected == 1 and ui.game.record_state() == before_units, "segmented BB selector preserves game")
	passive(ui.game)
	ui._refresh()
	var id = History.hand_id(ui.game.completed_record())
	ui.coach.avatar.pressed.emit()
	verify(ui.review.visible and ui.review.record_id_label.text.contains(id), "finished-hand coach opens the exact completed hand")
	verify(ui.review.left.visible and ui.review.analysis_panel.visible and not ui.review.portrait_tabs.visible, "analysis overlays replay rather than switching screen")
	verify(ui.review._hero_decision() and ui.review.frames[ui.review.index].view.seats[1].hole.is_empty(), "review begins at a decision with then-known information")
	while ui.review.job != null: await process_frame
	await settle()
	verify(not ui.review.analysis.is_empty(), "finished-hand coach produces decision analysis")
	verify(ui.review.analysis_panel.get_global_rect().end.y <= ui.review.slider.global_position.y, "overlay leaves timeline available")
	verify(ui.review.analysis_panel.global_position.y >= ui.review.table_view.board_row.get_global_rect().end.y, "overlay leaves community cards visible")
	ui.review.next_decision()
	verify(ui.review.left.visible and ui.review.analysis_panel.visible, "next decision keeps same table and overlay")
	ui._back()
	verify(ui.review.visible and not ui.review.analysis_panel.visible and ui.review.job == null, "back collapses analysis and cancels job")
	ui._back()
	verify(not ui.review.visible and ui.game.phase == "complete", "second back returns to completed live hand")
	ui.queue_free()
	await process_frame
	print("TABLE_PRESENCE_TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
