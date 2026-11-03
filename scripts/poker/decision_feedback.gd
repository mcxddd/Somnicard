extends RefCounted
## Post-decision comparison only. Never feed the actual choice into the solver.
const UI = preload("res://scripts/ui/style.gd")

static func value_text(value: float, blind: int, bb: bool) -> String:
	return "%+.2f BB" % (value / blind) if bb else "%+.2f 筹码" % value

static func compare(view: Dictionary, analysis: Dictionary, action: String, amount: int, bb: bool = true) -> Dictionary:
	var s: Dictionary = analysis.get("strategy", {})
	var selected: Dictionary = {}
	if s.get("supported", false) and s.get("converged", false):
		var best = -INF
		for option in s.get("frequencies", []):
			if option.has("ev"): best = maxf(best, float(option.ev))
			# Preflop chart sizes are a ladder, not exact amounts: any raise matches the chart raise.
			if option.action == action and (action != "raise" or option.amount == amount or s.get("kind", "") == "preflop"): selected = option
		if selected.is_empty(): return {"label": "未覆盖此尺度", "text": "你的下注尺寸不在这次求解的行动树中，不能据此判断优劣。可对照表中尺寸，再重打这个局面。", "scored": false}
		var label = "参考混合打法" if selected.frequency >= 0.05 else "低频选择"
		var text = "这次模型给该操作 %.1f%% 的参考比例；低频不等于绝不能采用。" % (selected.frequency * 100)
		if selected.has("ev") and is_finite(best):
			var loss = maxf(0.0, best - selected.ev)
			text += "\n该操作模型 EV %s；比表中最高值少约 %s。此差值只针对当前牌力档和受限树，不是本手实际输掉的筹码。" % [value_text(selected.ev, view.big_blind, bb), ("%.2f BB" % (loss / view.big_blind) if bb else "%.2f 筹码" % loss)]
			return {"label": label, "text": text, "scored": true, "loss": loss, "ev": selected.ev}
		return {"label": label, "text": text, "scored": false}
	var close = analysis.cost > 0 and absf(analysis.call_ev) <= maxf(analysis.ev_error, view.big_blind * 0.15)
	if close and action in ["fold", "call"]: return {"label": "边缘决策", "text": "跟注与弃牌的差距接近估算误差。先检查对手范围是否合理，不把这次选择记成明确错误。", "scored": false}
	var label = "不同选择"
	if action == analysis.action: label = "同类打法，金额不同" if action == "raise" and amount != analysis.amount else "与建议一致"
	var text = "尚未比较完整行动树，不为这个操作给出精确损失。"
	if action in ["fold", "call"] and analysis.cost > 0:
		text += "\n若后续无人再投入，跟注的估计净值为 %s，抽样区间约 %s 至 %s；弃牌从现在起不再损失筹码。" % [value_text(analysis.call_ev, view.big_blind, bb), value_text(analysis.call_ev - analysis.ev_error, view.big_blind, bb), value_text(analysis.call_ev + analysis.ev_error, view.big_blind, bb)]
	else:
		text += "问自己：哪些更弱的牌会付钱，哪些更强的牌会弃牌？若两者都不明确，先考虑控制底池。"
	return {"label": label, "text": text, "scored": false}

static func status(analysis: Dictionary) -> String:
	var strategy: Dictionary = analysis.get("strategy", {})
	if strategy.get("budget_limited", false): return "计算达到时间预算 · 先采用经验建议"
	if strategy.get("kind", "") == "preflop": return "翻牌前 100 BB 近似均衡 · 预先求解"
	if strategy.get("kind", "") == "pushfold": return "短筹码全押均衡 · 预先求解" + ("" if strategy.spot.exact else "（多人为近似）")
	if strategy.get("supported", false): return "河牌抽象策略 · 已达模型内目标" if strategy.get("converged", false) else "河牌求解未达目标 · 先采用经验建议"
	return "经验建议 · 此局面未运行 GTO 求解"
