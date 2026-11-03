extends RefCounted
## CFR for a two-player turn-and-river abstraction.
## Turn types: 5 buckets of average river strength, so draws are not lumped with air.
## River: a fixed sample of river cards (5, fine 8), each with 4 (fine 5) strength buckets;
## Vector-form CFR+ with alternating updates and linear averaging;
## river information sets keep the turn bucket (perfect recall).
## Each street: check / two-thirds pot / all-in; facing a bet fold / call / pot raise / all-in,
## at most two aggressive actions per street (fine: three).
## Exploitability is the exact best response inside this abstraction.
const VERSION = "turn-1"
const Ranges = preload("res://scripts/poker/range_model.gd")
const Rank = preload("res://scripts/poker/fast_rank.gd")
const TB = 5
var RB = 4
var river_count = 5
var samples_per_seat = 48
var aggression_limit = 2
var precision = 0
var state: Dictionary
var model
var ids: Array = []
var supported: bool = false
var ready: bool = false
var reason: String = "仅支持转牌剩两人、仍可合法行动且无边池的受限场景。"
var target: int = 600
var iterations: int = 0
var half_pot: float = 0.0
var stacks: Array = [0, 0]
var initial_street: Array = [0, 0]
var prior_raises: int = 0
var checked_to_hero: bool = false
var river_first: int = 0
var root_actions: Array = []
# Abstraction tables.
var rivers: Array = []
var hands: Array = [[], []]       # per seat: {"cards", "turn": bucket, "river": [bucket or -1 per river card]}
var turn_joint: Array = []        # [T0][T1] probability
var turn_outcome: Array = []      # [T0][T1] mean showdown sign over rivers
var cells: Array = []             # [T0][T1] -> [{"k", "r0", "r1", "p", "o"}], p conditional on (T0, T1)
var hs_cutoffs: Array = []
var river_cutoffs: Array = []     # per river card
# Tree.
var nodes: Array = []
var terminals: Array = []
# Per-node [type][action] tables; types are turn T or river (T * K + k) * RB + R.
var regrets: Array = []
var averages: Array = []
var river_types: int = 0
var jt := PackedFloat64Array()
var ot := PackedFloat64Array()
var e0 := PackedInt32Array()
var e1 := PackedInt32Array()
var ew := PackedFloat64Array()
var eo := PackedFloat64Array()
var prepare_phase: int = 0
var prepare_cursor: int = 0
var scores: Array = [[], []]      # per seat, per sample, per river: score or -1

func _init(public_state: Dictionary, iteration_count: int = 600, detail: int = 0) -> void:
	precision = clampi(detail, 0, 1)
	if precision == 1:
		river_count = 8
		RB = 5
		samples_per_seat = 64
		aggression_limit = 3
	state = public_state
	target = iteration_count
	if state.board.size() != 4:
		reason = "转牌求解只在转牌圈运行。"
		return
	for seat in state.seats:
		if seat.in_hand and not seat.folded: ids.append(seat.id)
	if ids.size() != 2 or 0 not in ids:
		reason = "仍有多名玩家：转牌求解只覆盖剩两人的底池，不将双人频率套用到多人。"
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
	stacks = [hero.stack, opponent.stack]
	initial_street = [hero.street_bet, opponent.street_bet]
	prior_raises = state.actions.filter(func(a): return a.board.size() == 4 and a.action == "raise").size()
	if due > 0: prior_raises = maxi(1, prior_raises)
	checked_to_hero = due == 0 and state.actions.any(func(a): return a.seat == ids[1] and a.board.size() == 4 and a.action == "check")
	half_pot = float(state.pot) / 2.0
	# Postflop the first live seat after the button acts first on the river.
	for offset in range(1, state.seats.size() + 1):
		var id = (int(state.get("button", 0)) + offset) % state.seats.size()
		if id == 0 or id == ids[1]:
			river_first = 0 if id == 0 else 1
			break
	# Ranges and river cards depend only on public information, never hero's cards.
	model = Ranges.new(state, ids, state.board)
	var unknown: Array = []
	for card in range(52):
		if card not in state.board: unknown.append(card)
	var offset = absi(str(state.board).hash()) % unknown.size()
	for i in range(river_count): rivers.append(unknown[(offset + i * unknown.size() / river_count) % unknown.size()])
	supported = true
	reason = "转牌 %d 档 × 河牌 %d 张代表牌 × %d 档；每方 %d 个范围样本。每条街过牌 / 三分之二池 / 全押，面对下注可底池加注或全押，每条街最多 %d 次进攻；河牌决策同时记得转牌档位。" % [TB, river_count, RB, samples_per_seat, aggression_limit]

## Time-sliced preparation: ranges, samples, river scores, buckets, joint tables, tree.
func prepare_step() -> void:
	if not supported or ready: return
	if not model.ready:
		model.prepare_step(12)
		return
	match prepare_phase:
		0:
			_sample_hands()
			prepare_phase = 1
		1:
			# River scores, a few samples per call.
			var seat = int(prepare_cursor / samples_per_seat)
			var until = mini(prepare_cursor + 8, samples_per_seat * 2)
			while prepare_cursor < until:
				seat = int(prepare_cursor / samples_per_seat)
				var h = hands[seat][prepare_cursor % samples_per_seat]
				var row: Array = []
				for r in rivers: row.append(-1 if r in h.cards else Rank.score(h.cards + state.board + [r]))
				scores[seat].append(row)
				prepare_cursor += 1
			if prepare_cursor >= samples_per_seat * 2: prepare_phase = 2
		2:
			_bucket_and_join()
			if not supported: return
			_build_tree()
			_allocate()
			ready = true

func _sample_hands() -> void:
	for s in range(2):
		var ranked: Array = []
		for i in range(model.combos.size()): ranked.append({"i": i, "score": Rank.score(model.combos[i] + state.board)})
		ranked.sort_custom(func(a, b): return a.score < b.score)
		var cdf = 0.0
		var next = 0
		for entry in ranked:
			cdf += model.weights[ids[s]][entry.i]
			while next < samples_per_seat and (next + 0.5) / samples_per_seat <= cdf + 1e-10:
				hands[s].append({"cards": model.combos[entry.i], "turn": 0, "river": []})
				next += 1
		while hands[s].size() < samples_per_seat: hands[s].append(hands[s][-1])

## Percentile of `score` among the pooled valid sample scores at river k.
func _percentile(pool: Array, score: int) -> float:
	var below = 0.0
	for v in pool:
		if v < score: below += 1.0
		elif v == score: below += 0.5
	return below / maxf(1.0, pool.size())

func _bucket_and_join() -> void:
	var pools: Array = []
	for k in range(rivers.size()):
		var pool: Array = []
		for s in range(2):
			for row in scores[s]:
				if row[k] >= 0: pool.append(row[k])
		pool.sort()
		pools.append(pool)
		var cut: Array = []
		for i in range(1, RB): cut.append(pool[mini(pool.size() - 1, int(pool.size() * i / RB))] if not pool.is_empty() else 0)
		river_cutoffs.append(cut)
	var strengths: Array = []
	for s in range(2):
		for n in range(samples_per_seat):
			var hs = _strength(scores[s][n], pools)
			hands[s][n].hs = hs
			strengths.append(hs)
			for k in range(rivers.size()): hands[s][n].river.append(-1 if scores[s][n][k] < 0 else _cut(river_cutoffs[k], scores[s][n][k]))
	strengths.sort()
	for i in range(1, TB): hs_cutoffs.append(strengths[int(strengths.size() * i / TB)])
	for s in range(2):
		for h in hands[s]: h.turn = _cut(hs_cutoffs, h.hs)
	var mass: Array = []
	var sums: Dictionary = {}
	for a in range(TB):
		turn_joint.append([])
		turn_outcome.append([])
		cells.append([])
		mass.append([])
		for b in range(TB):
			turn_joint[a].append(0.0)
			turn_outcome[a].append(0.0)
			cells[a].append([])
			mass[a].append(0.0)
	var total = 0.0
	for x in range(samples_per_seat):
		var ha = hands[0][x]
		for y in range(samples_per_seat):
			var hb = hands[1][y]
			if ha.cards[0] in hb.cards or ha.cards[1] in hb.cards: continue
			var valid: Array = []
			for k in range(rivers.size()):
				if scores[0][x][k] >= 0 and scores[1][y][k] >= 0 and rivers[k] not in ha.cards and rivers[k] not in hb.cards: valid.append(k)
			if valid.is_empty(): continue
			total += 1.0
			turn_joint[ha.turn][hb.turn] += 1.0
			for k in valid:
				var key = "%d/%d/%d/%d/%d" % [ha.turn, hb.turn, k, ha.river[k], hb.river[k]]
				var w = 1.0 / valid.size()
				if not sums.has(key): sums[key] = {"k": k, "r0": ha.river[k], "r1": hb.river[k], "p": 0.0, "o": 0.0}
				sums[key].p += w
				sums[key].o += w * signi(scores[0][x][k] - scores[1][y][k])
	if total == 0:
		supported = false
		reason = "抽象范围没有有效的不冲突组合，无法求解。"
		return
	for key in sums:
		var c = sums[key]
		var parts = key.split("/")
		var a = int(parts[0])
		var b = int(parts[1])
		c.o /= c.p
		c.p /= turn_joint[a][b]
		cells[a][b].append(c)
		turn_outcome[a][b] += c.p * c.o
	for a in range(TB):
		for b in range(TB): turn_joint[a][b] /= total

func _strength(row: Array, pools: Array) -> float:
	var sum = 0.0
	var n = 0
	for k in range(row.size()):
		if row[k] < 0: continue
		sum += _percentile(pools[k], row[k])
		n += 1
	return sum / maxi(1, n)

static func _cut(cutoffs: Array, value) -> int:
	for i in range(cutoffs.size()):
		if value <= cutoffs[i]: return i
	return cutoffs.size()

## Hero's own turn bucket from the same pooled samples.
func hero_bucket(hole: Array) -> int:
	var pools: Array = []
	var row: Array = []
	for k in range(rivers.size()):
		var pool: Array = []
		for s in range(2):
			for r in scores[s]:
				if r[k] >= 0: pool.append(r[k])
		pools.append(pool)
		row.append(-1 if rivers[k] in hole else Rank.score(hole + state.board + [rivers[k]]))
	return _cut(hs_cutoffs, _strength(row, pools))

# --- Tree -----------------------------------------------------------------
# A node: {"player", "actions", "children", "street", "river_root"}; a child is a node
# index (>= 0), a terminal (< 0), or a chance node {"chance": river subtree root}.

func _terminal(kind: String, m: float, c: float) -> int:
	terminals.append({"kind": kind, "m": m, "c": c})
	return -terminals.size()

func _showdown(put: Array, kind: String) -> int:
	return _terminal(kind, half_pot + float(put[0] + put[1]) / 2, float(put[1] - put[0]) / 2)

func _build_tree() -> void:
	_node(0, "turn", initial_street.duplicate(), [0, 0], maxi(state.big_blind, state.legal.min_raise_to - state.current_bet), prior_raises, checked_to_hero)

## street_bets: this street's totals; put: chips added from now on; returns node index.
func _node(player: int, street: String, street_bets: Array, put: Array, increment: int, aggression: int, checked: bool) -> int:
	var index = nodes.size()
	var actions: Array = []
	var children: Array = []
	nodes.append({"player": player, "actions": actions, "children": children, "street": street, "types": TB if street == "turn" else TB * river_count * RB})
	var due = street_bets[1 - player] - street_bets[player]
	var root = index == 0
	if due > 0:
		actions.append("fold")
		children.append(_terminal("fold", 0.0, -half_pot - put[0] if player == 0 else half_pot + put[1]))
		if root: root_actions.append({"action": "fold", "amount": 0})
		actions.append("call")
		var called_put = put.duplicate()
		called_put[player] += due
		children.append(_close(street, called_put))
		if root: root_actions.append({"action": "call", "amount": 0})
	else:
		actions.append("check")
		if root: root_actions.append({"action": "check", "amount": 0})
		children.append(_close(street, put) if checked else _node(1 - player, street, street_bets, put, increment, aggression, true))
	# Raise cap: what both players can still put in this street.
	var cap = mini(street_bets[0] + stacks[0] - put[0], street_bets[1] + stacks[1] - put[1])
	var current = maxi(street_bets[0], street_bets[1])
	if aggression >= aggression_limit or cap <= current or (root and not state.legal.get("raise", false)): return index
	var minimum = current + increment
	var pot_now = state.pot + put[0] + put[1]
	var candidates: Array = [current + pot_now + due, cap] if due > 0 else [street_bets[player] + roundi(pot_now * 0.66), cap]
	var sizes: Array = []
	for t in candidates:
		var size = mini(cap, maxi(minimum, int(t)))
		if size in sizes: continue
		sizes.append(size)
		actions.append("raise_%d" % size)
		if root: root_actions.append({"action": "raise", "amount": size})
		var raised_bets = street_bets.duplicate()
		var raised_put = put.duplicate()
		raised_put[player] += size - street_bets[player]
		raised_bets[player] = size
		children.append(_node(1 - player, street, raised_bets, raised_put, maxi(increment, size - current), aggression + 1, false))
	return index

## Betting closed on this street: river chance, or showdown.
func _close(street: String, put: Array) -> Variant:
	var all_in = put[0] >= stacks[0] or put[1] >= stacks[1]
	if street == "river": return _showdown(put, "river")
	if all_in: return _showdown(put, "turn")
	var root = _node(river_first, "river", [0, 0], put, state.big_blind, 0, false)
	return {"chance": root}

func _allocate() -> void:
	# Dense pair tables. Turn: index T0 * TB + T1. River entries share one river card k.
	river_types = TB * river_count * RB
	jt.resize(TB * TB)
	ot.resize(TB * TB)
	for a in range(TB):
		for b in range(TB):
			jt[a * TB + b] = turn_joint[a][b]
			ot[a * TB + b] = turn_outcome[a][b]
			for c in cells[a][b]:
				e0.append((a * river_count + c.k) * RB + c.r0)
				e1.append((b * river_count + c.k) * RB + c.r1)
				ew.append(turn_joint[a][b] * c.p)
				eo.append(c.o)
	for node in nodes:
		var n = node.types * node.actions.size()
		var r = PackedFloat64Array()
		r.resize(n)
		regrets.append(r)
		var avg = PackedFloat64Array()
		avg.resize(n)
		averages.append(avg)

static func _filled(n: int, value: float) -> PackedFloat64Array:
	var out = PackedFloat64Array()
	out.resize(n)
	out.fill(value)
	return out

## Regret matching+ (or the average) for every type at a node: row-major [type][action].
func _policy(node_id: int, use_average: bool) -> PackedFloat64Array:
	var node = nodes[node_id]
	var count: int = node.actions.size()
	var table: PackedFloat64Array = averages[node_id] if use_average else regrets[node_id]
	var out = PackedFloat64Array()
	out.resize(table.size())
	for t in range(node.types):
		var total = 0.0
		for a in range(count): total += maxf(0.0, table[t * count + a])
		for a in range(count): out[t * count + a] = maxf(0.0, table[t * count + a]) / total if total > 1e-18 else 1.0 / count
	return out

func step(batch: int = 1) -> void:
	if not supported: return
	if not ready:
		prepare_step()
		return
	for repeat in range(maxi(1, batch)):
		if iterations >= target: return
		_walk(0, _filled(TB, 1.0), _filled(TB, 1.0), 0, iterations % 2)
		iterations += 1

## Vector-form traversal. r0 / r1: reach of every type of each player on this street.
## mode 0: CFR+ update for `updating`; 1: average strategy; 2: best response for `updating`.
## Returns [v0, v1]: counterfactual values per type.
func _walk(child, r0: PackedFloat64Array, r1: PackedFloat64Array, mode: int, updating: int) -> Array:
	if child is Dictionary:
		# Turn to river: every (k, R) of a turn type inherits that type's reach.
		var per = river_count * RB
		var q0 = PackedFloat64Array()
		var q1 = PackedFloat64Array()
		q0.resize(river_types)
		q1.resize(river_types)
		for t in range(TB):
			for i in range(per):
				q0[t * per + i] = r0[t]
				q1[t * per + i] = r1[t]
		var river = _walk(child.chance, q0, q1, mode, updating)
		var v0 = _filled(TB, 0.0)
		var v1 = _filled(TB, 0.0)
		for t in range(TB):
			for i in range(per):
				v0[t] += river[0][t * per + i]
				v1[t] += river[1][t * per + i]
		return [v0, v1]
	if child < 0: return _terminal_values(terminals[-child - 1], r0, r1)
	var node = nodes[child]
	var player: int = node.player
	var count: int = node.actions.size()
	var types: int = node.types
	var policy = _policy(child, mode != 0)
	var own_reach: PackedFloat64Array = r0 if player == 0 else r1
	var results: Array = []
	for a in range(count):
		var next = PackedFloat64Array()
		next.resize(types)
		for t in range(types): next[t] = own_reach[t] * policy[t * count + a]
		results.append(_walk(node.children[a], next if player == 0 else r0, r1 if player == 0 else next, mode, updating))
	var mine = _filled(types, 0.0)
	var theirs = _filled(types, 0.0)
	var responding = mode == 2 and player == updating
	for t in range(types):
		var best = -INF
		for a in range(count):
			var u: float = results[a][player][t]
			theirs[t] += results[a][1 - player][t]
			if responding: best = maxf(best, u)
			else: mine[t] += policy[t * count + a] * u
		if responding: mine[t] = best
	if mode == 0 and player == updating:
		var r: PackedFloat64Array = regrets[child]
		var avg: PackedFloat64Array = averages[child]
		var weight = float(iterations + 1)
		for t in range(types):
			for a in range(count):
				var i = t * count + a
				r[i] = maxf(0.0, r[i] + results[a][player][t] - mine[t])
				avg[i] += weight * own_reach[t] * policy[i]
		regrets[child] = r
		averages[child] = avg
	return [mine, theirs] if player == 0 else [theirs, mine]

## Counterfactual payoff vectors at a terminal; player 1's payoff is the negative.
func _terminal_values(term: Dictionary, r0: PackedFloat64Array, r1: PackedFloat64Array) -> Array:
	var size = r0.size()
	var v0 = _filled(size, 0.0)
	var v1 = _filled(size, 0.0)
	if size == TB:
		# Turn: a fold, or an all-in showdown over the averaged rivers.
		for a in range(TB):
			for b in range(TB):
				var w = jt[a * TB + b]
				if w == 0.0: continue
				var pay = term.m * (ot[a * TB + b] if term.kind == "turn" else 0.0) + term.c
				v0[a] += w * r1[b] * pay
				v1[b] -= w * r0[a] * pay
		return [v0, v1]
	for i in range(e0.size()):
		var pay = term.m * (eo[i] if term.kind == "river" else 0.0) + term.c
		v0[e0[i]] += ew[i] * r1[e1[i]] * pay
		v1[e1[i]] -= ew[i] * r0[e0[i]] * pay
	return [v0, v1]

func exploitability() -> float:
	var total = 0.0
	for player in range(2):
		var values = _walk(0, _filled(TB, 1.0), _filled(TB, 1.0), 2, player)
		for t in range(TB): total += values[player][t]
	return maxf(0.0, total / 2.0)

func result() -> Dictionary:
	if not supported: return {"supported": false, "reason": reason}
	if not ready or iterations == 0: return {}
	var bucket = hero_bucket(state.hole)
	var mass = 0.0
	for b in range(TB): mass += jt[bucket * TB + b]
	if mass <= 0: return {"supported": false, "reason": "当前手牌所属档位未被范围采样覆盖，无法给出可靠频率。"}
	var node = nodes[0]
	var count: int = node.actions.size()
	var policy = _policy(0, true)
	var frequencies: Array = []
	for a in range(count):
		# Value of taking action a at the root with this bucket, then both play the average.
		var reach = _filled(TB, 0.0)
		reach[bucket] = 1.0
		var values = _walk(node.children[a], reach, _filled(TB, 1.0), 1, 0)
		frequencies.append({"action": root_actions[a].action, "amount": root_actions[a].amount, "frequency": policy[bucket * count + a], "ev": values[0][bucket] / mass + half_pot})
	var epsilon = exploitability()
	return {"supported": true, "kind": "turn", "scope": "转牌抽象 CFR", "reason": reason, "frequencies": frequencies,
		"iterations": iterations, "exploitability": epsilon, "converged": epsilon <= state.pot * 0.02,
		"tolerance": state.pot * 0.02, "bucket": bucket, "range_samples": samples_per_seat, "rivers": river_count, "nodes": nodes.size(), "precision": precision, "aggression_limit": aggression_limit, "version": VERSION, "facing_bet": state.legal.call_amount > 0}
