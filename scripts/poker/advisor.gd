extends RefCounted
## Incremental Monte Carlo job. Input is an allow-list of public state and hero cards.
## Neither the shuffled deck, opponent hole cards nor future events enter this job.
const Rank = preload("res://scripts/poker/fast_rank.gd")
const Sizing = preload("res://scripts/ui/bet_sizing.gd")
const Ranges = preload("res://scripts/poker/range_model.gd")
const River = preload("res://scripts/poker/river_cfr.gd")
var ranges
var solver
var precision = 0
var solver_started_ms = 0
var solver_budget_ms = 0
var solver_timed_out = false
var solve_enabled: bool = true
var attempts: int = 0
var state: Dictionary
var rng := RandomNumberGenerator.new()
var unknown: Array = []
var opponents: Array = []
var tiers: Array = []
var samples: int = 0
var target: int = 1600
var wins: int = 0
var ties: int = 0
var equity_sum: float = 0.0
var return_sum: float = 0.0
var return_square_sum: float = 0.0
var eligible_pot: int = 0
var cost: int = 0
var error: String = ""

static func information(view: Dictionary) -> Dictionary:
	var seats: Array = []
	for seat in view.seats:
		seats.append({"id": seat.id, "stack": seat.stack, "street_bet": seat.street_bet,
			"total_bet": seat.total_bet, "in_hand": seat.in_hand, "folded": seat.folded})
	return {"seats": seats, "hole": view.seats[0].hole.duplicate(), "board": view.board.duplicate(),
		"phase": view.phase, "actor": view.actor, "big_blind": view.big_blind, "pot": view.pot,
		"current_bet": view.current_bet, "legal": view.legal.duplicate(true),
		"button": view.get("button", 0), "actions": Ranges.public_actions(view), "model": Ranges.VERSION, "solver_version": River.VERSION}

static func cache_key(view: Dictionary) -> String:
	return JSON.stringify(information(view))

func _init(view: Dictionary, sample_count: int = 1600, with_solver: bool = true, detail: int = 0) -> void:
	precision = clampi(detail, 0, 1)
	state = information(view)
	solve_enabled = with_solver
	target = maxi(1, sample_count)
	if state.actor != 0 or state.legal.is_empty() or state.hole.size() != 2 or state.phase == "complete":
		error = "请选择轮到你行动的决策点"
		return
	rng.seed = JSON.stringify(state).hash()
	var known = state.hole + state.board
	for card in range(52):
		if card not in known: unknown.append(card)
	for seat in state.seats:
		if seat.id != 0 and seat.in_hand and not seat.folded: opponents.append(seat.id)
	if opponents.is_empty():
		error = "没有需要对比的对手"
		return
	ranges = Ranges.new(state, opponents, known)
	cost = state.legal.call_amount
	# Snapshot pots after hero calls, with no further contributions assumed.
	# Hero cannot win tiers above their own contribution cap.
	var contributions: Array = []
	var levels: Array = []
	for seat in state.seats:
		var amount: int = seat.total_bet + (cost if seat.id == 0 else 0)
		contributions.append(amount)
		if amount > 0 and amount not in levels: levels.append(amount)
	levels.sort()
	var previous: int = 0
	for level in levels:
		var amount: int = 0
		var eligible: Array = []
		for seat in state.seats:
			if contributions[seat.id] >= level:
				amount += level - previous
				if seat.in_hand and not seat.folded: eligible.append(seat.id)
		previous = level
		if 0 in eligible:
			tiers.append({"amount": amount, "eligible": eligible})
			eligible_pot += amount

func step(batch: int = 12) -> void:
	if error != "": return
	if not ranges.ready:
		ranges.prepare_step(maxi(12, batch))
		return
	if samples >= target:
		if solve_enabled:
			if solver == null:
				solver = River.new(state, 2400 if precision else 1200, precision)
				solver_started_ms = Time.get_ticks_msec()
			# UI may set a wall-clock budget. Headless numerical tests have no time cutoff.
			if solver_budget_ms > 0 and Time.get_ticks_msec() - solver_started_ms >= solver_budget_ms:
				solver_timed_out = true
				return
			solver.step()
		return
	for iteration in range(mini(batch, target - samples)):
		var holes: Array = []
		for retry in range(64):
			attempts += 1
			holes = ranges.draw_joint(rng)
			if not holes.is_empty(): break
		if holes.is_empty():
			if attempts > target * 500:
				error = "范围冲突过多，未得到足够有效样本；本次不提供建议。"
			return
		var used: Array = []
		for hole in holes: used.append_array(hole)
		var pool = unknown.filter(func(c): return c not in used)
		var missing: int = 5 - state.board.size()
		for index in range(missing):
			var other = rng.randi_range(index, pool.size() - 1)
			var card = pool[index]
			pool[index] = pool[other]
			pool[other] = card
		var board: Array = state.board + pool.slice(0, missing)
		var scores = {0: Rank.score(state.hole + board)}
		for i in range(opponents.size()): scores[opponents[i]] = Rank.score(holes[i] + board)
		var best: int = scores.values().max()
		var tied: int = scores.values().count(best)
		if scores[0] == best:
			equity_sum += 1.0 / tied
			if tied == 1: wins += 1
			else: ties += 1
		var returned: float = 0.0
		for tier in tiers:
			var top: int = -1
			var count: int = 0
			for id in tier.eligible:
				if scores[id] > top:
					top = scores[id]
					count = 1
				elif scores[id] == top: count += 1
			if scores[0] == top: returned += float(tier.amount) / count
		return_sum += returned
		return_square_sum += returned * returned
		samples += 1

func is_done() -> bool:
	return error != "" or (samples >= target and (not solve_enabled or solver_timed_out or (solver != null and (not solver.supported or solver.iterations >= solver.target))))

func progress_text() -> String:
	if ranges != null and not ranges.ready: return "正在更新对手范围 · %d / %d 组合" % [ranges.cursor, ranges.combos.size()]
	if samples < target: return "正在估算范围权益 · %d / %d" % [samples, target]
	if solver != null and solver.ready: return "正在求解河牌抽象策略 · %d / %d" % [solver.iterations, solver.target]
	return "正在准备河牌策略的双方公开范围…"

func result() -> Dictionary:
	if error != "": return {"error": error}
	if samples == 0: return {}
	var equity: float = equity_sum / samples
	var expected_return: float = return_sum / samples
	var variance: float = maxf(0.0, return_square_sum / samples - expected_return * expected_return)
	var ev: float = expected_return - cost
	var uncertainty: float = 1.96 * sqrt(variance / samples)
	var action: String = "check" if state.legal.check else "call"
	var reason: String
	var amount: int = 0
	if cost > 0 and ev < -maxf(uncertainty, state.big_blind * 0.15):
		action = "fold"
		reason = "按公开行动推断的对手范围，预计可分回的筹码不足以覆盖跟注成本，倾向弃牌。"
	elif cost > 0:
		reason = "跟注成本与预计可分回的筹码相容；先控制投入，留意后续下注压力。"
		if absf(ev) <= uncertainty: reason = "这是接近临界的决策，模拟误差内难以区分跟注与弃牌；建议控制投入，并结合对手的实际范围判断。"
	else:
		reason = "可以免费继续看牌；牌力优势不足以明确支持价值下注时，过牌控制底池。"
	# Conservative teaching heuristic, NOT a solver or an optimal EV comparison.
	var strong: bool = equity > maxf(0.60, 1.0 / (opponents.size() + 1) + 0.20)
	if strong and state.legal.get("raise", false) and ev >= uncertainty:
		action = "raise"
		amount = Sizing.from_bb(3.0, state.big_blind, state.legal) if state.phase == "preflop" and state.current_bet <= state.big_blind else Sizing.from_pot(0.5, state)
		reason = "相对推断范围有牌力优势，可考虑价值下注。此金额是经验档位，仍需考虑对手继续范围；不是加注 EV 的最优解。"
	var strategy: Dictionary = solver.result() if solver != null else {"supported": false, "reason": "此处使用范围权益与底池赔率教学，未运行均衡求解。"}
	if strategy.is_empty() and solver != null:
		strategy = {"supported": false, "preparing": solver.supported, "precision": precision, "reason": "抽象树仍在准备中，尚无可用策略频率。"}
	if solver_timed_out:
		strategy["budget_limited"] = true
		strategy["converged"] = false
		strategy["reason"] = "已达本次计算时间预算；当前频率仅供观察，继续精细计算可追加预算。" + strategy.get("reason", "")
	if strategy.get("supported", false) and strategy.converged:
		var most = strategy.frequencies[0]
		for choice in strategy.frequencies:
			if choice.frequency > most.frequency: most = choice
		action = most.action
		amount = most.amount
		reason = "频率来自双方范围的受限博弈：下注既可能获取价值，也可能用弱牌争取弃牌。下方 EV 比较的是你所在牌力档位，不能只按裸胜率决定，也不应每次都选最高频行动。"
	return {"equity": equity, "win": float(wins) / samples, "tie": float(ties) / samples,
		"pot_equity": expected_return / eligible_pot if eligible_pot > 0 else 0.0,
		"cost": cost, "eligible_pot": eligible_pot, "odds": float(cost) / eligible_pot if eligible_pot > 0 else 0.0,
		"call_ev": ev, "ev_error": uncertainty, "samples": samples, "opponents": opponents.size(),
		"action": action, "amount": amount, "reason": reason, "ranges": ranges.summaries,
		"strategy": strategy, "model": Ranges.VERSION, "acceptance": float(samples) / maxi(1, attempts),
		"equity_error": 0.98 / sqrt(float(samples))}
