extends RefCounted
## Only these public settings may be serialized. The API key lives in RAM.
const NAMES = preload("res://scripts/poker/player_names.gd").DEFAULTS

static func clean(value: Variant, limit: int = 32) -> String:
	if not value is String: return ""
	var out = ""
	for c in value:
		if c.unicode_at(0) >= 32 and c.unicode_at(0) != 127: out += c
	return out.strip_edges().left(limit)

static func seats(raw: Variant) -> Array:
	var out: Array = []
	for i in range(8):
		var p = raw[i] if raw is Array and i < raw.size() and raw[i] is Dictionary else {}
		var name = clean(p.get("name", NAMES[i]), 12)
		out.append({"enabled": p.get("enabled") == true, "name": name if name != "" else NAMES[i], "persona": clean(p.get("persona", "友善、简洁，专注扑克"), 120), "companion_id": clean(p.get("companion_id", ""), 64), "service_id": clean(p.get("service_id", "default"), 48)})
	return out

static func service(raw: Variant) -> Dictionary:
	var p: Dictionary = raw if raw is Dictionary else {}
	return {"endpoint": clean(p.get("endpoint", ""), 512), "model": clean(p.get("model", ""), 120), "timeout": 60, "speech": p.get("speech", true) == true, "api": "messages" if p.get("api") == "messages" else "chat"}

static func endpoint(value: String) -> Dictionary:
	var base = base_endpoint(value)
	return base if base.has("error") else {"url": base.url + "/chat/completions"}

static func base_endpoint(value: String) -> Dictionary:
	var url = value.strip_edges().trim_suffix("/")
	if url.is_empty(): return {"error": "请填写服务地址"}
	if clean(value, 1024) != value.strip_edges() or "@" in url or "?" in url or "#" in url or "\\" in url or " " in url: return {"error": "服务地址不能含账号、查询参数或特殊字符"}
	var secure = url.begins_with("https://")
	if not secure and not url.begins_with("http://"): return {"error": "服务地址需要以 https:// 开头"}
	var host = url.split("://", true, 1)[1].split("/")[0]
	if host.is_empty(): return {"error": "服务地址缺少域名"}
	if not secure and host.split(":")[0] not in ["localhost", "127.0.0.1", "[::1]"]: return {"error": "仅本机调试可使用 HTTP，远程服务请使用 HTTPS"}
	var explicit_route = false
	for suffix in ["/chat/completions", "/messages", "/responses", "/models"]:
		if url.ends_with(suffix):
			url = url.trim_suffix(suffix)
			explicit_route = true
			break
	var origin = url.split("://", true, 1)[0] + "://" + host
	if origin == "https://api.commandcode.ai" and url in [origin, origin + "/v1"]: url = origin + "/provider/v1"
	elif url == origin and not explicit_route and origin != "https://api.deepseek.com": url += "/v1"
	return {"url": url}

static func validate(p: Dictionary) -> String:
	var result = endpoint(str(p.get("endpoint", "")))
	if result.has("error"): return result.error
	if clean(p.get("model", ""), 120).is_empty(): return "请填写模型名称"
	return ""
