extends SceneTree
const Table = preload("res://scripts/poker/table.gd")
const History = preload("res://scripts/poker/history.gd")
const Advisor = preload("res://scripts/poker/advisor.gd")
const River = preload("res://scripts/poker/river_cfr.gd")
const Rank = preload("res://scripts/poker/fast_rank.gd")
const Feedback = preload("res://scripts/poker/decision_feedback.gd")
var checks = 0
var failures = 0
var leaves = 0

func _initialize() -> void: call_deferred("run")
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)

func ready_solver(game, iterations: int = 1200):
	var solver = River.new(Advisor.information(game.view_for(0)), iterations)
	while solver.supported and not solver.ready: solver.prepare_step()
	return solver

func river(button: int, stacks: Array = [100, 100]):
	var game = Table.new(stacks, 5, 10, 91)
	game.start_hand(button)
	while game.phase != "river": game.act(game.actor, "check" if game.legal_actions(game.actor).check else "call")
	return game

func verify_tree(solver, node_id: int, game, initial_stack: int, outcome: int) -> void:
	if node_id < 0:
		leaves += 1
		verify(game.phase == "complete", "every abstract terminal corresponds to completed rules-engine hand")
		var term = solver.terminals[-node_id - 1]
		var expected = term.m * outcome + term.c + solver.half_pot
		verify(absf(game.seats[0].stack - initial_stack - expected) < 0.001, "terminal utility matches independently settled chips")
		return
	var node = solver.nodes[node_id]
	verify(game.actor == solver.ids[node.player], "tree action order matches rules engine")
	for i in range(node.actions.size()):
		var move: String = node.actions[i]
		var rebuilt = History.replay(game.record_state(), false)
		verify(not rebuilt.has("error"), "clone valid hand prefix")
		var copy = rebuilt.game
		var amount = int(move.trim_prefix("raise_")) if move.begins_with("raise_") else 0
		var action = "raise" if move.begins_with("raise_") else move
		var err = copy.act(copy.actor, action, amount)
		verify(err.is_empty(), "every abstract action legal: " + move + " " + err)
		if err.is_empty(): verify_tree(solver, node.children[i], copy, initial_stack, outcome)

func run() -> void:
	for scenario in range(6):
		var game = river(1 if scenario == 0 else 0, [100, 70] if scenario == 4 else [100, 100])
		if scenario == 1: game.act(1, "check")
		if scenario in [2, 3, 4, 5]: game.act(1, "raise", 20 if scenario != 5 else 90)
		if scenario == 3:
			game.act(0, "raise", 40)
			game.act(1, "raise", 60)
		verify(game.actor == 0, "fixture hero decision")
		var solver = ready_solver(game)
		verify(solver.supported and solver.ready, "new river scope supports fixture %d" % scenario)
		if not solver.ready: continue
		var outcome = signi(Rank.score(game.seats[0].hole + game.board) - Rank.score(game.seats[1].hole + game.board))
		verify_tree(solver, 0, game, game.seats[0].stack, outcome)
		var initial = solver.exploitability()
		while solver.iterations < solver.target: solver.step(20)
		verify(solver.exploitability() < initial or initial < 0.001, "CFR reduces exploitability with raises and pending bets")
		var result = solver.result()
		verify(result.get("supported", false), "queried bucket covered")
		if not result.get("supported", false): continue
		var frequency = 0.0
		for option in result.frequencies:
			frequency += option.frequency
			verify(is_finite(option.ev), "action EV finite")
			if option.action == "fold": verify(absf(option.ev) < 0.00001, "fold EV zero from current decision")
			if option.action == "call":
				var bucket = result.bucket
				var mass = 0.0
				var won = 0.0
				for j in range(8):
					mass += solver.joint[bucket][j]
					won += solver.joint[bucket][j] * (solver.outcomes[bucket][j] + 1) / 2
				var call = game.legal_actions(0).call_amount
				verify(absf(option.ev - (won / mass * (game.pot_size() + call) - call)) < 0.00001, "call EV agrees with independent equity/price formula")
		verify(absf(frequency - 1) < 0.00001, "mixed frequencies normalized")
		if scenario == 2: verify(result.frequencies.any(func(o): return o.action == "raise"), "facing first bet includes raise")
		if scenario == 3 or scenario == 5: verify(not result.frequencies.any(func(o): return o.action == "raise"), "reraising cap or all in has only fold/call")
	var view = river(1).view_for(0)
	var analysis = {"cost": 0, "call_ev": 0.0, "ev_error": 0.0, "action": "raise", "amount": 10, "strategy": {"supported": true, "converged": true, "frequencies": [{"action": "check", "amount": 0, "frequency": 0.4, "ev": 5.0}, {"action": "raise", "amount": 10, "frequency": 0.6, "ev": 5.1}]}}
	var mixed = Feedback.compare(view, analysis, "check", 0)
	verify(mixed.label == "参考混合打法" and mixed.scored and absf(mixed.loss - 0.1) < 0.00001, "mixed action not incorrectly marked as wrong")
	verify(Feedback.compare(view, analysis, "raise", 11).label == "未覆盖此尺度", "off-tree size cannot be scored")
	analysis.strategy.converged = false
	verify(not Feedback.compare(view, analysis, "check", 0).scored, "unconverged strategy never assigns precise loss")
	analysis.cost = 5
	analysis.call_ev = 0.1
	analysis.ev_error = 0.3
	verify(Feedback.compare(view, analysis, "fold", 0).label == "边缘决策", "uncertainty respects competing decisions")
	var game = river(0, [25, 100])
	game.act(1, "raise", 40)
	verify(not ready_solver(game).supported, "short-call side-pot scenario explicitly excluded")
	print("RIVER_EXTENSION_TESTS: %d checks, %d leaves verified against rules engine, %d failures" % [checks, leaves, failures])
	quit(1 if failures else 0)
