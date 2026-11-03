extends Node
## Independent evaluation arena. No ordinary hand history or human rating.
signal changed
const Table = preload("res://scripts/poker/table.gd")
const History = preload("res://scripts/poker/history.gd")
const Bot = preload("res://scripts/poker/local_bot.gd")
const VERSION = "arena-1.11-v1"
var path = "user://ai/arena.json"
var data: Dictionary = {}
var game
var bots: Array = []
var running = false
var status = "尚未评测"
var subject = 0
var voluntary = false
var raised = false
var post_bets = 0
var post_calls = 0
var plan: Array = []

static func schedule(blocks: int, counts: Array = [2, 4, 6], depths: Array = [50, 100, 200]) -> Array:
	var out: Array = []
	for block in range(blocks):
		for depth in depths:
			for count in counts:
				for rotation in range(count): out.append({"block": block, "depth": depth, "count": count, "rotation": rotation, "group": "%d人/%dBB" % [count, depth]})
	return out

func start(params: Dictionary) -> void:
	pause()
	var clean = {"level": clampi(int(params.get("level", 1)), 0, 2), "style": clampi(int(params.get("style", 0)), 0, 2), "blocks": clampi(int(params.get("blocks", 16)), 2, 1024), "seed": int(params.get("seed", 11102601)), "counts": params.get("counts", [2, 4, 6]), "depths": params.get("depths", [50, 100, 200])}
	if not clean.counts is Array or not clean.depths is Array or not clean.counts.all(func(n): return n in [2, 4, 6]) or not clean.depths.all(func(n): return n in [50, 100, 200]):
		status = "评测配置无效"; changed.emit(); return
	data = {"schema": VERSION, "params": clean, "cursor": 0, "results": {}, "behavior": {}, "latencies": [], "decisions": 0, "valid_decisions": 0}
	plan = schedule(clean.blocks, clean.counts, clean.depths)
	game = null
	resume()

func resume() -> void:
	if data.is_empty(): return
	running = true
	status = "评测进行中"
	changed.emit()

func pause() -> void:
	running = false
	if not data.is_empty():
		status = "已暂停 · 可继续"
		_save()
	changed.emit()

func _save() -> void:
	if path.is_empty() or data.is_empty(): return
	data.erase("hand")
	if game != null and game.phase != "complete":
		data["hand"] = {"record": game.record_state(), "rng": bots.map(func(b): return str(b.rng.state)), "subject": subject, "vpip": voluntary, "pfr": raised, "bets": post_bets, "calls": post_calls}
	if History.save(data, path.get_file(), path.get_base_dir()) != OK:
		running = false
		status = "评测保存失败，当前结果保留在内存中。"

func load_saved() -> bool:
	if not FileAccess.file_exists(path): return false
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 16 * 1024 * 1024: return false
	var parser = JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary: return false
	var saved: Dictionary = parser.data
	if saved.get("schema") != VERSION or not saved.get("params") is Dictionary: return false
	var p: Dictionary = saved.params
	if p.get("online", false) != false: return false
	if not History._integer(p.get("blocks"), 2, 1024) or not p.get("counts") is Array or not p.get("depths") is Array: return false
	if not p.counts.all(func(n): return History._integer(n, 2, 6) and int(n) in [2, 4, 6]) or not p.depths.all(func(n): return History._integer(n, 50, 200) and int(n) in [50, 100, 200]): return false
	if p.counts.is_empty() or p.counts.size() > 3 or p.depths.is_empty() or p.depths.size() > 3: return false
	if p.counts.any(func(n): return p.counts.count(n) != 1) or p.depths.any(func(n): return p.depths.count(n) != 1): return false
	p.counts = p.counts.map(func(n): return int(n))
	p.depths = p.depths.map(func(n): return int(n))
	if not History._integer(p.get("level"), 0, 2) or not History._integer(p.get("style"), 0, 2) or not History._integer(p.get("seed"), 0, 1000000000): return false
	if not saved.get("results") is Dictionary or not saved.get("behavior") is Dictionary or not saved.get("latencies") is Array: return false
	plan = schedule(int(p.blocks), p.counts, p.depths)
	if not History._integer(saved.get("cursor"), 0, plan.size()): return false
	for field in ["decisions", "valid_decisions"]:
		if not History._integer(saved.get(field), 0, 1000000000): return false
		saved[field] = int(saved[field])
	saved.cursor = int(saved.cursor)
	if saved.latencies.size() > 2000000 or not saved.latencies.all(func(n): return History._integer(n, 0, 3600000)): return false
	if saved.valid_decisions > saved.decisions: return false
	var complete_hands = 0
	for group in saved.results:
		if not group is String or not saved.results[group] is Dictionary or not saved.behavior.get(group) is Dictionary: return false
		var group_tasks = plan.filter(func(t): return t.group == group)
		if group_tasks.is_empty(): return false
		var count = int(group_tasks[0].count)
		var depth = int(group_tasks[0].depth)
		var group_hands = 0
		for block in saved.results[group]:
			if not block is String or not block.is_valid_int() or int(block) < 0 or int(block) >= p.blocks: return false
			var b = saved.results[group][block]
			if not b is Dictionary or not History._integer(b.get("hands"), 1, count): return false
			b.hands = int(b.hands)
			if not (b.get("net") is float or b.get("net") is int) or not is_finite(float(b.net)) or absf(b.net) > depth * count * b.hands: return false
			group_hands += int(b.hands)
		var behavior: Dictionary = saved.behavior[group]
		for field in ["hands", "vpip", "pfr", "bets", "calls"]:
			if not History._integer(behavior.get(field), 0, group_tasks.size() * 500): return false
			behavior[field] = int(behavior[field])
		if behavior.hands != group_hands or behavior.pfr > behavior.vpip or behavior.vpip > group_hands: return false
		complete_hands += group_hands
	if complete_hands != saved.cursor or saved.behavior.size() != saved.results.size(): return false
	for field in ["online", "model", "endpoint"]: p.erase(field)
	for field in ["requests", "errors", "tokens", "usage_reports"]: saved.erase(field)
	data = saved
	game = null
	if data.has("hand"):
		if data.cursor >= plan.size(): data = {}; return false
		if not data.hand is Dictionary or not data.hand.get("record") is Dictionary: data = {}; return false
		var rebuilt = History.replay(data.hand.record, false)
		if rebuilt.has("error"): data = {}; return false
		_build_game()
		if data.hand.get("subject") != subject or rebuilt.game.seats.size() != game.seats.size(): data = {}; return false
		game = rebuilt.game
		if not data.hand.get("rng") is Array or data.hand.rng.size() != bots.size(): data = {}; return false
		if not data.hand.rng.all(func(n): return n is String and n.is_valid_int()): data = {}; return false
		for i in range(bots.size()): bots[i].rng.state = int(data.hand.rng[i])
		voluntary = data.hand.get("vpip", false) == true
		raised = data.hand.get("pfr", false) == true
		post_bets = int(data.hand.get("bets", 0))
		post_calls = int(data.hand.get("calls", 0))
	status = "已恢复上次评测 · 点击继续"
	changed.emit()
	return true

func _build_game() -> void:
	var task: Dictionary = plan[int(data.cursor)]
	subject = int(task.rotation)
	var seed_value = int(data.params.seed) + int(task.block) * 7919 + int(task.count) * 101 + int(task.depth)
	var stacks: Array = []
	stacks.resize(int(task.count)); stacks.fill(int(task.depth) * 10)
	game = Table.new(stacks, 5, 10, seed_value)
	game.start_hand(0)
	bots.clear()
	for id in range(int(task.count)):
		bots.append(Bot.new(seed_value * 37 + id * 379 + subject * 173, int(data.params.style) if id == subject else 0, int(data.params.level) if id == subject else 1))
	voluntary = false; raised = false; post_bets = 0; post_calls = 0

func _process(_delta: float) -> void:
	if running: tick()

func tick() -> void:
	if not running: return
	if data.cursor >= plan.size():
		running = false; status = "本组评测已完成"; _save(); changed.emit(); return
	if game == null: _build_game()
	if game.phase == "complete": _finish_hand(); return
	if game.events.size() > 500: pause(); status = "行动数异常，评测暂停"; changed.emit(); return
	var start_ms = Time.get_ticks_msec()
	var move = bots[game.actor].choose(game.view_for(game.actor))
	if game.actor == subject:
		data.decisions += 1; data.valid_decisions += 1
		data.latencies.append(Time.get_ticks_msec() - start_ms)
	_apply(move)

func _apply(move: Dictionary) -> void:
	if game.actor == subject:
		if game.phase == "preflop":
			voluntary = voluntary or move.action in ["call", "raise", "all_in"]
			raised = raised or move.action == "raise" or (move.action == "all_in" and game.legal_actions(subject).raise)
		else:
			post_bets += int(move.action == "raise")
			post_calls += int(move.action == "call")
	var error = game.act(game.actor, move.action, int(move.get("amount", 0)))
	if error != "": pause(); status = "规则校验失败：" + error; changed.emit()

func _finish_hand() -> void:
	var task: Dictionary = plan[int(data.cursor)]
	if game.chip_total() != int(task.count * task.depth * 10): pause(); status = "筹码校验失败"; return
	if not data.results.has(task.group): data.results[task.group] = {}
	var block_key = str(task.block)
	if not data.results[task.group].has(block_key): data.results[task.group][block_key] = {"net": 0.0, "hands": 0}
	var block: Dictionary = data.results[task.group][block_key]
	block.net += (game.seats[subject].stack - task.depth * 10) / 10.0
	block.hands += 1
	if not data.behavior.has(task.group): data.behavior[task.group] = {"hands": 0, "vpip": 0, "pfr": 0, "bets": 0, "calls": 0}
	var b: Dictionary = data.behavior[task.group]
	b.hands += 1; b.vpip += int(voluntary); b.pfr += int(raised); b.bets += post_bets; b.calls += post_calls
	data.cursor += 1
	game = null
	_save()
	changed.emit()

func report() -> Dictionary:
	var out = {"schema": VERSION, "groups": {}, "completed": false}
	if data.is_empty(): return out
	out["params"] = data.params.duplicate(true)
	out["baseline_version"] = Bot.VERSION
	out["block_returns"] = data.results.duplicate(true)
	out["completed"] = data.cursor == plan.size()
	for group in data.results:
		var values: Array = []
		var count = int(str(group).split("人")[0])
		for b in data.results[group].values():
			# Only complete seat rotations enter the confidence calculation.
			if b.hands == count: values.append(100.0 * b.net / b.hands)
		var mean = 0.0
		for value in values: mean += value / values.size()
		var variance = 0.0
		for value in values: variance += pow(value - mean, 2) / maxi(1, values.size() - 1)
		var n = values.size()
		var critical = 12.706 if n == 2 else 4.303 if n < 4 else 3.182 if n < 8 else 2.365 if n < 16 else 2.131 if n < 32 else 2.04 if n < 64 else 2.0
		var half = critical * sqrt(variance / maxi(1, n))
		out.groups[group] = {"blocks": n, "bb100": mean, "interval_available": n >= 2, "low": mean - half, "high": mean + half, "behavior": data.behavior[group].duplicate(true)}
	for key in ["decisions", "valid_decisions"]: out[key] = data[key]
	var times: Array = data.latencies.duplicate(); times.sort()
	out["latency_p50_ms"] = times[int(times.size() * 0.5)] if not times.is_empty() else 0
	out["latency_p95_ms"] = times[mini(times.size() - 1, int(times.size() * 0.95))] if not times.is_empty() else 0
	return out
