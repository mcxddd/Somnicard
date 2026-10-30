extends RefCounted
const Config = preload("res://scripts/ai/config.gd")
const Providers = preload("res://scripts/ai/providers.gd")

static func parse(raw: Variant) -> Dictionary:
	var data = raw.get("data", raw.get("models", [])) if raw is Dictionary else raw
	if not data is Array: return {"error": "服务返回的模型列表格式无法识别，可重试或手动填写模型。"}
	var models: Array = []
	var seen: Dictionary = {}
	var skipped = 0
	for entry in data.slice(0, 4096):
		var item: Dictionary = {"id": entry} if entry is String else entry if entry is Dictionary else {}
		var raw_id = item.get("id", "")
		var id = Config.clean(raw_id, 120)
		if id.is_empty() or id != raw_id or seen.has(id): continue
		seen[id] = true
		var api = "chat"
		if item.has("supported_endpoints"):
			var routes = item.supported_endpoints
			if not routes is Array: skipped += 1; continue
			if routes.any(func(r): return r is String and r.ends_with("/chat/completions")): api = "chat"
			elif routes.any(func(r): return r is String and r.ends_with("/messages")): api = "messages"
			else: skipped += 1; continue
		else:
			var lower = id.to_lower()
			var excluded = ["embedding", "rerank", "whisper", "tts-", "dall-e", "gpt-image", "moderation", "transcribe", "realtime", "sora", "text-to-image"]
			if excluded.any(func(word): return word in lower): skipped += 1; continue
		models.append({"id": id, "name": Config.clean(item.get("name", id), 120), "api": api})
	models.sort_custom(func(a, b): return a.id.naturalnocasecmp_to(b.id) < 0)
	return {"models": models, "skipped": skipped}

static func initial(models: Array, current: String, endpoint: String) -> int:
	for i in range(models.size()):
		if models[i].id == current: return i
	var preferred = Providers.PRESETS[Providers.identify(endpoint)].model
	for i in range(models.size()):
		if preferred != "" and models[i].id == preferred: return i
	# Choose an available small/fast variant without inventing a model ID or a price claim.
	for word in ["flash", "mini", "haiku", "luna"]:
		for i in range(models.size()):
			if word in models[i].id.to_lower(): return i
	return 0 if not models.is_empty() else -1
