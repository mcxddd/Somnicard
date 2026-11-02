extends RefCounted
## Stable seat identities shared by offline play and training.
const DEFAULTS = ["小夏", "阿岚", "米洛", "青禾", "诺亚", "橙子", "阿澈", "星野"]
## One line of character for each seat's portrait. It describes the character, not the
## play: difficulty and style are set per seat and shown next to it.
const BIOS = [
	"戴草帽的常客，来牌桌像来晒太阳。",
	"围巾从不摘下，说话慢，想得也慢。",
	"戴着耳机打牌，听说在听自己的心跳。",
	"刚发芽的新人，每一手都很认真。",
	"当过船长，习惯先看清风向再出手。",
	"笑起来停不下来，很难从表情看出底牌。",
	"墨镜推到头顶，自信全写在脸上。",
	"夜猫子，越晚越清醒。"]

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
