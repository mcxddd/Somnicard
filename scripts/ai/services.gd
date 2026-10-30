extends RefCounted
## Public model profiles only. Credentials are carried separately, never normalized here.
const Config = preload("res://scripts/ai/config.gd")

static func normalize(raw: Variant, legacy: Dictionary = {}) -> Array:
	var out: Array = []
	var ids: Array = []
	if raw is Array:
		for item in raw:
			if not item is Dictionary or out.size() >= 16: continue
			var id = Config.clean(item.get("id", ""), 48)
			if id.is_empty() or id in ids: continue
			ids.append(id)
			out.append({"id": id, "label": Config.clean(item.get("label", "模型档案"), 24), "service": Config.service(item.get("service", {})), "remember": item.get("remember") == true})
	if "default" not in ids: out.push_front({"id": "default", "label": "默认模型", "service": Config.service(legacy), "remember": false})
	return out.slice(0, 16)

static func find(profiles: Array, id: String) -> Dictionary:
	for p in profiles:
		if p.id == id: return p
	return {}

static func resolve(profiles: Array, id: String, legacy: Dictionary = {}) -> Dictionary:
	if id.is_empty(): id = "default"
	var p = find(profiles, id)
	if not p.is_empty(): return Config.service(p.service)
	if id == "default": return Config.service(legacy)
	return Config.service({})

static func binding(service: Dictionary) -> String:
	var base = Config.base_endpoint(str(service.get("endpoint", "")))
	return str(base.get("url", "")).sha256_text()
