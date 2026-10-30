extends RefCounted
## Stable seat identities shared by offline play, training and online configuration.
const DEFAULTS = ["小夏", "阿岚", "米洛", "青禾", "诺亚", "橙子", "阿澈", "星野"]

static func for_seat(id: int) -> String:
	return "你" if id == 0 else DEFAULTS[clampi(id - 1, 0, DEFAULTS.size() - 1)]
