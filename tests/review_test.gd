extends SceneTree
const Table = preload("res://scripts/poker/table.gd")
const History = preload("res://scripts/poker/history.gd")
const Advisor = preload("res://scripts/poker/advisor.gd")
const Fast = preload("res://scripts/poker/fast_rank.gd")
const Eval = preload("res://scripts/poker/evaluator.gd")
const Session = preload("res://scripts/poker/session.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("_run")

func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func finish(game) -> void:
	var guard = 0
	while game.phase != "complete" and guard < 200:
		var legal = game.legal_actions(game.actor)
		game.act(game.actor, "check" if legal.check else "call")
		guard += 1
	verify(game.phase == "complete", "bounded completed fixture")

func calculate(view: Dictionary, count: int = 1600) -> Dictionary:
	var job = Advisor.new(view, count)
	while not job.is_done(): job.step(count)
	return job.result()

func _run() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 49822
	for i in range(4500):
		var deck = range(52)
		for j in range(7):
			var other = rng.randi_range(j, 51)
			var card = deck[j]
			deck[j] = deck[other]
			deck[other] = card
		var cards = deck.slice(0, 5 + i % 3)
		verify(Fast.score(cards) == Eval.evaluate(cards).score, "fast rank agrees with independent combinations %d" % i)
	for cards in [[12, 0, 1, 2, 3, 26, 27], [12, 25, 38, 11, 24, 37, 0], [8, 9, 10, 11, 12, 25, 38], [12, 25, 38, 51, 11, 24, 37]]:
		verify(Fast.score(cards) == Eval.evaluate(cards).score, "wheel, double trips, royal and quads")
	var fixture
	for count in range(2, 10):
		for run in range(3):
			var stacks = []
			stacks.resize(count)
			stacks.fill(1000)
			var game = Table.new(stacks, 5, 10, count * 20 + run)
			game.start_hand(0)
			if run == 1: game.act(game.actor, "all_in")
			if run == 2: game.act(game.actor, "fold")
			finish(game)
			var record = JSON.parse_string(JSON.stringify(game.completed_record()))
			var rebuilt = History.replay(record)
			verify(not rebuilt.has("error"), "replay old schema / JSON / %d players" % count)
			if rebuilt.has("error"): continue
			fixture = rebuilt
			verify(rebuilt.final.result == game.result, "identical settlement")
			var previous_count = 0
			var streets = []
			for frame in rebuilt.frames:
				var view = frame.view
				verify(view.events.size() >= previous_count, "chronological prefix only")
				previous_count = view.events.size()
				if view.phase != "complete":
					verify(view.result.is_empty(), "no future result")
					for seat in view.seats:
						if seat.id != 0: verify(seat.hole.is_empty(), "no opponent cards before showdown")
				verify(not view.has("deck"), "no saved deck in snapshots")
				if frame.event.kind == "street": streets.append(view.phase)
				if frame.decision:
					verify(view.actor == frame.event.seat, "decision is before action")
					if view.actor == 0: verify(not view.legal.is_empty(), "hero legal actions present")
			if run == 1: verify(streets == ["flop", "turn", "river"], "all-in runout has each street")
	var record: Dictionary = fixture.record
	for bad in [{}, {"schema_version": 99}, {"schema_version": 1, "starting_stacks": "oops"}]:
		verify(History.replay(bad).has("error"), "reject malformed history")
	for key in ["button", "deck", "starting_stacks", "events", "result", "big_blind", "hand"]:
		var bad = record.duplicate(true)
		bad[key] = null
		verify(History.replay(bad).has("error"), "reject invalid field " + key)
	var bad = record.duplicate(true)
	bad.deck[1] = bad.deck[0]
	verify(History.replay(bad).has("error"), "duplicate deck rejected")
	bad = record.duplicate(true)
	bad.events[0].hand = 888
	verify(History.replay(bad).has("error"), "event tampering rejected")
	var test_dir = "user://review-test-%d" % Time.get_ticks_usec()
	verify(History.save(record, "one.json", test_dir) == OK, "atomic history save")
	verify(History.files(test_dir) == ["one.json"], "only complete JSON listed")
	verify(not History.replay(History.read_record(test_dir.path_join("one.json")).record).has("error"), "disk roundtrip")
	verify(History.save(record, "../escape.json", test_dir) == ERR_INVALID_PARAMETER, "filename stays inside history")
	var broken = FileAccess.open(test_dir.path_join("broken.json"), FileAccess.WRITE)
	broken.store_string("{broken")
	broken.close()
	verify(History.read_record(test_dir.path_join("broken.json")).has("error"), "bad JSON safe error")
	for file in DirAccess.get_files_at(test_dir): DirAccess.remove_absolute(test_dir.path_join(file))
	DirAccess.remove_absolute(test_dir)
	var game = Table.new([1000, 1000], 5, 10, 8)
	game.start_hand(0)
	var view = game.view_for(0)
	view.seats[0].hole = [12, 25]
	var started = Time.get_ticks_msec()
	var result = calculate(view, 6000)
	verify(result.equity > 0.80 and result.equity < 0.90, "AA versus random heads-up is approximately 85 percent")
	verify(result.action in ["check", "call", "raise", "fold"] and result.samples == 6000, "valid advice samples")
	var changed = view.duplicate(true)
	changed.seats[1].hole = [11, 24]
	changed["deck"] = range(52)
	changed["result"] = {"future": "hero loses"}
	changed["events"] = [{"future": "royal flush"}]
	verify(Advisor.cache_key(view) == Advisor.cache_key(changed), "hidden and future information excluded from key")
	verify(calculate(view, 300) == calculate(changed, 300), "hidden and future information do not affect estimate")
	var state = Advisor.information(changed)
	verify(not state.has("deck") and not state.seats[1].has("hole") and not state.has("result") and not state.has("events"), "allow-list removes leaked raw fields")
	game = Table.new([1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000], 5, 10, 9)
	game.start_hand(0)
	while game.actor != 0: game.act(game.actor, "call")
	view = game.view_for(0)
	view.board = [8, 9, 10, 11, 12]
	view.phase = "river"
	view.seats[0].hole = [0, 1]
	result = calculate(view, 100)
	verify(is_equal_approx(result.equity, 1.0 / 9) and result.win == 0 and result.tie == 1, "nine-way board royal tie splits equity")
	var full_started = Time.get_ticks_msec()
	calculate(view)
	print("ADVICE_BENCHMARK: HU6000+checks=%d ms; 9-way1600=%d ms" % [full_started - started, Time.get_ticks_msec() - full_started])
	game = Table.new([20, 100, 100], 5, 10, 4)
	game.start_hand(0)
	game.act(0, "call")
	game.act(1, "all_in")
	game.act(2, "call")
	view = game.view_for(0)
	result = calculate(view, 500)
	verify(result.cost == 10 and result.eligible_pot == 60, "short hero cannot count inaccessible side pot")
	verify(is_equal_approx(result.odds, 1.0 / 6), "short hero correct pot odds")
	verify(result.action != "raise", "no illegal raise facing capped call")
	finish(game)
	verify(Advisor.new(game.view_for(0)).result().has("error"), "completed hand cannot be analyzed with exposed cards")
	_session_tests()
	await _ui_tests(fixture)
	print("REVIEW_TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _session_tests() -> void:
	var directory = "user://session-test-%d" % Time.get_ticks_usec()
	var game = Table.new([1000, 1000, 1000, 1000, 1000, 1000], 5, 10, 622)
	game.start_hand(0)
	var moves = 0
	while true:
		verify(Session.save(game, "123456-789", 100, -1, directory) == OK, "session atomic overwrite")
		var loaded = Session.restore(directory.path_join("session.json"))
		verify(not loaded.has("error"), "unfinished session reload: " + str(loaded.get("error", "")))
		if loaded.has("error"): break
		verify(loaded.game.view_for(0) == game.view_for(0), "session restores cards, money, actor and legal choices")
		if game.phase == "complete": break
		verify(History.replay(game.record_state()).has("error"), "unfinished session not listed as a completed hand")
		var legal = game.legal_actions(game.actor)
		var action = "raise" if moves == 0 else "check" if legal.check else "call"
		var amount = 30 if moves == 0 else 0
		game.act(game.actor, action, amount)
		loaded.game.act(loaded.game.actor, action, amount)
		verify(loaded.game.view_for(0) == game.view_for(0), "restored deck continues identically")
		moves += 1
		if moves > 100:
			verify(false, "bounded session fixture")
			break
	Session.save(game, "../bad", 100, -1, directory)
	verify(Session.restore(directory.path_join("session.json")).has("error"), "unsafe session id rejected")
	for file in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)

func _ui_tests(fixture: Dictionary) -> void:
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	ui.smoke_mode = true
	ui._start_table(2)
	var before = JSON.stringify(ui.game.view_for(0))
	ui._open_advice()
	verify(ui.review.visible and ui.bot_timer.is_stopped(), "live advice pauses original table")
	verify(ui.call_button.focus_mode == Control.FOCUS_NONE, "modal traps background focus")
	ui._human_action("fold")
	ui._bot_step()
	verify(JSON.stringify(ui.game.view_for(0)) == before, "modal blocks commands and bot")
	var ticks = 0
	while ui.review.job != null and ticks < 1200:
		await process_frame
		ticks += 1
	verify(not ui.review.analysis.is_empty() and ui.review.job == null, "incremental advice completes")
	var analysis = ui.review.analysis.duplicate(true)
	ui.review.units.item_selected.emit(0)
	verify(not ui.use_bb and not ui.review.use_bb, "units synchronize to main")
	ui.review.units.item_selected.emit(1)
	verify(ui.use_bb and ui.review.analysis == analysis, "unit switch keeps exact equity")
	ui.review.close()
	verify(not ui.review.visible and ui.call_button.focus_mode != Control.FOCUS_NONE, "modal restores controls")
	verify(JSON.stringify(ui.game.view_for(0)) == before, "analysis never changes game")
	ui._open_history()
	ui.review.open_replay(fixture, true)
	ui.review.next_decision()
	verify(ui.review._hero_decision(), "jump to hero decision")
	ui.review._analyze()
	ui.review.seek(ui.review.frames.size() - 1)
	verify(ui.review.job == null and ui.review.analysis.is_empty(), "seek cancels stale analysis")
	verify(ui.review.frames[ui.review.index].view.phase == "complete" and ui.review.details.text.contains("本手净变化"), "settlement summary includes net result")
	ui.review._jump_street(1)
	verify(ui.review.frames[ui.review.index].view.phase == "flop", "street jump")
	ui.review.seek(0)
	ui.review._toggle_play()
	verify(not ui.review.timer.is_stopped(), "playback timer starts")
	ui.review.close()
	verify(ui.review.timer.is_stopped(), "closing stops playback")
	ui._open_lobby()
	ui._open_history()
	ui.review.close()
	verify(ui.lobby.visible and ui.start_button.focus_mode != Control.FOCUS_NONE and ui.call_button.focus_mode == Control.FOCUS_NONE, "nested lobby history restores correct focus scope")
	ui._open_help()
	verify(ui.support_center.visible and ui.support_center.topic == 1 and not ui.review.visible, "table help uses the shared support center")
	ui.support_center._licenses()
	verify(ui.support_center.body.get_child_count() > 10 and ui.support_center.body.get_child(0).text.contains("MIT"), "bundled engine credits available offline")
	ui.support_center.back_action()
	ui.support_center.back_action()
	ui._close_lobby()
	finish(ui.game)
	ui._refresh()
	ui.review_hand_button.pressed.emit()
	verify(ui.review.visible and not ui.review.frames.is_empty(), "direct review of current completed hand")
	ui.queue_free()
	await process_frame
