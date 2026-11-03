extends RefCounted
## Decision-specific language built only from the advisor's public-information allow-list.
const Advisor = preload("res://scripts/poker/advisor.gd")
const Eval = preload("res://scripts/poker/evaluator.gd")
const Ranges = preload("res://scripts/poker/range_model.gd")
const Feedback = preload("res://scripts/poker/decision_feedback.gd")
const UI = preload("res://scripts/ui/style.gd")

static func cards_text(cards: Array) -> String:
	var names: Array = []
	for card in cards: names.append(Eval.card_text(card))
	return " ".join(names)

static func explain(view: Dictionary, analysis: Dictionary, bb: bool) -> Dictionary:
	var state = Advisor.information(view)
	var money = func(value): return UI.money(int(value), state.big_blind, bb)
	var hero = state.seats[0]
	var action: String = analysis.action
	var cost: int = analysis.cost
	var equity: float = analysis.pot_equity * 100
	var odds: float = analysis.odds * 100
	var strategy: Dictionary = analysis.get("strategy", {})
	var mixed: bool = strategy.get("supported", false) and strategy.get("converged", false)
	var close: bool = cost > 0 and absf(analysis.call_ev) <= analysis.ev_error
	var summary: String
	if mixed:
		var frequency = 0.0
		var chosen: Dictionary = {}
		var call_option: Dictionary = {}
		var active_choices = 0
		for choice in strategy.get("frequencies", []):
			if choice.frequency >= 0.05: active_choices += 1
			if choice.action == "call": call_option = choice
			if choice.action == action and choice.amount == analysis.amount:
				frequency = choice.frequency
				chosen = choice
		var shove = strategy.get("kind", "") == "pushfold" and action == "raise"
		summary = "这次%s参考%s%s，比例约 %.0f%%。" % [{"pushfold": "短筹码均衡", "preflop": "翻牌前开局表", "turn": "转牌"}.get(strategy.get("kind", ""), "河牌"), "全押" if shove else {"check": "过牌", "call": "跟注", "fold": "弃牌", "raise": "加到"}.get(action, action), money.call(analysis.amount) if action == "raise" and not shove else "", frequency * 100]
		if action == "fold" and call_option.has("ev"):
			summary += "跟注的模型净值约 %s，弃牌不再投入。" % Feedback.value_text(call_option.ev, state.big_blind, bb)
		elif chosen.has("ev"):
			summary += "该操作的模型净值约 %s；具体替代操作见下方对照。" % Feedback.value_text(chosen.ev, state.big_blind, bb)
		if active_choices > 1: summary += "这是混合打法，多种操作都有参考比例。"
	elif action == "fold":
		summary = "跟注要 %s，预计分池份额 %.1f%% 低于回本门槛 %.1f%%，倾向保留这笔筹码。" % [money.call(cost), equity, odds]
	elif action == "raise":
		summary = "预计分池份额 %.1f%%，对当前范围有优势，倾向价值下注到 %s；本次再投入 %s。" % [equity, money.call(analysis.amount), money.call(analysis.amount - hero.street_bet)]
	elif action == "call":
		summary = "跟注 %s 的门槛是 %.1f%%，你的预计分池份额为 %.1f%%；%s" % [money.call(cost), odds, equity, "两者接近，属于边缘决策，先避免扩大投入。" if close else "当前价格可以接受，优先跟注控制投入。"]
	else:
		summary = "现在可以免费过牌，预计分池份额 %.1f%%；暂不主动扩大底池，保留%s。" % [equity, "摊牌机会" if state.phase == "river" else "继续看牌的机会"]
	var context = "你的手牌：%s。" % cards_text(state.hole)
	var position = Ranges.position(state, 0)
	var position_name: String = {"BTN": "庄家", "BTN/SB": "庄家兼小盲", "SB": "小盲", "BB": "大盲", "CO": "庄家右侧", "HJ": "中后位置", "UTG": "前位", "MP": "中间位置"}.get(position, position)
	context += "你在%s，仍有 %d 名对手没有弃牌。" % [position_name, analysis.opponents]
	var hand = "起手牌"
	var board_notes: Array = []
	if state.board.is_empty():
		var pair: bool = state.hole[0] % 13 == state.hole[1] % 13
		context += "这是一手%s，翻牌前还没有成型的公共牌组合。" % ["口袋对子" if pair else "同花起手牌" if int(state.hole[0] / 13) == int(state.hole[1] / 13) else "非同花起手牌"]
	else:
		var ranked = Eval.evaluate(state.hole + state.board)
		hand = ranked.name
		context += "\n公共牌：%s。当前最佳牌型是%s。" % [cards_text(state.board), hand]
		if state.board.size() == 5 and Eval.evaluate(state.board).score == ranked.score:
			board_notes.append("你当前的最佳牌力与公共牌相同，不能把牌面上的大牌当作自己的独有优势。")
		var suits = [0, 0, 0, 0]
		var ranks = {}
		for card in state.board:
			suits[int(card / 13)] += 1
			ranks[card % 13] = ranks.get(card % 13, 0) + 1
		if ranked.category == 1:
			var pair_rank: int = ranked.kickers[0] - 2
			if ranks.get(pair_rank, 0) == 2:
				board_notes.append("这一对来自公共牌，你自己的两张手牌没有配成对子，需要靠踢脚牌区分胜负。")
			elif state.hole[0] % 13 == state.hole[1] % 13 and pair_rank > ranks.keys().max():
				board_notes.append("你持有超对，高于公共牌的所有点数；它有价值，但仍不是一定获胜的牌。")
			elif pair_rank == ranks.keys().max():
				board_notes.append("你已配到顶对；面对持续加注，还要比较踢脚牌以及对手两对、三条的可能。")
		if suits.max() >= 3: board_notes.append("公共牌已有 %d 张同一花色，对手有组成同花的可能；不能只看自己的%s就忽略这一点。" % [suits.max(), hand])
		if ranks.values().max() >= 2: board_notes.append("公共牌出现重复点数，要留意对手的三条或葫芦可能。")
		if state.board.size() < 5 and ranked.category < 5:
			for suit in range(4):
				var own = state.hole.filter(func(c): return int(c / 13) == suit).size()
				if own > 0 and suits[suit] + own == 4:
					board_notes.append("你有%s同花听牌，但补成同花也未必一定获胜。" % Eval.SUITS[suit])
	if board_notes.is_empty():
		board_notes.append("这手牌面对的是 %d 名对手；多人继续入池时，不能照搬双人牌局的跟注标准。" % analysis.opponents if analysis.opponents > 1 else "目前只剩一名对手，重点比较这次跟注价格与他可能继续投入的牌。")
	var latest: Dictionary = {}
	for observed in state.actions:
		if observed.seat != 0: latest = observed
	if not latest.is_empty():
		var word: String = {"raise": "加注", "call": "跟注", "check": "过牌", "fold": "弃牌"}.get(latest.action, "行动")
		var name: String = view.seats[latest.seat].name
		board_notes.append("最近一项对手行动是%s%s%s。" % [name, word, "，比此前下注提高 " + money.call(latest.size) if latest.action == "raise" else ""])
	if cost > 0 and cost == hero.stack: board_notes.append("这次跟注会投入你剩下的全部筹码，之后无法再通过弃牌减少损失。")
	if analysis.eligible_pot < state.pot + cost: board_notes.append("底池中有你无法争夺的部分，下面的跟注价格只和你有资格赢取的筹码比较。")
	var alternatives: Array = []
	if state.legal.check:
		alternatives.append("过牌：本次投入为 0。%s" % ["可以控制底池，但也让对手免费继续。" if action == "raise" else "没有必要为了继续这手牌而主动下注。"])
	else:
		alternatives.append("跟注：再付 %s，可争夺的底池为 %s（含这次跟注）。如果之后无人再加钱，预计能分回约 %s；%s" % [money.call(cost), money.call(analysis.eligible_pot), money.call(roundi(analysis.call_ev + cost)), "仍低于这次跟注成本。" if analysis.call_ev < 0 else "后面再遇下注时需要重新判断。"])
	if state.legal.get("raise", false):
		var target: int = analysis.amount if action == "raise" else state.legal.min_raise_to
		var additional: int = target - hero.street_bet
		alternatives.append("%s %s：本次需要再放入 %s，比%s多投入 %s。%s" % ["参考加到" if mixed and action == "raise" else "建议加到" if action == "raise" else "最小加到", money.call(target), money.call(additional), "过牌" if cost == 0 else "跟注", money.call(additional - cost), "希望较弱的牌继续跟注；若被再加注，不要自动跟到底。" if action == "raise" and not mixed else "扩大底池前，要考虑哪些更弱的牌会跟注，哪些更强的牌会继续。"])
	if not state.legal.check:
		alternatives.append("弃牌：从现在起不再投入，但此前投入的筹码不会退回；它们不是继续跟注的理由。")
	var focus = "先确定价格，再决定是否继续。" if cost > 0 else "先确定下注的目的，再选择尺寸。"
	if cost > 0:
		focus = "本手重点：每付 %s，争夺 %s；需要约 %.1f%% 的分池份额才覆盖成本。" % [money.call(cost), money.call(analysis.eligible_pot), odds]
	elif action == "raise" and analysis.opponents == 1:
		var risk: int = analysis.amount - hero.street_bet
		focus = "本手重点：如果是完全没有摊牌权益的纯诈唬，投入 %s 争夺 %s，需要对手弃牌超过 %.1f%% 才回本；这不是当前手牌的建议频率。" % [money.call(risk), money.call(state.pot), 100.0 * risk / maxf(1, state.pot + risk)]
	elif analysis.opponents > 1:
		focus = "本手重点：仍有 %d 名对手，下注需要考虑多人继续的范围，不能套用双人防守比例。" % analysis.opponents
	var next_step: String
	if state.phase == "river":
		next_step = "河牌已经发完，没有下一张补牌。面对新的下注，按新的价格重新判断，不要因为之前跟过就自动跟到底。"
	elif state.phase == "preflop":
		next_step = "翻牌后先确认：是否成对、是否出现听牌，以及还有几名对手继续；不要仅因为翻牌前投入过就坚持到底。"
	else:
		next_step = "下一张公共牌后重新比较你的%s与牌面：同花牌、连续点数或更高的牌，都可能改变继续投入的价值。" % hand
	return {"summary": summary, "context": context, "focus": focus, "status": Feedback.status(analysis), "details": "这手牌的处境\n" + context + "\n\n需要注意什么\n" + "\n".join(board_notes) + "\n\n换一种打法会怎样\n" + "\n\n".join(alternatives) + "\n\n本手练习重点\n" + focus + "\n\n下一步怎么观察\n" + next_step + "\n\n离线近似建议；按当时的信息判断，不以最终输赢评价操作。"}
