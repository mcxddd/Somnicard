extends SceneTree
const Table = preload("res://scripts/poker/table.gd")
const History = preload("res://scripts/poker/history.gd")
const Bot = preload("res://scripts/poker/local_bot.gd")
const Outcome = preload("res://scripts/ui/outcome.gd")
const UI = preload("res://scripts/ui/style.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void: call_deferred("_run")
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func settle() -> void:
	for i in range(10): await process_frame

func deck(text: String) -> Array:
	var out: Array = []
	for token in text.split(" "): out.append("shdc".find(token[1]) * 13 + "23456789TJQKA".find(token[0]))
	for c in range(52):
		if c not in out: out.append(c)
	return out

func passive(game) -> void:
	while game.phase != "complete":
		var legal = game.legal_actions(game.actor)
		game.act(game.actor, "check" if legal.check else "call")

func _run() -> void:
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	ui.smoke_mode = true
	ui._start_table(3)
	var tie = Table.new([100, 100, 100])
	tie.start_hand(0, deck("2h 3h 4h 5h 6h 7h 8d As Ks Qs 9d Js Td Ts"))
	var stable_id = History.hand_id(tie.record_state())
	tie.act(tie.actor, "call")
	tie.act(tie.actor, "fold")
	passive(tie)
	ui.game = tie
	ui._refresh()
	await settle()
	verify(ui.table_view.result_label.text.contains("平分底池"), "tied pot explicitly shown")
	verify(Outcome.net(tie.view_for(0), 0) == 2, "odd-chip split net deducts contribution")
	verify(ui.table_view.seat_nodes[2].cards.all(func(c): return c.visible and c.card_id >= 0), "opponent showdown cards visible")
	verify(ui.table_view.seat_nodes[1].cards.all(func(c): return not c.visible and c.card_id == -1), "folded hole cards remain hidden")
	verify(History.hand_id(tie.completed_record()) == stable_id, "ID stable from deal through settlement")
	verify(History.hand_id(JSON.parse_string(JSON.stringify(tie.completed_record()))) == stable_id, "ID compatible with old JSON records")
	verify(ui.review._record_label(tie.completed_record(), "old.json").contains(stable_id), "history displays derived legacy ID")
	var side = Table.new([50, 100, 200])
	side.start_hand(0, deck("Ks Qs As Kh Qh Ah Jc 2s 3h 7d Tc 8c 9c 9d"))
	side.act(side.actor, "all_in")
	side.act(side.actor, "all_in")
	side.act(side.actor, "call")
	verify(not Outcome.summary(side.view_for(0)).contains("平分"), "different main and side-pot winners are not a tie")
	ui.table_view.set_preferences(0, false, false)
	verify(ui.table_view.result_label.modulate.a == 1.0, "disabled animations still show result")
	ui._start_table(2)
	await settle()
	var before = ui.game.record_state()
	ui.coach.avatar.pressed.emit()
	verify(ui.coach.expanded and not ui.review.visible and not ui._modal_open(), "coach stays on playable table")
	while ui.coach.job != null: await process_frame
	verify(ui.game.record_state() == before and not ui.coach.analysis.is_empty(), "coaching does not act or change game")
	verify(ui.coach.hole_cards[0].card_id == ui.game.seats[0].hole[0], "expanded coach retains own hand context")
	var analysis = ui.coach.analysis.duplicate(true)
	ui._unit_changed(0)
	verify(ui.coach.analysis == analysis, "unit change preserves current coach calculation")
	ui.call_button.pressed.emit()
	verify(not ui.coach.expanded and ui.coach.analysis.is_empty(), "action clears stale coach advice")
	var settings = ui._settings_values()
	settings.live_teaching = false
	settings.difficulty = 2
	settings.speed = 0
	ui._apply_settings(settings)
	verify(not ui.coach.visible and ui.bots[1].difficulty == 2, "coach switch and difficulty apply independently")
	settings.live_teaching = true
	settings.coach_auto = true
	ui._apply_settings(settings)
	ui._start_table(2)
	verify(ui.coach.expanded and ui.coach.job != null, "automatic coach starts on hero decision")
	ui._back()
	verify(not ui.coach.expanded and ui.coach.job == null, "back cancels floating coach")
	settings.coach_auto = false
	ui._apply_settings(settings)
	# Each level completes legal multiway games, conserving chips and using only its cards.
	for level in range(3):
		for players in [2, 6, 9]:
			var stacks: Array = []
			stacks.resize(players)
			stacks.fill(150)
			var game = Table.new(stacks, 5, 10, 45 + level + players)
			game.start_hand()
			var moves = 0
			while game.phase != "complete" and moves < 300:
				var snapshot = game.view_for(game.actor)
				var actor = Bot.new(100 + moves, moves % 3, level)
				var action = actor.choose(snapshot)
				var changed = snapshot.duplicate(true)
				for seat in changed.seats:
					if seat.id != game.actor: seat.hole = [51, 50]
				verify(Bot.new(100 + moves, moves % 3, level).choose(changed) == action, "difficulty ignores opponent hole cards")
				verify(game.act(game.actor, action.action, action.get("amount", 0)) == "", "difficulty emits legal action")
				moves += 1
			verify(game.phase == "complete" and game.chip_total() == players * 150, "difficulty finishes with chip conservation")
	# Actual input dispatch over history buttons: drag should scroll, never open.
	ui._open_history()
	while ui.review.scan_cursor >= 0: await process_frame
	UI.clear(ui.review.history_cards)
	var clicks = [0]
	for i in range(30):
		var card = UI.button("测试历史 %d" % i, func():
			if ui.review.history_scroll.can_activate(): clicks[0] += 1, UI.GREEN, 130)
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		ui.review.history_cards.add_child(card)
	await settle()
	var scroll = ui.review.history_scroll
	var start = scroll.global_position + Vector2(80, 200)
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	root.push_input(press, true)
	for step in range(1, 7):
		var drag = InputEventMouseMotion.new()
		drag.position = start - Vector2(0, step * 20)
		drag.relative = Vector2(0, -20)
		drag.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(drag, true)
	var release = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = start - Vector2(0, 120)
	root.push_input(release, true)
	await settle()
	verify(scroll.scroll_vertical >= 100 and clicks[0] == 0, "drag over history card scrolls without activation")
	await create_timer(0.1).timeout
	press.position = scroll.global_position + Vector2(80, 80)
	root.push_input(press, true)
	release.position = press.position
	root.push_input(release, true)
	verify(clicks[0] == 1, "tap after scrolling still opens card")
	var touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.position = start
	touch.pressed = true
	root.push_input(touch, true)
	var old_offset = scroll.scroll_vertical
	var swipe = InputEventScreenDrag.new()
	swipe.index = 0
	swipe.position = start - Vector2(0, 120)
	swipe.relative = Vector2(0, -120)
	root.push_input(swipe, true)
	touch.position = swipe.position
	touch.pressed = false
	root.push_input(touch, true)
	verify(scroll.scroll_vertical > old_offset and not scroll.can_activate(), "native touch swipe scrolls and suppresses activation")
	ui.queue_free()
	await process_frame
	print("FEEDBACK_TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
