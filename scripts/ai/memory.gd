extends RefCounted
## Factual, bounded observations only. No model reasoning, keys or hidden cards.
const Config = preload("res://scripts/ai/config.gd")
const History = preload("res://scripts/poker/history.gd")
var path: String
var companions: Dictionary = {}

func _init(file_path: String = "user://ai/companions.json") -> void:
	path = file_path
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 1024 * 1024: return
	var raw = JSON.parse_string(file.get_as_text())
	if not raw is Dictionary: return
	for id in raw.keys().slice(0, 32):
		if not id is String or id.length() > 64 or not raw[id] is Dictionary: continue
		var p = Config.seats([raw[id]])[0]
		p.companion_id = id
		p.enabled = true
		p["difficulty"] = _number(raw[id].get("difficulty"), 1, 2)
		p["aggression"] = _number(raw[id].get("aggression"), 0, 2)
		p["memory"] = normalize(raw[id].get("memory", {}))
		companions[id] = p

static func normalize(raw: Variant) -> Dictionary:
	var p: Dictionary = raw if raw is Dictionary else {}
	var out = {"hands": 0, "hero_vpip": 0, "hero_raises": 0, "hero_folds": 0, "recent": [], "seen": []}
	for key in ["hands", "hero_vpip", "hero_raises", "hero_folds"]:
		out[key] = _number(p.get(key), 0, 10000000)
	if p.get("recent") is Array:
		for item in p.recent.slice(-8): out.recent.append(Config.clean(item, 320))
	if p.get("seen") is Array:
		for item in p.seen.slice(-32): out.seen.append(Config.clean(item, 100))
	return out

static func observe(memory: Dictionary, view: Dictionary, seat: int, hand_id: String) -> Dictionary:
	var out = normalize(memory)
	if view.get("phase") != "complete" or hand_id in out.seen: return out
	out.hands += 1
	var vpip = false
	var raised = false
	var folded = false
	var own: Array = []
	for event in view.get("events", []):
		if event.get("kind") != "action": continue
		if event.seat == 0:
			if event.phase == "preflop" and event.action in ["call", "raise"]: vpip = true
			if event.action == "raise": raised = true
			if event.action == "fold": folded = true
		if event.seat == seat: own.append("%s:%s:%d" % [event.phase, event.action, event.to])
	out.hero_vpip += int(vpip)
	out.hero_raises += int(raised)
	out.hero_folds += int(folded)
	out.recent.append(Config.clean("%s；自己的行动 %s；玩家主动入池=%s，加注=%s，弃牌=%s；摊牌=%s" % [hand_id, ",".join(own), vpip, raised, folded, view.result.get("showdown", false)], 320))
	out.seen.append(hand_id)
	return normalize(out)

func save() -> Error:
	var err = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if err != OK: return err
	return History.save(companions, path.get_file(), path.get_base_dir())

func create(seat: Dictionary, profile: Dictionary, memory: Dictionary) -> String:
	if companions.size() >= 32: return ""
	var id = "%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	var value = seat.duplicate(true)
	value.companion_id = id
	value["difficulty"] = profile.difficulty
	value["aggression"] = profile.aggression
	value["memory"] = normalize(memory)
	companions[id] = value
	if save() != OK:
		companions.erase(id)
		return ""
	return id

static func _number(value: Variant, fallback: int, maximum: int) -> int:
	if (value is int or value is float) and is_finite(float(value)): return clampi(int(value), 0, maximum)
	return fallback
