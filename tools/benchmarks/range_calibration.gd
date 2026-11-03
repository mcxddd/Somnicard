extends SceneTree
## How well the public-action range model reads the shipped bots. At each
## postflop decision of seat 0, every live opponent's posterior is scored against
## the bot's real hole cards (known only to this tool):
## - bits: log2(p(true combo) × combos), information gained over a uniform range;
## - coverage: how often the real hand lies inside the most likely 50% / 80% mass
##   (a calibrated model hits about 50% / 80%);
## - buckets: predicted vs actual share of strong / medium / draw / air.
## Measures reads against THESE bots only; it says nothing about human players.
## Usage: --hands=400 --players=2,6 --out=res://.local/range-calibration.json
## --publish also writes the compact per-level summary the coach shows (data/range-calibration.json).
const Table = preload("res://scripts/poker/table.gd")
const Bot = preload("res://scripts/poker/local_bot.gd")
const Ranges = preload("res://scripts/poker/range_model.gd")
const Advisor = preload("res://scripts/poker/advisor.gd")
const BUCKETS = ["strong", "medium", "draw", "air"]
var hands = 400
var counts = [2, 6]
var output = "res://.local/range-calibration.json"
var seed_base = 515000
## Flattening exponents evaluated post hoc on the same reads: p^τ renormalised.
var temperatures = [1.0]

func _initialize() -> void: call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hands="): hands = maxi(4, int(arg.trim_prefix("--hands=")))
		if arg.begins_with("--players="): counts = Array(arg.trim_prefix("--players=").split(",")).map(func(n): return clampi(int(n), 2, Table.MAX_SEATS))
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		if arg.begins_with("--tau="): temperatures = Array(arg.trim_prefix("--tau=").split(",")).map(func(t): return float(t))
	var start = Time.get_ticks_msec()
	var report = {}
	for players in counts:
		for level in range(3):
			var acc = {"reads": 0, "bits": 0.0, "in50": 0, "in80": 0, "predicted": {}, "actual": {}, "by_street": {}, "tau": {}}
			for t in temperatures: acc.tau[str(t)] = {"bits": 0.0, "in50": 0, "in80": 0}
			for b in BUCKETS:
				acc.predicted[b] = 0.0
				acc.actual[b] = 0
			for hand in range(hands): _hand(players, level, hand, acc)
			var n = maxi(1, acc.reads)
			for t in acc.tau:
				var r = acc.tau[t]
				print("  tau=%s bits=%.2f cover50=%.0f%% cover80=%.0f%%" % [t, r.bits / n, 100.0 * r.in50 / n, 100.0 * r.in80 / n])
			var summary = {"reads": acc.reads, "bits": acc.bits / n, "coverage50": float(acc.in50) / n, "coverage80": float(acc.in80) / n, "buckets": {}, "by_street": {}}
			var brier = 0.0
			for b in BUCKETS:
				summary.buckets[b] = {"predicted": acc.predicted[b] / n, "actual": float(acc.actual[b]) / n}
			for street in acc.by_street:
				var s = acc.by_street[street]
				summary.by_street[street] = {"reads": s.reads, "bits": s.bits / maxi(1, s.reads), "coverage50": float(s.in50) / maxi(1, s.reads)}
			var key = "%dp/L%d" % [players, level]
			report[key] = summary
			print("CALIBRATION %s reads=%d bits=%.2f cover50=%.0f%% cover80=%.0f%% strong %.0f/%.0f medium %.0f/%.0f draw %.0f/%.0f air %.0f/%.0f %.0fs" % [key, acc.reads, summary.bits, 100 * summary.coverage50, 100 * summary.coverage80,
				100 * summary.buckets.strong.predicted, 100 * summary.buckets.strong.actual, 100 * summary.buckets.medium.predicted, 100 * summary.buckets.medium.actual,
				100 * summary.buckets.draw.predicted, 100 * summary.buckets.draw.actual, 100 * summary.buckets.air.predicted, 100 * summary.buckets.air.actual, (Time.get_ticks_msec() - start) / 1000.0])
	var file = FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"model": Ranges.VERSION, "bots": Bot.VERSION, "hands": hands, "seed": seed_base, "report": report}, "\t"))
	file.close()
	if "--publish" in OS.get_cmdline_user_args():
		# Pool every table size per level, weighting by reads.
		var levels: Array = []
		for level in range(3):
			var reads = 0
			var c50 = 0.0
			var c80 = 0.0
			for key in report:
				if key.ends_with("/L%d" % level):
					reads += report[key].reads
					c50 += report[key].coverage50 * report[key].reads
					c80 += report[key].coverage80 * report[key].reads
			levels.append({"reads": reads, "coverage50": snappedf(c50 / maxi(1, reads), 0.001), "coverage80": snappedf(c80 / maxi(1, reads), 0.001)})
		var compact = FileAccess.open("res://data/range-calibration.json", FileAccess.WRITE)
		compact.store_string(JSON.stringify({"model": Ranges.VERSION, "bots": Bot.VERSION, "players": counts, "hands": hands, "seed": seed_base, "levels": levels}, "\t"))
		compact.close()
	print("CALIBRATION_COMPLETE %.0fs" % ((Time.get_ticks_msec() - start) / 1000.0))
	quit()

static func bucket(hole: Array, board: Array) -> String:
	return Ranges.bucket(hole, board)

func _hand(players: int, level: int, hand: int, acc: Dictionary) -> void:
	var stacks: Array = []
	stacks.resize(players)
	stacks.fill(1000)
	var game = Table.new(stacks, 5, 10, seed_base + hand * 7919 + players * 31 + level)
	var bots: Array = []
	for id in range(players):
		bots.append(Bot.new(seed_base + hand * 100003 + id * 379, 0, level))
		# Same badge text as the table, so the model sees exactly what a player sees.
		game.seats[id]["style"] = bots[id].style_name()
	game.start_hand(hand % players)
	var moves = 0
	while game.phase != "complete" and moves < 300:
		var view = game.view_for(game.actor)
		if game.actor == 0 and not view.board.is_empty(): _score(game, view, acc)
		var choice = bots[game.actor].choose(view)
		game.act(game.actor, choice.action, int(choice.get("amount", 0)))
		moves += 1

func _score(game, view: Dictionary, acc: Dictionary) -> void:
	var state = Advisor.information(view)
	var known: Array = state.hole + state.board
	var opponents: Array = []
	for seat in state.seats:
		if seat.id != 0 and seat.in_hand and not seat.folded: opponents.append(seat.id)
	if opponents.is_empty(): return
	var model = Ranges.new(state, opponents, known)
	while not model.ready: model.prepare_step(400)
	var street = ["flop", "turn", "river"][view.board.size() - 3]
	if not acc.by_street.has(street): acc.by_street[street] = {"reads": 0, "bits": 0.0, "in50": 0}
	for id in opponents:
		var truth: Array = game.seats[id].hole.duplicate()
		truth.sort()
		var probabilities: Array = model.weights[id]
		var index = -1
		var mass = {}
		for b in BUCKETS: mass[b] = 0.0
		for i in range(model.combos.size()):
			var combo: Array = model.combos[i]
			if combo[0] == truth[0] and combo[1] == truth[1]: index = i
			mass[bucket(combo, view.board)] += probabilities[i]
		if index < 0: continue
		var p_true: float = probabilities[index]
		var bits = log(p_true * model.combos.size()) / log(2.0)
		# Mass strictly more likely than the true combo: inside the top-q set when below q.
		var above = 0.0
		for p in probabilities:
			if p > p_true: above += p
		acc.reads += 1
		acc.bits += bits
		acc.in50 += 1 if above < 0.5 else 0
		acc.in80 += 1 if above < 0.8 else 0
		for b in BUCKETS: acc.predicted[b] += mass[b]
		acc.actual[bucket(truth, view.board)] += 1
		acc.by_street[street].reads += 1
		acc.by_street[street].bits += bits
		acc.by_street[street].in50 += 1 if above < 0.5 else 0
		for t in temperatures:
			var total = 0.0
			for p in probabilities: total += pow(p, t)
			var pt = pow(p_true, t) / total
			var over = 0.0
			for p in probabilities:
				if p > p_true: over += pow(p, t) / total
			var r = acc.tau[str(t)]
			r.bits += log(pt * model.combos.size()) / log(2.0)
			r.in50 += 1 if over < 0.5 else 0
			r.in80 += 1 if over < 0.8 else 0
