extends RefCounted
const UI = preload("res://scripts/ui/style.gd")

static func net(view: Dictionary, id: int) -> int:
	return int(view.result.payouts.get(id, 0)) - int(view.result.contributions[id])

static func net_text(view: Dictionary, id: int, bb: bool) -> String:
	var amount = net(view, id)
	return ("净赢 +" if amount > 0 else "净输 " if amount < 0 else "不输不赢 ") + UI.money(absi(amount), view.big_blind, bb)

static func summary(view: Dictionary) -> String:
	var shared: Array = []
	for i in range(view.result.pots.size()):
		if view.result.pots[i].winners.size() > 1:
			shared.append("底池" if view.result.pots.size() == 1 else "主池" if i == 0 else "边池 %d" % i)
	if not shared.is_empty(): return "平分" + "、".join(shared)
	if view.result.pots.size() > 1: return "主池 / 边池已分配"
	var names: Array = []
	for id in view.result.payouts:
		if view.result.payouts[id] > 0: names.append(view.seats[id].name)
	return "、".join(names) + "赢得底池"
