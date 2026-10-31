extends SceneTree
const History = preload("res://scripts/poker/history.gd")
const Practice = preload("res://scripts/poker/practice.gd")
const Store = preload("res://scripts/poker/training_store.gd")
const Backup = preload("res://scripts/poker/training_backup.gd")
const Advisor = preload("res://scripts/poker/advisor.gd")
var checks = 0
var failures = 0
var temp: String
func _initialize() -> void: call_deferred("_run")
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)
func settle() -> void:
	for i in range(15): await process_frame
func finish(g) -> void:
	while g.phase != "complete":
		var legal = g.legal_actions(g.actor)
		g.act(g.actor, "check" if legal.check else "call")
func _run() -> void:
	temp = "res://.local/training-test-" + str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(temp)
	var fixtures = Practice.fixtures()
	var found_topics = {}
	var cases = 0
	for r in fixtures:
		var original = JSON.stringify(r)
		var rebuilt = History.replay(r)
		verify(not rebuilt.has("error"), "fixed lesson is a legal complete record")
		for p in Practice.points(rebuilt):
			found_topics[p.topic] = true
			var branch = Practice.new(r, p.point, "sampled", 947)
			while not branch.ready and branch.error.is_empty(): branch.step()
			verify(branch.error.is_empty(), "resample all table sizes")
			var info = Advisor.information(branch.game.view_for(0))
			verify(info == Advisor.information(p.view), "sampling preserves hero/public decision information exactly")
			verify(branch.game._starting_deck.size() == 52 and branch.game._starting_deck.duplicate().reduce(func(acc, c): acc[c] = true; return acc, {}).size() == 52, "resampled deck has no collisions")
			finish(branch.game)
			verify(not History.replay(branch.game.completed_record()).has("error"), "sampled branch replays and conserves chips")
			verify(JSON.stringify(r) == original, "source record never changes")
			cases += 1
	verify(found_topics.size() == 4, "fixtures cover all four themes")
	# Exact river oracles: board royal flush must split; private royal must win.
	var river_points = Practice.points(History.replay(fixtures[0])).filter(func(p): return p.view.phase == "river")
	var river_view = river_points[0].view.duplicate(true)
	river_view.board = [8, 9, 10, 11, 12]
	river_view.seats[0].hole = [13, 14]
	var oracle = Advisor.new(river_view, 400, false)
	while not oracle.is_done(): oracle.step(32)
	var split = oracle.result()
	verify(is_equal_approx(split.equity, 0.5) and split.action == "check", "shared royal split equity and free check oracle")
	river_view.board = [10, 9, 8, 0, 14]
	river_view.seats[0].hole = [12, 11]
	oracle = Advisor.new(river_view, 400, false)
	while not oracle.is_done(): oracle.step(32)
	var nuts = oracle.result()
	verify(is_equal_approx(nuts.equity, 1.0) and nuts.action == "raise" and nuts.amount >= river_view.legal.min_raise_to and nuts.amount <= river_view.legal.max_raise_to, "private royal wins and produces legal value amount")
	var hidden_view = river_view.duplicate(true)
	hidden_view.seats[1].hole = [1, 2]
	hidden_view.future_board = [3, 4, 5]
	oracle = Advisor.new(hidden_view, 400, false)
	while not oracle.is_done(): oracle.step(32)
	verify(oracle.result() == nuts, "advice oracle independent of hidden cards")
	var edge = nuts.duplicate(true)
	edge.cost = 10
	edge.call_ev = -0.01
	edge.ev_error = 0.5
	verify(Practice.feedback(river_view, edge, "fold", 0) == "边缘决策" and Practice.feedback(river_view, edge, "call", 0) == "边缘决策", "close decisions accept competing choices without correctness scores")
	var mixed = nuts.duplicate(true)
	mixed.strategy = {"supported": true, "converged": true, "frequencies": [{"action": "check", "amount": 0, "frequency": 0.4}, {"action": "raise", "amount": nuts.amount, "frequency": 0.6}]}
	verify(Practice.feedback(river_view, mixed, "check", 0) == "参考混合打法", "mixed strategy accepts more than the highest frequency action")
	var store = Store.new(temp.path_join("profile.json"))
	var id = History.hand_id(fixtures[0])
	var m = store.mark(id)
	m.star = true
	m.pending = true
	m.tags = ["跟注犹豫"]
	m.note = "先比较价格"
	verify(store.set_mark(id, m), "notes saved")
	var a = store.add_attempt(id, 0, "翻前入池", "call", 0, "边缘决策")
	store.set_unclear(a, true)
	var loaded = Store.new(temp.path_join("profile.json"))
	verify(loaded.mark(id).note == m.note and loaded.data.attempts[0].unclear, "notes and attempts survive restart")
	verify(loaded.report().positions == 1 and loaded.report().topics["翻前入池"].unclear == 1, "report counts revisited positions and uncertainty")
	var hands = temp.path_join("hands")
	History.save(fixtures[0], "one.json", hands)
	var original_branch = Practice.new(fixtures[0], 0, "original")
	finish(original_branch.game)
	store.save_branch(original_branch.game.completed_record(), id, 0, "original")
	var backup = temp.path_join("backup.json")
	verify(Backup.export_file(backup, store, hands) == "", "backup exports hands and annotations")
	var imported = Store.new(temp.path_join("restored.json"))
	var destination = temp.path_join("restored-hands")
	var result = Backup.import_file(backup, imported, destination)
	verify(not result.has("error") and result.added == 1, "backup restores complete validated records")
	verify(imported.mark(id).note == m.note and imported.data.branches.size() == 1, "backup restores annotations and separate branches")
	result = Backup.import_file(backup, imported, destination)
	verify(not result.has("error") and result.added == 0 and imported.data.attempts.size() == 1, "repeat import is idempotent")
	var corrupt = JSON.parse_string(FileAccess.get_file_as_string(backup))
	corrupt.hands[0].deck[0] = corrupt.hands[0].deck[1]
	var f = FileAccess.open(temp.path_join("bad.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(corrupt))
	f.close()
	var before = JSON.stringify(imported.data)
	verify(Backup.import_file(temp.path_join("bad.json"), imported, destination).has("error") and JSON.stringify(imported.data) == before, "corrupt import rejected before mutation")

	# Grades, wrong-answer review and automatic selection are derived from attempts only.
	verify(Store.grade("与建议一致") == "good" and Store.grade("参考混合打法") == "good" and Store.grade("边缘决策") == "ok" and Store.grade("同类打法，金额不同") == "ok" and Store.grade("不同选择") == "miss" and Store.grade("未覆盖此尺度") == "unscored", "coach labels collapse to three grades plus unscored")
	verify(Store.topic_name("加注尺度") == "主动下注" and Store.topic_name("跟注犹豫") == "面对下注" and Store.topic_name("诈唬判断") == "河牌判断" and Store.topic_name("翻前入池") == "翻前入池", "old topic names map to the four practice topics")
	var review = Store.new("")
	review.data.attempts = [
		{"id": "1", "hand": "H1", "point": 3, "topic": "面对下注", "action": "call", "amount": 0, "feedback": "不同选择", "date": "2026-10-30T10:00:00", "unclear": false},
		{"id": "2", "hand": "H2", "point": 4, "topic": "加注尺度", "action": "check", "amount": 0, "feedback": "不同选择", "date": "2026-10-30T10:00:00", "unclear": false},
		{"id": "3", "hand": "H2", "point": 4, "topic": "主动下注", "action": "raise", "amount": 30, "feedback": "与建议一致", "date": "2026-10-31T09:00:00", "unclear": false},
		{"id": "4", "hand": "H3", "point": 5, "topic": "河牌判断", "action": "call", "amount": 0, "feedback": "不同选择", "date": "2026-10-29T10:00:00", "unclear": false},
		{"id": "5", "hand": "H3", "point": 5, "topic": "河牌判断", "action": "fold", "amount": 0, "feedback": "与建议一致", "date": "2026-10-30T10:00:00", "unclear": false},
		{"id": "6", "hand": "H3", "point": 5, "topic": "河牌判断", "action": "fold", "amount": 0, "feedback": "与建议一致", "date": "2026-10-31T10:00:00", "unclear": false},
		{"id": "7", "hand": "H4", "point": 2, "topic": "翻前入池", "action": "call", "amount": 0, "feedback": "边缘决策", "date": "2026-10-31T10:00:00", "unclear": false}]
	verify(review.review_due("2026-10-31") == ["H1:3"], "a miss is due; one same-day fix waits; two clean answers retire it")
	verify(review.review_due("2026-11-01") == ["H1:3", "H2:4"], "a single fix comes back on a later day")
	var mastery = review.mastery()
	verify(mastery["主动下注"].attempts == 2 and is_equal_approx(mastery["主动下注"].rate, 0.5) and is_equal_approx(mastery["河牌判断"].rate, 2.0 / 3.0) and mastery["翻前入池"].rate == 1.0, "mastery merges old topic names and counts misses only")
	var pool: Array = []
	for r in fixtures:
		for p in Practice.points(History.replay(r)): pool.append({"record": r, "point": p.point, "topic": p.topic})
	var due_hand = History.hand_id(pool[0].record)
	review.data.attempts.append({"id": "8", "hand": due_hand, "point": int(pool[0].point), "topic": pool[0].topic, "action": "call", "amount": 0, "feedback": "不同选择", "date": "2026-10-28T10:00:00", "unclear": false})
	var picked: Array = review.pick(pool, "", 5, "2026-10-31")
	verify(picked.size() == 5 and History.hand_id(picked[0].record) == due_hand and int(picked[0].point) == int(pool[0].point), "due reviews lead the set")
	var keys = {}
	for c in picked: keys[History.hand_id(c.record) + ":" + str(c.point)] = true
	verify(keys.size() == 5, "a set never repeats a position")
	var river_only: Array = review.pick(pool, "河牌判断", 5, "2026-10-31")
	verify(not river_only.is_empty() and river_only.all(func(c): return Store.topic_name(c.topic) == "河牌判断"), "a topic narrows the automatic set")

	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	ui.smoke_mode = true
	root.size = Vector2i(360, 640)
	await settle()
	ui.training.store = Store.new("")
	ui.training.history_directory = hands
	ui.review.training_store = ui.training.store
	ui._open_training()
	while ui.training.hub.scan_cursor >= 0: await process_frame
	verify(ui.modals.top() == ui.training and not ui.training.hub.start_button.disabled and ui.training.hub.start_button.text == "开始练习", "training opens on a single start button")
	verify(ui.training.hub.topic_rows.get_child_count() == 4, "home lists the four topics")
	var t = ui.training
	t.hub.start_button.pressed.emit()
	await settle()
	verify(t.case_page.queue.size() == 5 and t.case_page.game.actor == 0 and t.case_page.answer.is_empty() and not t.case_page.result_card.visible and not t.case_page.sizing.visible, "a set opens on the first spot with only the actions showing")
	verify(t.case_page.situation.text.contains("人桌") and t.case_page.prompt.text.contains("1/5"), "spot shows progress and a situation line")
	if t.case_page.game.legal_actions(0).get("raise", false):
		t.case_page.raise.pressed.emit()
		verify(t.case_page.sizing.visible and t.case_page.answer.is_empty() and t.case_page.raise.text.begins_with("确认加到"), "first raise press opens sizing without answering")
		t.case_page.sizing_open = false
		t.case_page._render_case()
	var record_before = JSON.stringify(t.case_page.current.record)
	t.case_page.submit("check_call")
	while t.case_page.job != null: await process_frame
	verify(t.case_page.answer.has("attempt") and t.case_page.result_card.visible and not t.case_page.detail.text.is_empty() and t.case_page.next_button.visible, "answer shows a graded result card and the next button")
	verify(["✓", "≈", "✗", "·"].any(func(mark): return t.case_page.grade_label.text.begins_with(mark)) and t.case_page.compare_label.text.contains("建议"), "result card grades the answer and names the recommendation")
	verify(t.case_page.results.size() == 1 and t.store.data.attempts.size() == 1, "answers are recorded once")
	t.case_page.begin_branch()
	while t.case_page.builder != null: await process_frame
	verify(t.case_page.playing and t.case_page.game.phase != "idle" and not t.case_page.result_card.visible, "playing the hand out hides the result card")
	t.back_action()
	while t.hub.scan_cursor >= 0: await process_frame
	verify(t.hub.start_button.text == "继续练习", "an unfinished set turns the start button into resume")
	t.hub.start_button.pressed.emit()
	await settle()
	verify(t.case_page.playing and t.store.data.attempts.size() == 1 and t.case_page.results.size() == 1, "unfinished branch resumes without duplicate attempt")
	var max_steps = 0
	verify(t.case_page.branch_paused, "restored branch waits for explicit resume")
	t.case_page.branch_paused = false
	t.speed = 0.0
	while t.case_page.game.phase != "complete" and max_steps < 2000:
		if t.case_page.game.actor == 0: t.case_page.submit("check_call")
		await process_frame
		max_steps += 1
	verify(t.case_page.game.phase == "complete" and not t.case_page.branch_id.is_empty(), "branch completes and is saved separately")
	verify(JSON.stringify(t.case_page.current.record) == record_before and History.files(hands).size() == 1, "branch never enters ordinary hand history")
	verify(not History.replay(t.store.data.branches[t.case_page.branch_id].record).has("error"), "saved UI branch passes full validation")
	verify(t.store.data.branches[t.case_page.branch_id].mode == "sampled", "playing out always resamples unknown cards")
	t._review_branch(t.case_page.branch_id)
	verify(ui.review.visible and ui.review.analysis_view.comparisons.size() == 2 and ui.review.analysis_view.comparison_index == 1, "saved branch and source are linked for comparison")
	ui.review.comparison_button.pressed.emit()
	verify(ui.review.analysis_view.comparison_index == 0 and ui.review.current_record == t.case_page.current.record, "comparison switches to immutable original")
	ui.review.close()
	while t.case_page.job != null: await process_frame
	t.case_page.next_case()
	verify(t.case_page.cursor == 1 and t.case_page.answer.is_empty(), "set advances without exposing the next answer")
	for i in range(4):
		t.case_page.submit("check_call")
		while t.case_page.job != null: await process_frame
		t.case_page.next_case()
	while t.hub.scan_cursor >= 0: await process_frame
	verify(not t.case_page.visible and t.hub.summary_box.get_child_count() == 7 and t.hub.start_button.text == "再来一组" and t.store.data.session.is_empty(), "finishing a set shows its summary on the home page")
	t.hub.show_records()
	verify(t.hub.records_page.visible and t.hub.records_list.get_child_count() >= 6, "practice history lists answered spots by date")
	t.back_action()
	verify(t.hub.home_page.visible and t.visible, "back from history returns to the training home")
	t.back_action()
	verify(not t.visible, "training closes back to existing screen")
	ui._open_history()
	ui.review.open_replay(History.replay(fixtures[0]), true)
	ui.review.next_decision()
	verify(not ui.review.practice_button.disabled and ui.review.points_picker.item_count > 1, "review exposes playable decision and key navigation")
	ui.review.notes.edit(t.store, id)
	ui.review.notes.note.text = "标记测试"
	ui.review.notes.starred.button_pressed = true
	ui.review.notes._save()
	verify(t.store.mark(id).star and t.store.mark(id).note == "标记测试", "notes editor writes independent metadata")
	ui.review.close()
	ui._start_table(2)
	ui.prefs.coach_after = true
	ui.prefs.confirm_all_in = false
	var live_before = Advisor.information(ui.game.view_for(0))
	ui._human_action("check_call")
	verify(ui.review.visible and ui.review.live_mode and Advisor.information(ui.review.frames[0].view) == live_before, "after-action coach explains prior information while table is paused")
	var stopped = ui.game.record_state()
	ui._bot_step()
	verify(ui.game.record_state() == stopped, "after-action coaching blocks bots")
	ui.queue_free()
	await settle()
	# Only known test-owned files and directories, created under this unique fixture root.
	for directory in [hands, destination]:
		for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
		DirAccess.remove_absolute(directory)
	for filename in DirAccess.get_files_at(temp): DirAccess.remove_absolute(temp.path_join(filename))
	DirAccess.remove_absolute(temp)
	print("TRAINING_TESTS: %d scenarios, %d checks, %d failures" % [cases, checks, failures])
	quit(1 if failures else 0)
