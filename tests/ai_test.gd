extends SceneTree
const Config = preload("res://scripts/ai/config.gd")
const Protocol = preload("res://scripts/ai/protocol.gd")
const Memory = preload("res://scripts/ai/memory.gd")
const Table = preload("res://scripts/poker/table.gd")
const History = preload("res://scripts/poker/history.gd")
const Preferences = preload("res://scripts/ui/preferences.gd")
const Providers = preload("res://scripts/ai/providers.gd")
const Catalog = preload("res://scripts/ai/catalog.gd")
const Names = preload("res://scripts/ai/names.gd")
const Client = preload("res://scripts/ai/client.gd")
var checks = 0
var failures = 0
var server = TCPServer.new()
var peers: Array = []
var requests: Array = []
var response_mode = "decision"
var reply: Dictionary = {}
var base = "http://127.0.0.1:18947/v1"

func _initialize() -> void: call_deferred("run")
func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + message)

func _process(_delta: float) -> bool:
	while server.is_connection_available(): peers.append({"socket": server.take_connection(), "data": ""})
	for peer in peers.duplicate():
		var socket: StreamPeerTCP = peer.socket
		socket.poll()
		if socket.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			peers.erase(peer)
			continue
		if socket.get_available_bytes() > 0: peer.data += socket.get_utf8_string(socket.get_available_bytes())
		var split = peer.data.find("\r\n\r\n")
		if split < 0: continue
		var header: String = peer.data.substr(0, split)
		var length = 0
		for line in header.split("\r\n"):
			if line.to_lower().begins_with("content-length:"): length = int(line.split(":")[1])
		var body: String = peer.data.substr(split + 4)
		if body.to_utf8_buffer().size() < length: continue
		if peer.get("recorded", false): continue
		peer["recorded"] = true
		requests.append({"header": header, "body": JSON.parse_string(body) if not body.is_empty() else null})
		if response_mode == "wait": continue
		var code = "200 OK"
		var extra = ""
		var answer = {"action": "check", "amount": 0}
		var payload = JSON.parse_string(body) if not body.is_empty() else null
		if payload is Dictionary and payload.get("messages") is Array and payload.messages.size() > 0:
			var decoder = JSON.new()
			var data: Variant = null
			if decoder.parse(payload.messages[-1].content) == OK: data = decoder.data
			if data is Dictionary and data.has("observation"):
				if data.observation.has("legal"): answer.action = "check" if data.observation.legal.check else "call"
				else: answer = {"text": "这注我跟了。" if data.get("your_last_action", {}).get("action") == "call" else "先过，看你敢不敢打。"}
			if data is Dictionary and data.has("existing_names"): answer = {"names": ["深寻澜", "深海舟", "寻光者"]}
			if payload.messages[-1].content == "Connection test, no game data.": answer = {"ok": true}
		if payload is Dictionary and payload.get("messages") is Array:
			for message in payload.messages:
				var decoder = JSON.new()
				if decoder.parse(str(message.get("content", ""))) == OK and decoder.data is Dictionary and decoder.data.has("local_analysis"):
					answer = {"action": decoder.data.local_analysis.action, "reason": "当前价格与手牌权益相符，先控制投入。", "alternative": "加注需要更弱的牌愿意跟注，否则考虑控制底池。", "next": "新的公共牌或下注出现后重新判断。"}
		var content = JSON.stringify(answer)
		if response_mode == "bad": content = "not JSON"
		if response_mode == "illegal": content = '{"action":"raise","amount":99999999}'
		if response_mode == "401": code = "401 Unauthorized"
		if response_mode == "429": code = "429 Too Many Requests"
		if response_mode == "500": code = "500 Internal Server Error"
		if response_mode == "redirect":
			code = "302 Found"
			extra = "Location: http://127.0.0.1:18947/stolen\r\n"
		if response_mode == "large": content = "x".repeat(300000)
		var bytes = JSON.stringify({"choices": [{"message": {"content": content}}]}).to_utf8_buffer()
		if header.begins_with("GET "):
			bytes = JSON.stringify({"data": [{"id": "model-a", "name": "普通模型", "supported_endpoints": ["/chat/completions"]}, {"id": "model-b", "name": "对话模型", "supported_endpoints": ["/messages"]}, {"id": "model-a"}, {"id": "text-embedding-3"}, {"id": "decision-only", "supported_endpoints": ["/systemone"]}]}).to_utf8_buffer()
		if header.begins_with("POST /v1/messages "):
			bytes = JSON.stringify({"content": [{"type": "thinking", "thinking": "not displayed"}, {"type": "text", "text": content}], "stop_reason": "end_turn"}).to_utf8_buffer()
		if response_mode == "need_modern" and payload is Dictionary and payload.has("max_tokens"):
			code = "400 Bad Request"
			bytes = JSON.stringify({"error": {"param": "max_tokens", "message": "Unsupported parameter: max_tokens; use max_completion_tokens"}}).to_utf8_buffer()
		if response_mode in ["reject_optional", "reject_tokens"] and payload is Dictionary:
			for field in ["response_format", "thinking", "max_tokens", "max_completion_tokens"]:
				if field == "max_completion_tokens" and response_mode == "reject_optional": continue
				if payload.has(field):
					code = "400 Bad Request"
					bytes = JSON.stringify({"error": {"param": field, "message": "Unsupported parameter: " + field}}).to_utf8_buffer()
					break
		if response_mode in ["length", "length_null"]: bytes = JSON.stringify({"choices": [{"finish_reason": "length", "message": {"content": null if response_mode == "length_null" else content}}]}).to_utf8_buffer()
		if response_mode in ["length_recover", "messages_length_recover"]:
			var truncated = payload.get("max_completion_tokens", payload.get("max_tokens", 0)) < 16384
			var reported = {"prompt_tokens": 120, "completion_tokens": 4096 if truncated else 24, "completion_tokens_details": {"reasoning_tokens": 4096 if truncated else 12}}
			if header.begins_with("POST /v1/messages "):
				bytes = JSON.stringify({"content": [{"type": "thinking", "thinking": "PRIVATE_CHAIN_MUST_NOT_LOG"}, {"type": "text", "text": "" if truncated else content}], "stop_reason": "max_tokens" if truncated else "end_turn", "usage": reported}).to_utf8_buffer()
			else:
				bytes = JSON.stringify({"choices": [{"finish_reason": "length" if truncated else "stop", "message": {"content": "" if truncated else content, "reasoning_content": "PRIVATE_CHAIN_MUST_NOT_LOG"}}], "usage": reported}).to_utf8_buffer()
		if response_mode == "envelope": bytes = "{}".to_utf8_buffer()
		socket.put_data(("HTTP/1.1 %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\n%sConnection: close\r\n\r\n" % [code, bytes.size(), extra]).to_utf8_buffer())
		socket.put_data(bytes)
	return false

func wait_reply(client) -> void:
	var start = Time.get_ticks_msec()
	while client.busy and Time.get_ticks_msec() - start < 4000: await process_frame
	verify(not client.busy, "request terminates within test deadline")

func settle() -> void:
	for i in range(8): await process_frame

func run() -> void:
	verify(server.listen(18947, "127.0.0.1") == OK, "local mock server starts")
	for url in ["https://example.com/v1", "https://example.com/v1/", "https://example.com/v1/chat/completions"]:
		verify(Config.endpoint(url).get("url") == "https://example.com/v1/chat/completions", "normalize compatible endpoint")
	for url in ["http://example.com/v1", "https://u:p@example.com/v1", "https://x/v1?k=x", "https://x/#x", "https://x/\r\nBad: x", "file:///etc", "https://"]:
		verify(Config.endpoint(url).has("error"), "reject unsafe endpoint")
	verify(Config.seats([]).size() == 8 and Config.seats([])[0].name != "", "all eight AI identities have defaults")
	verify(not Config.service({"key": "SENTINEL"}).has("key"), "service serialization strips keys")
	var table = Table.new([1000, 1000, 1000], 5, 10, 123)
	table.start_hand(0)
	var actor = table.actor
	var view = table.view_for(actor)
	for i in range(view.seats.size()): view.seats[i].hole = [50, 51]
	view["deck"] = [1, 2, 3]
	view["future_board"] = [10, 11, 12]
	var observed = Protocol.observation(view, actor)
	verify(not observed.has("deck") and not observed.has("future_board"), "unknown top level private data never sent")
	for i in range(observed.seats.size()): verify(observed.seats[i].has("your_hole") == (i == actor), "only own cards sent")
	verify(not JSON.stringify(Protocol.observation(view, actor, false)).contains("hole"), "speech has zero hole cards")
	var legal = table.legal_actions(actor)
	verify(not Protocol.decision('{"action":"call","amount":0}', legal).has("error"), "legal call accepted")
	for bad in ['{"action":"check"}', '{"action":"raise","amount":1}', '{"action":"raise","amount":999999}', '{"action":"call","amount":3}', '{"action":"raise","amount":20.5}', '{"action":"steal"}', '{}', 'hello']:
		verify(Protocol.decision(bad, legal).has("error"), "reject invalid decision " + bad)
	verify(not Protocol.decision('```json\n{"action":"call","amount":0}\n```', legal).has("error"), "fenced JSON accepted")
	var short_legal = legal.duplicate()
	short_legal.max_raise_to = 15
	verify(not Protocol.decision('{"action":"raise","amount":15}', short_legal).has("error"), "short all in allowed")
	while table.phase != "complete": table.act(table.actor, "check" if table.legal_actions(table.actor).check else "call")
	var memory = Memory.observe({}, table.view_for(1), 1, "table:1")
	verify(memory.hands == 1 and memory.hero_vpip == 1, "public completed facts remembered")
	verify(Memory.observe(memory, table.view_for(1), 1, "table:1") == memory, "repeated refresh does not duplicate memory")
	verify(not JSON.stringify(memory).contains("hole"), "memory contains no hidden cards")
	for i in range(45): memory = Memory.observe(memory, table.view_for(1), 1, "table:%d" % (i + 2))
	verify(memory.recent.size() == 8 and memory.seen.size() == 32 and memory.hands == 46, "memory remains bounded")
	var prefs_path = "user://ai-test-prefs.cfg"
	verify(Preferences.save_values({"ai_key": "SECRET_SENTINEL", "ai_service": {"endpoint": base, "model": "mock", "key": "SECRET_SENTINEL"}}, prefs_path) == OK, "preferences saved")
	verify(not FileAccess.get_file_as_string(prefs_path).contains("SECRET_SENTINEL"), "credentials absent from disk settings")
	var client = Client.new()
	root.add_child(client)
	client.finished.connect(func(result): reply = result)
	var service = Config.service({"endpoint": base, "model": "mock"})
	client.send(service, "TEST_SENTINEL", [{"role": "user", "content": "test"}])
	await wait_reply(client)
	verify(reply.has("content"), "real HTTP roundtrip extracts content")
	verify(requests.back().header.contains("Authorization: Bearer TEST_SENTINEL"), "bearer header sent")
	verify(requests.back().body.model == "mock" and requests.back().body.stream == false and requests.back().body.max_tokens == 4096 and not requests.back().body.has("response_format"), "minimal compatible request without user JSON options")
	response_mode = "need_modern"
	var start_requests = requests.size()
	client.send(service, "", [{"role": "user", "content": "test"}])
	await wait_reply(client)
	verify(reply.has("content") and requests.size() == start_requests + 2 and requests.back().body.get("max_completion_tokens") == 4096, "explicit parameter rejection automatically adapts once")
	start_requests = requests.size()
	client.send(service, "", [{"role": "user", "content": "test"}])
	await wait_reply(client)
	verify(requests.size() == start_requests + 1 and requests.back().body.has("max_completion_tokens"), "successful compatibility cached for exact model and credentials")
	start_requests = requests.size()
	client.send(service, "DIFFERENT_KEY", [{"role": "user", "content": "test"}])
	await wait_reply(client)
	verify(requests.size() == start_requests + 2, "compatibility cache is isolated by credentials")
	response_mode = "reject_optional"
	var compatible = Config.service({"endpoint": base, "model": "compatibility-fixture"})
	var cache_key = JSON.stringify([base, compatible.model, "chat", "".sha256_text()])
	Client.compatibility[cache_key] = Providers.options({"endpoint": "https://api.commandcode.ai/provider/v1", "model": "deepseek/deepseek-v4.1-flash"})
	start_requests = requests.size()
	client.send(compatible, "", [{"role": "user", "content": "test"}])
	await wait_reply(client)
	verify(reply.has("content") and requests.size() == start_requests + 4, "unsupported JSON/thinking/token parameters adapt within bounded attempts")
	verify(requests[start_requests].body.thinking.type == "disabled" and requests[start_requests].body.response_format.type == "json_object", "CommandCode DeepSeek defaults reach actual HTTP payload")
	response_mode = "reject_tokens"
	start_requests = requests.size()
	client.send(compatible, "", [{"role": "user", "content": "test"}])
	await wait_reply(client)
	verify(reply.has("error") and requests.size() == start_requests + 2, "rejected alternative token format stops without retry loop")
	for mode in ["length", "length_null"]:
		response_mode = mode
		client.send(service, "", [])
		await wait_reply(client)
		verify(reply.get("error", "").contains("长度上限"), "truncated reasoning or answer gives actionable output-limit guidance")
	var traces: Array = []
	client.exchange.connect(func(entry): traces.append(entry))
	for api in ["chat", "messages"]:
		response_mode = "length_recover"
		var recovery = Config.service({"endpoint": base, "model": "recovery-" + api, "api": api})
		traces.clear()
		var before = requests.size()
		client.send(recovery, "RECOVERY_SECRET", [{"role": "user", "content": "RECOVERY_SECRET"}], 4, {"seat": 1, "hand": 1})
		await wait_reply(client)
		verify(reply.has("content") and requests.size() == before + 2, "single bounded generation recovery " + api)
		verify(traces.size() == 4 and traces[1].state == "retrying" and traces.back().state == "complete", "each retry attempt has pending and terminal diagnostics " + api)
		verify(traces[1].limit == 4096 and traces.back().limit == 16384 and traces[1].finish_reason in ["length", "max_tokens"], "generation budget and stop reason traced " + api)
		verify(reply.usage.reasoning_tokens == 12 and traces[1].usage.output_tokens == 4096, "reasoning and visible output accounting " + api)
		verify(not JSON.stringify(traces).contains("RECOVERY_SECRET") and not JSON.stringify(traces).contains("PRIVATE_CHAIN_MUST_NOT_LOG"), "credentials and hidden reasoning never traced " + api)
		before = requests.size()
		client.send(recovery, "RECOVERY_SECRET", [], 4)
		await wait_reply(client)
		verify(requests.size() == before + 1 and requests.back().body.get("max_completion_tokens", requests.back().body.get("max_tokens")) == 16384, "successful larger budget reused " + api)
	response_mode = "length_null"
	var before_limited = requests.size()
	client.send(service, "", [], 1)
	await wait_reply(client)
	verify(requests.size() == before_limited + 1 and reply.has("error"), "caller request cap also bounds length recovery")
	for mode in ["401", "429", "500", "redirect"]:
		response_mode = mode
		var before = requests.size()
		client.send(service, "TEST_SENTINEL", [])
		await wait_reply(client)
		verify(reply.has("error"), "HTTP error surfaced " + mode)
		verify(requests.size() == before + 1, "no automatic retry or redirect " + mode)
	response_mode = "wait"
	reply = {}
	client.send(service, "", [])
	await settle()
	client.cancel()
	await settle()
	verify(reply.is_empty() and not client.busy, "cancel suppresses callbacks")
	var quick_service = service.duplicate()
	quick_service.timeout = 0.1
	client.send(quick_service, "", [])
	await wait_reply(client)
	verify(reply.get("error", "").contains("超时"), "actual HTTP timeout is reported")
	for mode in ["large", "envelope"]:
		response_mode = mode
		client.send(service, "", [])
		await wait_reply(client)
		verify(reply.has("error"), "malformed or oversized response rejected " + mode)
	response_mode = "wait"
	# Exercise the real table controller with asynchronous opponents.
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	ui.smoke_mode = true
	ui.ai_store = Memory.new("user://ai-test-companions.json")
	ui.ai_store.companions.clear()
	ui.ai_store.save()
	ui.ai_service = Config.service({"endpoint": base, "model": "mock", "speech": true})
	ui.ai_seats[0].enabled = true
	ui.ai_seats[0].name = "测试陪练"
	ui._start_table(2)
	verify(ui.game.seats[1].name == "测试陪练", "table uses AI identity")
	if ui.game.actor == 0: ui._human_action("call", 0, true)
	var events = ui.game.events.size()
	ui._bot_step()
	await settle()
	verify(ui.ai_client.busy, "online seat waits asynchronously")
	ui._open_settings()
	verify(not ui.ai_client.busy and ui.game.events.size() == events, "settings cancels pending action")
	ui.settings.cancel()
	response_mode = "illegal"
	ui._bot_step()
	await wait_reply(ui.ai_client)
	verify(ui.game.events.size() == events and ui.ai_error != "" and ui.ai_recovery.visible, "illegal model action pauses and offers recovery")
	ui._take_over_ai()
	verify(ui.game.events.size() > events and ui.ai_local_hand.has(1), "explicit local takeover advances legally")
	response_mode = "decision"
	ui._start_table(6)
	for i in range(5): ui.ai_seats[i].enabled = true
	ui._apply_ai_names()
	var steps = 0
	while ui.game.phase != "complete" and steps < 100:
		if ui.game.actor == 0: ui._human_action("check_call", 0, true)
		else:
			ui._bot_step()
			await wait_reply(ui.ai_client)
			if ui.speech_client.busy: await wait_reply(ui.speech_client)
		steps += 1
	verify(ui.game.phase == "complete" and ui.game.result.showdown and ui.game.chip_total() == 6000, "six-seat AI table completes all streets and conserves chips")
	verify(ui.ai_dialogue.size() > 0 and ui.ai_dialogue.size() <= 5, "public AI speech displayed and bounded")
	for request in requests:
		if not request.body is Dictionary or not request.body.get("messages") is Array or request.body.messages.size() < 2: continue
		var data = JSON.parse_string(request.body.messages[1].content)
		if not data is Dictionary or not data.has("observation"): continue
		var private_count = 0
		for seat in data.observation.seats: private_count += int(seat.has("your_hole"))
		verify(private_count == (1 if data.observation.has("legal") else 0), "every network request obeys card privacy boundary")
	verify(ui.ai_memories["1"].hands == 1, "completed game updates isolated memory once")
	ui._next_hand()
	verify(ui.ai_memories["1"].hands == 1 and ui.ai_dialogue.is_empty(), "next hand keeps session memory and resets speech")
	var id = ui.ai_store.create(ui.ai_seats[0], {"difficulty": 2, "aggression": 2}, ui.ai_memories["1"])
	verify(id != "", "save long term companion")
	ui.ai_seats[0].companion_id = id
	ui._start_table(2)
	verify(ui.ai_memories["1"].hands == 1 and ui.ai_memories["2"].hands == 0, "new table keeps saved companion but resets temporary seats")
	ui._open_settings()
	ui.settings.opponent_editor.ai_seats[0].name = "未保存名字"
	ui.settings.ai_page.key.text = "DRAFT_SECRET"
	ui.settings.cancel()
	verify(ui.game.seats[1].name == "测试陪练" and ui.ai_key == "" and ui.settings.ai_page.key.text == "", "cancel discards identity and staged key")
	var state = ui._ai_session_state()
	ui.ai_memories["2"] = Memory.normalize({"hands": 99})
	ui._restore_ai_state(state)
	verify(ui.ai_memories["2"].hands == 0 and ui.ai_memories["1"].hands == 1, "resume restores session isolation")
	ui._open_settings()
	ui.settings._select_page(6)
	await settle()
	verify(ui.settings.ai_page.visible and ui.settings.ai_page.library.get_child_count() == 1, "service and companion library reachable")
	var draft = ui._settings_values()
	draft.ai_seats[1].companion_id = id
	draft.ai_seats[1].enabled = true
	verify(not ui._apply_ai_settings(draft), "same saved companion cannot occupy two seats")
	ui._edit_ai_library("clear", id, "")
	verify(ui.ai_memories["1"].hands == 0 and ui.ai_store.companions[id].memory.hands == 0, "clear immediately updates active and stored memory")
	ui._edit_ai_library("rename", id, "新名字")
	verify(ui.game.seats[1].name == "新名字", "rename updates active identity")
	var stale_state = ui._ai_session_state()
	stale_state.memories["1"] = Memory.normalize({"hands": 88})
	ui._edit_ai_library("delete", id, "")
	verify(not ui.ai_store.companions.has(id) and ui.ai_seats[0].companion_id == "", "delete detaches active companion")
	ui._restore_ai_state(stale_state)
	verify(ui.ai_seats[0].companion_id == "" and ui.ai_memories["1"].hands == 0, "old session cannot resurrect deleted companion memory")
	ui.settings.cancel()
	response_mode = "decision"
	ui._start_table(9)
	ui.ai_service.api = "messages"
	for i in range(8): ui.ai_seats[i].enabled = true
	ui.ai_service.speech = false
	ui._apply_ai_names()
	steps = 0
	while ui.game.phase != "complete" and steps < 100:
		if ui.game.actor == 0: ui._human_action("check_call", 0, true)
		else:
			ui._bot_step()
			await wait_reply(ui.ai_client)
		steps += 1
	verify(ui.game.phase == "complete" and ui.game.result.showdown and ui.game.chip_total() == 9000, "nine-seat online table completes and conserves chips")
	verify(ui.ai_dialogue.is_empty(), "speech toggle prevents extra speech requests")
	var record = ui.game.completed_record()
	record.seat_names = ui.game.seats.map(func(s): return s.name)
	record.ai_dialogue = [{"name": "小夏", "text": "测试发言", "event": ui.game.events.size(), "seat": 1}]
	var rebuilt = History.replay(record)
	verify(not rebuilt.has("error") and rebuilt.game.seats[1].name == ui.game.seats[1].name, "replay preserves identities without model calls")
	ui._open_settings()
	ui.settings.opponent_editor.ai_seats[0].companion_id = "new:1"
	ui.settings.opponent_editor.ai_seats[0].name = "保存测试"
	ui._apply_settings(ui.settings.values())
	verify(not ui.settings.visible and ui.ai_store.companions.has(ui.ai_seats[0].companion_id), "save settings creates companion from draft")
	var reloaded = Memory.new("user://ai-test-companions.json")
	verify(reloaded.companions.size() == 1 and reloaded.companions.values()[0].name == "保存测试", "companion survives disk reload")
	response_mode = "wait"
	ui._start_table(2)
	if ui.game.actor == 0: ui._human_action("call", 0, true)
	ui._bot_step()
	var old_serial = ui.ai_client.serial
	ui._start_table(2)
	events = ui.game.events.size()
	ui.ai_client._completed(old_serial, 0, 200, '{"choices":[{"message":{"content":"{\"action\":\"fold\",\"amount\":0}"}}]}'.to_utf8_buffer())
	verify(ui.game.events.size() == events and not ui.ai_client.busy, "late response cannot act on replacement table")
	var before_requests = requests.size()
	ui._open_settings()
	ui.settings._select_page(6)
	var page = ui.settings.ai_page
	page.key.text = "OLD_PROVIDER_SENTINEL"
	page._preset(1)
	verify(page.endpoint.text == "https://api.deepseek.com" and page.model.text == "" and page.key.text == "", "DeepSeek preset awaits live catalog and clears other-provider key")
	verify(not page.values().has("json_mode") and not page.values().has("thinking_mode"), "technical toggles removed from user settings")
	verify(Providers.options(page.values()).thinking, "DeepSeek thinking mode handled internally")
	page._preset(2)
	verify(page.model.text == "" and Providers.options(page.values()).token_key == "max_completion_tokens", "OpenAI compatibility inferred without manual option")
	page._preset(3)
	verify(page.endpoint.text == "https://api.siliconflow.cn/v1", "SiliconFlow endpoint preset")
	page._preset(4)
	verify(page.endpoint.text == "https://dashscope.aliyuncs.com/compatible-mode/v1", "Qwen regional endpoint preset")
	page._preset(5)
	verify(page.endpoint.text == "https://api.commandcode.ai/provider/v1" and page.model.text == "", "CommandCode uses official endpoint and live model catalog")
	verify(requests.size() == before_requests, "provider selection never sends requests")
	page.fill(Config.service({"endpoint": base, "model": "deepseek-flash"}), "")
	ui.settings._select_page(4)
	response_mode = "decision"
	ui.settings._generate_names(1)
	await wait_reply(ui.settings.name_client)
	var editor = ui.settings.opponent_editor
	verify(editor.name_choices.get_child_count() == 3, "name generation offers three candidates")
	var name_request = JSON.parse_string(requests.back().body.messages[1].content)
	verify(name_request.model == "deepseek-flash" and not name_request.has("observation") and not name_request.has("key") and not name_request.has("memory"), "name generation sends model/personality only, no hand or credentials in prompt")
	editor.name_choices.get_child(0).pressed.emit()
	verify(editor.ai_seats[0].name == "深寻澜" and ui.ai_seats[0].name != "深寻澜", "candidate selection changes draft only")
	ui.settings.cancel()
	verify(ui.ai_seats[0].name != "深寻澜", "cancel discards generated name")
	ui._open_settings()
	page.fill(Config.service({"endpoint": base, "model": "deepseek-flash"}), "")
	ui.settings._select_page(4)
	response_mode = "wait"
	ui.settings._generate_names(1)
	await settle()
	editor.name_edit.text = "自己起名"
	editor.name_edit.text_changed.emit("自己起名")
	verify(not ui.settings.name_client.busy and editor.ai_seats[0].name == "自己起名", "typing own name cancels pending generation")
	verify("已取消" in editor.name_status.text, "cancelled name request no longer appears busy")
	ui.settings._generate_names(1)
	ui.settings._select_page(6)
	verify(not ui.settings.name_client.busy, "leaving opponent page cancels generation")
	page.key.text = "OLD_ORIGIN_SECRET"
	page.endpoint.text = "https://other.example/v1"
	page.endpoint.text_changed.emit(page.endpoint.text)
	verify(page.key.text == "", "editing endpoint host clears staged key")
	verify(Names.parse('{"names":["重复","重复","合法昵称"]}', ["重复"]).names == ["合法昵称"], "nickname validation removes duplicates")
	verify(Names.parse('{"names":["https://x","[bad]",123]}', []).has("error"), "nickname parser rejects links and malformed entries")
	for url in ["https://api.commandcode.ai", "https://api.commandcode.ai/v1", "https://api.commandcode.ai/provider/v1/models", "https://api.commandcode.ai/provider/v1/messages"]:
		verify(Config.base_endpoint(url).get("url") == "https://api.commandcode.ai/provider/v1", "CommandCode endpoint normalized from root or complete route")
	verify(Config.base_endpoint("https://custom.example").url == "https://custom.example/v1", "bare custom host gains conventional prefix")
	verify(Config.base_endpoint("https://custom.example/gateway/models").url == "https://custom.example/gateway", "custom prefix preserved")
	verify(Config.endpoint("https://custom.example/chat/completions").url == "https://custom.example/chat/completions", "explicit route without v1 is honored")
	verify(not Config.service({"json_mode": true, "modern_tokens": true, "token_limit": 99999}).has("json_mode"), "legacy technical settings migrate to automatic behavior")
	verify(Providers.wire({"endpoint": "https://api.commandcode.ai/provider/v1", "model": "claude-example"}) == "messages", "manual CommandCode Claude model selects messages")
	var parsed_catalog = Catalog.parse({"models": ["z-model", "a-model", "a-model", {"id": "embeddings-test"}, {"id": "bad\nname"}, {"id": "no-route", "supported_endpoints": ["/systemone"]}, {"id": "claude-test", "supported_endpoints": ["/messages"]}]})
	verify(parsed_catalog.models.size() == 3 and parsed_catalog.models[0].id == "a-model", "catalog accepts alternative envelope, sorts and deduplicates valid IDs")
	verify(parsed_catalog.models[1].api == "messages" and parsed_catalog.skipped == 2, "catalog maps supported routes and excludes non-text endpoints")
	verify(Catalog.parse("not a list").has("error"), "malformed model list rejected")
	response_mode = "decision"
	client.list_models({"endpoint": base + "/chat/completions"}, "LIST_SECRET")
	await wait_reply(client)
	verify(reply.get("models", []).size() == 2 and reply.get("skipped") == 2, "model discovery parses real GET response")
	verify(requests.back().header.begins_with("GET /v1/models ") and requests.back().body == null and requests.back().header.contains("Bearer LIST_SECRET"), "discovery sends credentials to normalized same host and no game payload")
	var native_service = Config.service({"endpoint": base, "model": "model-b", "api": "messages"})
	client.send(native_service, "NATIVE_SECRET", [{"role": "system", "content": "Return JSON"}, {"role": "user", "content": "test"}])
	await wait_reply(client)
	verify(reply.has("content") and not reply.content.contains("not displayed"), "messages response extracts text only, excludes private thinking")
	verify(requests.back().header.begins_with("POST /v1/messages ") and requests.back().body.system == "Return JSON" and requests.back().body.messages.size() == 1 and not requests.back().body.has("response_format"), "messages wire automatically separates system and user roles")
	ui._open_settings()
	ui.settings._select_page(6)
	page.fill(Config.service({"endpoint": base, "model": "model-b", "api": "messages"}), "DRAFT_KEY")
	page.fetch_models()
	await wait_reply(page.models_client)
	verify(page.models.size() == 2 and page.model.text == "model-b" and page.values().api == "messages", "refresh retains chosen model and wire")
	page._test()
	await wait_reply(page.client)
	verify(page.status.text.contains("连接成功"), "selected native model passes in-app connection test")
	page._choose_model(0)
	verify(page.model.text == "model-a" and page.values().api == "chat", "model selection changes draft and route together")
	verify(ui.ai_service.model != "model-a", "discovery and model selection do not apply settings early")
	var many: Array = []
	for i in range(20): many.append({"id": "model-%02d" % i, "name": "模型 %d" % i, "api": "chat"})
	page._models_received({"models": many, "skipped": 0})
	var before_filter = page.model.text
	page.model_search.text = "19"
	page.model_search.text_changed.emit("19")
	verify(page.filtered.size() == 1 and page.model.text == before_filter, "search filters list without silently changing selection")
	page._choose_model(0)
	verify(page.model.text == "model-19", "filtered selection uses correct underlying ID")
	page.key.text = "AUTO_KEY"
	page.key.text_changed.emit(page.key.text)
	verify(not page.fetch_timer.is_stopped() and page.models.is_empty(), "credential edit schedules automatic fetch and discards old-account catalog")
	await create_timer(1.4).timeout
	await wait_reply(page.models_client)
	verify(page.models.size() == 2 and page.model.text == "model-a", "automatic discovery selects available default when previous model is missing")
	response_mode = "wait"
	page.fetch_models()
	await settle()
	var listing_token = page.models_client.serial
	ui.settings._select_page(4)
	verify(not page.models_client.busy and page.fetch_timer.is_stopped(), "leaving service page cancels model fetch and debounce")
	page.models_client._completed(listing_token, 0, 200, '{"data":[{"id":"stale"}]}'.to_utf8_buffer())
	verify(page.model.text != "stale", "cancelled catalog cannot overwrite newer draft")
	ui.settings._select_page(6)
	page.model.text = "manual-model"
	page._manual_model("manual-model")
	verify(page.values().model == "manual-model" and page.values().api == "chat", "manual fallback remains available without protocol settings")
	page.endpoint.text = "https://custom.example/chat/completions"
	verify(Config.endpoint(page.values().endpoint).url == "https://custom.example/chat/completions", "saved endpoint preserves explicit root-level route")
	var invalid_draft = ui._settings_values()
	invalid_draft.ai_seats[0].enabled = true
	invalid_draft.ai_service.model = ""
	for p in invalid_draft.ai_profiles:
		if p.id == "default": p.service.model = ""
	verify(not ui._apply_ai_settings(invalid_draft), "online seats cannot save without a selected model")
	root.size = Vector2i(360, 640)
	await settle()
	verify(page.model_picker.get_global_rect().end.x <= ui.settings.scroll.get_global_rect().end.x + 1, "model picker fits small portrait despite long IDs")
	ui.settings.cancel()
	# A single table routes alternating seats to independent models and credentials.
	ui.ai_profiles = preload("res://scripts/ai/services.gd").normalize([
		{"id": "default", "label": "A", "service": Config.service({"endpoint": base, "model": "model-a"})},
		{"id": "second", "label": "B", "service": Config.service({"endpoint": base, "model": "model-b", "api": "messages"})}])
	ui.ai_keys = {"default": "KEY_A_TEST", "second": "KEY_B_TEST"}
	ui.ai_service = ui.ai_profiles[0].service
	ui.ai_key = "KEY_A_TEST"
	for i in range(8):
		ui.ai_seats[i].enabled = true
		ui.ai_seats[i].service_id = "second" if i % 2 == 0 else "default"
	response_mode = "decision"
	ui._start_table(6)
	ui.paused = false
	var request_start = requests.size()
	var move_count = 0
	while ui.game.phase != "complete" and move_count < 150:
		if ui.game.actor == 0:
			ui.game.act(0, "check" if ui.game.legal_actions(0).check else "call")
		else:
			ui._request_ai()
			await wait_reply(ui.ai_client)
			verify(ui.ai_error.is_empty(), "mixed-model table action completes")
		move_count += 1
	verify(ui.game.phase == "complete" and ui.game.chip_total() == 6000, "mixed models complete same six-seat hand with conserved chips")
	var both = {}
	for req in requests.slice(request_start):
		if not req.body is Dictionary or not req.body.has("model"): continue
		both[req.body.model] = true
		verify(req.header.contains("Bearer KEY_B_TEST" if req.body.model == "model-b" else "Bearer KEY_A_TEST"), "model receives only its own credential")
	verify(both.size() == 2, "both independent models were actually requested")
	# Coach responds through the same client but receives no opponent memories.
	ui._start_table(2)
	if ui.game.actor != 0: ui.game.act(ui.game.actor, "call")
	ui.ai_live_coach = true
	ui.review.ai_coach.configure(ui._settings_values())
	ui._open_advice()
	while ui.review.job != null: await process_frame
	ui.review.ai_coach.ask("为什么不加注？")
	await wait_reply(ui.review.ai_coach.client)
	verify(ui.review.ai_coach.dialogue.size() == 1 and "推荐理由" in ui.review.ai_coach.answer.text, "coach explanation renders inside live table panel")
	response_mode = "wait"
	ui.review.ai_coach.ask("继续解释")
	await settle()
	ui.review.close()
	verify(not ui.review.ai_coach.client.busy, "closing coach cancels online request")
	response_mode = "decision"
	# Online arena shares the same routing, with a hard per-batch request limit.
	var arena = preload("res://scripts/ai/arena.gd").new()
	arena.path = "user://arena-111-test.json"
	root.add_child(arena)
	arena.start({"online": true, "blocks": 2, "counts": [2], "depths": [50]}, ui.ai_service, "ARENA_TEST_KEY", 1)
	var deadline = Time.get_ticks_msec() + 6000
	while arena.running and Time.get_ticks_msec() < deadline: await process_frame
	verify(not arena.running and arena.data.requests == 1, "arena respects request budget without local fallback")
	verify(not FileAccess.get_file_as_string(arena.path).contains("ARENA_TEST_KEY"), "arena checkpoint contains no credential")
	var saved_cursor = arena.data.cursor
	var resumed = preload("res://scripts/ai/arena.gd").new()
	resumed.path = arena.path
	root.add_child(resumed)
	var restored_arena = resumed.load_saved()
	verify(restored_arena and resumed.data.cursor == saved_cursor and not resumed.running, "arena restores paused checkpoint")
	if restored_arena:
		resumed.resume(ui.ai_service, "ARENA_TEST_KEY", 100)
		deadline = Time.get_ticks_msec() + 10000
		while resumed.running and Time.get_ticks_msec() < deadline: await process_frame
		verify(resumed.report().completed and resumed.data.valid_decisions > 1, "resumed online arena finishes the remaining seat rotations")
	# Compatibility retries must consume the same hard request budget.
	response_mode = "reject_optional"
	var capped_service = ui.ai_service.duplicate(true)
	capped_service.model = "fresh-cap-test"
	var cap_start = requests.size()
	arena.start({"online": true, "blocks": 2, "counts": [2], "depths": [50]}, capped_service, "ARENA_TEST_KEY", 1)
	deadline = Time.get_ticks_msec() + 4000
	while arena.running and Time.get_ticks_msec() < deadline: await process_frame
	verify(not arena.running and arena.data.requests == 1 and requests.size() == cap_start + 1, "wire-level retries cannot exceed arena request cap")
	verify(arena.data.errors == 1, "unsupported parameters at cap pause without silently playing a fallback")
	response_mode = "decision"
	arena.queue_free()
	resumed.queue_free()
	DirAccess.remove_absolute("user://arena-111-test.json")
	ui.queue_free()
	client.queue_free()
	server.stop()
	for peer in peers: peer.socket.disconnect_from_host()
	await settle()
	for path in [prefs_path, "user://ai-test-companions.json"]: DirAccess.remove_absolute(path)
	print("AI_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
