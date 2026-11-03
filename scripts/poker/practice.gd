extends RefCounted
## Reconstruct at an action boundary. No mutation of the source record or active table.
const Table = preload("res://scripts/poker/table.gd")
const History = preload("res://scripts/poker/history.gd")
const Advisor = preload("res://scripts/poker/advisor.gd")
const Ranges = preload("res://scripts/poker/range_model.gd")
var game
var model
var source: Dictionary
var point: int
var mode: String
var ready: bool = false
var error: String = ""
var rng = RandomNumberGenerator.new()

static func prefix(record: Dictionary, count: int, deck: Array = []) -> Dictionary:
	var g = Table.new(record.starting_stacks, int(record.small_blind), int(record.big_blind))
	g.hand_number = int(record.hand) - 1
	var cards: Array = deck if not deck.is_empty() else record.deck.map(func(c): return int(c))
	var err = g.start_hand(int(record.button), cards)
	if not err.is_empty(): return {"error": err}
	var actions = record.events.filter(func(e): return e.kind == "action")
	if count < 0 or count > actions.size(): return {"error": "决策序号无效"}
	for e in actions.slice(0, count):
		err = g.act(int(e.seat), e.action, int(e.to))
		if not err.is_empty(): return {"error": err}
	return {"game": g}

func _init(record: Dictionary, action_index: int, kind: String, seed_value: int = -1) -> void:
	source = record.duplicate(true)
	point = action_index
	mode = kind
	if seed_value < 0: rng.randomize()
	else: rng.seed = seed_value
	var checked = History.replay(record)
	if checked.has("error"):
		error = checked.error
		return
	var built = prefix(record, point)
	if built.has("error"):
		error = built.error
		return
	game = built.game
	if game.actor != 0 or game.phase == "complete":
		error = "请选择自己的行动时刻"
		return
	if kind == "original":
		ready = true
		return
	if kind != "sampled":
		error = "未知练习模式"
		return
	var view = game.view_for(0)
	var ids: Array = []
	for seat in view.seats:
		if seat.id != 0 and seat.in_hand: ids.append(seat.id)
	var info = Advisor.information(view)
	model = Ranges.new(info, ids, info.hole + info.board)

func step() -> void:
	if ready or not error.is_empty(): return
	model.prepare_step(32)
	if not model.ready: return
	var dealt: Array = []
	for attempt in range(4096):
		dealt = model.draw_joint(rng)
		if not dealt.is_empty(): break
	if dealt.is_empty():
		error = "此次范围采样未成功，请重试。"
		return
	var deck: Array = source.deck.map(func(c): return int(c))
	var fixed = {}
	var used: Array = game.seats[0].hole + game.board
	for card in used: fixed[deck.find(card)] = card
	for i in range(model.ids.size()):
		var original: Array = game.seats[model.ids[i]].hole
		for n in range(2): fixed[deck.find(original[n])] = dealt[i][n]
		used.append_array(dealt[i])
	var remaining: Array = range(52).filter(func(c): return c not in used)
	for i in range(remaining.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var old = remaining[i]
		remaining[i] = remaining[j]
		remaining[j] = old
	for i in range(52): deck[i] = fixed[i] if fixed.has(i) else remaining.pop_back()
	var rebuilt = prefix(source, point, deck)
	if rebuilt.has("error"): error = rebuilt.error
	else:
		game = rebuilt.game
		ready = true

static func topic(view: Dictionary) -> String:
	if view.phase == "preflop": return "翻前入池"
	if view.phase == "river": return "河牌判断"
	return "面对下注" if view.legal.get("call_amount", 0) > 0 else "主动下注"

static func points(rebuilt: Dictionary) -> Array:
	var found: Array = []
	var count = 0
	for i in range(rebuilt.frames.size()):
		var frame = rebuilt.frames[i]
		if not frame.decision: continue
		if frame.view.actor == 0:
			var event: Dictionary = rebuilt.frames[i + 1].event
			var tags: Array = []
			if event.get("all_in", false): tags.append("全押")
			if event.get("amount", 0) >= frame.view.big_blind * 10: tags.append("大额投入")
			if event.get("action") == "raise": tags.append("加注尺度")
			found.append({"frame": i, "point": count, "topic": topic(frame.view), "tags": tags, "view": frame.view})
		count += 1
	return found

static func feedback(view: Dictionary, analysis: Dictionary, action: String, amount: int) -> String:
	return preload("res://scripts/poker/decision_feedback.gd").compare(view, analysis, action, amount).label

static func reliability(analysis: Dictionary) -> String:
	var s: Dictionary = analysis.get("strategy", {})
	if s.get("supported", false) and s.get("converged", false): return "受限双人河牌参考 · 抽象范围与有限下注树"
	if analysis.cost > 0 and absf(analysis.call_ev) <= analysis.ev_error: return "边缘判断 · 抽样误差内难以区分"
	return "经验建议 · 范围推断与跟注价格，未比较完整后续策略"

static func fixtures() -> Array:
	var out: Array = []
	for i in range(8):
		var stacks: Array = []
		for seat in range([2, 4, 6][i % 3]): stacks.append(500)
		var g = Table.new(stacks, 5, 10, 8300 + i)
		g.start_hand(0)
		var raised = {}
		while g.phase != "complete":
			var legal = g.legal_actions(g.actor)
			if i % 2 == 1 and not raised.has(g.phase) and legal.raise:
				raised[g.phase] = true
				g.act(g.actor, "raise", mini(legal.max_raise_to, maxi(legal.min_raise_to, g.current_bet + 20)))
			else: g.act(g.actor, "check" if legal.check else "call")
		var r = g.completed_record()
		r["fixture"] = true
		r["saved_at"] = "固定练习"
		out.append(r)
	return out
