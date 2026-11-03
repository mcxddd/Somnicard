extends SceneTree
const Table = preload("res://scripts/poker/table.gd")
const Advisor = preload("res://scripts/poker/advisor.gd")
const Turn = preload("res://scripts/poker/turn_cfr.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("_run")
func verify(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

## A heads-up hand checked or called down to hero's turn decision.
func turn_spot(seed_value: int, bet_first: bool) -> Table:
	var g = Table.new([1000, 1000], 5, 10, seed_value)
	g.start_hand(0)
	while g.phase != "complete" and not (g.phase == "turn" and g.actor == 0 and (not bet_first or g.legal_actions(0).call_amount > 0)):
		var l = g.legal_actions(g.actor)
		if bet_first and g.phase == "turn" and g.actor != 0 and l.check: g.act(g.actor, "raise", 40)
		else: g.act(g.actor, "check" if l.check else "call")
	return g

## Runs to `iterations` of a solver whose target is `target` (default: the same).
func solve(state: Dictionary, iterations: int, target: int = -1):
	var solver = Turn.new(state, iterations if target < 0 else target)
	while solver.supported and not solver.ready: solver.step()
	while solver.supported and solver.iterations < iterations: solver.step(10)
	return solver

func _run() -> void:
	var tested = 0
	for seed_value in [5, 11]:
		for facing in [false, true]:
			var g = turn_spot(seed_value, facing)
			if g.phase != "turn" or g.actor != 0: continue
			var state = Advisor.information(g.view_for(0))
			var solver = solve(state, 40, 300)
			verify(solver.supported and solver.ready, "turn spot is supported")
			var early = solver.exploitability()
			while solver.iterations < 300: solver.step(20)
			var r = solver.result()
			var total = 0.0
			for f in r.frequencies: total += f.frequency
			verify(absf(total - 1.0) < 1e-6, "root frequencies sum to one")
			verify(r.exploitability < early * 0.5 and r.exploitability <= state.pot * 0.06, "exploitability falls to within 6%% of the pot (%.2f%%)" % (100.0 * r.exploitability / state.pot))
			# Zero-sum: the average-strategy values of both players cancel.
			var v = solver._walk(0, Turn._filled(Turn.TB, 1.0), Turn._filled(Turn.TB, 1.0), 1, 0)
			var sum0 = 0.0
			var sum1 = 0.0
			for t in range(Turn.TB):
				sum0 += v[0][t]
				sum1 += v[1][t]
			verify(absf(sum0 + sum1) < 1e-6 * state.pot, "the abstract game is zero-sum")
			# Best responses never earn less than the average strategy.
			for player in range(2):
				var br = solver._walk(0, Turn._filled(Turn.TB, 1.0), Turn._filled(Turn.TB, 1.0), 2, player)
				var b_total = 0.0
				for t in range(Turn.TB): b_total += br[player][t]
				verify(b_total >= (sum0 if player == 0 else sum1) - 1e-9, "best response dominates the average for player %d" % player)
			for f in r.frequencies:
				if f.action == "fold": verify(absf(f.ev) < 1e-6, "folding is worth zero from now")
				if f.action == "raise": verify(f.amount >= g.legal_actions(0).min_raise_to and f.amount <= g.legal_actions(0).max_raise_to, "root raise sizes are legal")
			# The opponent's real cards never enter the solution.
			var changed = state.duplicate(true)
			for seat in changed.seats: seat["hole_hint"] = "ignored"
			var other = solve(changed, 20)
			verify(JSON.stringify(other.result().frequencies) == JSON.stringify(solve(state, 20).result().frequencies), "same public state, same solution")
			tested += 1
	verify(tested >= 3, "enough turn spots were exercised")
	# Unsupported spots explain themselves.
	var g = Table.new([1000, 1000, 1000], 5, 10, 3)
	g.start_hand(0)
	while g.phase != "complete" and not (g.phase == "turn" and g.actor == 0):
		var l = g.legal_actions(g.actor)
		g.act(g.actor, "check" if l.check else "call")
	if g.phase == "turn":
		var multi = Turn.new(Advisor.information(g.view_for(0)), 10)
		verify(not multi.supported and multi.reason.contains("多名玩家"), "multiway turn is not solved")
	# The advisor picks the turn solver on the turn.
	var spot = turn_spot(11, false)
	var advisor = Advisor.new(spot.view_for(0), 200, true)
	while not advisor.is_done():
		advisor.step(64)
		if advisor.solver != null and advisor.solver.ready: advisor.solver.target = 30
	var strategy = advisor.result().strategy
	verify(strategy.get("kind", "") == "turn" and strategy.supported, "advisor solves the turn")
	print("TURN_SOLVER_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
