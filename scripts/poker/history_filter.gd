extends RefCounted
## Lightweight catalogue for searching all saved hands. Opening still replays/validates the record.
const History = preload("res://scripts/poker/history.gd")

static func summary(loaded: Dictionary, filename: String) -> Dictionary:
	var out = {"file": filename, "id": "", "players": 0, "net": 0, "pot": 0, "big_blind": 1, "valid_result": false, "showdown": false, "all_in": false, "raised": false, "vpip": false, "pfr": false, "day": "", "search": filename.to_upper()}
	if not loaded.get("record") is Dictionary: return out
	var record: Dictionary = loaded.record
	var stacks = record.get("starting_stacks")
	if stacks is Array and stacks.size() >= 2 and stacks.size() <= 9: out.players = stacks.size()
	if History._integer(record.get("hand"), 1, 100000000) and History._integer(record.get("button"), 0, 8) and History._integer(record.get("small_blind"), 1, 1000000) and History._integer(record.get("big_blind"), 1, 1000000) and record.get("deck") is Array and record.deck.size() == 52 and out.players > 0:
		out.id = History.hand_id(record)
	var result = record.get("result")
	if result is Dictionary and result.get("payouts") is Dictionary and result.get("contributions") is Array and not result.contributions.is_empty():
		var paid = result.payouts.get("0", result.payouts.get(0))
		if History._integer(paid, 0, 900000000) and History._integer(result.contributions[0], 0, 100000000) and History._integer(record.get("big_blind"), 1, 1000000) and History._integer(result.get("pot"), 0, 900000000):
			out.net = int(paid) - int(result.contributions[0])
			out.pot = int(result.pot)
			out.big_blind = int(record.big_blind)
			out.valid_result = true
			out.showdown = result.get("showdown") == true
	if record.get("events") is Array:
		for event in record.events:
			if event is Dictionary and event.get("kind") == "action" and event.get("seat") == 0:
				out.all_in = out.all_in or event.get("all_in") == true
				out.raised = out.raised or event.get("action") == "raise"
				if event.get("phase") == "preflop":
					out.vpip = out.vpip or event.get("action") in ["call", "raise"]
					out.pfr = out.pfr or event.get("action") == "raise"
	var saved: String = str(record.get("saved_at", ""))
	var pattern = RegEx.new()
	pattern.compile("^[0-9]{4}-[0-9]{2}-[0-9]{2}")
	if pattern.search(saved) != null: out.day = saved.left(10)
	else:
		var stamp = filename.get_slice("-", 0)
		if stamp.is_valid_int() and int(stamp) > 0 and int(stamp) < 4102444800:
			out.day = Time.get_datetime_string_from_unix_time(int(stamp) + int(Time.get_time_zone_from_system().bias) * 60).left(10)
	out.search = (filename + " " + out.id + " " + saved + " " + out.day).to_upper()
	return out

static func matches(item: Dictionary, filters: Dictionary, today: String) -> bool:
	var query: String = filters.get("query", "").strip_edges().to_upper()
	if not query.is_empty() and not item.search.contains(query): return false
	if filters.get("players", 0) > 0 and item.players != filters.players: return false
	var result_filter: int = filters.get("result", 0)
	if result_filter > 0:
		if not item.valid_result: return false
		if result_filter == 1 and item.net <= 0: return false
		if result_filter == 2 and item.net >= 0: return false
		if result_filter == 3 and item.net != 0: return false
	var ending: int = filters.get("ending", 0)
	if ending > 0 and (not item.valid_result or item.showdown != (ending == 1)): return false
	if filters.get("action", 0) == 1 and not item.all_in: return false
	if filters.get("action", 0) == 2 and not item.raised: return false
	var days: int = filters.get("days", 0)
	if days > 0:
		var cutoff = Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_datetime_string(today + "T00:00:00")) - (days - 1) * 86400).left(10)
		if item.day.is_empty() or item.day < cutoff or item.day > today: return false
	return true

static func select(items: Array, filters: Dictionary, today: String) -> Array:
	var found = items.filter(func(item): return matches(item, filters, today))
	var sorting: int = filters.get("sort", 0)
	found.sort_custom(func(a, b):
		if sorting > 0 and a.valid_result != b.valid_result: return a.valid_result
		if sorting == 1 and a.pot * b.big_blind != b.pot * a.big_blind: return a.pot * b.big_blind > b.pot * a.big_blind
		if sorting == 2 and a.net * b.big_blind != b.net * a.big_blind: return a.net * b.big_blind < b.net * a.big_blind
		return a.file > b.file)
	return found.map(func(item): return item.file)
