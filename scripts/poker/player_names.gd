extends RefCounted
## Stable seat identities shared by offline play and training.
const DEFAULTS = ["小夏", "阿岚", "米洛", "青禾", "诺亚", "橙子", "阿澈", "星野"]

static func for_seat(id: int) -> String:
	return "你" if id == 0 else DEFAULTS[clampi(id - 1, 0, DEFAULTS.size() - 1)]

static func clean(value: Variant, limit: int = 12) -> String:
	if not value is String: return ""
	var out = ""
	for c in value:
		if c.unicode_at(0) >= 32 and c.unicode_at(0) != 127: out += c
	return out.strip_edges().left(limit)

static func normalize(raw: Variant) -> Array:
	var out: Array = []
	for i in range(8):
		var name = clean(raw[i] if raw is Array and i < raw.size() else DEFAULTS[i])
		out.append(name if name != "" else DEFAULTS[i])
	return out
