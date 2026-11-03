extends RefCounted
const Profiles = preload("res://scripts/poker/opponent_profiles.gd")
const History = preload("res://scripts/poker/history.gd")

static func save(game, session_id: String, depth: int, saved_hand: int, directory: String = "user://", opponents: Array = [], changes: Array = [], configured: Array = [], default_level: int = 1) -> Error:
	var record = game.record_state()
	record["seat_names"] = game.seats.map(func(s): return s.name)
	if not configured.is_empty(): record["opponent_settings"] = {"profiles": Profiles.normalize(configured), "difficulty": clampi(default_level, 0, 2)}
	record["opponents"] = opponents.duplicate(true)
	record["opponent_changes"] = changes.duplicate(true)
	record["session_id"] = session_id
	record["starting_bb"] = depth
	record["saved_hand"] = saved_hand
	return History.save(record, "session.json", directory)

static func restore(path: String = "user://session.json") -> Dictionary:
	var loaded = History.read_record(path)
	if loaded.has("error"): return loaded
	var record: Dictionary = loaded.record
	if not record.get("session_id") is String or record.session_id.length() > 80 or record.session_id.is_empty(): return {"error": "存档标识无效"}
	for character in record.session_id:
		if character not in "0123456789-": return {"error": "存档标识无效"}
	if not History._integer(record.get("starting_bb"), 15, 200) or int(record.starting_bb) not in History.Table.DEPTHS: return {"error": "初始筹码无效"}
	if not History._integer(record.get("saved_hand"), -1, 100000000): return {"error": "保存进度无效"}
	if record.get("opponent_settings") is Dictionary:
		var config: Dictionary = record.opponent_settings
		record.opponent_settings = {"profiles": Profiles.normalize(config.get("profiles", [])), "difficulty": int(config.difficulty) if Profiles._integer(config.get("difficulty"), 0, 2) else 1}
	if record.has("opponents"): record.opponents = Profiles.normalize(record.opponents)
	if not record.get("opponent_changes", []) is Array: record.opponent_changes = []
	if record.get("opponent_changes") is Array:
		record.opponent_changes = record.opponent_changes.filter(func(c): return c is Dictionary and Profiles._integer(c.get("event"), 0, 1000000) and c.get("profiles") is Array)
	return History.replay(record, false)
