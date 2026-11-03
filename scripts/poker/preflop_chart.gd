extends RefCounted
## Precomputed approximate 100 BB preflop equilibrium (tools/solvers/preflop.mjs).
## An abstract game: open / 3-bet / 4-bet / all-in ladder, heads-up pots only,
## postflop value from an equity-realisation assumption. Applies at 70–140 BB
## effective while the hand still follows that ladder (no limps, no cold calls).
const Ranges = preload("res://scripts/poker/range_model.gd")
const Pushfold = preload("res://scripts/poker/pushfold.gd")
const PATH = "res://data/preflop.json"
const DIGITS = "0123456789abcdefghijk"
static var _data: Dictionary = {}
static var _index: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_data = parsed
			for n in _data.tables:
				for node in _data.tables[n].nodes: _index["%s/%s" % [n, node.label]] = node
	return _data

## {} outside the chart; otherwise the chart node and this seat's class row.
static func lookup(view: Dictionary, seat_id: int, hole: Array) -> Dictionary:
	if not view.board.is_empty() or hole.size() != 2 or view.legal.is_empty() or data().is_empty(): return {}
	var bb: int = view.big_blind
	var dealt: Array = []
	for seat in view.seats:
		if seat.in_hand: dealt.append(seat.id)
	var n = dealt.size()
	if n < 2 or n > 6: return {}
	# Effective depth against the deepest other live player.
	var own = view.seats[seat_id]
	var deepest = 0
	for seat in view.seats:
		if seat.id != seat_id and seat.in_hand and not seat.folded: deepest = maxi(deepest, seat.stack + seat.total_bet)
	var depth = float(mini(own.stack + own.total_bet, deepest)) / bb
	if depth < 70 or depth > 140: return {}
	var raisers: Array = []
	for a in view.get("actions", Ranges.public_actions(view)):
		if a.action == "fold": continue
		if a.action != "raise": return {}  # a limp or a cold call leaves the chart
		raisers.append(a.seat)
	var names: Array = data().positions[str(n)]
	var me = Pushfold.order(view, seat_id, dealt)
	var label = ""
	if raisers.is_empty():
		if me >= n - 1: return {}
		label = "%s-open" % names[me]
	else:
		var o = Pushfold.order(view, raisers[0], dealt)
		match raisers.size():
			1:
				if me <= o: return {}
				label = "%s-vs-%s" % [names[me], names[o]]
			_:
				var j = Pushfold.order(view, raisers[1], dealt)
				# The ladder alternates between the same two seats.
				for k in range(raisers.size()):
					if raisers[k] != (raisers[0] if k % 2 == 0 else raisers[1]): return {}
				if (me != o and me != j) or raisers.size() > 4: return {}
				var facing_jam = view.seats[raisers[-1]].stack == 0
				if raisers.size() == 4 or facing_jam:
					label = "%s-%s-jam" % [names[o], names[j]]
				else:
					label = "%s-%s-%d" % [names[o], names[j], raisers.size() - 1]
	var node: Dictionary = _index.get("%d/%s" % [n, label], {})
	if node.is_empty() or node.player != names[me]: return {}
	var h = Pushfold.class_index(hole)
	var options: Array = []
	var fold_ev = 0.0
	for a in range(node.actions.size()):
		var ev = int(node.ev[a].split(",")[h]) / 100.0
		if node.actions[a].action == "fold": fold_ev = ev
		options.append({"action": node.actions[a].action, "to_bb": float(node.actions[a].to), "frequency": DIGITS.find(node.frequency[a][h]) / 20.0, "ev_bb": ev})
	for option in options: option.ev_bb -= fold_ev
	return {"label": label, "players": n, "position": names[me], "depth_bb": depth, "options": options,
		"exploitability_bb": float(data().tables[str(n)].exploitability), "version": str(data().version)}

## Advisor strategy record in the same shape as the river solver's.
static func strategy(view: Dictionary, seat_id: int, hole: Array) -> Dictionary:
	var spot = lookup(view, seat_id, hole)
	if spot.is_empty(): return {}
	var legal: Dictionary = view.legal
	var bb: int = view.big_blind
	var frequencies: Array = []
	for option in spot.options:
		var choice = {"action": option.action, "amount": 0, "frequency": option.frequency, "ev": option.ev_bb * bb}
		if option.action == "raise":
			if not legal.get("raise", false): return {}
			choice.amount = clampi(roundi(option.to_bb * bb), int(legal.min_raise_to), int(legal.max_raise_to)) if option.to_bb < 100 else int(legal.max_raise_to)
		elif option.action == "call" and not legal.get("call", false):
			if not legal.get("check", false): return {}
			choice.action = "check"
		frequencies.append(choice)
	var scope = "翻牌前 100 BB 近似均衡"
	var step = {"open": "前面都弃牌，开池或弃牌", "vs": "面对开池", "jam": "面对全押"}
	var where = step.open if spot.label.ends_with("-open") else step.vs if spot.label.contains("-vs-") else step.jam if spot.label.ends_with("-jam") else "加注战"
	return {"supported": true, "kind": "preflop", "scope": scope, "converged": true, "frequencies": frequencies,
		"exploitability": spot.exploitability_bb * bb, "tolerance": bb * 0.01, "spot": spot,
		"reason": "%s · %d 人 · %s · %s（约 %d BB）。表来自简化的翻牌前博弈：只允许开池、3-bet、4-bet、全押，底池始终两人；翻牌后的价值按“胜率兑现”假设估算，不是完整求解。EV 相对弃牌，单位筹码。" % [scope, spot.players, spot.position, where, roundi(spot.depth_bb)]}
