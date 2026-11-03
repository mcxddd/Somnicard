extends SceneTree
const Table = preload("res://scripts/poker/table.gd")
const Eval = preload("res://scripts/poker/evaluator.gd")
const Bot = preload("res://scripts/poker/local_bot.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_evaluator_tests()
	_heads_up_tests()
	_raise_tests()
	_pot_tests()
	_visibility_and_replay()
	_simulations()
	print("POKER_TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func verify(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func cards(text: String) -> Array:
	var result = []
	for token in text.split(" "):
		var rank = "23456789TJQKA".find(token[0])
		var suit = "shdc".find(token[1])
		result.append(suit * 13 + rank)
	return result

func deck_with(prefix: Array) -> Array:
	var deck = prefix.duplicate()
	for card in range(52):
		if card not in deck:
			deck.append(card)
	return deck

func do_action(table, action: String, amount: int = 0) -> void:
	var err = table.act(table.actor, action, amount)
	verify(err.is_empty(), "action %s %d: %s" % [action, amount, err])

func finish_passive(table) -> void:
	var steps = 0
	while table.phase != "complete" and steps < 100:
		var legal = table.legal_actions(table.actor)
		do_action(table, "check" if legal.get("check", false) else "call")
		steps += 1
	verify(table.phase == "complete", "passive play terminates")

func _evaluator_tests() -> void:
	var examples = ["As Kd 9h 5c 3s", "As Ah Kd 9c 2s", "As Ah Kd Kc 2s",
		"As Ah Ad Kc 2s", "As 2h 3d 4c 5s", "As Js 9s 5s 2s",
		"As Ah Ad Kc Ks", "As Ah Ad Ac Ks", "9s Ts Js Qs Ks"]
	var previous = -1
	for index in range(examples.size()):
		var value = Eval.evaluate(cards(examples[index]))
		verify(value.category == index and value.score > previous, "category ordering %d" % index)
		previous = value.score
	verify(Eval.evaluate(cards("As 2h 3d 4c 5s")).score < Eval.evaluate(cards("2s 3h 4d 5c 6s")).score, "wheel is five high")
	verify(Eval.evaluate(cards("As Ah Kd 9c 2s")).score > Eval.evaluate(cards("Ad Ac Qh Jc 9s")).score, "pair kicker")
	verify(Eval.evaluate(cards("As Ah Ad Kc Ks Kh 2d")).kickers == [14, 13], "two trips choose higher full house")
	verify(Eval.evaluate(cards("As Ah Kd Kc Qs Qh 2d")).kickers == [14, 13, 12], "three pairs choose top two and kicker")
	verify(Eval.evaluate(cards("As Ks Qs Js Ts 2h 3d")).score == Eval.evaluate(cards("As Ks Qs Js Ts 9h 9d")).score, "board plays for tie")
	verify(Eval.evaluate(cards("As Ah Ad Ac Ks Kh Kd")).kickers == [14, 13], "quads kicker")
	verify(Eval.evaluate(cards("As As 2d 3d 4c")).is_empty(), "reject duplicate cards")

func _heads_up_tests() -> void:
	var t = Table.new([100, 100], 5, 10, 10)
	verify(t.start_hand(0) == "", "start heads up")
	verify(t.actor == 0 and t.small_blind_seat == 0 and t.big_blind_seat == 1 and t.pot_size() == 15, "HU blinds and action")
	var before = t.view_for(0)
	verify(t.act(1, "call") != "" and t.view_for(0) == before, "out of turn rejected atomically")
	verify(t.act(0, "check") != "" and t.view_for(0) == before, "cannot check facing blind")
	verify(t.start_hand() != "" and t.view_for(0) == before, "cannot restart live hand")
	do_action(t, "call")
	verify(t.actor == 1 and t.legal_actions(1).check, "BB retains option after limp")
	do_action(t, "check")
	verify(t.phase == "flop" and t.actor == 1 and t.board.size() == 3, "BB acts first on flop")
	finish_passive(t)
	verify(t.result.showdown and t.board.size() == 5 and t.chip_total() == 200, "complete showdown conserves chips")
	verify(t.result.pot == 20, "checked-down pot")
	verify(t.start_hand() == "" and t.button == 1 and t.actor == 1, "button alternates")
	do_action(t, "fold")
	verify(not t.result.showdown and t.board.is_empty() and t.chip_total() == 200, "preflop fold ends without runout")
	var short_bb = Table.new([100, 3])
	short_bb.start_hand(0)
	verify(short_bb.phase == "complete" and short_bb.result.pot == 6 and short_bb.chip_total() == 103, "short BB automatic runout and refund")
	var short_sb = Table.new([3, 100])
	short_sb.start_hand(0)
	verify(short_sb.phase == "complete" and short_sb.result.pot == 6, "short SB automatic runout")
	var multi = Table.new([100, 100, 3])
	multi.start_hand(0)
	verify(multi.actor == 0 and multi.legal_actions(0).to_call == 10, "multiway short blind still requires nominal BB")
	var invalid = Table.new()
	verify(invalid.start_hand(0, range(51)) != "" and invalid.phase == "idle", "reject invalid deck before mutation")

func _raise_tests() -> void:
	var t = Table.new([200, 200, 35])
	t.start_hand(0)
	var before = t.view_for(0)
	verify(t.act(0, "raise", 15) != "" and t.view_for(0) == before, "non-all-in underraise rejected")
	do_action(t, "raise", 30)
	verify(t.min_raise == 20 and t.legal_actions(1).min_raise_to == 50, "min raise uses increment not double total")
	do_action(t, "call")
	do_action(t, "all_in")
	verify(t.actor == 0 and not t.legal_actions(0).raise and not t.legal_actions(0).all_in, "short all-in does not reopen")
	before = t.view_for(0)
	verify(t.act(0, "raise", 55) != "" and t.view_for(0) == before, "blocked raise cannot mutate pot")
	do_action(t, "call")
	do_action(t, "call")
	verify(t.phase == "flop" and t.actor == 1, "folded/all-in seats skipped")
	finish_passive(t)
	verify(t.chip_total() == 435, "short raise chips conserved")
	# Four seats: seat 3 opens, 0 calls, 1 and 2 make cumulative short all-ins.
	var c = Table.new([200, 40, 50, 200])
	c.start_hand(0)
	do_action(c, "raise", 30)
	do_action(c, "call")
	do_action(c, "all_in")
	do_action(c, "all_in")
	verify(c.actor == 3 and c.legal_actions(3).raise and c.legal_actions(3).min_raise_to == 70, "cumulative short raises reopen")
	do_action(c, "raise", 70)
	finish_passive(c)
	verify(c.chip_total() == 490, "cumulative all-ins settle")
	var dry = Table.new([100, 20])
	dry.start_hand(0)
	do_action(dry, "raise", 50)
	do_action(dry, "all_in")
	verify(dry.phase == "complete" and dry.result.pot == 40 and dry.chip_total() == 120, "uncalled 30 returned before runout")
	verify(dry.events.any(func(e): return e.kind == "refund" and e.amount == 30), "refund recorded")

func _pot_tests() -> void:
	# Deal order 1,2,0 twice; seat 0 AA, seat 1 KK, seat 2 QQ. Dry low board.
	var prefix = cards("Ks Qs As Kh Qh Ah Jc 2s 3h 7d Tc 8c 9c 9d")
	var t = Table.new([50, 100, 200])
	t.start_hand(0, deck_with(prefix))
	do_action(t, "all_in")
	do_action(t, "all_in")
	do_action(t, "call")
	verify(t.phase == "complete" and t.result.pot == 250, "3-way all-in pot size")
	verify(t.result.pots.size() == 2 and t.result.pots[0].amount == 150 and t.result.pots[1].amount == 100, "main and side pot tiers")
	verify(t.seats[0].stack == 150 and t.seats[1].stack == 100 and t.seats[2].stack == 100, "main and side pot have different winners")
	# Shared royal flush, folded seat contributes 5. Odd chip goes left of button.
	var tie = Table.new([100, 100, 100])
	tie.start_hand(0, deck_with(cards("2h 3h 4h 5h 6h 7h 8d As Ks Qs 9d Js Td Ts")))
	do_action(tie, "call")
	do_action(tie, "fold")
	finish_passive(tie)
	verify(tie.result.pot == 25 and tie.seats[0].stack == 102 and tie.seats[1].stack == 95 and tie.seats[2].stack == 103, "dead money and odd chip tie split")
	verify(tie.result.payouts[1] == 0, "folded player never wins")
	# Settlement fixture: three folded contributions must not create artificial pots
	# that award several odd chips to the same tied winner (38 must split 19/19).
	var dead = Table.new([100, 100, 100, 100, 100], 1, 2)
	dead.board = cards("As Ks Qs Js Ts")
	dead.button = 0
	var investments = [10, 10, 9, 6, 3]
	for id in range(5):
		dead.seats[id].in_hand = true
		dead.seats[id].folded = id > 1
		dead.seats[id].total_bet = investments[id]
		dead.seats[id].stack -= investments[id]
	dead.seats[0].hole = cards("2h 3h")
	dead.seats[1].hole = cards("4h 5h")
	dead._finish(true)
	verify(dead.result.pots.size() == 1 and dead.result.payouts[0] == 19 and dead.result.payouts[1] == 19, "merge dead-money tiers before distributing odd chips")
	verify(dead.chip_total() == 500, "dead-money settlement conserves chips")
	# Moving button skips empty seats and transition to HU avoids repeating BB.
	var eliminated = Table.new([100, 0, 100, 100])
	eliminated.start_hand(0)
	verify(eliminated.small_blind_seat == 2 and eliminated.big_blind_seat == 3, "empty seats skipped")
	finish_passive(eliminated)
	# Use a separate table to deterministically model an eliminated seat between hands.
	var transition = Table.new([100, 100, 0])
	transition.button = 0
	transition.big_blind_seat = 1
	transition.start_hand()
	verify(transition.big_blind_seat == 0 and transition.button == 1, "HU transition does not repeat surviving BB")

func _visibility_and_replay() -> void:
	var t = Table.new([100, 100, 100], 5, 10, 55)
	t.start_hand(0)
	var view = t.view_for(0)
	verify(view.seats[0].hole.size() == 2 and view.seats[1].hole.is_empty() and view.seats[2].hole.is_empty(), "opponent hole cards hidden")
	verify(not view.has("deck") and t.completed_record().is_empty(), "future deck and unfinished full history inaccessible to bots")
	view.seats[0].stack = 9999
	view.board.append(51)
	verify(t.seats[0].stack == 100 and t.board.is_empty(), "views have no mutable references")
	do_action(t, "raise", 30)
	do_action(t, "fold")
	do_action(t, "call")
	finish_passive(t)
	verify(t.view_for(0).seats[1].hole.is_empty() and t.view_for(0).seats[2].hole.size() == 2, "showdown reveals live hands only")
	var record = t.completed_record()
	var replay = Table.new(record.starting_stacks, record.small_blind, record.big_blind)
	replay.start_hand(record.button, record.deck)
	for event in record.events:
		if event.kind == "action":
			verify(replay.act(event.seat, event.action, event.to) == "", "event can replay")
	verify(replay.result == t.result and replay.seats == t.seats, "deterministic replay matches stacks and settlement")

func _simulations() -> void:
	var action_rng := RandomNumberGenerator.new()
	action_rng.seed = 10001
	var hands = 0
	for count in range(2, 7):
		for sample in range(30):
			var stacks = []
			for seat in range(count):
				stacks.append(action_rng.randi_range(1, 300))
			var t = Table.new(stacks, 5, 10, count * 100 + sample)
			var total = t.chip_total()
			t.start_hand()
			var steps = 0
			while t.phase != "complete" and steps < 300:
				var legal = t.legal_actions(t.actor)
				verify(not legal.is_empty(), "simulation has actor")
				if legal.is_empty():
					break
				var choices = ["check" if legal.check else "call"]
				if legal.call:
					choices.append("fold")
				if legal.all_in:
					choices.append("all_in")
				if legal.raise and legal.min_raise_to <= legal.max_raise_to:
					choices.append("raise")
				var action = choices[action_rng.randi_range(0, choices.size() - 1)]
				do_action(t, action, legal.min_raise_to if action == "raise" else 0)
				verify(t.chip_total() == total, "chips conserved after each action")
				verify(t.seats.all(func(s): return s.stack >= 0 and s.total_bet >= 0), "stacks never negative")
				steps += 1
			verify(t.phase == "complete", "2-6 seat hand terminates")
			var dealt = t.board.duplicate()
			for seat in t.seats:
				dealt.append_array(seat.hole)
			var unique = {}
			for card in dealt:
				unique[card] = true
			verify(unique.size() == dealt.size(), "no duplicate dealt cards")
			hands += 1
	# Exercise the actual bot contract across consecutive hands, including bust-outs.
	for count in [2, 4, 6]:
		var stacks = []
		stacks.resize(count)
		stacks.fill(200)
		var t = Table.new(stacks, 5, 10, count)
		var bot = Bot.new(count)
		for hand in range(10):
			if t.start_hand() != "":
				break
			var steps = 0
			while t.phase != "complete" and steps < 400:
				var decision = bot.choose(t.view_for(t.actor))
				do_action(t, decision.action, decision.get("amount", 0))
				steps += 1
			verify(t.phase == "complete" and t.chip_total() == count * 200, "bot game terminates and conserves chips")
			hands += 1
	print("SIMULATED_HANDS: %d (2-6 seats)" % hands)
