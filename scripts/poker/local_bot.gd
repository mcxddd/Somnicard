extends RefCounted
## Three distinct offline policies. Empirical difficulty, NOT solved GTO or a human rating.
## Uses ONLY actor's hole cards, public board, actions and stacks.
const Ranges = preload("res://scripts/poker/range_model.gd")
const Rank = preload("res://scripts/poker/fast_rank.gd")
const Sizing = preload("res://scripts/ui/bet_sizing.gd")
const Profiles = preload("res://scripts/poker/opponent_profiles.gd")
const VERSION = "opponent-3"
var samples: Array = []
var rng := RandomNumberGenerator.new()
var style: int = 0
var difficulty: int = 1

func _init(random_seed: int = -1, personality: int = 0, level: int = 1) -> void:
	style = clampi(personality, 0, 2)
	difficulty = clampi(level, 0, 2)
	if random_seed < 0: rng.randomize()
	else: rng.seed = random_seed

func style_name() -> String:
	return Profiles.LEVELS[difficulty] + " · " + Profiles.STYLES[style]

func choose(view: Dictionary) -> Dictionary:
	var legal: Dictionary = view.legal
	if legal.is_empty(): return {}
	if view.board.is_empty(): return _preflop(view)
	var own = view.seats[view.actor]
	var opponents = view.seats.filter(func(s): return s.id != view.actor and s.in_hand and not s.folded)
	var equity = _equity(view, opponents)
	var feature = Ranges.features(own.hole, view.board)
	feature.draw = _private_draw(own.hole, view.board)
	var cap: int = own.total_bet + legal.call_amount
	var eligible: int = legal.call_amount
	for seat in view.seats: eligible += mini(cap, seat.total_bet)
	var price = float(legal.call_amount) / maxi(1, eligible)
	var in_position = _in_position(view)
	var realization = 1.0 if view.board.size() == 5 else (0.94 if in_position else 0.84) - 0.035 * maxi(0, opponents.size() - 1)
	var aggression: float = [0.0, -0.10, 0.12][style]
	if difficulty == 0:
		# Coherent recreational leaks: call too wide, overvalue private pairs,
		# under-react to position/price. Mistakes do not reveal private cards.
		equity = clampf(equity + rng.randf_range(-0.13, 0.13) + 0.06, 0.0, 1.0)
		var bet_chance = (0.12 + aggression + maxf(0.0, feature.strength - 0.50) * 1.3)
		if legal.raise and rng.randf() < bet_chance:
			return _raise(Sizing.from_pot(0.5 if rng.randf() < 0.8 else 1.0, view))
		if legal.check: return {"action": "check"}
		return {"action": "call" if _chance(equity - price + 0.035, 9.0) else "fold"}
	var edge = equity * realization - price
	if difficulty == 2 and legal.raise and _can_compare(view, opponents):
		var best = _compare_sizes(view, opponents, equity, realization)
		if best > 0: return _raise(best)
	elif legal.raise:
		var value = equity > 0.61 + 0.035 * maxi(0, opponents.size() - 1)
		var draw_bluff = feature.draw > 0.12 and opponents.size() <= 2 and edge > -0.12
		var bet_chance = (0.73 if value else 0.20 if draw_bluff else 0.035) + aggression
		if not value: bet_chance *= pow(0.45, opponents.size() - 1)
		if edge < -0.10 and not draw_bluff: bet_chance = 0.0
		if rng.randf() < maxf(0.0, bet_chance):
			return _raise(Sizing.from_pot(0.75 if value else 0.50, view))
	if legal.check: return {"action": "check"}
	# Aggression shifts bets/bluffs, never simply widens all calls.
	var margin = 0.0 if difficulty == 1 else 0.015
	return {"action": "call" if _chance(edge - margin, 36.0 if difficulty == 1 else 65.0) else "fold"}

func _chance(edge: float, precision: float) -> bool:
	return rng.randf() < 1.0 / (1.0 + exp(-edge * precision))

func _raise(amount: int) -> Dictionary:
	return {"action": "raise", "amount": amount}

func _in_position(view: Dictionary) -> bool:
	# Last live seat clockwise before the button acts last postflop.
	for offset in range(view.seats.size()):
		var id = (view.button - offset + view.seats.size()) % view.seats.size()
		var seat = view.seats[id]
		if seat.in_hand and not seat.folded and seat.stack > 0: return id == view.actor
	return false

func _preflop(view: Dictionary) -> Dictionary:
	var l: Dictionary = view.legal
	var own: Dictionary = view.seats[view.actor]
	var strength = Ranges.preflop_strength(own.hole)
	var position = Ranges.position(view, view.actor)
	var active = view.seats.filter(func(s): return s.in_hand and not s.folded).size()
	var opening = view.current_bet <= view.big_blind
	var raises = 0
	var limpers = 0
	for a in view.events:
		if a.get("kind") == "action":
			if a.action == "raise": raises += 1
			elif a.action == "call" and raises == 0: limpers += 1
	var aggression: float = [0.0, -0.055, 0.055][style]
	var threshold = 0.64
	# Advanced opens wider heads-up; paired-deck duels showed the standard range folds too much.
	if position in ["BTN", "BTN/SB"]: threshold = (0.32 if difficulty == 2 else 0.41) if active == 2 else 0.50
	elif position == "CO": threshold = 0.56
	elif position == "HJ": threshold = 0.59
	elif position == "SB": threshold = 0.56
	elif position == "BB": threshold = 0.51
	if difficulty == 0: threshold = 0.36  # mostly ignores position
	if not opening: threshold += 0.10 + 0.055 * maxi(0, raises - 1)
	var cost_bb = float(l.call_amount) / view.big_blind
	if cost_bb > 5: threshold += minf(0.22, log(cost_bb / 5.0) * 0.10)
	var price = float(l.call_amount) / maxi(1, view.pot + l.call_amount)
	if difficulty > 0 and price < 0.18: threshold -= 0.04
	var depth = float(own.stack + own.street_bet) / view.big_blind
	if difficulty == 2 and depth < 25 and opening: threshold -= 0.035
	var precision: float = [10.0, 32.0, 48.0][difficulty]
	var enter = _chance(strength - threshold + aggression * 0.35, precision)
	var premium = strength >= (0.87 if raises <= 1 else 0.94)
	var raise_chance = 0.85 if opening else 0.88 if premium else 0.08
	if difficulty == 0: raise_chance = 0.25 if not premium else 0.60
	# Advanced adds a small suited-ace re-raise component; far less multiway.
	if difficulty == 2 and raises == 1 and active <= 3:
		var suited = int(own.hole[0] / 13) == int(own.hole[1] / 13)
		if suited and (own.hole[0] % 13 == 12 or own.hole[1] % 13 == 12): raise_chance += 0.10
	raise_chance = clampf(raise_chance + aggression * 2.0, 0.02, 0.98)
	if l.raise and (enter or premium) and rng.randf() < raise_chance:
		var target: int
		if opening:
			target = Sizing.from_bb((2.5 if difficulty > 0 else 3.0) + limpers, view.big_blind, l)
		else:
			target = Sizing.clamp_target(roundi(view.current_bet * (3.0 if _in_position(view) else 3.5)), l)
		return _raise(target)
	if l.check: return {"action": "check"}
	return {"action": "call" if enter or premium else "fold"}

static func _private_draw(hole: Array, board: Array) -> float:
	if board.size() >= 5: return 0.0
	var draw = 0.0
	for suit in range(4):
		var total = (hole + board).filter(func(c): return int(c / 13) == suit).size()
		if total == 4 and hole.any(func(c): return int(c / 13) == suit): draw += 0.20
	var board_ranks: Array = board.map(func(c): return c % 13 + 2)
	var private_ranks: Array = hole.map(func(c): return c % 13 + 2).filter(func(r): return r not in board_ranks)
	if 14 in board_ranks: board_ranks.append(1)
	if 14 in private_ranks: private_ranks.append(1)
	var combined = board_ranks + private_ranks
	var outs: Array = []
	for high in range(5, 15):
		var needed: Array = range(high - 4, high + 1)
		var missing = needed.filter(func(r): return r not in combined)
		if missing.size() == 1 and missing[0] not in outs and private_ranks.any(func(r): return r in needed): outs.append(missing[0])
	return draw + minf(0.16, outs.size() * 0.08)

func _can_compare(view: Dictionary, opponents: Array) -> bool:
	# Response EV is a one-street model. Avoid applying it to side pots or an
	# all-in opponent who cannot fold; use the conservative value policy there.
	return opponents.all(func(s): return s.stack > 0 and s.stack + s.street_bet >= view.seats[view.actor].street_bet + view.legal.call_amount)

func _compare_sizes(view: Dictionary, opponents: Array, equity: float, realization: float) -> int:
	var own = view.seats[view.actor]
	var pot: float = view.pot
	var call_cost: float = view.legal.call_amount
	var baseline = maxf(0.0, equity * realization * (pot + call_cost) - call_cost)
	var best: int = 0
	var threshold = maxf(view.big_blind * 0.20, pot * 0.025)
	var best_ev = baseline + threshold
	var aggression: float = [1.0, 0.65, 1.35][style]
	var feature = Ranges.features(own.hole, view.board)
	feature.draw = _private_draw(own.hole, view.board)
	for fraction in [0.33, 0.66, 1.0]:
		var target = Sizing.from_pot(fraction, view)
		# Avoid unequal effective stacks in this approximate response model.
		if opponents.any(func(s): return s.stack + s.street_bet < target): continue
		var cost: float = target - own.street_bet
		var weighted_ev = 0.0
		var weights = 0.0
		for sample in samples:
			var all_fold = 1.0
			var no_better = 1.0
			var tie_probs: Array = [1.0]
			var extra = 0.0
			for i in range(opponents.size()):
				var response = sample.responses[i]
				var price = float(target - opponents[i].street_bet) / maxf(1.0, pot + cost + target - opponents[i].street_bet)
				# Conservative, fixed response prior, not knowledge of actual cards.
				var p = clampf(1.0 / (1.0 + exp(-(response.strength + response.draw * 0.65 - 0.23 - price) * 11.0)), 0.06, 0.98)
				all_fold *= 1.0 - p
				extra += p * (target - opponents[i].street_bet)
				if sample.scores[i] > sample.own: no_better *= 1.0 - p
				elif sample.scores[i] == sample.own:
					var next: Array = []
					next.resize(tie_probs.size() + 1)
					next.fill(0.0)
					for t in range(tie_probs.size()):
						next[t] += tie_probs[t] * (1.0 - p)
						next[t + 1] += tie_probs[t] * p
					tie_probs = next
			var share = 0.0
			for t in range(tie_probs.size()): share += tie_probs[t] / (t + 1.0)
			var called_share = maxf(0.0, no_better * share - all_fold)
			var ev = all_fold * pot + called_share * realization * (pot + cost + extra / maxf(0.001, 1.0 - all_fold)) - (1.0 - all_fold) * cost
			weighted_ev += ev * sample.weight
			weights += sample.weight
		var ev = weighted_ev / maxf(weights, 1e-30)
		# Modelling error grows with money risked and with more opponents.
		ev -= cost * (0.06 + 0.02 * maxi(0, opponents.size() - 1))
		# Style controls marginal pressure; value betting remains across styles.
		var marginal = equity < 0.60
		if marginal:
			ev = baseline + (ev - baseline) * aggression
			if opponents.size() >= 3: ev -= pot * 0.10
			if feature.draw < 0.10 and view.board.size() < 5: ev -= pot * 0.06
		if ev > best_ev:
			best_ev = ev
			best = target
	# A positive model EV is not enough to bluff with every weak holding.
	# Separate value, private draws and rare air; avoid systematic over-bluffing
	# against callers or in multiway pots. These are explicit policy priors.
	var frequency = 0.86
	if equity < 0.62 + 0.025 * maxi(0, opponents.size() - 1):
		if feature.draw > 0.10 and view.board.size() < 5: frequency = 0.28 * aggression / opponents.size()
		elif view.legal.call_amount == 0 and opponents.size() == 1: frequency = 0.08 * aggression
		else: frequency = 0.02 * aggression / opponents.size()
	return best if best > 0 and rng.randf() < frequency else 0

func _equity(view: Dictionary, opponents: Array) -> float:
	var hole: Array = view.seats[view.actor].hole
	var known = hole + view.board
	var unknown: Array = []
	for c in range(52):
		if c not in known: unknown.append(c)
	var actions = Ranges.public_actions(view)
	var relevant: Dictionary = {}
	var positions: Dictionary = {}
	var depths: Dictionary = {}
	for seat in opponents:
		relevant[seat.id] = actions.filter(func(a): return a.seat == seat.id)
		positions[seat.id] = Ranges.position(view, seat.id)
		depths[seat.id] = float(mini(seat.stack + seat.total_bet, view.seats[view.actor].stack + view.seats[view.actor].total_bet)) / view.big_blind
	var weighted: float = 0.0
	var total: float = 0.0
	var square: float = 0.0
	var uniform: float = 0.0
	var count: int = [24, 72, 320][difficulty]
	samples.clear()
	var needed = 5 - view.board.size() + opponents.size() * 2
	for sample in range(count):
		var pool = unknown.duplicate()
		for i in range(needed):
			var other = rng.randi_range(i, pool.size() - 1)
			var card = pool[i]
			pool[i] = pool[other]
			pool[other] = card
		var missing: int = 5 - view.board.size()
		var board: Array = view.board + pool.slice(0, missing)
		var own_score = Rank.score(hole + board)
		var best = own_score
		var ties: int = 1
		var weight: float = 1.0
		var scores: Array = []
		var responses: Array = []
		for i in range(opponents.size()):
			var seat = opponents[i]
			var cards: Array = pool.slice(missing + i * 2, missing + i * 2 + 2)
			var score = Rank.score(cards + board)
			scores.append(score)
			if difficulty == 2: responses.append(Ranges.features(cards, view.board))
			if score > best:
				best = score
				ties = 1
			elif score == best: ties += 1
			if difficulty > 0:
				for observation in relevant[seat.id]: weight *= Ranges.likelihood(cards, observation, positions[seat.id], depths[seat.id])
		if difficulty == 2: samples.append({"own": own_score, "scores": scores, "responses": responses, "weight": weight})
		var share = 1.0 / ties if own_score == best else 0.0
		weighted += weight * share
		total += weight
		square += weight * weight
		uniform += share
	# Importance sampling can degenerate for narrow multiway ranges. Explicitly
	# shrink to a uniform baseline instead of treating one rollout as certainty.
	var effective = total * total / maxf(square, 1e-30)
	var trust = clampf(effective / 24.0, 0.0, 1.0)
	if difficulty == 2:
		for sample in samples: sample.weight = lerpf(1.0 / count, sample.weight / maxf(total, 1e-30), trust)
	return lerpf(uniform / count, weighted / maxf(total, 1e-30), trust)
