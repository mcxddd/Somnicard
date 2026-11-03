extends RefCounted
## Seat-based no-limit Hold'em engine, independent of scene tree, UI and AI.
## Commands are validated before mutation. Amounts are integers; raise_to is street total.

const Evaluator = preload("res://scripts/poker/evaluator.gd")
const PlayerNames = preload("res://scripts/poker/player_names.gd")
const STREETS = ["preflop", "flop", "turn", "river"]
## Six-max at most: every solver, chart and layout targets 2–6 seats.
const MAX_SEATS = 6
var seats: Array = []
var small_blind: int = 5
var big_blind: int = 10
var button: int = -1
var small_blind_seat: int = -1
var big_blind_seat: int = -1
var actor: int = -1
var phase: String = "idle"
var hand_number: int = 0
var current_bet: int = 0
var min_raise: int = 10
var board: Array = []
var events: Array = []
var result: Dictionary = {}
## Optional observer used only by deterministic replay; never included in saved data.
var event_observer: Callable
var _pending: Array = []
var _deck: Array = []
var _burns: Array = []
var _starting_deck: Array = []
var _starting_stacks: Array = []
var _rng := RandomNumberGenerator.new()

func _init(stacks: Array = [1000, 1000], sb: int = 5, bb: int = 10, random_seed: int = -1) -> void:
	assert(stacks.size() >= 2 and stacks.size() <= MAX_SEATS)
	assert(sb > 0 and bb >= sb)
	small_blind = sb
	big_blind = bb
	if random_seed < 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed
	for index in range(stacks.size()):
		assert(stacks[index] >= 0)
		seats.append({"id": index, "name": PlayerNames.for_seat(index),
			"stack": int(stacks[index]), "hole": [], "in_hand": false, "folded": false,
			"street_bet": 0, "total_bet": 0, "acted_at": -1})

func start_hand(requested_button: int = -1, ordered_deck: Array = []) -> String:
	if phase != "idle" and phase != "complete":
		return "当前牌局尚未结束"
	var funded = []
	for seat in seats:
		if seat.stack > 0:
			funded.append(seat.id)
	if funded.size() < 2:
		return "至少需要两名有筹码的玩家"
	if requested_button != -1 and requested_button not in funded:
		return "庄家座位无效"
	if not ordered_deck.is_empty():
		var unique = {}
		for card in ordered_deck:
			if not card is int or card < 0 or card > 51 or unique.has(card):
				return "牌堆必须包含 52 张不同的有效牌"
			unique[card] = true
		if unique.size() != 52:
			return "牌堆必须包含 52 张不同的有效牌"
	var previous_bb = big_blind_seat
	if requested_button >= 0:
		button = requested_button
	elif funded.size() == 2 and previous_bb >= 0:
		# On transition to heads-up, the surviving previous BB must not post BB twice.
		button = _next_in(_next_in(previous_bb, funded), funded)
	else:
		button = _next_in(button, funded)
	board = []
	_burns = []
	events = []
	result = {}
	_starting_stacks = []
	for seat in seats:
		_starting_stacks.append(seat.stack)
		seat.hole = []
		seat.in_hand = seat.stack > 0
		seat.folded = false
		seat.street_bet = 0
		seat.total_bet = 0
		seat.acted_at = -1
	_deck = ordered_deck.duplicate()
	if _deck.is_empty():
		_deck = range(52)
		for index in range(51, 0, -1):
			var swap = _rng.randi_range(0, index)
			var card = _deck[index]
			_deck[index] = _deck[swap]
			_deck[swap] = card
	_starting_deck = _deck.duplicate()
	hand_number += 1
	phase = "preflop"
	current_bet = big_blind
	min_raise = big_blind
	small_blind_seat = button if funded.size() == 2 else _next_in(button, funded)
	big_blind_seat = _next_in(small_blind_seat, funded)
	for round_index in range(2):
		var recipient = button
		for count in range(funded.size()):
			recipient = _next_in(recipient, funded)
			seats[recipient].hole.append(_deck.pop_front())
	_event("start", {"button": button, "hand": hand_number})
	for blind in [[small_blind_seat, small_blind], [big_blind_seat, big_blind]]:
		var paid = mini(blind[1], seats[blind[0]].stack)
		_pay(blind[0], paid)
		_event("blind", {"seat": blind[0], "amount": paid})
	_pending = _can_act()
	_progress(big_blind_seat)
	return ""

func legal_actions(seat_id: int) -> Dictionary:
	if seat_id != actor or actor < 0 or phase == "complete":
		return {}
	var seat = seats[seat_id]
	var due = maxi(0, current_bet - seat.street_bet)
	var reopened = seat.acted_at < 0 or current_bet - seat.acted_at >= min_raise
	var maximum = seat.street_bet + seat.stack
	var may_raise = reopened and maximum > current_bet and _can_act().size() > 1
	return {"fold": true, "check": due == 0, "call": due > 0,
		"call_amount": mini(due, seat.stack), "to_call": due,
		"raise": may_raise, "min_raise_to": current_bet + min_raise,
		"max_raise_to": maximum, "all_in": maximum <= current_bet or may_raise}

func act(seat_id: int, action: String, raise_to: int = 0) -> String:
	var legal = legal_actions(seat_id)
	if legal.is_empty():
		return "尚未轮到该玩家行动"
	var seat = seats[seat_id]
	var chosen = action
	if action == "all_in":
		if not legal.all_in:
			return "当前不能全押加注"
		chosen = "call" if legal.max_raise_to <= current_bet else "raise"
		raise_to = legal.max_raise_to
	if chosen not in ["fold", "check", "call", "raise"]:
		return "未知操作"
	if not legal.get(chosen, false):
		return "当前不允许该操作"
	if chosen == "raise":
		if raise_to <= current_bet or raise_to > legal.max_raise_to:
			return "加注总额超出范围"
		if raise_to < legal.min_raise_to and raise_to != legal.max_raise_to:
			return "不足最小加注；只有全押可例外"
	var paid = 0
	var full_raise = false
	_pending.erase(seat_id)
	if chosen == "fold":
		seat.folded = true
	elif chosen == "call":
		paid = legal.call_amount
		_pay(seat_id, paid)
	elif chosen == "raise":
		var increment = raise_to - current_bet
		full_raise = increment >= min_raise
		if full_raise:
			min_raise = increment
		paid = raise_to - seat.street_bet
		_pay(seat_id, paid)
		current_bet = raise_to
		_pending = _can_act()
		_pending.erase(seat_id)
	seat.acted_at = current_bet
	_event("action", {"seat": seat_id, "action": chosen, "paid": paid,
		"to": seat.street_bet, "all_in": seat.stack == 0, "full_raise": full_raise})
	_progress(seat_id)
	return ""

func pot_size() -> int:
	var total = 0
	for seat in seats:
		total += seat.total_bet
	return total

func chip_total() -> int:
	var total = pot_size()
	for seat in seats:
		total += seat.stack
	return total

func view_for(viewer: int) -> Dictionary:
	var public_seats = seats.duplicate(true)
	for seat in public_seats:
		if seat.id != viewer and not (phase == "complete" and result.get("showdown", false) and not seat.folded):
			seat.hole = []
		seat.erase("acted_at")
	return {"seats": public_seats, "board": board.duplicate(), "phase": phase,
		"actor": actor, "button": button, "small_blind_seat": small_blind_seat,
		"big_blind_seat": big_blind_seat, "big_blind": big_blind,
		"pot": pot_size(), "current_bet": current_bet, "hand": hand_number,
		"legal": legal_actions(viewer).duplicate(true), "events": events.duplicate(true),
		"result": result.duplicate(true)}

func completed_record() -> Dictionary:
	if phase != "complete":
		return {}
	return record_state()

func record_state() -> Dictionary:
	# Private persistence boundary; never pass this record to bots or the advisor.
	return {"schema_version": 1, "hand": hand_number, "button": button,
		"seat_names": seats.map(func(seat): return seat.name),
		"small_blind": small_blind, "big_blind": big_blind,
		"starting_stacks": _starting_stacks.duplicate(), "deck": _starting_deck.duplicate(),
		"events": events.duplicate(true), "result": result.duplicate(true)}

func _pay(seat_id: int, amount: int) -> void:
	seats[seat_id].stack -= amount
	seats[seat_id].street_bet += amount
	seats[seat_id].total_bet += amount

func _live() -> Array:
	var ids = []
	for seat in seats:
		if seat.in_hand and not seat.folded:
			ids.append(seat.id)
	return ids

func _can_act() -> Array:
	return _live().filter(func(id): return seats[id].stack > 0)

func _next_in(after: int, ids: Array) -> int:
	for step in range(1, seats.size() + 1):
		var candidate = (after + step) % seats.size()
		if candidate in ids:
			return candidate
	return -1

func _progress(after: int) -> void:
	if _live().size() == 1:
		_refund_uncalled()
		_finish(false)
		return
	var actionable = _can_act()
	_pending = _pending.filter(func(id): return id in actionable)
	if actionable.size() <= 1:
		# No betting into a dry side pot; only a real unmatched bet needs a response.
		current_bet = 0
		for seat in seats:
			current_bet = maxi(current_bet, seat.street_bet)
		_pending = actionable.filter(func(id): return seats[id].street_bet < current_bet)
	if not _pending.is_empty():
		actor = _next_in(after, _pending)
		return
	_refund_uncalled()
	if phase == "river":
		_finish(true)
		return
	_next_street()
	if _can_act().size() <= 1:
		# All-in runout: burn and deal the remaining streets without meaningless checks.
		while phase != "river":
			_next_street()
		_finish(true)
	else:
		_pending = _can_act()
		actor = _next_in(button, _pending)

func _next_street() -> void:
	phase = STREETS[STREETS.find(phase) + 1]
	current_bet = 0
	min_raise = big_blind
	for seat in seats:
		seat.street_bet = 0
		seat.acted_at = -1
	_burns.append(_deck.pop_front())
	for count in range(3 if phase == "flop" else 1):
		board.append(_deck.pop_front())
	_event("street", {"board": board.duplicate()})

func _refund_uncalled() -> void:
	var order = range(seats.size())
	order.sort_custom(func(a, b): return seats[a].street_bet > seats[b].street_bet)
	var highest = seats[order[0]]
	var excess = highest.street_bet - seats[order[1]].street_bet
	if excess > 0:
		highest.street_bet -= excess
		highest.total_bet -= excess
		highest.stack += excess
		_event("refund", {"seat": highest.id, "amount": excess})

func _finish(showdown: bool) -> void:
	var total = pot_size()
	var ranks = {}
	var payouts = {}
	var contributions = []
	var pots = []
	for seat in seats:
		payouts[seat.id] = 0
		contributions.append(seat.total_bet)
		if showdown and seat.id in _live():
			ranks[seat.id] = Evaluator.evaluate(seat.hole + board)
	if not showdown:
		var winner = _live()[0]
		payouts[winner] = total
		pots.append({"amount": total, "eligible": [winner], "winners": [winner], "shares": {winner: total}})
	else:
		var levels = []
		for amount in contributions:
			if amount > 0 and amount not in levels:
				levels.append(amount)
		levels.sort()
		var previous = 0
		var tiers = []
		for level in levels:
			var amount = 0
			var eligible = []
			for seat in seats:
				if seat.total_bet >= level:
					amount += level - previous
					if seat.id in _live():
						eligible.append(seat.id)
			previous = level
			assert(not eligible.is_empty(), "A valid pot must have an eligible player")
			# Folded players' contribution levels do not create separate side pots.
			# Merge equal eligibility before odd-chip distribution, or ties can be biased.
			if not tiers.is_empty() and tiers[-1].eligible == eligible:
				tiers[-1].amount += amount
			else:
				tiers.append({"amount": amount, "eligible": eligible})
		for tier in tiers:
			var amount = tier.amount
			var eligible = tier.eligible
			var best = -1
			var winners = []
			for id in eligible:
				if ranks[id].score > best:
					best = ranks[id].score
					winners = [id]
				elif ranks[id].score == best:
					winners.append(id)
			# Odd chips start at the first tied winner clockwise after the button.
			winners.sort_custom(func(a, b): return (a - button - 1 + seats.size()) % seats.size() < (b - button - 1 + seats.size()) % seats.size())
			var shares = {}
			for index in range(winners.size()):
				var share = int(amount / winners.size()) + (1 if index < amount % winners.size() else 0)
				shares[winners[index]] = share
				payouts[winners[index]] += share
			pots.append({"amount": amount, "eligible": eligible, "winners": winners, "shares": shares})
	for seat in seats:
		seat.stack += payouts[seat.id]
		seat.street_bet = 0
		seat.total_bet = 0
	result = {"showdown": showdown, "pot": total, "pots": pots, "payouts": payouts, "ranks": ranks, "contributions": contributions}
	phase = "complete"
	actor = -1
	current_bet = 0
	_pending = []
	_event("finish", {"pot": total, "showdown": showdown, "payouts": payouts.duplicate()})

func _event(kind: String, detail: Dictionary) -> void:
	var event = detail.duplicate(true)
	event["kind"] = kind
	event["phase"] = phase
	event["seq"] = events.size()
	events.append(event)
	if event_observer.is_valid(): event_observer.call(event.duplicate(true), view_for(0))
