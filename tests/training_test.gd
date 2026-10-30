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

	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	ui.smoke_mode = true
	root.size = Vector2i(360, 640)
	await settle()
	ui.training.store = Store.new("")
	ui.training.history_directory = hands
	ui.review.training_store = ui.training.store
	ui._open_training()
	while ui.training.scan_cursor >= 0: await process_frame
	verify(ui._top_modal() == ui.training and not ui.training.start_button.disabled, "training is an independent modal")
	var t = ui.training
	t.source_picker.select(4)
	t.start_set()
	await settle()
	verify(t.queue.size() == 5 and t.game.actor == 0 and t.answer.is_empty() and not t.answer_area.visible, "five-case set hides answers and future result")
	var record_before = JSON.stringify(t.current.record)
	t.submit("check_call")
	while t.job != null: await process_frame
	verify(t.answer.has("attempt") and t.answer_area.visible and not t.detail.text.is_empty(), "answer submission unlocks feedback")
	verify(t.summary.text.contains("经验建议") or t.summary.text.contains("参考") or t.summary.text.contains("边缘判断"), "feedback identifies reliability")
	t.unclear.button_pressed = true
	verify(t.store.mark(History.hand_id(t.current.record)).pending, "unclear answer becomes pending review")
	t.begin_branch()
	while t.builder != null: await process_frame
	verify(t.playing and t.game.phase != "idle", "answer starts playable isolated branch")
	var session = t.store.data.session.duplicate(true)
	t.back_action()
	while t.scan_cursor >= 0: await process_frame
	t.resume_set()
	await settle()
	verify(t.playing and t.store.data.attempts.size() == 1, "unfinished branch resumes without duplicate attempt")
	var max_steps = 0
	verify(t.branch_paused, "restored branch waits for explicit resume")
	t.branch_paused = false
	t.speed = 0.0
	while t.game.phase != "complete" and max_steps < 2000:
		if t.game.actor == 0: t.submit("check_call")
		await process_frame
		max_steps += 1
	verify(t.game.phase == "complete" and not t.branch_id.is_empty(), "branch completes and is saved separately")
	verify(JSON.stringify(t.current.record) == record_before and History.files(hands).size() == 1, "branch never enters ordinary hand history")
	verify(not History.replay(t.store.data.branches[t.branch_id].record).has("error"), "saved UI branch passes full validation")
	t._review_branch(t.branch_id)
	verify(ui.review.visible and ui.review.comparisons.size() == 2 and ui.review.comparison_index == 1, "saved branch and source are linked for comparison")
	ui.review.comparison_button.pressed.emit()
	verify(ui.review.comparison_index == 0 and ui.review.current_record == t.current.record, "comparison switches to immutable original")
	ui.review.close()
	while t.job != null: await process_frame
	t.next_case()
	verify(t.cursor == 1 and t.answer.is_empty(), "lesson advances without exposing next answer")
	t.back_action()
	while t.scan_cursor >= 0: await process_frame
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
	ui.coach_after = true
	ui.confirm_all_in = false
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
