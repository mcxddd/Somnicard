extends SceneTree
## Reproducible 100 BB cash-game evaluation, no rake. Each deal resets stacks.
## Confidence units are independent DECK BLOCKS, not correlated rotated hands.
const Table = preload("res://scripts/poker/table.gd")
const Bot = preload("res://scripts/poker/local_bot.gd")
const Legacy = preload("res://tools/benchmarks/legacy_bot.gd")
var blocks = 128
var seed_base = 760001
var output = "res://.local/opponent-benchmark.json"
var results: Dictionary = {}
var behavior: Dictionary = {}
var timings: Array = []
var games = 0
var style_mode = false

func _initialize() -> void: call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--styles": style_mode = true
		if arg.begins_with("--blocks="): blocks = maxi(2, int(arg.trim_prefix("--blocks=")))
		if arg.begins_with("--seed="): seed_base = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	var start = Time.get_ticks_msec()
	for block in range(blocks):
		var totals: Dictionary = {}
		if style_mode:
			for rotation in range(9): play([0, 1, 2, 3, 4, 5, 6, 7, 8], rotation, block, "9styles", totals)
		else:
			for pair in [[0, 1], [0, 2], [1, 2], [0, 3], [1, 3], [2, 3]]:
				for rotation in range(2): play(pair, rotation, block, "HU-%d-%d" % [pair[0], pair[1]], totals)
			for lineup in [[0, 1, 2, 0, 1, 2], [0, 1, 2, 0, 1, 2, 0, 1, 2]]:
				for rotation in range(3): play(lineup, rotation, block, "%dmax" % lineup.size(), totals)
		for key in totals:
			if not results.has(key): results[key] = []
			results[key].append(totals[key].net * 100.0 / totals[key].hands)
		if (block + 1) % 8 == 0: print("BENCH_PROGRESS %d/%d games=%d elapsed=%.1fs" % [block + 1, blocks, games, (Time.get_ticks_msec() - start) / 1000.0])
		await process_frame
	var summaries: Dictionary = {}
	for key in results:
		var values: Array = results[key]
		var mean = 0.0
		for value in values: mean += value / values.size()
		var variance = 0.0
		for value in values: variance += pow(value - mean, 2) / (values.size() - 1)
		# Student t approximation (conservative small-block critical values).
		var critical = 4.303 if blocks < 4 else 2.776 if blocks < 8 else 2.365 if blocks < 16 else 2.131 if blocks < 32 else 2.04 if blocks < 64 else 2.0 if blocks < 128 else 1.98
		var half = critical * sqrt(variance / values.size())
		summaries[key] = {"bb_per_100": mean, "ci95_low": mean - half, "ci95_high": mean + half, "blocks": blocks}
	for key in behavior:
		var b = behavior[key]
		b["vpip_pct"] = 100.0 * b.vpip / b.hands
		b["pfr_pct"] = 100.0 * b.pfr / b.hands
		b["postflop_aggression_pct"] = 100.0 * b.bets / maxi(1, b.bets + b.calls)
	timings.sort()
	var report = {"version": Bot.VERSION, "styles": style_mode, "seed": seed_base, "blocks": blocks, "games": games, "stack_bb": 100, "rake": 0,
		"elapsed_seconds": (Time.get_ticks_msec() - start) / 1000.0, "summaries": summaries, "behavior": behavior,
		"policy_ms_p50": timings[timings.size() / 2], "policy_ms_p95": timings[int(timings.size() * 0.95)], "block_bb_per_100": results,
		"style_mapping": "When styles=true: L0..L8 = level*3+style; styles 0 balanced, 1 passive, 2 aggressive. Nine rotations, one of each profile.",
		"scope": "Strength mode: balanced styles only. 0 beginner, 1 standard, 2 advanced, 3 frozen v1.5 standard. HU pairs; 6/9max equal mixes of 0/1/2. Common decks with rotated seats; independent blocks; approximate Student confidence intervals. Not a human rating or GTO exploitability."}
	var f = FileAccess.open(output, FileAccess.WRITE)
	if f == null: printerr("BENCH_WRITE_FAILED"); quit(1); return
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	print("BENCH_COMPLETE " + JSON.stringify(summaries))
	quit()

func play(lineup: Array, rotation: int, block: int, group: String, totals: Dictionary) -> void:
	var count = lineup.size()
	var stacks: Array = []
	stacks.resize(count)
	stacks.fill(1000)
	var game = Table.new(stacks, 5, 10, seed_base + block * 7919 + count * 101)
	var bots: Array = []
	var levels: Array = []
	var voluntary: Array = []
	var raised: Array = []
	for id in range(count):
		var level: int = lineup[(id + rotation) % count]
		levels.append(level)
		var actual_level = int(level / 3) if style_mode else level
		var personality = level % 3 if style_mode else 0
		var bot_seed = seed_base + block * 100003 + id * 379 + rotation * 173 + level * 31
		bots.append(Legacy.new(bot_seed, 0, 1) if not style_mode and level == 3 else Bot.new(bot_seed, personality, actual_level))
		voluntary.append(false)
		raised.append(false)
	game.start_hand(0)
	var moves = 0
	while game.phase != "complete" and moves < 300:
		var actor: int = game.actor
		var key = "%s-L%d" % [group, levels[actor]]
		if not behavior.has(key): behavior[key] = {"hands": 0, "vpip": 0, "pfr": 0, "bets": 0, "calls": 0}
		var now = Time.get_ticks_usec()
		var choice = bots[actor].choose(game.view_for(actor))
		timings.append((Time.get_ticks_usec() - now) / 1000.0)
		if game.phase == "preflop":
			if choice.action in ["call", "raise"]: voluntary[actor] = true
			if choice.action == "raise": raised[actor] = true
		else:
			if choice.action == "raise": behavior[key].bets += 1
			elif choice.action == "call": behavior[key].calls += 1
		var error = game.act(actor, choice.action, int(choice.get("amount", 0)))
		if not error.is_empty(): printerr("BENCH_ILLEGAL " + error); quit(1); return
		moves += 1
	assert(game.phase == "complete" and game.chip_total() == count * 1000)
	for id in range(count):
		var key = "%s-L%d" % [group, levels[id]]
		if not behavior.has(key): behavior[key] = {"hands": 0, "vpip": 0, "pfr": 0, "bets": 0, "calls": 0}
		if not totals.has(key): totals[key] = {"net": 0.0, "hands": 0}
		totals[key].net += (game.seats[id].stack - 1000) / 10.0
		totals[key].hands += 1
		behavior[key].hands += 1
		behavior[key].vpip += int(voluntary[id])
		behavior[key].pfr += int(raised[id])
	games += 1
