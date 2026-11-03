extends RefCounted
## Precomputed short-stack push/fold equilibrium (tools/solvers/pushfold.mjs).
## Applies preflop at ≤15 BB effective when the player is first in, or faces a
## single all-in with nobody calling yet. Heads-up the table is the full
## push/fold equilibrium; with 3–6 players it assumes at most one caller.
## Uses only public information and the asking seat's own cards.
const Ranges = preload("res://scripts/poker/range_model.gd")
const PATH = "res://data/pushfold.json"
const MAX_BB = 15.5
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary: _data = parsed
	return _data

## 13×13 grid index shared with the range grid: row/col count down from A; upper right is suited.
static func class_index(hole: Array) -> int:
	var a = 12 - hole[0] % 13
	var b = 12 - hole[1] % 13
	if a == b: return a * 13 + a
	var suited = int(hole[0] / 13) == int(hole[1] / 13)
	return mini(a, b) * 13 + maxi(a, b) if suited else maxi(a, b) * 13 + mini(a, b)

## Order in the chart: UTG … BTN, SB, BB (heads-up: SB, BB).
static func order(view: Dictionary, seat_id: int, dealt: Array) -> int:
	var start = dealt.find(int(view.get("button", 0)))
	var offset = (dealt.find(seat_id) - start + dealt.size()) % dealt.size()
	if dealt.size() == 2: return offset
	return [dealt.size() - 3, dealt.size() - 2, dealt.size() - 1][offset] if offset <= 2 else offset - 3

## {} when the spot is outside the table; otherwise the equilibrium choice for `seat_id`.
static func lookup(view: Dictionary, seat_id: int, hole: Array) -> Dictionary:
	if not view.board.is_empty() or hole.size() != 2 or view.legal.is_empty(): return {}
	var bb: int = view.big_blind
	var dealt: Array = []
	for seat in view.seats:
		if seat.in_hand: dealt.append(seat.id)
	if dealt.size() < 2 or dealt.size() > 6: return {}
	var shover = -1
	for a in view.get("actions", Ranges.public_actions(view)):
		if a.action == "fold": continue
		if a.action == "raise" and shover < 0:
			shover = a.seat
			continue
		return {}  # a limp, a call or a second raise: outside push/fold
	var own = view.seats[seat_id]
	var own_total: int = own.stack + own.total_bet
	var effective: int
	if shover < 0:
		if view.current_bet > bb: return {}
		var deepest = 0
		for seat in view.seats:
			if seat.id != seat_id and seat.in_hand and not seat.folded: deepest = maxi(deepest, seat.stack + seat.total_bet)
		effective = mini(own_total, deepest)
	else:
		var s = view.seats[shover]
		if s.stack > 0: return {}  # a raise that is not all-in
		effective = mini(own_total, s.total_bet)
	var depth = float(effective) / bb
	if depth > MAX_BB or depth < 1.5: return {}
	var n = dealt.size()
	var table: Dictionary = data().get("tables", {}).get("%d/%d" % [n, clampi(roundi(depth), 2, 15)], {})
	if table.is_empty(): return {}
	var me = order(view, seat_id, dealt)
	var h = class_index(hole)
	var frequency: float
	var margin: float
	if shover < 0:
		if me >= n - 1: return {}
		frequency = _frequency(table.push[me], h)
		margin = _margin(table.push_margin[me], h)
	else:
		var i = order(view, shover, dealt)
		if me <= i: return {}
		frequency = _frequency(table.call[i][me - i - 1], h)
		margin = _margin(table.call_margin[i][me - i - 1], h)
	var names: Array = data().positions[str(n)]
	return {"facing": shover >= 0, "frequency": frequency, "margin_bb": margin, "depth_bb": depth, "chart_bb": clampi(roundi(depth), 2, 15),
		"players": n, "position": names[me], "shover": names[order(view, shover, dealt)] if shover >= 0 else "",
		"exact": n == 2, "exploitability_bb": float(table.exploitability), "version": str(data().version)}

static func _frequency(text: String, h: int) -> float:
	return "0123456789a".find(text[h]) / 10.0

static func _margin(text: String, h: int) -> float:
	return int(text.split(",")[h]) / 100.0

## Advisor strategy record in the same shape as the river solver's.
static func strategy(view: Dictionary, seat_id: int, hole: Array) -> Dictionary:
	var spot = lookup(view, seat_id, hole)
	if spot.is_empty(): return {}
	var legal: Dictionary = view.legal
	var bb: int = view.big_blind
	var aggressive = {"action": "call", "amount": 0} if spot.facing else {"action": "raise", "amount": int(legal.get("max_raise_to", 0))}
	if spot.facing and not legal.get("call", false): return {}
	if not spot.facing and not legal.get("raise", false): return {}
	var scope = "短筹码全押均衡" + ("" if spot.exact else "（最多一人跟注）")
	var line = "%s · %d 人 · 约 %d BB · %s%s" % [scope, spot.players, spot.chart_bb, spot.position, "，面对 %s 全押" % spot.shover if spot.facing else "，前面都弃牌"]
	return {"supported": true, "kind": "pushfold", "scope": scope, "converged": true,
		"frequencies": [aggressive.merged({"frequency": spot.frequency, "ev": spot.margin_bb * bb}), {"action": "fold", "amount": 0, "frequency": 1.0 - spot.frequency, "ev": 0.0}],
		"exploitability": spot.exploitability_bb * bb, "tolerance": bb * 0.01, "spot": spot,
		"reason": line + "。EV 是相对弃牌的筹码期望（不含已投入的盲注），按均衡对手范围计算。" + ("" if spot.exact else "三人以上时假设一人跟注后其余玩家都弃牌。")}
