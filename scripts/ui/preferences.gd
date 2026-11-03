extends RefCounted
## Backward-compatible, validated settings; gameplay state lives in session.gd.
const Names = preload("res://scripts/poker/player_names.gd")
const Profiles = preload("res://scripts/poker/opponent_profiles.gd")
const DEFAULTS = {"sound": 1, "haptics": false, "performance": 0, "bb": true, "speed": 1, "fast_fold": true, "sidebar": false, "felt": 0, "four_color": false, "motion": true, "confirm_all_in": true, "live_teaching": true, "review_teaching": true, "difficulty": 1, "coach_after": false, "coach_auto": false, "coach_detail": 0, "coach_side": 1, "text_size": 1}

static func load_values(path: String = "user://preferences.cfg", default_sidebar: bool = false) -> Dictionary:
	var prefs = ConfigFile.new()
	var values = DEFAULTS.duplicate()
	values.sidebar = default_sidebar
	values["opponents"] = Profiles.normalize([])
	values["seat_names"] = Names.normalize([])
	values["players"] = 2
	values["depth"] = 100
	if prefs.load(path) != OK: return values
	for key in DEFAULTS:
		var candidate = prefs.get_value("ui", key, values[key])
		if DEFAULTS[key] is bool:
			if candidate is bool: values[key] = candidate
		elif candidate is int:
			values[key] = clampi(candidate, 0, 2 if key in ["speed", "difficulty", "sound", "text_size"] else 1)
	var names = prefs.get_value("table", "seat_names", [])
	if not prefs.has_section_key("table", "seat_names") and prefs.has_section_key("ai", "seats"):
		var old = prefs.get_value("ai", "seats", [])
		if old is Array: names = old.map(func(p): return p.get("name", "") if p is Dictionary else "")
	values.seat_names = Names.normalize(names)
	values.opponents = Profiles.normalize(prefs.get_value("table", "opponents", []))
	var count = prefs.get_value("table", "players", 2)
	if count is int: values.players = clampi(count, 2, 6)
	var depth = prefs.get_value("table", "depth", 100)
	if depth is int and depth in [15, 50, 100, 200]: values.depth = depth
	return values

static func save_values(values: Dictionary, path: String = "user://preferences.cfg") -> Error:
	var prefs = ConfigFile.new()
	for key in DEFAULTS: prefs.set_value("ui", key, values.get(key, DEFAULTS[key]))
	prefs.set_value("table", "seat_names", Names.normalize(values.get("seat_names", [])))
	prefs.set_value("table", "opponents", Profiles.normalize(values.get("opponents", [])))
	prefs.set_value("table", "players", values.get("players", 2))
	prefs.set_value("table", "depth", values.get("depth", 100))
	var err = prefs.save(path + ".tmp")
	if err != OK: return err
	return DirAccess.rename_absolute(path + ".tmp", path)
