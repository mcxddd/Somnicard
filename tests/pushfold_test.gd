extends SceneTree
const Table = preload("res://scripts/poker/table.gd")
const Pushfold = preload("res://scripts/poker/pushfold.gd")
const Ranges = preload("res://scripts/poker/range_model.gd")
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

func grid_name(index: int) -> String:
	var ranks = "AKQJT98765432"
	var row = index / 13
	var col = index % 13
	return ranks[mini(row, col)] + ranks[maxi(row, col)] + ("" if row == col else "s" if col > row else "o")

## Seat `actor`'s hole cards replaced: the chart only reads the asking seat's cards.
func spot(game, hole: Array) -> Dictionary:
	return Pushfold.lookup(game.view_for(game.actor), game.actor, hole)

func _run() -> void:
	var data = Pushfold.data()
	verify(not data.is_empty() and data.version == "pushfold-1", "push/fold table loads")
	var complete = true
	for n in range(2, 7):
		for depth in range(2, 16):
			var t: Dictionary = data.tables.get("%d/%d" % [n, depth], {})
			complete = complete and t.push.size() == n - 1 and t.call.size() == n - 1
			for i in range(n - 1):
				complete = complete and t.push[i].length() == 169 and t.call[i].size() == n - 1 - i and t.push_margin[i].split(",").size() == 169
			# Aces always shove and always call; seven-deuce never calls a 15 BB shove.
			for i in range(n - 1):
				verify(Pushfold._frequency(t.push[i], 0) == 1.0, "AA shoves %d/%d order %d" % [n, depth, i])
				for c in t.call[i]: verify(Pushfold._frequency(c, 0) == 1.0, "AA calls %d/%d" % [n, depth])
	verify(complete, "every table has one shove row per first-in seat and one call row per responder")
	verify(float(data.exploitability_max) < 0.01, "every table is within 0.01 BB of a best response")
	# Grid index agrees with the range model's class names for all 1326 combos.
	var names_ok = true
	for a in range(52):
		for b in range(a + 1, 52):
			names_ok = names_ok and grid_name(Pushfold.class_index([a, b])) == Ranges.hand_class([a, b])
	verify(names_ok, "class index matches range grid naming")
	# Heads-up 10 BB: the small blind is first in, the big blind then faces the shove.
	var game = Table.new([100, 100], 5, 10, 7)
	game.start_hand(0)
	var aces = [12, 25]
	var trash = [5, 13]  # 7♠ 2♥
	var sb = spot(game, aces)
	verify(not sb.is_empty() and not sb.facing and sb.position == "SB" and sb.exact and sb.frequency == 1.0 and sb.margin_bb > 0, "heads-up SB shoves aces")
	game.act(game.actor, "raise", game.legal_actions(game.actor).max_raise_to)
	var bb = spot(game, trash)
	verify(not bb.is_empty() and bb.facing and bb.position == "BB" and bb.shover == "SB" and bb.frequency == 0.0 and bb.margin_bb < 0, "heads-up BB folds seven-deuce to a shove")
	# Deep stacks, limps and non-all-in raises are outside the table.
	game = Table.new([1000, 1000], 5, 10, 7)
	game.start_hand(0)
	verify(spot(game, aces).is_empty(), "100 BB is not a push/fold spot")
	game = Table.new([100, 100, 100, 100, 100, 100], 5, 10, 9)
	game.start_hand(0)
	var first = spot(game, aces)
	verify(not first.is_empty() and first.position == "UTG" and first.players == 6 and not first.exact, "six-handed UTG is first in")
	game.act(game.actor, "call")
	verify(spot(game, aces).is_empty(), "a limp leaves push/fold")
	game = Table.new([100, 100, 100, 100, 100, 100], 5, 10, 9)
	game.start_hand(0)
	game.act(game.actor, "raise", 30)
	verify(spot(game, aces).is_empty(), "a raise that is not all-in leaves push/fold")
	# Folds keep the spot; responders are ordered after the shover.
	game = Table.new([100, 100, 100, 100, 100, 100], 5, 10, 9)
	game.start_hand(0)
	game.act(game.actor, "fold")
	game.act(game.actor, "fold")
	var co = spot(game, aces)
	verify(co.position == "CO" and not co.facing, "folds keep the first-in spot")
	game.act(game.actor, "raise", game.legal_actions(game.actor).max_raise_to)
	var btn = spot(game, aces)
	verify(btn.facing and btn.position == "BTN" and btn.shover == "CO" and btn.frequency == 1.0, "button faces the cutoff shove")
	# The coach reports the table as a converged strategy record.
	game = Table.new([100, 100], 5, 10, 21)
	game.start_hand(0)
	var view = game.view_for(0)
	var advisor = Advisor.new(view, 200, true)
	while not advisor.is_done(): advisor.step(64)
	var result = advisor.result()
	verify(result.strategy.get("kind", "") == "pushfold" and result.strategy.converged and result.strategy.frequencies.size() == 2, "coach uses the push/fold equilibrium at 10 BB")
	verify(result.action in ["raise", "fold"] and (result.action != "raise" or result.amount == view.legal.max_raise_to), "coach advice is shove or fold")
	# Advanced bots follow the table and stay legal at short stacks.
	var legal_play = true
	for n in [2, 4, 6]:
		for hand in range(30):
			var stacks: Array = []
			for i in range(n): stacks.append(60 + 20 * ((hand + i) % 5))
			var g = Table.new(stacks, 5, 10, 300 + hand)
			g.start_hand(hand % n)
			var bots: Array = []
			for i in range(n): bots.append(Bot.new(500 + hand * 7 + i, 0, 2))
			var moves = 0
			while g.phase != "complete" and moves < 200:
				var choice = bots[g.actor].choose(g.view_for(g.actor))
				legal_play = legal_play and g.act(g.actor, choice.action, int(choice.get("amount", 0))).is_empty()
				moves += 1
	verify(legal_play, "advanced bots act legally in push/fold spots")
	game = Table.new([100, 100], 5, 10, 7)
	game.start_hand(0)
	var probe = game.view_for(game.actor)
	probe.seats[game.actor].hole = aces
	verify(Bot.new(1, 0, 2).choose(probe).action == "raise", "advanced bot shoves aces at 10 BB")
	print("PUSHFOLD_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
