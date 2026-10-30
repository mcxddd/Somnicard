extends SceneTree
const Services = preload("res://scripts/ai/services.gd")
const Vault = preload("res://scripts/ai/vault.gd")
const Config = preload("res://scripts/ai/config.gd")
const Coach = preload("res://scripts/ai/coach_protocol.gd")
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
	var profiles = Services.normalize([{ "id": "other", "label": "不同模型", "service": {"endpoint": "https://b.example/v1", "model": "model-b"}, "remember": true, "key": "NEVER_SERIALIZE"}], {"endpoint": "https://a.example/v1", "model": "model-a"})
	verify(profiles.size() == 2 and profiles[0].id == "default", "legacy settings migrate with default profile")
	verify(not JSON.stringify(profiles).contains("NEVER_SERIALIZE"), "public profiles strip credentials")
	verify(Services.resolve(profiles, "other").model == "model-b", "seat resolves its independent model")
	verify(Config.validate(Services.resolve(profiles, "deleted")) != "", "missing profile cannot silently use another provider")
	var path = "user://ai/test-vault-111.bin"
	if OS.get_name() == "Windows":
		verify(Vault.save(profiles, {"other": "test-only-secret-111"}, path).is_empty(), "DPAPI encrypt succeeds")
		verify(FileAccess.file_exists(path), "encrypted payload persists")
		verify(not FileAccess.get_file_as_bytes(path).get_string_from_ascii().contains("test-only-secret-111"), "disk contains no plaintext key")
		verify(Vault.load_keys(profiles, path).get("other") == "test-only-secret-111", "DPAPI decrypt restores current-user secret")
		var changed = profiles.duplicate(true)
		changed[1].service.endpoint = "https://c.example/v1"
		verify(not Vault.load_keys(changed, path).has("other"), "old key never follows changed endpoint")
		var file = FileAccess.open(path, FileAccess.READ_WRITE)
		file.seek(20)
		file.store_8(255)
		file.close()
		verify(Vault.load_keys(profiles, path).is_empty(), "tampered ciphertext fails closed")
		verify(Vault.save([], {}, path).is_empty() and not FileAccess.file_exists(path), "forget removes encrypted file")
	var record = Practice.fixtures()[0]
	var rebuilt = History.replay(record)
	var point = Practice.points(rebuilt)[0]
	var view = point.view.duplicate(true)
	var job = Advisor.new(view, 80, false)
	while not job.is_done(): job.step(64)
	var analysis = job.result()
	verify(not analysis.has("error"), "fixture local analysis ready")
	var original = Coach.context(view, analysis)
	view["future_board"] = [40, 41, 42]
	view["deck"] = range(52)
	view["memories"] = {"private": "DO_NOT_SEND"}
	view["result"] = {"winners": [1]}
	for id in range(1, view.seats.size()): view.seats[id].hole = [40, 41]
	verify(Coach.context(view, analysis) == original, "coach payload invariant to future, opponent cards and memories")
	var answer = {"action": analysis.action, "reason": "当前价格与手牌权益需要一起比较。", "alternative": "加注会让继续的范围更强，需要谨慎。", "next": "观察对手后续下注，再重新判断。"}
	verify(not Coach.parse(JSON.stringify(answer), analysis.action).has("error"), "grounded structured explanation accepted")
	answer.reason = "你的胜率是99%"
	verify(Coach.parse(JSON.stringify(answer), analysis.action).has("error"), "invented numeric claim rejected")
	answer.reason = "可以继续观察。"
	answer.action = "not-the-local-recommendation"
	verify(Coach.parse(JSON.stringify(answer), analysis.action).has("error"), "contradictory recommendation rejected")
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
	var ui = preload("res://scripts/ui/ai_coach.gd").new()
	root.add_child(ui)
	ui.configure({"ai_review_coach": true, "ai_profiles": profiles})
	ui.sync(point.view, analysis, false, "hand:step1")
	ui.dialogue.append({"question": "previous", "answer": {}})
	ui.sync(point.view, analysis, false, "hand:step2")
	verify(ui.dialogue.is_empty(), "changing steps clears dialogue despite identical visible cards")
	ui.configure({"ai_review_coach": false})
	ui.sync(point.view, analysis, false, "hand:step2")
	verify(not ui.visible, "coach toggle prevents questions")
	ui.queue_free()
	var Arena = preload("res://scripts/ai/arena.gd")
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
	print("VERSION111_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
