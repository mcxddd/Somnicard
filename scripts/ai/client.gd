extends Node
## One cancellable operation. Only explicit parameter rejections permit bounded retries.
signal finished(result: Dictionary)
signal request_issued
signal exchange(entry: Dictionary)
const Config = preload("res://scripts/ai/config.gd")
const Providers = preload("res://scripts/ai/providers.gd")
const Catalog = preload("res://scripts/ai/catalog.gd")
const Trace = preload("res://scripts/ai/trace_log.gd")
static var usage: Dictionary = {}
var started_ms = 0
var usage_key = ""
static var compatibility: Dictionary = {}
static var output_limits: Dictionary = {}
var active_trace: Dictionary = {}
var request_node: HTTPRequest
var serial: int = 0
var busy: bool = false
var task: Dictionary = {}
var attempts: int = 0
var request_cap = 4

func cancel(report: bool = true) -> void:
	if report and not active_trace.is_empty():
		_trace_end({"state": "cancelled", "error": "请求已取消；返回牌桌后可重新请求"})
	serial += 1
	busy = false
	if is_instance_valid(request_node):
		request_node.cancel_request()
		request_node.queue_free()
	request_node = null
	task.clear()

func send(service: Dictionary, key: String, messages: Array, maximum_requests: int = 4, context: Dictionary = {}) -> void:
	request_cap = clampi(maximum_requests, 1, 4)
	_start(service, key, messages, false, context)

func list_models(service: Dictionary, key: String) -> void:
	_start(service, key, [], true)

func _start(service: Dictionary, key: String, messages: Array, listing: bool, context: Dictionary = {}) -> void:
	cancel()
	var base = Config.base_endpoint(str(service.get("endpoint", "")))
	if base.has("error"):
		finished.emit(base)
		return
	if not listing and Config.validate(service) != "":
		finished.emit({"error": Config.validate(service)})
		return
	if "\r" in key or "\n" in key:
		finished.emit({"error": "密钥格式无效"})
		return
	var cache_key = JSON.stringify([base.url, service.get("model", ""), Providers.wire(service), key.sha256_text()])
	task = {"base": base.url, "service": service.duplicate(true), "key": key.strip_edges(), "messages": messages.duplicate(true), "listing": listing, "wire": Providers.wire(service), "cache_key": cache_key, "options": compatibility.get(cache_key, Providers.options(service)).duplicate(true)}
	task["limit"] = output_limits.get(cache_key, 4096)
	task["context"] = context.duplicate(true)
	attempts = 0
	started_ms = Time.get_ticks_msec()
	usage_key = str(base.url) + " | " + str(service.get("model", ""))
	if not listing and not usage.has(usage_key): usage[usage_key] = {"requests": 0, "completed": 0, "errors": 0, "milliseconds": 0, "tokens": 0, "usage_reports": 0}
	_issue()

func _issue() -> void:
	if is_instance_valid(request_node): request_node.queue_free()
	serial += 1
	var token = serial
	request_node = HTTPRequest.new()
	add_child(request_node)
	request_node.timeout = minf(30, float(task.service.get("timeout", 60))) if task.listing else float(task.service.get("timeout", 60))
	request_node.body_size_limit = 2097152 if task.listing else 262144
	request_node.max_redirects = 0
	request_node.request_completed.connect(func(result, code, _headers, body): _completed(token, result, code, body))
	var headers = PackedStringArray(["Content-Type: application/json"])
	if not task.key.is_empty(): headers.append("Authorization: Bearer " + task.key)
	var route = "/models" if task.listing else "/messages" if task.wire == "messages" else "/chat/completions"
	var payload: Dictionary = {}
	if not task.listing:
		payload = {"model": task.service.model, "stream": false}
		if task.wire == "messages":
			headers.append("anthropic-version: 2023-06-01")
			var system: Array = []
			var dialogue: Array = []
			for message in task.messages:
				if message.role == "system": system.append(message.content)
				else: dialogue.append(message)
			payload["system"] = "\n\n".join(system)
			payload["messages"] = dialogue
			payload["max_tokens"] = task.limit
		else:
			payload["messages"] = task.messages
			payload[task.options.token_key] = task.limit
			if task.options.json: payload["response_format"] = {"type": "json_object"}
			if task.options.thinking: payload["thinking"] = {"type": "disabled"}
	busy = true
	if not task.listing:
		active_trace = {"id": "%d:%d" % [get_instance_id(), serial], "context": task.context, "model": task.service.model, "url": task.base + route, "request": payload.duplicate(true), "attempt": attempts + 1, "limit": task.limit, "state": "pending", "started": Time.get_unix_time_from_system(), "started_ms": Time.get_ticks_msec()}
		exchange.emit(_safe_trace(active_trace))
	if not task.listing: usage[usage_key].requests += 1
	var err = request_node.request(task.base + route, headers, HTTPClient.METHOD_GET if task.listing else HTTPClient.METHOD_POST, "" if task.listing else JSON.stringify(payload))
	request_issued.emit()
	if err != OK: _finish({"error": "无法连接，请检查服务地址与网络"})

func _finish(result: Dictionary) -> void:
	if not active_trace.is_empty(): result["trace_id"] = active_trace.id
	_trace_end({"state": "error" if result.has("error") else "complete", "error": result.get("error", ""), "response": result.get("content", ""), "usage": result.get("usage", {}), "finish_reason": result.get("finish_reason", ""), "http_status": result.get("status", 0)})
	if not task.is_empty() and not task.listing:
		result["elapsed_ms"] = Time.get_ticks_msec() - started_ms
		var stats: Dictionary = usage[usage_key]
		stats.completed += 1
		stats.errors += int(result.has("error"))
		stats.milliseconds += result.elapsed_ms
		var raw_usage = result.get("usage", {})
		if raw_usage is Dictionary:
			var tokens = raw_usage.get("total_tokens", -1)
			if not (tokens is int or tokens is float): tokens = -1
			if tokens >= 0 and tokens <= 100000000:
				stats.tokens += int(tokens)
				stats.usage_reports += 1
	cancel(false)
	finished.emit(result)

func _safe_trace(entry: Dictionary) -> Dictionary:
	# Only our payload and visible reply are recorded. Headers and hidden reasoning
	# are never included, and a key echoed by a service is scrubbed before emission.
	return Trace.redact(entry, [task.get("key", "")])

func _trace_end(fields: Dictionary) -> void:
	if active_trace.is_empty(): return
	active_trace.merge(fields, true)
	active_trace["elapsed_ms"] = Time.get_ticks_msec() - int(active_trace.started_ms)
	active_trace.erase("started_ms")
	exchange.emit(_safe_trace(active_trace))
	active_trace = {}

func _reported(parsed: Dictionary) -> Dictionary:
	var raw = parsed.get("usage", {})
	var reported: Dictionary = {}
	if not raw is Dictionary: return reported
	for pair in [["input_tokens", "prompt_tokens", "input_tokens"], ["output_tokens", "completion_tokens", "output_tokens"]]:
		var value = raw.get(pair[1], raw.get(pair[2], -1))
		if (value is int or value is float) and value >= 0 and value <= 100000000: reported[pair[0]] = int(value)
	if reported.has("input_tokens") and reported.has("output_tokens"): reported["total_tokens"] = reported.input_tokens + reported.output_tokens
	var details = raw.get("completion_tokens_details", raw.get("output_tokens_details", {}))
	if details is Dictionary:
		var value = details.get("reasoning_tokens", -1)
		if (value is int or value is float) and value >= 0 and value <= 100000000: reported["reasoning_tokens"] = int(value)
	return reported

func _adapt(code: int, parsed: Variant) -> bool:
	if task.listing or task.wire != "chat" or attempts + 1 >= request_cap or code not in [400, 422] or not parsed is Dictionary: return false
	var error = parsed.get("error", {})
	if not error is Dictionary: return false
	var message = str(error.get("message", "")).to_lower()
	var param = str(error.get("param", ""))
	var rejection = ["unsupported", "not supported", "unknown", "unrecognized", "not permitted", "not allowed"]
	if not rejection.any(func(word): return word in message): return false
	var options: Dictionary = task.options
	if options.json and (param == "response_format" or "response_format" in message):
		options.json = false
	elif options.thinking and (param == "thinking" or "thinking" in message):
		options.thinking = false
	elif param == options.token_key or str(options.token_key) in message:
		if task.get("token_switched", false): return false
		task["token_switched"] = true
		options.token_key = "max_tokens" if options.token_key == "max_completion_tokens" else "max_completion_tokens"
	else: return false
	_trace_end({"state": "retrying", "http_status": code, "error": "服务拒绝参数，自动调整兼容格式"})
	attempts += 1
	_issue()
	return true

func _completed(token: int, result: int, code: int, body: PackedByteArray) -> void:
	if token != serial or not busy: return
	if result != HTTPRequest.RESULT_SUCCESS:
		# Preserve the engine's transport result for diagnostics; no headers/body/key.
		if not active_trace.is_empty(): active_trace["transport_result"] = result
		_finish({"error": "连接超时，请重试或本地接管" if result == HTTPRequest.RESULT_TIMEOUT else "连接失败，请检查网络、证书或服务响应", "transport_result": result, "status": code})
		return
	var parser = JSON.new()
	var parsed: Variant = null
	if parser.parse(body.get_string_from_utf8()) == OK: parsed = parser.data
	if code < 200 or code >= 300:
		if _adapt(code, parsed): return
		var hint = {400: "该模型或服务暂不兼容，请刷新模型后重试", 401: "密钥无效或已过期", 403: "服务拒绝访问，请检查账号权限", 404: "地址或模型不存在", 429: "请求限流或额度不足"}.get(code, "服务暂不可用")
		_finish({"error": "HTTP %d · %s" % [code, hint], "status": code})
		return
	if task.listing:
		_finish(Catalog.parse(parsed))
		return
	if not parsed is Dictionary:
		_finish({"error": "服务响应格式无法识别，请重试或更换模型"})
		return
	var content = ""
	if task.wire == "messages":
		var blocks = parsed.get("content", [])
		if blocks is Array:
			for block in blocks:
				if block is Dictionary and block.get("type") == "text" and block.get("text") is String: content += block.text
	else:
		var choices = parsed.get("choices", [])
		if not choices is Array or choices.is_empty() or not choices[0] is Dictionary:
			_finish({"error": "服务响应缺少模型回复"})
			return
		if choices[0].get("message") is Dictionary and choices[0].message.get("content") is String: content = choices[0].message.content
	var finish_reason = str(parsed.get("stop_reason", "")) if task.wire == "messages" else str(parsed.choices[0].get("finish_reason", ""))
	var reported = _reported(parsed)
	if finish_reason in ["length", "max_tokens"]:
		var details = {"finish_reason": finish_reason, "usage": reported, "status": code, "content": content}
		if not task.get("length_retry", false) and task.limit < 16384 and attempts + 1 < request_cap:
			_trace_end({"state": "retrying", "response": content, "finish_reason": finish_reason, "usage": reported, "http_status": code, "error": "单次生成长度不足，自动扩大至 16384 tokens 重试一次"})
			# Count the first generation too; it may have consumed a full budget.
			if reported.has("total_tokens"):
				usage[usage_key].tokens += reported.total_tokens
				usage[usage_key].usage_reports += 1
			task["length_retry"] = true
			task.limit = 16384
			attempts += 1
			_issue()
			return
		details["error"] = "单次回复达到长度上限（%d tokens），并非牌局次数用完。可换模型或本手本地接管。" % task.limit
		_finish(details)
		return
	if content.strip_edges().is_empty():
		_finish({"error": "模型未返回可用回复，请重试或选择其他模型", "usage": reported, "finish_reason": finish_reason, "status": code})
		return
	if compatibility.size() >= 64: compatibility.clear()
	compatibility[task.cache_key] = task.options.duplicate(true)
	if output_limits.size() >= 64: output_limits.clear()
	output_limits[task.cache_key] = task.limit
	_finish({"content": content, "usage": reported, "finish_reason": finish_reason, "status": code})
