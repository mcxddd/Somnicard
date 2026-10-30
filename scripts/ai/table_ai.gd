extends Node
## Depends on host: game, paused, modals, _refresh, _schedule_bot, _bot_step, _open_info, _open_settings, _request_confirmation, _save_session, _save_preferences, _action_stamp, settings, screen.turn_label, screen.table_view, screen.controls, session_id, session_stamp, settings_status, opponent_profiles, difficulty, bots, smoke_mode.
var host
const AIConfig = preload("res://scripts/ai/config.gd")
const AIProtocol = preload("res://scripts/ai/protocol.gd")
const AIClient = preload("res://scripts/ai/client.gd")
const AIMemory = preload("res://scripts/ai/memory.gd")
const AIServices = preload("res://scripts/ai/services.gd")
const AIVault = preload("res://scripts/ai/vault.gd")
const AITrace = preload("res://scripts/ai/trace_log.gd")
const Profiles = preload("res://scripts/poker/opponent_profiles.gd")
const UI = preload("res://scripts/ui/style.gd")
const History = preload("res://scripts/poker/history.gd")
var trace = AITrace.new()
var profiles: Array = []
var keys: Dictionary = {}
var live_coach = false
var review_coach = false
var coach_service_id = "default"
var service: Dictionary = AIConfig.service({})
var seats: Array = AIConfig.seats([])
var key: String = ""
var memories: Dictionary = {}
var store
var client
var speech_client
var stamp: String = ""
var actor: int = -1
var error: String = ""
var hand_recorded: String = ""
var local_hand: Dictionary = {}
var dialogue: Array = []
var spoken: Dictionary = {}
var speech_stamp: String = ""
var speech_actor: int = -1
var speech_phase: String = ""
var speech_event: int = 0
var bar: Button
var recovery: HBoxContainer

func build() -> void:
	store = AIMemory.new("user://ai/test-unused.json" if host.smoke_mode or "--capture-test" in OS.get_cmdline_user_args() else "user://ai/companions.json")
	client = AIClient.new()
	add_child(client)
	client.finished.connect(_on_received)
	client.exchange.connect(_on_exchange)
	speech_client = AIClient.new()
	add_child(speech_client)
	speech_client.finished.connect(_on_speech_received)
	speech_client.exchange.connect(_on_exchange)
	bar = UI.button("", open_dialogue, Color("213d45"), 46)
	bar.clip_text = true
	bar.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bar.alignment = HORIZONTAL_ALIGNMENT_LEFT
	bar.add_theme_font_size_override("font_size", 17)
	host.screen.controls.add_child(bar)
	host.screen.controls.move_child(bar, 1)
	bar.hide()
	recovery = HBoxContainer.new()
	host.screen.controls.add_child(recovery)
	host.screen.controls.move_child(recovery, 2)
	for pair in [["重试", retry], ["本手本地接管", take_over], ["配置服务", open_settings]]:
		var button = UI.button(pair[0], pair[1], UI.GREEN, 48)
		button.add_theme_font_size_override("font_size", 17)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		recovery.add_child(button)
	recovery.hide()
	host.settings.ai_page.library_action.connect(library_action)

func cancel() -> void:
	if client != null: client.cancel()
	if speech_client != null: speech_client.cancel()
	stamp = ""
	speech_stamp = ""

func reset_memory() -> void:
	hand_recorded = ""
	memories.clear()
	for id in range(1, 9):
		var companion = store.companions.get(seats[id - 1].companion_id, {})
		memories[str(id)] = AIMemory.normalize(companion.get("memory", {}))

func apply_names() -> void:
	if host.game == null: return
	for id in range(1, host.game.seats.size()):
		host.game.seats[id].name = seats[id - 1].name
		host.game.seats[id]["style"] = "在线 AI · " + Profiles.label(Profiles.resolve(host.opponent_profiles, id, host.difficulty)) if seats[id - 1].enabled else host.bots[id].style_name()

func request() -> void:
	if client.busy or not error.is_empty(): return
	stamp = host._action_stamp()
	actor = host.game.actor
	var seat = seats[actor - 1]
	var messages = AIProtocol.messages(host.game.view_for(actor), actor, seat, Profiles.resolve(host.opponent_profiles, actor, host.difficulty), AIMemory.normalize(memories.get(str(actor), {})))
	var service = seat_service(actor)
	client.send(service, seat_key(actor), messages, 4, context(actor, "decision"))
	host._refresh()

func context(actor: int, purpose: String) -> Dictionary:
	return {"seat": actor, "hand": host.game.hand_number, "phase": host.game.phase, "event": host.game.events.size(), "purpose": purpose}

func _on_exchange(entry: Dictionary) -> void:
	if entry.get("context", {}).is_empty(): return
	trace.append(entry, keys.values() + [key])
	if entry.get("state") == "retrying" and entry.context.get("purpose") == "decision" and host.game != null:
		host.screen.turn_label.text = host.game.seats[int(entry.context.seat)].name + (" · 回复未完成，扩大额度重试中…" if entry.get("finish_reason") in ["length", "max_tokens"] else " · 正在调整接口兼容格式…")

func _on_received(result: Dictionary) -> void:
	if stamp != host._action_stamp() or host.game == null or host.paused or host.modals.is_open() or host.game.actor != self.actor: return
	stamp = ""
	var decision = result if result.has("error") else AIProtocol.decision(result.content, host.game.legal_actions(self.actor))
	if decision.has("error"):
		trace.resolve(str(result.get("trace_id", "")), "未执行：" + decision.error)
		error = decision.error
		host._refresh()
		return
	var actor = self.actor
	var err = host.game.act(actor, decision.action, decision.amount)
	trace.resolve(str(result.get("trace_id", "")), "执行：" + {"check": "过牌", "fold": "弃牌", "call": "跟注", "raise": "加注到 %d 筹码" % decision.amount, "all_in": "全押"}.get(decision.action, decision.action) if err.is_empty() else "未执行：" + err)
	if err != "":
		error = "规则校验未通过，请重试或本地接管"
		host._refresh()
		return
	host._refresh()
	# Speech uses a new public-only prompt, never the private decision response.
	if seat_service(actor).speech and not spoken.has(actor) and not speech_client.busy and host.game.phase != "complete":
		spoken[actor] = true
		speech_actor = actor
		speech_phase = host.game.phase
		speech_event = host.game.events.size()
		speech_stamp = "%s:%d" % [host.session_id, host.game.hand_number]
		speech_client.send(seat_service(actor), seat_key(actor), AIProtocol.messages(host.game.view_for(actor), actor, seats[actor - 1], Profiles.resolve(host.opponent_profiles, actor, host.difficulty), AIMemory.normalize(memories.get(str(actor), {})), true, dialogue), 4, context(actor, "speech"))
	host._schedule_bot()

func _on_speech_received(result: Dictionary) -> void:
	if host.game == null or speech_stamp != "%s:%d" % [host.session_id, host.game.hand_number] or result.has("error"): return
	if not AIProtocol.speech_current(host.game.view_for(speech_actor), speech_actor, speech_event, speech_phase):
		trace.resolve(str(result.get("trace_id", "")), "未展示：牌局已推进，原发言对应的动作已过时")
		return
	var parsed = AIProtocol.table_talk(result.content, dialogue.map(func(item): return item.text))
	if parsed.has("error"):
		trace.resolve(str(result.get("trace_id", "")), "未展示：" + parsed.error)
		return
	var line: String = parsed.text
	if line.is_empty():
		trace.resolve(str(result.get("trace_id", "")), "本次保持沉默")
		return
	trace.resolve(str(result.get("trace_id", "")), "已展示桌边发言")
	dialogue.append({"seat": speech_actor, "name": host.game.seats[speech_actor].name, "text": line, "event": speech_event})
	if dialogue.size() > 8: dialogue.pop_front()
	host.session_stamp = ""
	host.screen.table_view.sync_speech(dialogue)
	update_bar()
	host._save_session()

func update_bar() -> void:
	if bar == null: return
	bar.visible = not error.is_empty() or not local_hand.is_empty()
	recovery.visible = not error.is_empty()
	if not error.is_empty(): bar.text = "连接暂停 · " + error
	else: bar.text = "本手部分 AI 已由本地电脑接管 · 点击查看"
	for button in recovery.get_children(): button.disabled = host.paused or host.modals.is_open()

func open_dialogue() -> void:
	var lines: Array = []
	if error != "": lines.append(error + "\n返回牌桌后重试、接管或配置服务。")
	for id in local_hand: lines.append(host.game.seats[id].name + "：本手由本地电脑接管，下手恢复在线。")
	for line in dialogue: lines.append("%s：%s" % [line.name, line.text])
	host._open_info("本手 AI 发言与状态", "\n\n".join(lines))

func retry() -> void:
	if host.paused or host.modals.is_open(): return
	error = ""
	request()

func take_over() -> void:
	if host.game == null or host.game.actor <= 0 or host.paused or host.modals.is_open(): return
	local_hand[host.game.actor] = true
	error = ""
	cancel()
	host._bot_step()

func open_settings() -> void:
	host._open_settings()
	host.settings._select_page(6)

func finish_hand() -> void:
	if host.game == null or host.game.phase != "complete": return
	# Stop late speech from modifying a history record already saved.
	if speech_client != null: speech_client.cancel()
	var identity = "%s:%d" % [host.session_id, host.game.hand_number]
	if hand_recorded == identity: return
	hand_recorded = identity
	var changed = false
	for id in range(1, host.game.seats.size()):
		if not seats[id - 1].enabled: continue
		var previous = AIMemory.normalize(memories.get(str(id), {}))
		var updated = AIMemory.observe(previous, host.game.view_for(id), id, identity)
		memories[str(id)] = updated
		var companion_id = seats[id - 1].companion_id
		if store.companions.has(companion_id) and updated != previous:
			store.companions[companion_id].memory = updated
			changed = true
	if changed and store.save() != OK: host.settings_status = "陪练记忆保存失败，请检查存储空间"

func session_state() -> Dictionary:
	return {"seats": AIConfig.seats(seats), "memories": memories.duplicate(true), "dialogue": dialogue.duplicate(true), "local_hand": local_hand.keys(), "recorded": hand_recorded, "spoken": spoken.keys()}

func restore_state(raw: Variant) -> void:
	cancel()
	var state: Dictionary = raw if raw is Dictionary else {}
	seats = AIConfig.seats(state.get("seats", []))
	reset_memory()
	if state.get("memories") is Dictionary:
		for id in range(1, 9):
			if seats[id - 1].companion_id == "": memories[str(id)] = AIMemory.normalize(state.memories.get(str(id), memories[str(id)]))
	for i in range(8):
		var companion_id = seats[i].companion_id
		if companion_id == "": continue
		if store.companions.has(companion_id):
			seats[i].name = store.companions[companion_id].name
			seats[i].persona = store.companions[companion_id].persona
		else:
			# A deleted companion must not be resurrected by an older saved table.
			seats[i].companion_id = ""
			memories[str(i + 1)] = AIMemory.normalize({})
	hand_recorded = AIConfig.clean(state.get("recorded", ""), 100)
	dialogue = []
	spoken.clear()
	if state.get("spoken") is Array:
		for id in state.spoken:
			if History._integer(id, 1, host.game.seats.size() - 1): spoken[int(id)] = true
	if state.get("dialogue") is Array:
		for line in state.dialogue.slice(0, 8):
			if line is Dictionary and History._integer(line.get("seat"), 1, host.game.seats.size() - 1) and History._integer(line.get("event"), 0, host.game.events.size()):
				dialogue.append({"seat": int(line.seat), "event": int(line.event), "name": AIConfig.clean(line.get("name", ""), 12), "text": AIConfig.clean(line.get("text", ""), 48)})
				spoken[int(line.seat)] = true
	local_hand.clear()
	if state.get("local_hand") is Array:
		for id in state.local_hand:
			if History._integer(id, 1, host.game.seats.size() - 1): local_hand[int(id)] = true
	error = ""

func apply_settings(values: Dictionary) -> bool:
	var seats = AIConfig.seats(values.get("ai_seats", self.seats))
	var service = AIConfig.service(values.get("ai_service", self.service))
	var profiles = AIServices.normalize(values.get("ai_profiles", []), service)
	var keys: Dictionary = values.get("ai_keys", {"default": values.get("ai_key", key)}).duplicate()
	for seat in seats:
		if seat.enabled and AIConfig.validate(AIServices.resolve(profiles, seat.service_id)) != "":
			host.settings.summary.text = seat.name + "：请在 AI 服务中配置所选模型档案。"
			return false
	if (values.get("ai_live_coach", false) or values.get("ai_review_coach", false)) and AIConfig.validate(AIServices.resolve(profiles, str(values.get("coach_service_id", "default")))) != "":
		host.settings.summary.text = "请先选择可用的教练模型档案。"
		return false
	var used: Array = []
	var pending = 0
	for seat in seats:
		if seat.companion_id.begins_with("new:"): pending += 1
		elif seat.enabled and seat.companion_id != "":
			if seat.companion_id in used:
				host.settings.summary.text = "同一陪练只能占一个座位，请选择不同身份。"
				return false
			used.append(seat.companion_id)
	if store.companions.size() + pending > 32:
		host.settings.summary.text = "最多保存 32 位陪练，请先删除不用的档案。"
		return false
	var old_library = store.companions.duplicate(true)
	for i in range(8):
		var seat = seats[i]
		var old = self.seats[i]
		if seat.companion_id.begins_with("new:"):
			seat.companion_id = store.create(seat, Profiles.resolve(values.get("opponents", host.opponent_profiles), i + 1, int(values.get("difficulty", host.difficulty))), memories.get(str(i + 1), {}))
			if seat.companion_id == "":
				store.companions = old_library
				store.save()
				host.settings.summary.text = "陪练档案保存失败，请检查存储空间。"
				return false
		elif seat.companion_id != old.companion_id:
			memories[str(i + 1)] = AIMemory.normalize(store.companions.get(seat.companion_id, {}).get("memory", {}))
		if store.companions.has(seat.companion_id):
			var saved = store.companions[seat.companion_id]
			saved.name = seat.name
			saved.persona = seat.persona
			saved.service_id = seat.service_id
			var profile = Profiles.resolve(values.get("opponents", host.opponent_profiles), i + 1, int(values.get("difficulty", host.difficulty)))
			saved.difficulty = profile.difficulty
			saved.aggression = profile.aggression
	if store.companions != old_library and store.save() != OK:
		store.companions = old_library
		host.settings.summary.text = "陪练档案保存失败，请检查存储空间。"
		return false
	var vault_error = AIVault.save(profiles, keys) if not host.smoke_mode and "--capture-test" not in OS.get_cmdline_user_args() else ""
	if vault_error != "":
		store.companions = old_library
		store.save()
		host.settings.summary.text = vault_error
		return false
	self.profiles = profiles
	self.keys = keys
	live_coach = values.get("ai_live_coach", false)
	review_coach = values.get("ai_review_coach", false)
	coach_service_id = str(values.get("coach_service_id", "default"))
	self.seats = seats
	self.service = AIConfig.service(values.get("ai_service", self.service))
	key = str(keys.get("default", "")).strip_edges()
	error = ""
	cancel()
	apply_names()
	host.session_stamp = ""
	return true

func library_action(action: String, id: String, name: String) -> void:
	if not store.companions.has(id): return
	if action in ["clear", "delete"]:
		host._request_confirmation("清空陪练记忆？" if action == "clear" else "删除这位陪练？", "会立即更新档案和当前牌桌；此操作不可撤销。已保存的历史牌局仍然保留。", "确认", edit_library.bind(action, id, name))
	else: edit_library(action, id, name)

func edit_library(action: String, id: String, name: String) -> void:
	if not store.companions.has(id): return
	var old = store.companions.duplicate(true)
	if action == "delete": store.companions.erase(id)
	elif action == "clear": store.companions[id].memory = AIMemory.normalize({})
	elif action == "rename":
		name = AIConfig.clean(name, 12)
		if name == "": return
		store.companions[id].name = name
	if store.save() != OK:
		store.companions = old
		host.settings.ai_page.status.text = "档案操作保存失败，请检查存储空间。"
		return
	for i in range(8):
		if seats[i].companion_id == id:
			if action == "delete": seats[i].companion_id = ""
			elif action == "rename": seats[i].name = name
			if action in ["clear", "delete"]: memories[str(i + 1)] = AIMemory.normalize({})
		var draft = host.settings.opponent_editor.ai_seats[i]
		if draft.companion_id == id:
			if action == "delete": draft.companion_id = ""
			elif action == "rename": draft.name = name
	host.settings.ai_library = store.companions
	host.settings.ai_page.fill_library(store.companions)
	host.settings.opponent_editor.companions = store.companions.duplicate(true)
	host.settings.opponent_editor._render()
	apply_names()
	host._save_preferences()
	host.session_stamp = ""
	host._save_session()

func seat_service(id: int) -> Dictionary:
	return AIServices.resolve(profiles, seats[id - 1].service_id, service)

func seat_key(id: int) -> String:
	var key_id = seats[id - 1].service_id
	return str(keys.get(key_id, key if key_id == "default" else ""))
