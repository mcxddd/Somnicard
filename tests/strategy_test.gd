extends SceneTree
const Table = preload("res://scripts/poker/table.gd")
const Advisor = preload("res://scripts/poker/advisor.gd")
const Ranges = preload("res://scripts/poker/range_model.gd")
const River = preload("res://scripts/poker/river_cfr.gd")
const Bot = preload("res://scripts/poker/local_bot.gd")
const Preferences = preload("res://scripts/ui/preferences.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("_run")
func verify(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func prepare(model) -> void:
	while not model.ready: model.prepare_step(64)

func _run() -> void:
	_range_tests()
	_cfr_tests()
	await _teaching_tests()
	print("STRATEGY_TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _range_tests() -> void:
	var game = Table.new([1000, 1000], 5, 10, 7)
	game.start_hand(0)
	var view = game.view_for(0)
	var state = Advisor.information(view)
	var model = Ranges.new(state, [1], state.hole)
	prepare(model)
	verify(model.combos.size() == 1225, "C(50,2) hero-blocked combos")
	var total: float = 0.0
	for i in range(model.combos.size()):
		verify(model.combos[i][0] not in state.hole and model.combos[i][1] not in state.hole, "known blockers excluded")
		total += model.weights[1][i]
		verify(absf(model.weights[1][i] - 1.0 / 1225) < 1e-10, "no voluntary actions means uniform prior")
	verify(absf(total - 1.0) < 1e-9, "posterior normalized")
	game.act(0, "raise", 30)
	game.act(1, "raise", 100)
	state = Advisor.information(game.view_for(0))
	var raised = Ranges.new(state, [1], state.hole)
	prepare(raised)
	var baseline: float = 0.0
	var posterior: float = 0.0
	for i in range(model.combos.size()):
		baseline += Ranges.preflop_strength(model.combos[i]) * model.weights[1][i]
		posterior += Ranges.preflop_strength(raised.combos[i]) * raised.weights[1][i]
	verify(posterior > baseline + 0.08, "3-bet evidence materially strengthens range")
	verify(raised.summaries[0].effective_combos < 1225, "evidence concentrates effective range")
	verify(state.actions[1].raises == 1 and state.actions[1].cost == 20 and state.actions[1].size == 70, "action context reconstructed before action")
	var changed = game.view_for(0).duplicate(true)
	changed.seats[1].hole = [0, 51]
	changed["deck"] = range(52)
	changed["result"] = {"winner": 1}
	changed.events.append({"kind": "street", "board": [1, 2, 3]})
	changed.events.append({"kind": "action", "seat": 1, "action": "raise", "paid": 900, "to": 1000})
	verify(Advisor.cache_key(changed) == Advisor.cache_key(game.view_for(0)), "opponent cards, deck, result and future street ignored")
	changed = game.view_for(0).duplicate(true)
	changed.events[4].action = "call"
	verify(Advisor.cache_key(changed) != Advisor.cache_key(game.view_for(0)), "real past action changes analysis cache")
	var a = Advisor.new(game.view_for(0), 400, false)
	while not a.is_done(): a.step(40)
	var result = a.result()
	verify(result.samples == 400 and result.ranges.size() == 1 and result.equity >= 0 and result.equity <= 1, "weighted equity completes and reports ranges")
	# A tiny analytic distribution detects biased sequential conditional draws.
	model.ids = [0, 1]
	model.combos = [[0, 1], [2, 3]]
	model.cdfs = {0: [0.8, 1.0], 1: [0.2, 1.0]}
	var rng = RandomNumberGenerator.new()
	rng.seed = 23
	var accepted: int = 0
	var first: int = 0
	while accepted < 5000:
		var draw = model.draw_joint(rng)
		if draw.is_empty(): continue
		verify(draw[0] != draw[1], "joint deal has no card collisions")
		accepted += 1
		if draw[0] == [0, 1]: first += 1
	verify(absf(float(first) / accepted - 0.64 / 0.68) < 0.02, "joint posterior matches analytic conditional distribution")
	for count in [2, 4, 6]:
		var stacks: Array = []
		stacks.resize(count)
		stacks.fill(1000)
		game = Table.new(stacks, 5, 10, count)
		game.start_hand(0)
		verify(Ranges.position(game.view_for(0), 0) == ("BTN/SB" if count == 2 else "BTN"), "button position maps")
		verify(Ranges.position(game.view_for(0), 1 if count == 2 else 2) == "BB", "blind position maps")
		var actor = game.actor
		view = game.view_for(actor)
		changed = view.duplicate(true)
		for seat in changed.seats:
			if seat.id != actor: seat.hole = [0, 1]
		changed["deck"] = range(52)
		verify(Bot.new(32).choose(view) == Bot.new(32).choose(changed), "bot never uses opponent private cards")

func _cfr_tests() -> void:
	var game = Table.new([1000, 1000], 5, 10, 31)
	game.start_hand(1)
	while game.phase != "river" or game.actor != 0:
		var legal = game.legal_actions(game.actor)
		game.act(game.actor, "check" if legal.check else "call")
	var state = Advisor.information(game.view_for(0))
	var solver = River.new(state, 1200)
	while solver.supported and not solver.ready: solver.prepare_step()
	verify(solver.supported and solver.ready, "eligible river builds finite game")
	var alternate = state.duplicate(true)
	alternate.hole = [0, 1] if 0 not in state.board and 1 not in state.board else [2, 3]
	var other = River.new(alternate, 1)
	while other.supported and not other.ready: other.prepare_step()
	verify(solver.joint == other.joint and solver.outcomes == other.outcomes, "solver public prior independent of actual hero cards")
	var checked = state.duplicate(true)
	checked.actions.append({"seat": 1, "action": "check", "board": state.board, "pot": state.pot, "cost": 0, "size": 0, "raises": 0, "active": 2})
	var last_to_act = River.new(checked, 1)
	while not last_to_act.ready: last_to_act.prepare_step()
	verify(last_to_act.checked_to_hero and last_to_act.nodes[0].children[0] < 0, "checked-to hero check ends river, no illegal extra betting turn")
	verify(solver.nodes[0].children[0] >= 0, "first actor check gives opponent a turn")
	var early = solver.exploitability()
	while solver.iterations < solver.target: solver.step(25)
	var solved = solver.result()
	verify(solver.exploitability() < early, "CFR lowers best-response exploitability")
	if solved.get("supported", false):
		var sum: float = 0.0
		for choice in solved.frequencies:
			sum += choice.frequency
			verify(choice.action == "check" or (choice.amount >= state.legal.min_raise_to and choice.amount <= state.legal.max_raise_to), "strategy sizes legal")
			verify(is_finite(choice.ev) and choice.ev <= state.pot + minf(state.seats[0].stack, state.seats[1].stack), "action EV finite and bounded")
		verify(absf(sum - 1.0) < 1e-8, "strategy frequencies normalized")
	print("RIVER_CFR: epsilon=%.5f chips, initial=%.5f, iterations=%d" % [solver.exploitability(), early, solver.iterations])
	alternate.legal.call_amount = 10
	verify(not River.new(alternate).supported, "facing bet excluded from solver scope")
	var multi = state.duplicate(true)
	multi.seats.append({"id": 2, "in_hand": true, "folded": false, "stack": 100, "total_bet": 10})
	verify(not River.new(multi).supported, "multiway solver explicitly unsupported")
	var side = state.duplicate(true)
	side.seats[1].total_bet += 10
	verify(not River.new(side).supported, "unequal contribution subgame explicitly unsupported")
	# Reuse the generic finite tree for canonical Kuhn poker. Exact equilibrium
	# value is -1/18. This checks solver math against an independent benchmark.
	var kuhn = River.new(alternate, 4000)
	kuhn.supported = true
	kuhn.ready = true
	kuhn.half_pot = 1.0
	kuhn.bet_sizes = [1]
	for a in range(8):
		kuhn.joint.append([])
		kuhn.outcomes.append([])
		for b in range(8):
			kuhn.joint[a].append(1.0 / 6 if a < 3 and b < 3 and a != b else 0.0)
			kuhn.outcomes[a].append(float(signi(a - b)))
	kuhn._build_tree()
	while kuhn.iterations < kuhn.target: kuhn.step(100)
	var avg = kuhn.profile()
	var value = _kuhn_value(avg, -1, 0)
	var computed: float = 0.0
	for own in range(3): computed += kuhn._expected(0, own, kuhn.joint[own], avg)
	verify(absf(computed - value) < 1e-9, "recursive profile EV matches independent Kuhn payoff formula")
	var br0 = -INF
	var br1 = -INF
	for plan in range(64):
		br0 = maxf(br0, _kuhn_value(avg, 0, plan))
		br1 = maxf(br1, -_kuhn_value(avg, 1, plan))
	verify(absf(value + 1.0 / 18.0) < 0.008, "Kuhn value converges to -1/18")
	verify(absf(kuhn.exploitability() - (br0 + br1) / 2.0) < 1e-9, "best response certificate matches enumeration of all pure information-set plans")
	verify(kuhn.exploitability() < 0.015, "Kuhn equilibrium has small exploitability")
	print("KUHN: value=%.6f target=-0.055556; epsilon=%.6f" % [value, kuhn.exploitability()])

func _kuhn_value(profile: Array, replaced_player: int, plan: int) -> float:
	var total: float = 0.0
	for a in range(3):
		for b in range(3):
			if a == b: continue
			var check0: float = profile[a][0]
			var check1: float = profile[8 + b][0]
			var fold1: float = profile[16 + b][0]
			var fold0: float = profile[24 + a][0]
			if replaced_player == 0:
				check0 = float((plan >> a) & 1)
				fold0 = float((plan >> (a + 3)) & 1)
			if replaced_player == 1:
				check1 = float((plan >> b) & 1)
				fold1 = float((plan >> (b + 3)) & 1)
			var sign_value = float(signi(a - b))
			total += (check0 * (check1 * sign_value + (1 - check1) * (-fold0 + (1 - fold0) * 2 * sign_value)) + (1 - check0) * (fold1 + (1 - fold1) * 2 * sign_value)) / 6.0
	return total

func _teaching_tests() -> void:
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	ui.smoke_mode = true
	ui._start_table(2)
	ui._open_advice()
	verify(ui.review.analysis_view.job != null, "live teaching starts incremental job")
	ui.review.analysis_view.teaching_toggle.pressed.emit()
	verify(not ui.prefs.live_teaching and ui.prefs.review_teaching and ui.review.analysis_view.job == null and ui.review.analysis_view.analysis.is_empty(), "live switch independent, cancels and clears")
	ui.review.analysis_view._analyze()
	verify(ui.review.analysis_view.job == null and not ui.review.analysis_view.analyze_button.visible, "disabled teaching cannot start computation")
	ui.review.close()
	ui._open_advice()
	verify(ui.settings.visible and ui.settings.pages[2].visible, "off entry explains and opens teaching settings")
	ui.settings.controls.live_teaching.button_pressed = true
	ui.settings.controls.review_teaching.button_pressed = false
	ui.settings.apply_button.pressed.emit()
	verify(ui.prefs.live_teaching and not ui.prefs.review_teaching, "settings applies independent modes")
	ui._open_advice()
	var ticks = 0
	while ui.review.analysis_view.job != null and ticks < 1000:
		await process_frame
		ticks += 1
	verify(not ui.review.analysis_view.analysis.is_empty(), "live works while replay disabled")
	var analysis = ui.review.analysis_view.analysis.duplicate(true)
	ui.review.set_units(false)
	verify(ui.review.analysis_view.analysis == analysis, "units preserve posterior and strategy")
	ui.review.live_mode = false
	ui.review.analysis_view.set_teaching(true, false)
	verify(ui.review.analysis_view.analysis.is_empty() and not ui.review.analysis_view.range_button.visible, "no cached teaching leaks into disabled review")
	ui.review.analysis_view._toggle_teaching()
	verify(ui.prefs.review_teaching and ui.prefs.live_teaching, "review toggle updates only review preference")
	var path = "user://strategy-preferences-test.cfg"
	var prefs = Preferences.DEFAULTS.duplicate()
	prefs.live_teaching = false
	prefs.review_teaching = true
	Preferences.save_values(prefs, path)
	var loaded = Preferences.load_values(path)
	verify(not loaded.live_teaching and loaded.review_teaching, "independent toggles persist")
	DirAccess.remove_absolute(path)
	ui.queue_free()
	await process_frame
