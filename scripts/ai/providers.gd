extends RefCounted
## Endpoints verified against official documentation. Model catalogs stay live.
const PRESETS = [
	{"id": "custom", "label": "自定义兼容服务", "endpoint": "", "model": "", "hint": "填写地址与密钥，自动获取模型；也支持粘贴完整请求地址。"},
	{"id": "deepseek", "label": "DeepSeek", "endpoint": "https://api.deepseek.com", "model": "deepseek-flash", "hint": "填入 DeepSeek 密钥后自动获取模型。"},
	{"id": "openai", "label": "OpenAI", "endpoint": "https://api.openai.com/v1", "model": "", "hint": "填入 API 密钥后获取账号可见模型，再测试所选模型。"},
	{"id": "siliconflow", "label": "硅基流动", "endpoint": "https://api.siliconflow.cn/v1", "model": "", "hint": "填入硅基流动密钥后自动获取模型。"},
	{"id": "qwen", "label": "阿里云百炼 · 北京", "endpoint": "https://dashscope.aliyuncs.com/compatible-mode/v1", "model": "qwen-plus", "hint": "使用对应地域的密钥；也可粘贴控制台的业务空间地址。"},
	{"id": "commandcode", "label": "CommandCode", "endpoint": "https://api.commandcode.ai/provider/v1", "model": "", "hint": "填入 CommandCode API 密钥。模型与连接方式自动识别。"}
]

static func identify(endpoint: String) -> int:
	var url = endpoint.strip_edges().trim_suffix("/")
	for suffix in ["/chat/completions", "/models", "/messages", "/responses"]: url = url.trim_suffix(suffix)
	for i in range(1, PRESETS.size()):
		if url == PRESETS[i].endpoint or (i == 1 and url == PRESETS[i].endpoint + "/v1"): return i
	if url in ["https://api.commandcode.ai", "https://api.commandcode.ai/v1"]: return 5
	if url == "https://api.openai.com": return 2
	return 0

static func origin(endpoint: String) -> String:
	return "/".join(endpoint.strip_edges().split("/", true, 3).slice(0, 3)).to_lower()

static func wire(service: Dictionary) -> String:
	if service.get("api") == "messages": return "messages"
	if identify(service.get("endpoint", "")) == 5 and "claude" in str(service.get("model", "")).to_lower(): return "messages"
	return "chat"

static func options(service: Dictionary) -> Dictionary:
	var provider = identify(service.get("endpoint", ""))
	var model = str(service.get("model", "")).to_lower().split("/")[-1]
	var modern = provider == 2 or (provider == 5 and (model.begins_with("gpt-") or model.begins_with("o1") or model.begins_with("o3") or model.begins_with("o4")))
	# CommandCode preserves a vendor prefix in its catalog. Apply the same short
	# structured-reply defaults as direct DeepSeek; otherwise V4 can spend the
	# entire output allowance on reasoning and never emit the poker action.
	# Explicit parameter rejections still use Client's bounded compatibility retry.
	var deepseek = provider == 1 or (provider == 5 and model.begins_with("deepseek-v4"))
	return {"token_key": "max_completion_tokens" if modern else "max_tokens", "json": deepseek, "thinking": deepseek}
