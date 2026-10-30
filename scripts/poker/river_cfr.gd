extends RefCounted
## CFR for a precisely defined, two-player zero-sum river abstraction.
## Normal: 8 rank buckets/64 samples/2 aggressions; fine: 12/96/3.
## Multi-size raises and effective all-in. Exploitability only covers this abstraction.
const VERSION = "river-3-multisize"
const Ranges = preload("res://scripts/poker/range_model.gd")
const Rank = preload("res://scripts/poker/fast_rank.gd")
const BUCKETS = 8
const RANGE_SAMPLES = 64
var bucket_count = BUCKETS
var range_sample_count = RANGE_SAMPLES
var aggression_limit = 2
var precision = 0
var chance_cursor = 0
var state: Dictionary
var model
var ids: Array = []
var nodes: Array = []
var terminals: Array = []
var regrets: Array = []
var averages: Array = []
var strategies: Array = []
var joint: Array = []
var outcomes: Array = []
var cutoffs: Array = []
var bet_sizes: Array = []
var iterations: int = 0
var target: int = 1200
var ready: bool = false
var supported: bool = false
var reason: String = "仅支持河牌剩两人、仍可合法行动且无边池的受限场景。"
var half_pot: float = 0.0
var checked_to_hero: bool = false
var ranked_combos: Array = []
var rank_cursor: int = 0
var root_actions: Array = []
var initial_bets: Array = [0, 0]
var caps: Array = [0, 0]
var prior_raises: int = 0
var initial_increment: int = 0
var extended_tree: bool = false

func _init(public_state: Dictionary, iteration_count: int = 1200, detail: int = 0) -> void:
	precision = clampi(detail, 0, 1)
	if precision == 1:
		bucket_count = 12
		range_sample_count = 96
		aggression_limit = 3
	state = public_state
	target = iteration_count
	if state.board.size() != 5:
		reason = "尚未到河牌：当前提供范围权益与价格分析，未求解后续街。"
		return
	for seat in state.seats:
		if seat.in_hand and not seat.folded: ids.append(seat.id)
	if ids.size() != 2 or 0 not in ids:
		reason = "仍有多名玩家：本求解器只覆盖剩两人的河牌，不将双人频率套用到多人。"
		return
	ids.erase(0)
	ids.push_front(0)
	var hero = state.seats[0]
	var opponent = state.seats[ids[1]]
	var due = maxi(0, opponent.street_bet - hero.street_bet)
	if due != state.legal.call_amount or due > hero.stack or opponent.total_bet - hero.total_bet != due:
		reason = "存在短码跟注或之前的贡献差：当前不求解边池或不同权益资格。"
		return
	for seat in state.seats:
		if seat.total_bet > hero.total_bet and seat.id != opponent.id:
			reason = "有其他座位的超额贡献：当前不求解这类边池。"
			return
	if hero.stack <= 0 or (due == 0 and (opponent.stack <= 0 or not state.legal.get("raise", false))): return
	initial_bets = [hero.street_bet, opponent.street_bet]
	caps = [hero.street_bet + hero.stack, opponent.street_bet + opponent.stack]
	initial_increment = maxi(state.big_blind, state.legal.min_raise_to - state.current_bet)
	prior_raises = state.actions.filter(func(a): return a.board.size() == 5 and a.action == "raise").size()
	# A current bet exists even in a minimal externally constructed snapshot.
	if due > 0: prior_raises = maxi(1, prior_raises)
	checked_to_hero = due == 0 and state.actions.any(func(a): return a.seat == ids[1] and a.board.size() == 5 and a.action == "check")
	half_pot = float(state.pot) / 2.0
	# Both players' priors depend only on public history, never hero's actual cards.
	model = Ranges.new(state, ids, state.board)
	supported = true
	reason = "%d 档牌力、每方 %d 个范围样本；三分之一/半池/满池/有效全押，最小/半池/底池/有效全押再加注。每条分支最多 %d 次进攻（含已发生的下注与加注）；档内阻断差异被合并。" % [bucket_count, range_sample_count, aggression_limit]

func _bucket(score: int) -> int:
	for i in range(cutoffs.size()):
		if score <= cutoffs[i]: return i
	return bucket_count - 1

func prepare_step() -> void:
	if not supported or ready: return
	if not model.ready:
		model.prepare_step(12)
		return
	if rank_cursor < model.combos.size():
		var until = mini(model.combos.size(), rank_cursor + 24)
		while rank_cursor < until:
			ranked_combos.append({"index": rank_cursor, "score": Rank.score(model.combos[rank_cursor] + state.board)})
			rank_cursor += 1
		return
	var ranked = ranked_combos
	ranked.sort_custom(func(a, b): return a.score < b.score)
	for i in range(1, bucket_count): cutoffs.append(ranked[mini(ranked.size() - 1, int(ranked.size() * i / bucket_count))].score)
	var hands: Array = []
	for id in ids:
		var samples: Array = []
		var cdf: float = 0.0
		var next_sample: int = 0
		for entry in ranked:
			cdf += model.weights[id][entry.index]
			while next_sample < range_sample_count and (next_sample + 0.5) / range_sample_count <= cdf + 1e-10:
				samples.append({"cards": model.combos[entry.index], "score": entry.score, "type": _bucket(entry.score)})
				next_sample += 1
		hands.append(samples)
	for i in range(bucket_count):
		joint.append([])
		outcomes.append([])
		for j in range(bucket_count):
			joint[i].append(0.0)
			outcomes[i].append(0.0)
	var total: float = 0.0
	for a in hands[0]:
		for b in hands[1]:
			if a.cards[0] in b.cards or a.cards[1] in b.cards: continue
			joint[a.type][b.type] += 1.0
			outcomes[a.type][b.type] += signi(a.score - b.score)
			total += 1.0
	if total == 0:
		supported = false
		reason = "抽象范围没有有效的不冲突组合，无法求解。"
		return
	for i in range(bucket_count):
		for j in range(bucket_count):
			if joint[i][j] > 0: outcomes[i][j] /= joint[i][j]
			joint[i][j] /= total
	_build_river_tree()
	ready = true

func _terminal(multiplier: float, constant: float) -> int:
	terminals.append({"m": multiplier, "c": constant})
	return -terminals.size()

func _build_river_tree() -> void:
	extended_tree = true
	nodes.clear()
	terminals.clear()
	regrets.clear()
	averages.clear()
	strategies.clear()
	root_actions.clear()
	_river_node(0, initial_bets.duplicate(), initial_increment, prior_raises, checked_to_hero)
	for node in nodes:
		for bucket in range(bucket_count):
			var zero: Array = []
			var uniform: Array = []
			for action in node.actions:
				zero.append(0.0)
				uniform.append(1.0 / node.actions.size())
			regrets.append(zero.duplicate())
			averages.append(zero.duplicate())
			strategies.append(uniform)

func _showdown(bets: Array) -> int:
	var future0 = bets[0] - initial_bets[0]
	var future1 = bets[1] - initial_bets[1]
	# Center at P/2 to obtain a zero-sum game even when facing a prior bet.
	return _terminal(half_pot + float(future0 + future1) / 2, float(future1 - future0) / 2)

func _river_node(player: int, bets: Array, increment: int, aggression_count: int, checked: bool) -> int:
	var index = nodes.size()
	var actions: Array = []
	var children: Array = []
	nodes.append({"player": player, "actions": actions, "children": children, "bets": bets.duplicate()})
	var due = bets[1 - player] - bets[player]
	if due > 0:
		actions.append("fold")
		var future = bets[player] - initial_bets[player]
		children.append(_terminal(0.0, -half_pot - future if player == 0 else half_pot + future))
		if index == 0: root_actions.append({"action": "fold", "amount": 0})
		actions.append("call")
		var called = bets.duplicate()
		called[player] += due
		children.append(_showdown(called))
		if index == 0: root_actions.append({"action": "call", "amount": 0})
	else:
		actions.append("check")
		if index == 0: root_actions.append({"action": "check", "amount": 0})
		children.append(_showdown(bets) if checked else _river_node(1 - player, bets, increment, aggression_count, true))
	var cap = mini(caps[0], caps[1])
	var current = maxi(bets[0], bets[1])
	var can_raise = aggression_count < aggression_limit and cap > current and (index != 0 or state.legal.get("raise", false))
	if not can_raise: return index
	var minimum = current + increment
	var pot_now = state.pot + bets[0] - initial_bets[0] + bets[1] - initial_bets[1]
	var candidates: Array = [minimum, current + roundi((pot_now + due) * 0.5), current + pot_now + due, cap] if due > 0 else [bets[player] + roundi(pot_now / 3.0), bets[player] + roundi(pot_now * 0.5), bets[player] + pot_now, cap]
	var sizes: Array = []
	for target_size in candidates:
		var size = mini(cap, maxi(minimum, int(target_size)))
		if size < minimum and size != caps[player]: continue
		if size in sizes: continue
		sizes.append(size)
		actions.append("raise_%d" % size)
		if index == 0: root_actions.append({"action": "raise", "amount": size})
		var raised = bets.duplicate()
		raised[player] = size
		children.append(_river_node(1 - player, raised, maxi(increment, size - current), aggression_count + 1, false))
	return index

func _build_tree() -> void:
	var actions: Array = ["check"]
	for size in bet_sizes: actions.append("bet_%d" % size)
	nodes = [{"player": 0, "actions": actions, "children": [1]},
		{"player": 1, "actions": actions, "children": [_terminal(half_pot, 0.0)]}]
	if checked_to_hero: nodes = [{"player": 0, "actions": actions, "children": [_terminal(half_pot, 0.0)]}]
	for parent in range(1 if checked_to_hero else 2):
		for size in bet_sizes:
			var child = nodes.size()
			nodes[parent].children.append(child)
			nodes.append({"player": 1 - parent, "actions": ["fold", "call"],
				"children": [_terminal(0.0, half_pot if parent == 0 else -half_pot), _terminal(half_pot + size, 0.0)]})
	for node in nodes:
		for bucket in range(bucket_count):
			var zero: Array = []
			var uniform: Array = []
			for a in node.actions:
				zero.append(0.0)
				uniform.append(1.0 / node.actions.size())
			regrets.append(zero.duplicate())
			averages.append(zero.duplicate())
			strategies.append(uniform)

func step(batch: int = 1) -> void:
	if not supported: return
	if not ready:
		prepare_step()
		return
	# Slice chance traversal while retaining ONE frozen profile for the entire iteration.
	# Regrets from earlier pairs cannot influence the remaining pairs in that iteration.
	for pair in range(maxi(1, batch) * 8):
		if iterations >= target: return
		if chance_cursor == 0:
			for info in range(regrets.size()): strategies[info] = _normalize(regrets[info])
		var a = int(chance_cursor / bucket_count)
		var b = chance_cursor % bucket_count
		if joint[a][b] > 0: _walk(0, a, b, 1.0, 1.0, joint[a][b], outcomes[a][b])
		chance_cursor += 1
		if chance_cursor == bucket_count * bucket_count:
			chance_cursor = 0
			iterations += 1

static func _normalize(values: Array) -> Array:
	var total: float = 0.0
	for value in values: total += maxf(0.0, value)
	var result: Array = []
	for value in values: result.append(maxf(0.0, value) / total if total > 1e-18 else 1.0 / values.size())
	return result

func _walk(node_id: int, a: int, b: int, reach0: float, reach1: float, chance: float, outcome: float) -> float:
	if node_id < 0:
		var term = terminals[-node_id - 1]
		return term.m * outcome + term.c
	var node = nodes[node_id]
	var player: int = node.player
	var info: int = node_id * bucket_count + (a if player == 0 else b)
	var profile: Array = strategies[info]
	var utilities: Array = []
	var value: float = 0.0
	for action in range(profile.size()):
		var result = _walk(node.children[action], a, b, reach0 * (profile[action] if player == 0 else 1.0),
			reach1 * (profile[action] if player == 1 else 1.0), chance, outcome)
		utilities.append(result)
		value += profile[action] * result
	for action in range(profile.size()):
		regrets[info][action] += chance * (reach1 if player == 0 else reach0) * (utilities[action] - value) * (1.0 if player == 0 else -1.0)
		averages[info][action] += chance * (reach0 if player == 0 else reach1) * profile[action]
	return value

func profile() -> Array:
	var result: Array = []
	for values in averages: result.append(_normalize(values))
	return result

func exploitability() -> float:
	var avg = profile()
	var best: float = 0.0
	for player in range(2):
		for own in range(bucket_count):
			var belief: Array = []
			for other in range(bucket_count): belief.append(joint[own][other] if player == 0 else joint[other][own])
			best += _best_response(0, player, own, belief, avg)
	return maxf(0.0, best / 2.0)

func _best_response(node_id: int, player: int, own: int, belief: Array, avg: Array) -> float:
	if node_id < 0:
		var value: float = 0.0
		var term = terminals[-node_id - 1]
		for other in range(bucket_count):
			var outcome: float = outcomes[own][other] if player == 0 else outcomes[other][own]
			value += belief[other] * (term.m * outcome + term.c) * (1.0 if player == 0 else -1.0)
		return value
	var node = nodes[node_id]
	var values: Array = []
	for action in range(node.actions.size()):
		var next_belief = belief.duplicate()
		if node.player != player:
			for other in range(bucket_count): next_belief[other] *= avg[node_id * bucket_count + other][action]
		values.append(_best_response(node.children[action], player, own, next_belief, avg))
	# Max AFTER summing private opponent types: no clairvoyant best response.
	if node.player == player: return values.max()
	var total: float = 0.0
	for value in values: total += value
	return total

func _expected(node_id: int, own: int, belief: Array, avg: Array) -> float:
	if node_id < 0:
		var term = terminals[-node_id - 1]
		var value: float = 0.0
		for other in range(bucket_count): value += belief[other] * (term.m * outcomes[own][other] + term.c)
		return value
	var node = nodes[node_id]
	var total: float = 0.0
	for action in range(node.actions.size()):
		var next_belief = belief.duplicate()
		for other in range(bucket_count): next_belief[other] *= avg[node_id * bucket_count + (own if node.player == 0 else other)][action]
		total += _expected(node.children[action], own, next_belief, avg)
	return total

func result() -> Dictionary:
	if not supported: return {"supported": false, "reason": reason}
	if not ready or iterations == 0: return {}
	var bucket = _bucket(Rank.score(state.hole + state.board))
	var mass: float = 0.0
	for p in joint[bucket]: mass += p
	if mass <= 0: return {"supported": false, "reason": "当前手牌所属档位未被范围采样覆盖，无法给出可靠频率。"}
	var frequencies: Array = []
	var all_profiles = profile()
	var avg: Array = all_profiles[bucket]
	for i in range(avg.size()):
		var ev = _expected(nodes[0].children[i], bucket, joint[bucket], all_profiles) / mass + half_pot
		var move = root_actions[i] if extended_tree else {"action": "check" if i == 0 else "raise", "amount": 0 if i == 0 else bet_sizes[i - 1] + state.seats[0].street_bet}
		frequencies.append({"action": move.action, "amount": move.amount, "frequency": avg[i], "ev": ev})
	var epsilon = exploitability()
	return {"supported": true, "scope": "河牌抽象 CFR", "reason": reason, "frequencies": frequencies,
		"iterations": iterations, "exploitability": epsilon, "converged": epsilon <= state.pot * 0.01,
		"tolerance": state.pot * 0.01, "bucket": bucket, "range_samples": range_sample_count, "nodes": nodes.size(), "buckets": bucket_count, "precision": precision, "aggression_limit": aggression_limit, "version": VERSION, "facing_bet": state.legal.call_amount > 0}
