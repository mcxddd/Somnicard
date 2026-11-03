extends SceneTree
## Compare a candidate bot script against the shipped bot on common decks.
## Each block deals the same deck twice with seats swapped (HU) or rotated (multi-way),
## so card luck largely cancels. Reports candidate BB/100 with block-level 95% intervals.
## Usage: --candidate=res://path/bot.gd --level=2 --vs-level=1 --players=2 --blocks=2000 --seed=424242
## --opponent=res://path/bot.gd replaces the shipped bot on the other seats (e.g. a frozen older version).
const Table = preload("res://scripts/poker/table.gd")
const Bot = preload("res://scripts/poker/local_bot.gd")
var candidate_path = "res://scripts/poker/local_bot.gd"
var level = 2
var vs_level = 2
var players = 2
var blocks = 1000
var seed_base = 424242
var Opponent = Bot

func _initialize() -> void: call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--candidate="): candidate_path = arg.trim_prefix("--candidate=")
		if arg.begins_with("--level="): level = int(arg.trim_prefix("--level="))
		if arg.begins_with("--vs-level="): vs_level = int(arg.trim_prefix("--vs-level="))
		if arg.begins_with("--players="): players = clampi(int(arg.trim_prefix("--players=")), 2, Table.MAX_SEATS)
		if arg.begins_with("--blocks="): blocks = maxi(4, int(arg.trim_prefix("--blocks=")))
		if arg.begins_with("--seed="): seed_base = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--opponent="): Opponent = load(arg.trim_prefix("--opponent="))
	var Candidate = load(candidate_path)
	var start = Time.get_ticks_msec()
	var values: Array = []
	for block in range(blocks):
		var net = 0.0
		for rotation in range(players):
			net += play(Candidate, block, rotation)
		values.append(net * 100.0 / players)
		if (block + 1) % 500 == 0: print("DUEL_PROGRESS %d/%d %.0fs" % [block + 1, blocks, (Time.get_ticks_msec() - start) / 1000.0])
	var mean = 0.0
	for v in values: mean += v / values.size()
	var variance = 0.0
	for v in values: variance += pow(v - mean, 2) / (values.size() - 1)
	var half = 1.96 * sqrt(variance / values.size())
	print("DUEL_RESULT candidate=%s L%d vs L%d players=%d hands=%d bb100=%+.1f ci=[%+.1f, %+.1f] %.0fs" % [candidate_path.get_file(), level, vs_level, players, blocks * players, mean, mean - half, mean + half, (Time.get_ticks_msec() - start) / 1000.0])
	quit()

## One deal with the candidate in seat `rotation`; returns the candidate's net in BB.
func play(Candidate, block: int, rotation: int) -> float:
	var stacks: Array = []
	stacks.resize(players)
	stacks.fill(1000)
	var game = Table.new(stacks, 5, 10, seed_base + block * 7919)
	var bots: Array = []
	for id in range(players):
		var bot_seed = seed_base + block * 100003 + ((id - rotation + players) % players) * 379
		bots.append(Candidate.new(bot_seed, 0, level) if id == rotation else Opponent.new(bot_seed, 0, vs_level))
	game.start_hand(0)
	var moves = 0
	while game.phase != "complete" and moves < 300:
		var choice = bots[game.actor].choose(game.view_for(game.actor))
		var error = game.act(game.actor, choice.action, int(choice.get("amount", 0)))
		if not error.is_empty(): printerr("DUEL_ILLEGAL " + error); quit(1); return 0.0
		moves += 1
	return (game.seats[rotation].stack - 1000) / 10.0
