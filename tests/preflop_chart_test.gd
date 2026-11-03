extends SceneTree
const Table = preload("res://scripts/poker/table.gd")
const Chart = preload("res://scripts/poker/preflop_chart.gd")
const Advisor = preload("res://scripts/poker/advisor.gd")
const Bot = preload("res://scripts/poker/local_bot.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("_run")
func verify(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func spot(game, hole: Array) -> Dictionary:
	return Chart.lookup(game.view_for(game.actor), game.actor, hole)

func freq(s: Dictionary, action: String) -> float:
	for o in s.get("options", []):
		if o.action == action: return o.frequency
	return -1.0

func _run() -> void:
	var data = Chart.data()
	verify(not data.is_empty() and data.version == "preflop-1" and float(data.exploitability_max) < 0.01, "preflop chart loads within 0.01 BB of a best response")
	# Every class's frequencies sum to one (each digit is rounded to 5%).
	var sums_ok = true
	for n in data.tables:
		for node in data.tables[n].nodes:
			for h in range(169):
				var total = 0.0
				for row in node.frequency: total += Chart.DIGITS.find(row[h]) / 20.0
				sums_ok = sums_ok and absf(total - 1.0) <= 0.08
	verify(sums_ok, "action frequencies sum to one for every class")
	var aces = [12, 25]
	var trash = [5, 13]  # 7♠ 2♥
	# Six-handed 100 BB: open, facing an open, facing a 3-bet.
	var game = Table.new([1000, 1000, 1000, 1000, 1000, 1000], 5, 10, 3)
	game.start_hand(0)
	var utg = spot(game, aces)
	verify(utg.label == "UTG-open" and freq(utg, "raise") == 1.0, "aces open under the gun")
	verify(freq(spot(game, trash), "fold") == 1.0, "seven-deuce folds under the gun")
	# Open ranges widen toward the button.
	var shares = {}
	var Pf = preload("res://scripts/poker/pushfold.gd")
	for node in data.tables["6"].nodes:
		if node.label.ends_with("-open"):
			var share = 0.0
			for a in range(52):
				for b in range(a + 1, 52): share += Chart.DIGITS.find(node.frequency[1][Pf.class_index([a, b])]) / 20.0 / 1326.0
			shares[node.player] = share
	verify(shares.UTG > 0.12 and shares.UTG < 0.24 and shares.UTG < shares.HJ and shares.HJ < shares.CO and shares.CO < shares.BTN, "open ranges widen from UTG to the button")
	game.act(game.actor, "raise", 25)
	var hj = spot(game, aces)
	verify(hj.label == "HJ-vs-UTG" and freq(hj, "raise") > 0.5, "aces mostly 3-bet against an open")
	game.act(game.actor, "raise", 75)
	game.act(game.actor, "fold")
	game.act(game.actor, "fold")
	game.act(game.actor, "fold")
	game.act(game.actor, "fold")
	var back = spot(game, aces)
	verify(back.label == "UTG-HJ-1" and back.position == "UTG", "opener faces the 3-bet")
	# A limp leaves the chart; so does a short stack.
	game = Table.new([1000, 1000, 1000, 1000, 1000, 1000], 5, 10, 3)
	game.start_hand(0)
	game.act(game.actor, "call")
	verify(spot(game, aces).is_empty(), "a limp leaves the chart")
	game = Table.new([300, 300, 300, 300, 300, 300], 5, 10, 3)
	game.start_hand(0)
	verify(spot(game, aces).is_empty(), "30 BB is outside the 100 BB chart")
	# Heads-up labels and the coach record.
	game = Table.new([1000, 1000], 5, 10, 4)
	game.start_hand(0)
	verify(spot(game, aces).label == "SB-open", "heads-up small blind opens")
	game.act(game.actor, "raise", 25)
	verify(spot(game, aces).label == "BB-vs-SB", "heads-up big blind faces the open")
	var view = game.view_for(game.actor)
	var record = Chart.strategy(view, game.actor, aces)
	var fold_ev = -1.0
	for choice in record.frequencies:
		if choice.action == "fold": fold_ev = choice.ev
	verify(record.kind == "preflop" and record.converged and fold_ev == 0.0, "strategy record measures EV relative to folding")
	game = Table.new([1000, 1000], 5, 10, 4)
	game.start_hand(0)
	view = game.view_for(0)
	var advisor = Advisor.new(view, 200, true)
	while not advisor.is_done(): advisor.step(64)
	verify(advisor.result().strategy.get("kind", "") == "preflop", "coach uses the preflop chart at 100 BB")
	# Advanced bots follow the chart and stay legal.
	var legal_play = true
	for n in [2, 4, 6]:
		for hand in range(40):
			var stacks: Array = []
			for i in range(n): stacks.append(1000)
			var g = Table.new(stacks, 5, 10, 900 + hand)
			g.start_hand(hand % n)
			var bots: Array = []
			for i in range(n): bots.append(Bot.new(700 + hand * 11 + i, 0, 2))
			var moves = 0
			while g.phase != "complete" and moves < 300:
				var choice = bots[g.actor].choose(g.view_for(g.actor))
				legal_play = legal_play and g.act(g.actor, choice.action, int(choice.get("amount", 0))).is_empty()
				moves += 1
	verify(legal_play, "advanced bots act legally from the chart")
	print("PREFLOP_CHART_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
