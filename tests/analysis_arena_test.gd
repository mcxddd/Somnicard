extends SceneTree
const Practice = preload("res://scripts/poker/practice.gd")
const History = preload("res://scripts/poker/history.gd")
const Advisor = preload("res://scripts/poker/advisor.gd")
const Store = preload("res://scripts/poker/training_store.gd")
var checks = 0
var failures = 0
func _initialize() -> void: call_deferred("run")
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)
func run() -> void:
	var record = Practice.fixtures()[0]
	var rebuilt = History.replay(record)
	var point = Practice.points(rebuilt)[0]
	var view = point.view.duplicate(true)
	var job = Advisor.new(view, 80, false)
	while not job.is_done(): job.step(64)
	var analysis = job.result()
	verify(not analysis.has("error"), "fixture local analysis ready")
	var store = Store.new("")
	store.suggest_hand(record)
	verify(store.suggested_decisions().size() <= 3 and store.suggested_decisions().size() > 0, "finished hand yields a bounded review list")
	verify(store.suggested_decisions().all(func(d): return not d.scored and d.verdict == "待讨论"), "structural review points are never called mistakes")
	verify(Store.valid(store.data), "learning records pass backup validation")
	# Fine analysis may yield before convergence and resume the same numerical state.
	var river_view: Dictionary = {}
	for fixture in Practice.fixtures():
		for p in Practice.points(History.replay(fixture)):
			if p.view.phase == "river" and p.view.seats.filter(func(s): return s.in_hand and not s.folded).size() == 2:
				river_view = p.view
	if not river_view.is_empty():
		var bounded = Advisor.new(river_view, 16, true, 1)
		bounded.solver_budget_ms = 1
		while not bounded.is_done(): bounded.step(64)
		verify(bounded.solver_timed_out and not bounded.result().strategy.get("converged", false), "time limit never certifies an unfinished solver")
		var old_solver = bounded.solver
		bounded.solver_timed_out = false
		bounded.solver_started_ms = Time.get_ticks_msec()
		bounded.step(64)
		verify(bounded.solver == old_solver, "continuation retains range samples and regret state")
	else: verify(false, "river fixture exists for compute budget test")
	var Arena = preload("res://scripts/poker/arena.gd")
	var arena = Arena.new()
	arena.path = "user://arena-local-111-test.json"
	root.add_child(arena)
	arena.start({"blocks": 2, "counts": [2], "depths": [50]})
	for i in range(6): arena.tick()
	arena.pause()
	var restored = Arena.new()
	restored.path = arena.path
	root.add_child(restored)
	verify(restored.load_saved(), "local arena restores full game and RNG checkpoint")
	arena.path = ""
	for runner in [arena, restored]:
		runner.resume()
		for i in range(500):
			if not runner.running: break
			runner.tick()
	verify(arena.report().completed and restored.report().completed, "both local evaluations finish")
	verify(arena.report().block_returns == restored.report().block_returns and arena.data.behavior == restored.data.behavior, "resume preserves deterministic results and behavioral counts")
	var damaged: Dictionary = restored.data.duplicate(true)
	damaged.results[damaged.results.keys()[0]] = {"0": {"net": "invalid", "hands": 2}}
	History.save(damaged, restored.path.get_file(), restored.path.get_base_dir())
	verify(not restored.load_saved(), "malformed aggregate rejected before rendering a report")
	DirAccess.remove_absolute(restored.path)
	arena.queue_free()
	restored.queue_free()
	await process_frame
	print("ANALYSIS_ARENA_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
