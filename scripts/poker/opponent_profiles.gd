extends RefCounted
## Seat 1..8; -1 inherits the global level. Style is independent of skill.
const LEVELS = ["入门", "标准", "进阶"]
const STYLES = ["均衡", "偏被动", "偏激进"]
const DESCRIPTIONS = [
	"休闲型：起手范围偏宽，爱跟注；位置与大额下注判断较粗糙。",
	"基础策略型：重视位置、跟注价格和听牌，多人底池更谨慎。",
	"策略比较型：进一步比较下注尺寸与被跟注后的价值，控制边缘跟注。"
]

static func normalize(raw: Variant) -> Array:
	var out: Array = []
	for i in range(8):
		var p: Dictionary = raw[i] if raw is Array and i < raw.size() and raw[i] is Dictionary else {}
		var level: Variant = p.get("difficulty", -1)
		var style: Variant = p.get("aggression", 0)
		out.append({"difficulty": int(level) if _integer(level, -1, 2) else -1,
			"aggression": int(style) if _integer(style, 0, 2) else 0})
	return out

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= low and value <= high

static func resolve(profiles: Array, seat: int, default_level: int) -> Dictionary:
	var p: Dictionary = normalize(profiles)[clampi(seat - 1, 0, 7)]
	return {"difficulty": clampi(default_level, 0, 2) if p.difficulty < 0 else p.difficulty, "aggression": p.aggression}

static func snapshot(profiles: Array, count: int, default_level: int) -> Array:
	var out: Array = []
	for id in range(1, count): out.append(resolve(profiles, id, default_level))
	return out

static func label(p: Dictionary) -> String:
	return LEVELS[p.difficulty] + " · " + STYLES[p.aggression]

static func record_snapshot(record: Dictionary, event_count: int) -> Array:
	# Never use a later configuration when returning to an earlier decision.
	var selected: Array = []
	var latest = -1
	if record.get("opponent_changes") is Array:
		for change in record.opponent_changes:
			if not change is Dictionary or not _integer(change.get("event"), 0, event_count) or not change.get("profiles") is Array: continue
			if int(change.event) >= latest:
				selected = normalize(change.profiles)
				latest = int(change.event)
	elif record.get("opponents") is Array: selected = normalize(record.opponents)
	return selected
