extends SceneTree
const Table = preload("res://scripts/poker/table.gd")
const History = preload("res://scripts/poker/history.gd")
const Filter = preload("res://scripts/poker/history_filter.gd")
const Teaching = preload("res://scripts/poker/teaching.gd")
var checks = 0
var failures = 0

func _initialize() -> void: call_deferred("_run")
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)
func settle() -> void:
	for i in range(10): await process_frame
func finish(game) -> void:
	while game.phase != "complete":
		var legal = game.legal_actions(game.actor)
		game.act(game.actor, "check" if legal.check else "call")

func swipe(scroll, dy: float) -> void:
	var start = scroll.get_global_rect().get_center()
	var touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.position = start
	touch.pressed = true
	root.push_input(touch, true)
	for step in range(1, 5):
		var move = InputEventScreenDrag.new()
		move.index = 0
		move.position = start + Vector2(0, dy * step / 4)
		move.relative = Vector2(0, dy / 4)
		root.push_input(move, true)
	touch.position = start + Vector2(0, dy)
	touch.pressed = false
	root.push_input(touch, true)

func _run() -> void:
	var game = Table.new([1000, 1000], 5, 10, 14)
	game.start_hand(0)
	var view = game.view_for(0)
	view.phase = "flop"
	view.seats[0].hole = [12, 25]
	view.board = [0, 20, 34]
	var a = {"action": "fold", "amount": 0, "cost": 5, "eligible_pot": 20, "odds": 0.25, "pot_equity": 0.16, "call_ev": -1.8, "ev_error": 0.4, "opponents": 1, "strategy": {"supported": false}}
	var words = Teaching.explain(view, a, true)
	verify(words.summary.contains("0.5 BB") and words.summary.contains("16.0%") and words.summary.contains("25.0%"), "explanation uses this decision's price and equity")
	verify(words.details.contains("超对") and words.details.contains("A♠ A♥"), "explanation identifies actual known hand")
	verify(not words.details.contains("均匀发牌先验") and not words.details.contains("有效组合"), "teaching explains play rather than implementation")
	var hidden = view.duplicate(true)
	hidden.seats[1].hole = [1, 2]
	hidden.deck = [51, 50, 49]
	hidden.future_board = [15, 16]
	verify(Teaching.explain(hidden, a, true) == words, "explanations cannot read hidden hands or future fields")
	verify(Teaching.explain(view, a, false).summary.contains("跟注要 5"), "explanation converts units without changing cost")
	view.seats[0].hole = [13, 27]
	view.board = [8, 9, 10, 11, 12]
	view.phase = "river"
	verify(Teaching.explain(view, a, true).details.contains("最佳牌力与公共牌相同"), "shared board hand is not claimed as private strength")
	view.seats[0].hole = [12, 11]
	view.board = [0, 3, 27]
	view.phase = "flop"
	verify(Teaching.explain(view, a, true).details.contains("同花听牌"), "current flush draw explained")
	var solved = a.duplicate(true)
	solved.strategy = {"supported": true, "converged": true, "frequencies": [{"action": "fold", "amount": 0, "frequency": 0.999, "ev": 0.0}, {"action": "call", "amount": 0, "frequency": 0.001, "ev": -3.0}]}
	var river_view = view.duplicate(true)
	river_view.phase = "river"
	river_view.board = [0, 3, 27, 31, 42]
	var solved_words = Teaching.explain(river_view, solved, true)
	verify(solved_words.summary.contains("-0.30 BB") and not solved_words.summary.contains("这是混合打法"), "dominant fold explains alternative model EV without implying meaningful mixing")
	solved.strategy.frequencies[0].frequency = 0.6
	solved.strategy.frequencies[1].frequency = 0.4
	verify(Teaching.explain(river_view, solved, false).summary.contains("这是混合打法"), "meaningful alternatives are described as mixed play")
	var base = {"file": "100", "id": "SC-ABC", "players": 6, "net": -10, "pot": 100, "big_blind": 5, "valid_result": true, "showdown": true, "all_in": true, "raised": false, "day": "2026-10-16", "search": "SC-ABC 2026-10-16"}
	verify(Filter.matches(base, {"query": "sc-ab", "players": 6, "result": 2, "ending": 1, "action": 1, "days": 7}, "2026-10-22"), "filters combine and include seventh calendar day")
	verify(not Filter.matches(base, {"days": 1}, "2026-10-22"), "today excludes older hands")
	verify(not Filter.matches(base, {"players": 9}, "2026-10-22") and not Filter.matches(base, {"result": 1}, "2026-10-22"), "seat and profit filters exclude mismatches")
	var other = base.duplicate()
	other.file = "200"
	other.net = -15
	other.big_blind = 10
	verify(Filter.select([base, other], {"sort": 2}, "2026-10-22") == ["100", "200"], "loss sort compares BB not raw chips")
	verify(Filter.summary({"record": {"result": "broken", "deck": "invalid"}}, "broken.json").valid_result == false, "malformed metadata is safe")

	var directory = "res://.local/history-test-" + str(Time.get_ticks_usec())
	var files: Array = []
	var records: Array = []
	for i in range(35):
		var hand = Table.new([100, 100], 5, 10, 91 + i)
		hand.hand_number = i
		hand.start_hand(0)
		if i % 3 == 0:
			hand.act(0, "all_in")
			finish(hand)
		else: hand.act(0, "fold")
		var record = hand.completed_record()
		record.saved_at = "2026-10-%02d 12:00:00" % (1 + i % 22)
		var file = "%d-%04d.json" % [1700000000 + i, i]
		verify(History.save(record, file, directory) == OK, "fixture saved")
		files.append(file)
		records.append(record)
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	ui.smoke_mode = true
	root.size = Vector2i(360, 640)
	await settle()
	ui.review.history_page.history_directory = directory
	ui._open_history()
	while ui.review.history_page.scan_cursor >= 0: await process_frame
	await settle()
	var review = ui.review
	verify(review.history_page.filenames.size() == 35 and review.history_page.entries.size() == 25, "catalogue spans all pages")
	review.history_page.search.text = History.hand_id(records[0]).right(8).to_lower()
	review.history_page._filters_changed()
	verify(review.history_page.filenames == [files[0]], "ID search finds hand outside first page")
	review.history_page._reset_history_filters()
	review.history_page.filters.action.select(1)
	review.history_page._filters_changed()
	verify(review.history_page.filenames.size() == 12 and review.history_page.entries.size() == 12, "hero all-in filter uses recorded actions")
	review.history_page.search.text = "NO-MATCH"
	review.history_page._filters_changed()
	verify(review.history_page.entries.is_empty() and review.history_page.history_status.text.contains("没有符合"), "no results has a useful empty state")
	review.history_page._reset_history_filters()
	review.history_page.filters.result.select(2)
	review.history_page._filters_changed()
	await settle()
	review.history_page.history_scroll.reset_scroll(200)
	review.history_page.list_offset = 200
	review._open_entry(2)
	verify(review.replay_page.visible, "filtered entry still validates and opens")
	review.history_page.show_history()
	while review.history_page.scan_cursor >= 0: await process_frame
	await settle()
	verify(review.history_page.filters.result.selected == 2 and review.history_page.history_scroll.scroll_vertical == 200, "return preserves filter and list position: selected=%d scroll=%d stored=%d" % [review.history_page.filters.result.selected, review.history_page.history_scroll.scroll_vertical, review.history_page.list_offset])
	review.history_page.filter_panel.show()
	await settle()
	verify(root.get_visible_rect().encloses(review.history_page.reset_filters.get_global_rect()) and root.get_visible_rect().encloses(review.history_page.next_page.get_global_rect()), "expanded filters and paging fit small portrait")
	review.close()
	ui._start_table(2)
	var before = ui.game.record_state()
	ui._open_advice()
	while review.analysis_view.job != null: await process_frame
	await settle()
	verify(not review.analysis_view.details.scroll_active, "one scroll owner for long explanation")
	var scroll = review.analysis_view.analysis_scroll
	scroll.reset_scroll(100)
	await settle()
	var initial = scroll.scroll_vertical
	swipe(scroll, -90)
	verify(scroll.scroll_vertical > initial, "upward swipe reads later explanation")
	var later = scroll.scroll_vertical
	swipe(scroll, 70)
	verify(scroll.scroll_vertical < later, "downward swipe returns to earlier explanation")
	scroll.reset_scroll(100000)
	await settle()
	var bottom = scroll.scroll_vertical
	swipe(scroll, 90)
	verify(scroll.scroll_vertical < bottom, "can reverse away from bottom boundary")
	scroll.reset_scroll()
	swipe(scroll, -80)
	verify(scroll.scroll_vertical > 0 and ui.game.record_state() == before, "can leave top boundary without acting on live table")
	ui.queue_free()
	await process_frame
	for file in files: DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("TEACHING_HISTORY_TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
