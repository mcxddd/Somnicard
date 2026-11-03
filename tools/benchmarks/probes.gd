extends SceneTree
## Leak matrix: each probe mode against each shipped level, paired against the
## unmodified bot on identical decks and seat rotations. A positive difference
## means that level pays off the deviation (a leak to fix); negative means it
## punishes it. Writes raw per-block differences for later re-analysis.
## Usage: --blocks=300 --players=2,6 --base=1 --modes=threebet,barrel --out=res://.local/probes.json
const Table = preload("res://scripts/poker/table.gd")
const Bot = preload("res://scripts/poker/local_bot.gd")
const Probe = preload("res://tools/benchmarks/probe_bot.gd")
var blocks = 300
var counts = [2, 6]
var base_level = 1
var modes: Array = Probe.MODES.slice(1)
var output = "res://.local/probes.json"
var seed_base = 707070

func _initialize() -> void: call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--blocks="): blocks = maxi(4, int(arg.trim_prefix("--blocks=")))
		if arg.begins_with("--players="): counts = Array(arg.trim_prefix("--players=").split(",")).map(func(n): return clampi(int(n), 2, Table.MAX_SEATS))
		if arg.begins_with("--base="): base_level = clampi(int(arg.trim_prefix("--base=")), 0, 2)
		if arg.begins_with("--modes="): modes = Array(arg.trim_prefix("--modes=").split(","))
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		if arg.begins_with("--seed="): seed_base = int(arg.trim_prefix("--seed="))
	var start = Time.get_ticks_msec()
	var results = {}
	for players in counts:
		for vs in range(3):
			# The baseline is shared by every mode on the same decks.
			Probe.mode = "baseline"
			var base: Array = []
			for block in range(blocks): base.append(_block(players, vs, block))
			for m in modes:
				Probe.mode = m
				var diffs: Array = []
				for block in range(blocks): diffs.append(_block(players, vs, block) - base[block])
				var key = "%s/%dp/L%d" % [m, players, vs]
				results[key] = _stats(diffs)
				print("PROBE %s diff=%+.1f ci=[%+.1f, %+.1f] BB/100 hands=%d %.0fs" % [key, results[key].mean, results[key].low, results[key].high, blocks * players, (Time.get_ticks_msec() - start) / 1000.0])
	var file = FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": Bot.VERSION, "base": base_level, "blocks": blocks, "seed": seed_base, "results": results}, "\t"))
	file.close()
	print("PROBES_COMPLETE %d %.0fs" % [results.size(), (Time.get_ticks_msec() - start) / 1000.0])
	quit()

## Probe's BB/100 over one deck dealt once per seat rotation.
func _block(players: int, vs: int, block: int) -> float:
	var net = 0.0
	for rotation in range(players): net += _play(players, vs, block, rotation)
	return net * 100.0 / players

func _play(players: int, vs: int, block: int, rotation: int) -> float:
	var stacks: Array = []
	stacks.resize(players)
	stacks.fill(1000)
	var game = Table.new(stacks, 5, 10, seed_base + block * 7919 + players)
	var bots: Array = []
	for id in range(players):
		var bot_seed = seed_base + block * 100003 + ((id - rotation + players) % players) * 379
		bots.append(Probe.new(bot_seed, 0, base_level) if id == rotation else Bot.new(bot_seed, 0, vs))
	game.start_hand(0)
	var moves = 0
	while game.phase != "complete" and moves < 300:
		var choice = bots[game.actor].choose(game.view_for(game.actor))
		var error = game.act(game.actor, choice.action, int(choice.get("amount", 0)))
		if not error.is_empty(): printerr("PROBE_ILLEGAL %s %s" % [Probe.mode, error]); quit(1); return 0.0
		moves += 1
	return (game.seats[rotation].stack - 1000) / 10.0

static func _stats(values: Array) -> Dictionary:
	var mean = 0.0
	for v in values: mean += v / values.size()
	var variance = 0.0
	for v in values: variance += pow(v - mean, 2) / (values.size() - 1)
	var half = 1.96 * sqrt(variance / values.size())
	return {"mean": mean, "low": mean - half, "high": mean + half, "blocks": values.size(), "values": values}
