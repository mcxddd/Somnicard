extends RefCounted
## Bounded range-weighted rollouts + stochastic policy. Not a GTO opponent.
## Uses ONLY actor's hole cards, public board, actions and stacks.
const Ranges = preload("res://scripts/poker/range_model.gd")
const Rank = preload("res://scripts/poker/fast_rank.gd")
const Sizing = preload("res://scripts/ui/bet_sizing.gd")
var rng := RandomNumberGenerator.new()
var style: int = 0
var difficulty: int = 1

func _init(random_seed: int = -1, personality: int = 0, level: int = 1) -> void:
	style = clampi(personality, 0, 2)
	difficulty = clampi(level, 0, 2)
	if random_seed < 0: rng.randomize()
	else: rng.seed = random_seed

func style_name() -> String:
	return ["均衡", "稳健", "积极"][style]

func choose(view: Dictionary) -> Dictionary:
	var legal = view.legal
	if legal.is_empty(): return {}
	var own = view.seats[view.actor]
	var opponents = view.seats.filter(func(s): return s.id != view.actor and s.in_hand and not s.folded)
	var equity = _equity(view, opponents)
	# Beginner mode deliberately makes noisier estimates and overcalls more.
	# Advanced mode uses more samples and less decision noise, not hidden cards.
	if difficulty == 0: equity = clampf(equity + rng.randf_range(-0.16, 0.16), 0.0, 1.0)
	var cap: int = own.total_bet + legal.call_amount
	var eligible: int = legal.call_amount
	for seat in view.seats: eligible += mini(cap, seat.total_bet)
	var threshold = float(legal.call_amount) / maxi(1, eligible)
	var realization: float = 1.0 if view.board.size() == 5 else 0.80 if opponents.size() >= 3 else 0.90
	var edge: float = equity * realization - threshold
	var feature = Ranges.features(own.hole, view.board)
	var aggression: float = [0.0, -0.06, 0.08][style]
	var value_edge = equity - maxf(0.57, 1.0 / (opponents.size() + 1) + 0.22)
	var raise_frequency = clampf(0.03 + aggression + maxf(0.0, value_edge) * 2.2 + feature.draw * 0.25, 0.01, 0.80)
	# Bluff less into several opponents; use several legal sizes, not one fixed bet.
	if opponents.size() >= 3: raise_frequency *= 0.55
	if edge < -0.08: raise_frequency *= 0.25
	var roll = rng.randf()
	if legal.raise and roll < raise_frequency:
		var size: int
		if view.board.is_empty() and view.current_bet <= view.big_blind:
			size = Sizing.from_bb([2.5, 3.0, 3.5][rng.randi_range(0, 2)], view.big_blind, legal)
		else: size = Sizing.from_pot([0.33, 0.5, 0.75, 1.0][rng.randi_range(0, 3)], view)
		return {"action": "raise", "amount": size}
	if legal.check: return {"action": "check"}
	var bias: float = 0.08 if difficulty == 0 else 0.0
	var precision: float = [10.0, 24.0, 36.0][difficulty]
	var continue_probability = clampf(1.0 / (1.0 + exp(-(edge + aggression * 0.4 + bias) * precision)), 0.02, 0.98)
	return {"action": "call" if rng.randf() < continue_probability else "fold"}

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
	var count: int = [32, 96, 256][difficulty]
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
		for i in range(opponents.size()):
			var seat = opponents[i]
			var cards: Array = pool.slice(missing + i * 2, missing + i * 2 + 2)
			var score = Rank.score(cards + board)
			if score > best:
				best = score
				ties = 1
			elif score == best: ties += 1
			if difficulty > 0:
				for observation in relevant[seat.id]: weight *= Ranges.likelihood(cards, observation, positions[seat.id], depths[seat.id])
		var share = 1.0 / ties if own_score == best else 0.0
		weighted += weight * share
		total += weight
		square += weight * weight
		uniform += share
	# Importance sampling can degenerate for narrow multiway ranges. Explicitly
	# shrink to a uniform baseline instead of treating one rollout as certainty.
	var effective = total * total / maxf(square, 1e-30)
	var trust = clampf(effective / 24.0, 0.0, 1.0)
	return lerpf(uniform / count, weighted / maxf(total, 1e-30), trust)
