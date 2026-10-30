extends RefCounted
## Backward-compatible, validated settings; gameplay state lives in session.gd.
const Services = preload("res://scripts/ai/services.gd")
const AIConfig = preload("res://scripts/ai/config.gd")
const Profiles = preload("res://scripts/poker/opponent_profiles.gd")
const DEFAULTS = {"sound": 1, "haptics": false, "performance": 0, "bb": true, "speed": 1, "fast_fold": true, "sidebar": false, "felt": 0, "four_color": false, "motion": true, "confirm_all_in": true, "live_teaching": true, "review_teaching": true, "difficulty": 1, "coach_after": false, "coach_auto": false, "coach_detail": 0, "coach_side": 1, "ai_live_coach": false, "ai_review_coach": false}

static func load_values(path: String = "user://preferences.cfg", default_sidebar: bool = false) -> Dictionary:
	var prefs = ConfigFile.new()
	var values = DEFAULTS.duplicate()
	values.sidebar = default_sidebar
	values["opponents"] = Profiles.normalize([])
	values["ai_service"] = AIConfig.service({})
	values["ai_seats"] = AIConfig.seats([])
	values["ai_profiles"] = Services.normalize([])
	values["coach_service_id"] = "default"
	values["players"] = 2
	values["depth"] = 100
	if prefs.load(path) != OK: return values
	for key in DEFAULTS:
		var candidate = prefs.get_value("ui", key, values[key])
		if DEFAULTS[key] is bool:
			if candidate is bool: values[key] = candidate
		elif candidate is int:
			values[key] = clampi(candidate, 0, 2 if key in ["speed", "difficulty", "sound"] else 1)
	values.ai_service = AIConfig.service(prefs.get_value("ai", "service", {}))
	values.ai_seats = AIConfig.seats(prefs.get_value("ai", "seats", []))
	values.ai_profiles = Services.normalize(prefs.get_value("ai", "profiles", []), values.ai_service)
	values.coach_service_id = AIConfig.clean(prefs.get_value("ai", "coach_service_id", "default"), 48)
	values.opponents = Profiles.normalize(prefs.get_value("table", "opponents", []))
	var count = prefs.get_value("table", "players", 2)
	if count is int: values.players = clampi(count, 2, 9)
	var depth = prefs.get_value("table", "depth", 100)
	if depth is int and depth in [50, 100, 200]: values.depth = depth
	return values

static func save_values(values: Dictionary, path: String = "user://preferences.cfg") -> Error:
	var prefs = ConfigFile.new()
	for key in DEFAULTS: prefs.set_value("ui", key, values.get(key, DEFAULTS[key]))
	prefs.set_value("table", "opponents", Profiles.normalize(values.get("opponents", [])))
	prefs.set_value("table", "players", values.get("players", 2))
	prefs.set_value("table", "depth", values.get("depth", 100))
	prefs.set_value("ai", "service", AIConfig.service(values.get("ai_service", {})))
	prefs.set_value("ai", "profiles", Services.normalize(values.get("ai_profiles", []), values.get("ai_service", {})))
	prefs.set_value("ai", "coach_service_id", AIConfig.clean(values.get("coach_service_id", "default"), 48))
	prefs.set_value("ai", "seats", AIConfig.seats(values.get("ai_seats", [])))
	var err = prefs.save(path + ".tmp")
	if err != OK: return err
	return DirAccess.rename_absolute(path + ".tmp", path)
