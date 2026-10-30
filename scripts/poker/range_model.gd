extends RefCounted
## Public-action Bayesian range model. Likelihoods are explicit expert priors,
## not solver charts or fitted population data. Preparation is time-slice friendly.
const Rank = preload("res://scripts/poker/fast_rank.gd")
const VERSION = "range-1"
var state: Dictionary
var ids: Array
var combos: Array = []
var weights: Dictionary = {}
var cdfs: Dictionary = {}
var summaries: Array = []
var cursor: int = 0
var ready: bool = false
var observations: Dictionary = {}
var positions: Dictionary = {}
var depths: Dictionary = {}

static func public_actions(view: Dictionary) -> Array:
	var out: Array = []
	var board: Array = []
	var bets: Dictionary = {}
	var pot: int = 0
	var highest: int = 0
	var raises: int = 0
	var active: int = view.seats.filter(func(s): return s.in_hand).size()
	for event in view.get("events", []):
		if not event is Dictionary: continue
		match event.get("kind", ""):
			"blind":
				var seat = int(event.get("seat", -1))
				if seat < 0 or seat >= view.seats.size(): continue
				var amount = maxi(0, int(event.get("amount", 0)))
				bets[seat] = amount
				pot += amount
				highest = maxi(highest, amount)
			"street":
				var revealed: Array = event.get("board", [])
				# Never accept a street beyond the currently visible board.
				if revealed.size() > view.board.size() or revealed != view.board.slice(0, revealed.size()): break
				board = revealed.duplicate()
				bets.clear()
				highest = 0
				raises = 0
			"action":
				var seat = int(event.get("seat", -1))
				var action = str(event.get("action", ""))
				if seat < 0 or seat >= view.seats.size() or action not in ["fold", "check", "call", "raise"]: continue
				var paid = maxi(0, int(event.get("paid", 0)))
				var to = maxi(0, int(event.get("to", 0)))
				out.append({"seat": seat, "action": action, "board": board.duplicate(),
					"pot": pot, "cost": maxi(0, highest - int(bets.get(seat, 0))),
					"size": maxi(0, to - highest), "raises": raises, "active": active})
				pot += paid
				bets[seat] = to
				highest = maxi(highest, to)
				if action == "raise": raises += 1
				if action == "fold": active -= 1
			"finish": break
	return out

static func position(state_view: Dictionary, seat_id: int) -> String:
	var funded: Array = []
	for seat in state_view.seats:
		if seat.in_hand: funded.append(seat.id)
	var button = int(state_view.get("button", 0))
	var start = funded.find(button)
	if start < 0 or seat_id not in funded: return "未知位置"
	var offset = (funded.find(seat_id) - start + funded.size()) % funded.size()
	if offset == 0: return "BTN/SB" if funded.size() == 2 else "BTN"
	if funded.size() == 2: return "BB"
	if offset == 1: return "SB"
	if offset == 2: return "BB"
	if offset == funded.size() - 1: return "CO"
	if offset == funded.size() - 2 and funded.size() >= 6: return "HJ"
	return "UTG" if offset == 3 else "MP"

static func preflop_strength(hole: Array) -> float:
	var high = maxi(hole[0] % 13, hole[1] % 13) + 2
	var low = mini(hole[0] % 13, hole[1] % 13) + 2
	if high == low: return 0.52 + float(high - 2) * 0.038
	var value = float(high + low - 4) / 30.0
	if int(hole[0] / 13) == int(hole[1] / 13): value += 0.09
	if high - low == 1: value += 0.05
	elif high - low > 4: value -= 0.08
	if high == 14 and low <= 5: value += 0.04
	return clampf(value, 0.03, 0.94)

static func features(hole: Array, board: Array) -> Dictionary:
	if board.size() < 3: return {"strength": preflop_strength(hole), "draw": 0.0}
	var score = Rank.score(hole + board)
	var category = int(score / 759375)
	var kicker = int(score / 50625) % 15
	var strength: float = [0.13, 0.40, 0.66, 0.78, 0.86, 0.91, 0.96, 0.99, 1.0][category]
	strength += float(kicker - 8) * (0.018 if category <= 1 else 0.004)
	# A pair on the board alone is not a strong private pair.
	if category <= 2 and board.size() >= 3:
		var paired_private = board.any(func(c): return c % 13 == hole[0] % 13 or c % 13 == hole[1] % 13) or hole[0] % 13 == hole[1] % 13
		if not paired_private: strength -= 0.18
	var draw: float = 0.0
	if board.size() < 5:
		var suits = [0, 0, 0, 0]
		var mask: int = 0
		for card in hole + board:
			suits[int(card / 13)] += 1
			mask |= 1 << (card % 13 + 2)
		if suits.max() == 4: draw += 0.20
		if mask & (1 << 14): mask |= 1 << 1
		var missing: Array = []
		for high in range(5, 15):
			var absent: Array = []
			for rank in range(high - 4, high + 1):
				if not mask & (1 << rank): absent.append(rank)
			if absent.size() == 1 and absent[0] not in missing: missing.append(absent[0])
		draw += minf(0.16, missing.size() * 0.08)
	return {"strength": clampf(strength, 0.03, 1.0), "draw": draw}

static func likelihood(hole: Array, observation: Dictionary, position_name: String, depth: float) -> float:
	var feature = features(hole, observation.board)
	var preflop: bool = observation.board.is_empty()
	var late: bool = position_name in ["BTN", "BTN/SB", "CO", "BB"]
	var pressure = float(observation.cost) / maxf(1.0, observation.pot + observation.cost)
	var size_ratio = float(observation.size) / maxf(1.0, observation.pot + observation.cost)
	var threshold = 0.59 if preflop else 0.60
	if preflop:
		threshold += 0.055 * mini(observation.raises, 3)
		threshold += 0.045 if not late and observation.active >= 6 else 0.0
		threshold -= 0.10 if observation.active == 2 else 0.04 if late else 0.0
		threshold -= 0.04 if depth <= 25 else 0.0
	else: threshold += minf(0.10, maxf(0, observation.active - 2) * 0.025)
	threshold += minf(0.12, size_ratio * 0.08)
	var aggression = 1.0 / (1.0 + exp(-(feature.strength + feature.draw * 0.6 - threshold) * 13.0))
	var continue_chance = 1.0 / (1.0 + exp(-(feature.strength + feature.draw - pressure - (0.19 if preflop else 0.10)) * 12.0))
	var raise_chance = clampf(0.035 + aggression * 0.72 + feature.draw * 0.15, 0.025, 0.88)
	match observation.action:
		"raise": return raise_chance
		"call": return maxf(0.025, (1.0 - raise_chance) * continue_chance)
		"fold": return maxf(0.025, (1.0 - raise_chance) * (1.0 - continue_chance))
		"check": return maxf(0.025, 1.0 - raise_chance)
	return 1.0

func _init(public_state: Dictionary, seat_ids: Array, blockers: Array) -> void:
	state = public_state
	ids = seat_ids.duplicate()
	for id in ids:
		weights[id] = []
		observations[id] = state.get("actions", []).filter(func(a): return a.seat == id)
		positions[id] = position(state, id)
		var largest_other: int = 0
		for seat in state.seats:
			if seat.id != id and seat.in_hand: largest_other = maxi(largest_other, seat.stack + seat.total_bet)
		depths[id] = float(mini(largest_other, state.seats[id].stack + state.seats[id].total_bet)) / state.big_blind
	for a in range(52):
		if a in blockers: continue
		for b in range(a + 1, 52):
			if b not in blockers: combos.append([a, b])

func prepare_step(batch: int = 16) -> void:
	if ready: return
	for i in range(cursor, mini(combos.size(), cursor + batch)):
		for id in ids:
			var weight: float = 1.0
			for observation in observations[id]: weight *= likelihood(combos[i], observation, positions[id], depths[id])
			weights[id].append(maxf(1e-18, weight))
	cursor = mini(combos.size(), cursor + batch)
	if cursor == combos.size(): _finish()

func _finish() -> void:
	for id in ids:
		var total: float = 0.0
		for w in weights[id]: total += w
		var cumulative: Array = []
		var sum_p: float = 0.0
		var square: float = 0.0
		var classes: Dictionary = {}
		var class_counts: Dictionary = {}
		for i in range(combos.size()):
			var probability: float = weights[id][i] / total
			weights[id][i] = probability
			sum_p += probability
			square += probability * probability
			cumulative.append(sum_p)
			var name_text = hand_class(combos[i])
			classes[name_text] = classes.get(name_text, 0.0) + probability
			class_counts[name_text] = class_counts.get(name_text, 0) + 1
		cumulative[-1] = 1.0
		cdfs[id] = cumulative
		var ranked: Array = []
		for name_text in classes: ranked.append({"hand": name_text, "mass": classes[name_text]})
		ranked.sort_custom(func(a, b): return a.mass > b.mass)
		summaries.append({"seat": id, "position": position(state, id), "actions": observations[id].size(),
			"effective_combos": 1.0 / square, "available_combos": combos.size(), "top": ranked.slice(0, 6), "classes": classes, "class_counts": class_counts})
	ready = true

static func hand_class(hole: Array) -> String:
	var ranks = "23456789TJQKA"
	var high = maxi(hole[0] % 13, hole[1] % 13)
	var low = mini(hole[0] % 13, hole[1] % 13)
	return ranks[high] + ranks[low] + ("" if high == low else "s" if int(hole[0] / 13) == int(hole[1] / 13) else "o")

func at_quantile(id: int, probability: float) -> Array:
	var cdf: Array = cdfs[id]
	var lo: int = 0
	var hi: int = cdf.size() - 1
	while lo < hi:
		var mid: int = (lo + hi) / 2
		if probability < cdf[mid]: hi = mid
		else: lo = mid + 1
	return combos[lo]

func draw_joint(rng: RandomNumberGenerator) -> Array:
	# Independent draws, rejecting the ENTIRE deal on collision, exactly target
	# product(range weights) conditioned on disjoint cards. No seat-order bias.
	var dealt: Array = []
	var used: Array = []
	for id in ids:
		var hole = at_quantile(id, rng.randf())
		if hole[0] in used or hole[1] in used: return []
		used.append_array(hole)
		dealt.append(hole)
	return dealt
