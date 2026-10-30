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
	for i in range(8): await process_frame

func fits(control: Control, message: String) -> void:
	verify(Rect2(Vector2.ZERO, root.get_visible_rect().size).grow(1).encloses(control.get_global_rect()), message + " " + str(control.get_global_rect()) + " in " + str(root.get_visible_rect()))

func geometry(table, label: String) -> void:
	var area = Rect2(Vector2.ZERO, table.size).grow(1)
	verify(area.encloses(table.center.get_rect()), label + " public cards inside table")
	for i in range(table.seat_nodes.size()):
		var rect = table.seat_nodes[i].panel.get_rect()
		verify(area.encloses(rect), label + " seat inside table")
		verify(not rect.intersects(table.center.get_rect()), label + " seat does not overlap board")
		for j in range(i + 1, table.seat_nodes.size()):
			verify(not rect.intersects(table.seat_nodes[j].panel.get_rect()), label + " seats do not overlap: %d / %d %s / %s" % [i, j, rect, table.seat_nodes[j].panel.get_rect()])
		for card in table.seat_nodes[i].cards:
			if card.visible: verify(table.seat_nodes[i].panel.get_global_rect().encloses(card.get_global_rect()), label + " face fits seat")

func _run() -> void:
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	ui.smoke_mode = true
	await settle()
	verify(ProjectSettings.get_setting("display/window/size/window_width_override") < ProjectSettings.get_setting("display/window/size/window_height_override") and ui.portrait, "desktop configuration starts portrait without flags")
	verify(ui.menu_sheet.content.get_children().all(func(c): return not c.text.contains("横屏") and not c.text.contains("竖屏")), "menu has no orientation toggle")
	verify(not ui.settings.controls.sidebar.is_visible_in_tree(), "obsolete sidebar option hidden")
	for resolution in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(412, 915)]:
		root.size = resolution
		await settle()
		verify(ui.portrait and root.content_scale_size == Vector2i(540, 960), "portrait logical scale")
		ui._open_lobby()
		await settle()
		fits(ui.lobby_panel, "lobby panel fits")
		ui._close_lobby()
		for count in range(2, 10):
			ui._start_table(count)
			await settle()
			geometry(ui.table_view, str(resolution) + " " + str(count))
			for button in [ui.fold_button, ui.call_button, ui.bet_open_button, ui.more_button, ui.advice_button]: fits(button, "primary control fits")
			verify(not ui.sidebar.visible, "portrait never squeezes sidebar")
			for id in range(1, count):
				verify(ui.table_view.seat_nodes[id].cards.all(func(card): return card.card_id == -1), "compact seats contain no hidden faces")
		ui._start_table(2)
		# Long coach explanations must scroll, never push over the board or action dock.
		ui.coach.expand()
		while ui.coach.job != null: await process_frame
		ui.coach.reason.text = "长篇教学解释，用来检查小屏幕仍能查看公共牌并完成操作。".repeat(30)
		await settle()
		fits(ui.coach.panel, "coach constrained to portrait")
		verify(ui.coach.panel.global_position.y > ui.table_view.board_row.get_global_rect().end.y, "live coach leaves board visible")
		verify(ui.coach.panel.get_global_rect().end.y < ui.dock.global_position.y, "live coach leaves action buttons available")
		verify(ui.coach.scroll.get_v_scroll_bar().max_value > ui.coach.scroll.size.y, "long explanation is scrollable")
		ui.coach.collapse()
		var before = ui.game.record_state()
		ui.bet_open_button.pressed.emit()
		await settle()
		verify(ui.bet_sheet.visible and ui.game.record_state() == before, "opening raise sheet does not bet")
		for button in [ui.raise_button, ui.all_in_button, ui.bet_sheet.close_button]: fits(button, "raise sheet footer fits")
		ui.quick_buttons[2].pressed.emit()
		verify(ui.selected_raise == 25 and ui.game.record_state() == before, "sheet 2.5 BB only fills draft")
		ui.sheet_units.select(0)
		ui.sheet_units.item_selected.emit(0)
		verify(ui.selected_raise == 25 and ui.amount_input.value == 25 and not ui.prefs.use_bb, "sheet units preserve exact chips")
		ui._human_action("fold")
		ui._next_hand()
		verify(ui.game.record_state() == before, "sheet blocks hidden gameplay actions")
		ui._back()
		verify(not ui.bet_sheet.visible and ui.game.record_state() == before, "back closes sheet without betting")
		ui._open_bet()
		ui.raise_button.pressed.emit()
		verify(not ui.bet_sheet.visible and ui.game.current_bet == 25, "sheet submit performs one legal raise")
		ui._start_table(2)
		ui._open_bet()
		before = ui.game.record_state()
		ui.all_in_button.pressed.emit()
		verify(ui.confirmation.visible and ui.game.record_state() == before, "sheet all-in protected")
		await settle()
		fits(ui.confirmation.panel, "all-in dialog fits")
		ui._back()
		verify(ui.game.record_state() == before, "cancel sheet all-in preserves state")
		ui._open_settings()
		ui.settings.controls.felt.select(1)
		await settle()
		fits(ui.settings.panel, "settings fits")
		fits(ui.settings.apply_button, "settings apply reachable")
		fits(ui.settings.cancel_button, "settings cancel reachable")
		ui._back()
		ui._open_menu()
		await settle()
		fits(ui.menu_sheet.panel, "menu fits")
		ui._back()
		ui._seat_details(1)
		verify(ui.info_sheet.visible and ui.info_text.text.contains("未公开"), "tap seat reveals public data only")
		ui._back()
		ui._start_table(9)
		while ui.game.phase != "complete":
			var legal = ui.game.legal_actions(ui.game.actor)
			ui.game.act(ui.game.actor, "check" if legal.check else "call")
		ui._refresh()
		await settle()
		geometry(ui.table_view, "showdown")
		fits(ui.next_button, "next hand fits")
		ui._open_history()
		ui.review.open_replay(History.replay(ui.game.completed_record()), true)
		ui.review._jump_street(1)
		ui.review.next_decision()
		await settle()
		geometry(ui.review.table_view, "replay")
		for control in [ui.review.prev, ui.review.next, ui.review.play, ui.review.mine, ui.review.street, ui.review.slider]: fits(control, "replay transport fits")
		var step = ui.review.index
		ui.review.analysis_tab.pressed.emit()
		ui.review._analyze()
		while ui.review.job != null: await process_frame
		await settle()
		verify(ui.review.analysis_selected and ui.review.left.visible and not ui.review.portrait_tabs.visible and ui.review.index == step, "coach overlay preserves visible table and replay step")
		fits(ui.review.analysis_panel, "analysis fits")
		verify(not ui.review.details.visible and not ui.review.range_button.visible, "review opens with concise advice")
		ui.review.detail_toggle.pressed.emit()
		await settle()
		verify(ui.review.details.visible and ui.review.range_button.visible and ui.review.index == step, "details disclosure preserves replay decision")
		verify(ui.review.analysis_panel.global_position.y >= ui.review.table_view.board_row.get_global_rect().end.y, "expanded analysis leaves community cards visible")
		fits(ui.review.analysis_panel, "expanded analysis fits")
		ui.review.replay_tab.pressed.emit()
		verify(ui.review.index == step and ui.review.left.visible, "return to same replay step")
		root.size = Vector2i(1280, 800)
		await settle()
		verify(ui.review.index == step and ui.review.visible, "wide window preserves portrait replay cursor")
		verify(ui.portrait and is_equal_approx(ui.safe_root.size.x, 540) and ui.review.portrait, "wide window keeps portrait surface")
		root.size = resolution
		await settle()
		verify(ui.review.index == step and ui.review.visible, "portrait preserves replay cursor")
		ui._back()
	# Menu callbacks keep their own destination and stop bots until dismissed.
	ui._start_table(2)
	for index in range(6):
		var before = ui.game.record_state()
		ui._open_menu()
		ui.menu_sheet.content.get_child(index).pressed.emit()
		verify(not ui.menu_sheet.visible and [ui.settings, ui.lobby, ui.review, ui.training, ui.support_center, ui.info_sheet][index].visible, "menu destination " + str(index))
		ui._bot_step()
		ui._human_action("fold")
		verify(ui.game.record_state() == before, "menu destination pauses gameplay")
		ui._back()
		if index == 4:
			verify(ui.support_center.visible and ui.support_center.topic == -1, "table help back first returns to help categories")
			ui._back()
	# Complete actual portrait games through the same action buttons as the player.
	for count in [2, 6, 9]:
		ui._start_table(count)
		var total = ui.game.chip_total()
		var moves = 0
		while ui.game.phase != "complete" and moves < 300:
			if ui.game.actor == 0: ui.call_button.pressed.emit()
			else: ui._bot_step()
			if ui.confirmation.visible: ui.confirmation.accept_button.pressed.emit()
			moves += 1
		verify(ui.game.phase == "complete" and ui.game.chip_total() == total, "portrait full game with bots " + str(count))
	# Wide desktop windows keep portrait and preserve all in-progress work.
	ui._start_table(2)
	ui._unit_changed(1)
	ui._open_bet()
	ui.amount_input.get_line_edit().text = "3.7"
	var original = ui.game.record_state()
	root.size = Vector2i(1280, 800)
	await settle()
	verify(ui.portrait and ui.bet_sheet.visible and ui.selected_raise == 37, "wide resize keeps portrait sheet and typed draft")
	verify(is_equal_approx(ui.safe_root.size.x, 540) and ui.safe_root.size.y > ui.safe_root.size.x, "wide resize maintains tall game surface")
	verify(is_equal_approx(ui.safe_root.position.x, (root.get_visible_rect().size.x - 540) / 2), "portrait surface centered")
	fits(ui.raise_button, "wide resize keeps sheet submit reachable")
	verify(ui.game.record_state() == original, "resize never changes cards or chips")
	geometry(ui.table_view, "portrait within wide window")
	ui._back()
	ui._open_settings()
	ui.settings.controls.felt.select(1)
	root.size = Vector2i(390, 844)
	await settle()
	verify(ui.settings.visible and ui.settings.controls.felt.selected == 1 and ui.prefs.felt_theme == 0, "resize preserves unapplied settings")
	ui._back()
	ui._open_lobby()
	await settle()
	fits(ui.start_button, "portrait lobby start visible after return")
	print("PORTRAIT_TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
