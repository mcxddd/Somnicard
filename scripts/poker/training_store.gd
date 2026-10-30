extends RefCounted
## Training metadata is separate from immutable hand records and ordinary table statistics.
const History = preload("res://scripts/poker/history.gd")
const TAGS = ["跟注犹豫", "加注尺度", "诈唬判断", "翻前入池", "河牌判断"]
var path: String
var data: Dictionary = {"schema": 1, "marks": {}, "attempts": [], "branches": {}, "session": {}, "decisions": {}}
var error: String = ""
var load_failed: bool = false

func _init(storage_path: String = "user://training/profile.json") -> void:
	path = storage_path
	if path.is_empty() or not FileAccess.file_exists(path): return
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 64 * 1024 * 1024:
		load_failed = true
		error = "训练档案无法读取，原文件已保留。"
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if valid(parsed): data = parsed
	else:
		load_failed = true
		error = "训练档案格式损坏，原文件已保留；请从备份恢复。"

static func valid(value) -> bool:
	if not value is Dictionary or value.get("schema") != 1: return false
	if not preload("res://scripts/product/academy.gd").valid(value.get("academy", {})): return false
	if not value.get("marks") is Dictionary or not value.get("attempts") is Array or not value.get("branches") is Dictionary or not value.get("session") is Dictionary: return false
	if value.marks.size() > 20000 or value.attempts.size() > 100000 or value.branches.size() > 10000: return false
	var decisions = value.get("decisions", {})
	if not decisions is Dictionary or decisions.size() > 5000: return false
	for key in decisions:
		var d = decisions[key]
		if not key is String or key.length() > 120 or not d is Dictionary: return false
		for field in ["hand", "topic", "reason", "verdict", "date"]:
			if not d.get(field) is String or d[field].length() > 500: return false
		if not History._integer(d.get("point"), 0, 1000) or not d.get("scored") is bool: return false
	for id in value.marks:
		var m = value.marks[id]
		if not id is String or id.length() > 80 or not m is Dictionary: return false
		if not m.get("star", false) is bool or not m.get("pending", false) is bool or not m.get("seen", false) is bool: return false
		if not m.get("note", "") is String or m.get("note", "").length() > 2000 or not m.get("tags", []) is Array: return false
		for tag in m.get("tags", []):
			if tag not in TAGS: return false
	for a in value.attempts:
		if not a is Dictionary: return false
		for key in ["id", "hand", "topic", "action", "feedback", "date"]:
			if not a.get(key) is String or a[key].length() > 1000: return false
		if not History._integer(a.get("point"), 0, 1000) or not History._integer(a.get("amount"), 0, 900000000): return false
		if not a.get("unclear", false) is bool: return false
	for id in value.branches:
		var b = value.branches[id]
		if not id is String or id.length() > 100 or not b is Dictionary or not b.get("record") is Dictionary or not b.get("source") is String or not b.get("mode") is String or not History._integer(b.get("point"), 0, 1000): return false
	var session: Dictionary = value.session
	if not session.is_empty():
		if not session.get("queue") is Array or session.queue.is_empty() or session.queue.size() > 5 or not History._integer(session.get("cursor"), 0, session.queue.size() - 1): return false
		if not session.get("answer") is Dictionary or not History._integer(session.get("mode"), 0, 1) or not session.get("playing") is bool or not session.get("branch_id") is String: return false
		for c in session.queue:
			if not c is Dictionary or not c.get("record") is Dictionary or not History._integer(c.get("point"), 0, 1000) or not c.get("topic") is String: return false
		var a: Dictionary = session.answer
		if not a.is_empty():
			if a.get("action") not in ["fold", "call", "check", "raise"] or not History._integer(a.get("amount"), 0, 900000000) or not a.get("attempt", "") is String: return false
		if session.playing and not session.get("branch_record") is Dictionary: return false
	return true

func save() -> bool:
	if path.is_empty(): return true
	if load_failed: return false
	var result = History.save(data, path.get_file(), path.get_base_dir())
	if result != OK:
		error = "训练保存失败，请检查存储空间；当前内容仍在内存中。"
		return false
	error = ""
	return true

func mark(id: String) -> Dictionary:
	var value = {"star": false, "pending": false, "seen": false, "tags": [], "note": ""}
	value.merge(data.marks.get(id, {}), true)
	return value.duplicate(true)

func set_mark(id: String, value: Dictionary) -> bool:
	data.marks[id] = value.duplicate(true)
	return save()

func seen(id: String) -> void:
	var m = mark(id)
	if m.seen: return
	m.seen = true
	set_mark(id, m)

static func uid() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()

func add_attempt(hand: String, point: int, topic: String, action: String, amount: int, feedback: String) -> String:
	var id = uid()
	data.attempts.append({"id": id, "hand": hand, "point": point, "topic": topic, "action": action, "amount": amount, "feedback": feedback, "date": Time.get_datetime_string_from_system(), "unclear": false})
	save()
	return id

func set_unclear(id: String, value: bool) -> void:
	for a in data.attempts:
		if a.id == id:
			a.unclear = value
			var m = mark(a.hand)
			m.pending = value or data.attempts.any(func(other): return other.hand == a.hand and other.unclear)
			data.marks[a.hand] = m
			break
	save()

func save_branch(record: Dictionary, source: String, point: int, mode: String) -> String:
	var id = uid()
	data.branches[id] = {"record": record.duplicate(true), "source": source, "point": point, "mode": mode, "date": Time.get_datetime_string_from_system()}
	save()
	return id

func report() -> Dictionary:
	var topics = {}
	var reviewed = {}
	for a in data.attempts:
		if not topics.has(a.topic): topics[a.topic] = {"total": 0, "unclear": 0, "different": 0}
		topics[a.topic].total += 1
		topics[a.topic].unclear += int(a.unclear)
		topics[a.topic].different += int(a.feedback == "不同选择")
		reviewed[a.hand + ":" + str(a.point)] = true
	var suggested = "翻前入池"
	var priority = -1
	for topic in topics:
		var weight: int = topics[topic].unclear * 3 + topics[topic].different
		if weight > priority:
			priority = weight
			suggested = topic
	return {"attempts": data.attempts.size(), "positions": reviewed.size(), "topics": topics, "suggested": suggested}

func suggest_hand(record: Dictionary) -> void:
	var rebuilt = History.replay(record)
	if rebuilt.has("error"): return
	var points = preload("res://scripts/poker/practice.gd").points(rebuilt)
	points.sort_custom(func(a, b): return a.view.legal.call_amount > b.view.legal.call_amount)
	for p in points.slice(0, 3):
		remember_decision(History.hand_id(record), p.point, p.topic, "待讨论", false, "较大跟注或关键行动，值得回看；尚未评价好坏。")

func remember_decision(hand: String, point: int, topic: String, verdict: String, scored: bool, reason: String) -> void:
	if not data.has("decisions"): data["decisions"] = {}
	var key = hand + ":" + str(point)
	if verdict == "待讨论" and data.decisions.has(key): return
	if data.decisions.size() >= 5000 and not data.decisions.has(key): data.decisions.erase(data.decisions.keys()[0])
	data.decisions[key] = {"hand": hand, "point": point, "topic": topic, "verdict": verdict, "scored": scored, "reason": reason.left(500), "date": Time.get_datetime_string_from_system()}
	save()

func suggested_decisions() -> Array:
	var rows: Array = data.get("decisions", {}).values().duplicate(true)
	rows.reverse()
	return rows.slice(0, 12)
