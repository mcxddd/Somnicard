extends RefCounted
## Ephemeral, bounded diagnostics. Never part of saves, backups or companions.
const MAX_ENTRIES = 160
const MAX_BYTES = 2097152
var entries: Array = []

static func redact(value: Variant, secrets: Array) -> Variant:
	if value is String:
		var clean: String = value
		for secret in secrets:
			if secret is String and not secret.is_empty(): clean = clean.replace(secret, "[已隐藏密钥]")
		var pattern = RegEx.new()
		pattern.compile("(?i)Bearer\\s+[A-Za-z0-9._~+/=-]+|\\bsk-[A-Za-z0-9_-]{8,}")
		clean = pattern.sub(clean, "[已隐藏密钥]", true)
		return clean.left(32768) + ("\n…记录已截短" if clean.length() > 32768 else "")
	if value is Dictionary:
		var copy = {}
		for key in value:
			if str(key).to_lower() in ["authorization", "api_key", "key", "reasoning_content", "thinking", "reasoning"]: continue
			copy[key] = redact(value[key], secrets)
		return copy
	if value is Array:
		return value.slice(0, 128).map(func(item): return redact(item, secrets))
	return value

func append(entry: Dictionary, secrets: Array = []) -> void:
	var clean: Dictionary = redact(entry, secrets)
	if not clean.has("id"): return
	if JSON.stringify(clean.get("request", {})).length() > 65536:
		clean["request"] = {"record_truncated": true, "preview": JSON.stringify(clean.request).left(65536) + "\n…请求记录过长，已截短"}
	for i in range(entries.size()):
		if entries[i].id == clean.id:
			entries[i] = clean
			_prune()
			return
	entries.append(clean)
	_prune()

func _prune() -> void:
	while entries.size() > MAX_ENTRIES: entries.pop_front()
	while entries.size() > 1 and JSON.stringify(entries).to_utf8_buffer().size() > MAX_BYTES: entries.pop_front()

func for_seat(seat: int) -> Array:
	return entries.filter(func(e): return e.get("context", {}).get("seat", -1) == seat).duplicate(true)

func resolve(id: String, outcome: String) -> void:
	for entry in entries:
		if entry.id == id:
			entry["outcome"] = outcome
			return

static func unlocked(entry: Dictionary, hand: int, complete: bool) -> bool:
	return int(entry.get("context", {}).get("hand", hand)) < hand or complete

func clear() -> void:
	entries.clear()
