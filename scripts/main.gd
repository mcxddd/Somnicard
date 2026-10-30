extends Control
const AIConfig = preload("res://scripts/ai/config.gd")
const AIProtocol = preload("res://scripts/ai/protocol.gd")
const AIClient = preload("res://scripts/ai/client.gd")
const AIMemory = preload("res://scripts/ai/memory.gd")
const AIServices = preload("res://scripts/ai/services.gd")
const AIVault = preload("res://scripts/ai/vault.gd")
const AITrace = preload("res://scripts/ai/trace_log.gd")
var ai_trace = AITrace.new()
var ai_inspector
var last_system_back_ms: int = -1000
var ai_profiles: Array = []
var ai_keys: Dictionary = {}
var ai_live_coach = false
var ai_review_coach = false
var coach_service_id = "default"
var ai_service: Dictionary = AIConfig.service({})
var ai_seats: Array = AIConfig.seats([])
var ai_key: String = ""
var ai_memories: Dictionary = {}
var ai_store
var ai_client
var speech_client
var ai_stamp: String = ""
var ai_actor: int = -1
var ai_error: String = ""
var ai_hand_recorded: String = ""
var ai_local_hand: Dictionary = {}
var ai_dialogue: Array = []
var ai_spoken: Dictionary = {}
var speech_stamp: String = ""
var speech_actor: int = -1
var speech_phase: String = ""
var speech_event: int = 0
var ai_bar: Button
var ai_recovery: HBoxContainer
const Table = preload("res://scripts/poker/table.gd")
const Eval = preload("res://scripts/poker/evaluator.gd")
const Profiles = preload("res://scripts/poker/opponent_profiles.gd")
const LocalBot = preload("res://scripts/poker/local_bot.gd")
const UI = preload("res://scripts/ui/style.gd")
const UnitSwitch = preload("res://scripts/ui/unit_switch.gd")
const Sizing = preload("res://scripts/ui/bet_sizing.gd")
const TableView = preload("res://scripts/ui/table_view.gd")
const History = preload("res://scripts/poker/history.gd")
const Review = preload("res://scripts/ui/review.gd")
const Session = preload("res://scripts/poker/session.gd")
const Settings = preload("res://scripts/ui/settings.gd")
const Confirmation = preload("res://scripts/ui/confirm.gd")
const Home = preload("res://scripts/ui/home.gd")
const TouchScroll = preload("res://scripts/ui/touch_scroll.gd")
var home
const Badge = preload("res://scripts/ui/seat_badge.gd")
const Sheet = preload("res://scripts/ui/sheet.gd")
const Coach = preload("res://scripts/ui/coach.gd")
const Training = preload("res://scripts/ui/training.gd")
const TrainingStore = preload("res://scripts/poker/training_store.gd")
var training
var training_store
var training_origin: Dictionary = {}
var training_replay: bool = false
const Preferences = preload("res://scripts/ui/preferences.gd")
const PHASES = {"preflop": "翻牌前", "flop": "翻牌", "turn": "转牌", "river": "河牌", "complete": "本手结束"}
const ACTIONS = {"fold": "弃牌", "check": "过牌", "call": "跟注", "raise": "加注"}
const SPEEDS = [1.0, 0.65, 0.25]
var player_count: int = 2
var starting_bb: int = 100
var selected_count: int = 2
var game
var bots: Dictionary = {}
var bot = LocalBot.new()
var bot_timer: Timer
var paused: bool = false
var smoke_mode: bool = false
var use_bb: bool = true
var speed_index: int = 1
var selected_raise: int = 20
var decision_key: String = ""
var session_id: String = ""
var saved_hand: int = -1
var save_status: String = ""
var table_view
var header: Label
var turn_label: Label
var explanation: Label
var log_view: RichTextLabel
var sidebar: PanelContainer
var pause_button: Button
var fold_button: Button
var call_button: Button
var raise_button: Button
var all_in_button: Button
var next_button: Button
var amount_input: SpinBox
var unit_picker
var amount_slider: HSlider
var amount_note: Label
var minus_button: Button
var plus_button: Button
var quick_buttons: Array = []
var sizing_row: HBoxContainer
var quick_row: GridContainer
var speed_picker: OptionButton
var fast_fold: CheckBox
var lobby: ColorRect
var count_picker: OptionButton
var depth_picker: OptionButton
var lobby_note: Label
var start_button: Button
var cancel_button: Button
var preset_buttons: Dictionary = {}
var mobile_layout: bool = true
var background_focus: Dictionary = {}
var review
var advice_button: Button
var review_hand_button: Button
var resume_button: Button
var resume_status: Label
var session_stamp: String = ""
var session_save_error: bool = false
var settings
var confirmation
var confirmation_action: Callable
var felt_theme: int = 0
var four_color: bool = false
var motion: bool = true
var confirm_all_in: bool = true
var show_sidebar: bool = true
var fast_fold_enabled: bool = true
var live_teaching: bool = true
var review_teaching: bool = true
var coach
var difficulty: int = 1
var opponent_profiles: Array = Profiles.normalize([])
var opponent_changes: Array = []
var coach_after: bool = false
var coach_auto: bool = false
var coach_detail: int = 0
var coach_side: int = 1
var last_table_count: int = 2
var settings_status: String = ""
const portrait: bool = true
var safe_root: Control
var margin: MarginContainer
var top: HBoxContainer
var subhead: HBoxContainer
var brand: VBoxContainer
var mark: Control
var dock: PanelContainer
var controls: VBoxContainer
var actions: HBoxContainer
var more_button: Button
var bet_open_button: Button
var bet_sheet
var menu_sheet
var info_sheet
var info_opponent_button: Button
var info_opponent_id: int = -1
var info_text: RichTextLabel
var sheet_units: OptionButton
var lobby_panel: PanelContainer
var lobby_scroll: ScrollContainer
var lobby_shell: BoxContainer
var lobby_welcome: VBoxContainer
var lobby_art: Control
var lobby_column: VBoxContainer
var lobby_extras: BoxContainer
var lobby_buttons: BoxContainer
var layout_ready: bool = false
var learning_center
var support_center
var feedback_player
var sound_level = 1
var haptics_enabled = false
var performance_mode = 0

func _ready() -> void:
	get_window().title = "Somnicard %s · 德州扑克练习" % ProjectSettings.get_setting("application/config/version", "1.4.1")
	smoke_mode = "--smoke-test" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless"
	_update_scale()
	show_sidebar = not mobile_layout
	_load_preferences()
	_build_ui()
	review.ai_coach.configure(_settings_values())
	training.ai_coach.configure(_settings_values())
	layout_ready = true
	get_window().size_changed.connect(_resize_ui)
	resized.connect(_resize_ui)
	_arrange_ui()
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	_open_home()
	if "--smoke-test" in OS.get_cmdline_user_args(): call_deferred("_smoke_test")

func _build_ai() -> void:
	ai_store = AIMemory.new("user://ai/test-unused.json" if smoke_mode or "--capture-test" in OS.get_cmdline_user_args() else "user://ai/companions.json")
	ai_client = AIClient.new()
	add_child(ai_client)
	ai_client.finished.connect(_ai_received)
	ai_client.exchange.connect(_ai_exchange)
	speech_client = AIClient.new()
	add_child(speech_client)
	speech_client.finished.connect(_speech_received)
	speech_client.exchange.connect(_ai_exchange)
	ai_bar = UI.button("", _open_ai_dialogue, Color("213d45"), 46)
	ai_bar.clip_text = true
	ai_bar.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ai_bar.alignment = HORIZONTAL_ALIGNMENT_LEFT
	ai_bar.add_theme_font_size_override("font_size", 17)
	controls.add_child(ai_bar)
	controls.move_child(ai_bar, 1)
	ai_bar.hide()
	ai_recovery = HBoxContainer.new()
	controls.add_child(ai_recovery)
	controls.move_child(ai_recovery, 2)
	for pair in [["重试", _retry_ai], ["本手本地接管", _take_over_ai], ["配置服务", _open_ai_settings]]:
		var button = UI.button(pair[0], pair[1], UI.GREEN, 48)
		button.add_theme_font_size_override("font_size", 17)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ai_recovery.add_child(button)
	ai_recovery.hide()
	settings.ai_page.library_action.connect(_ai_library_action)

func _cancel_ai() -> void:
	if ai_client != null: ai_client.cancel()
	if speech_client != null: speech_client.cancel()
	ai_stamp = ""
	speech_stamp = ""

func _reset_ai_memory() -> void:
	ai_hand_recorded = ""
	ai_memories.clear()
	for id in range(1, 9):
		var companion = ai_store.companions.get(ai_seats[id - 1].companion_id, {})
		ai_memories[str(id)] = AIMemory.normalize(companion.get("memory", {}))

func _apply_ai_names() -> void:
	if game == null: return
	for id in range(1, game.seats.size()):
		game.seats[id].name = ai_seats[id - 1].name
		game.seats[id]["style"] = "在线 AI · " + Profiles.label(Profiles.resolve(opponent_profiles, id, difficulty)) if ai_seats[id - 1].enabled else bots[id].style_name()

func _request_ai() -> void:
	if ai_client.busy or not ai_error.is_empty(): return
	ai_stamp = _action_stamp()
	ai_actor = game.actor
	var seat = ai_seats[ai_actor - 1]
	var messages = AIProtocol.messages(game.view_for(ai_actor), ai_actor, seat, Profiles.resolve(opponent_profiles, ai_actor, difficulty), AIMemory.normalize(ai_memories.get(str(ai_actor), {})))
	var service = _seat_service(ai_actor)
	ai_client.send(service, _seat_key(ai_actor), messages, 4, _ai_context(ai_actor, "decision"))
	_refresh()

func _ai_context(actor: int, purpose: String) -> Dictionary:
	return {"seat": actor, "hand": game.hand_number, "phase": game.phase, "event": game.events.size(), "purpose": purpose}

func _ai_exchange(entry: Dictionary) -> void:
	if entry.get("context", {}).is_empty(): return
	ai_trace.append(entry, ai_keys.values() + [ai_key])
	if entry.get("state") == "retrying" and entry.context.get("purpose") == "decision" and game != null:
		turn_label.text = game.seats[int(entry.context.seat)].name + (" · 回复未完成，扩大额度重试中…" if entry.get("finish_reason") in ["length", "max_tokens"] else " · 正在调整接口兼容格式…")

func _ai_received(result: Dictionary) -> void:
	if ai_stamp != _action_stamp() or game == null or paused or _modal_open() or game.actor != ai_actor: return
	ai_stamp = ""
	var decision = result if result.has("error") else AIProtocol.decision(result.content, game.legal_actions(ai_actor))
	if decision.has("error"):
		ai_trace.resolve(str(result.get("trace_id", "")), "未执行：" + decision.error)
		ai_error = decision.error
		_refresh()
		return
	var actor = ai_actor
	var err = game.act(actor, decision.action, decision.amount)
	ai_trace.resolve(str(result.get("trace_id", "")), "执行：" + {"check": "过牌", "fold": "弃牌", "call": "跟注", "raise": "加注到 %d 筹码" % decision.amount, "all_in": "全押"}.get(decision.action, decision.action) if err.is_empty() else "未执行：" + err)
	if err != "":
		ai_error = "规则校验未通过，请重试或本地接管"
		_refresh()
		return
	_refresh()
	# Speech uses a new public-only prompt, never the private decision response.
	if _seat_service(actor).speech and not ai_spoken.has(actor) and not speech_client.busy and game.phase != "complete":
		ai_spoken[actor] = true
		speech_actor = actor
		speech_phase = game.phase
		speech_event = game.events.size()
		speech_stamp = "%s:%d" % [session_id, game.hand_number]
		speech_client.send(_seat_service(actor), _seat_key(actor), AIProtocol.messages(game.view_for(actor), actor, ai_seats[actor - 1], Profiles.resolve(opponent_profiles, actor, difficulty), AIMemory.normalize(ai_memories.get(str(actor), {})), true, ai_dialogue), 4, _ai_context(actor, "speech"))
	_schedule_bot()

func _speech_received(result: Dictionary) -> void:
	if game == null or speech_stamp != "%s:%d" % [session_id, game.hand_number] or result.has("error"): return
	if not AIProtocol.speech_current(game.view_for(speech_actor), speech_actor, speech_event, speech_phase):
		ai_trace.resolve(str(result.get("trace_id", "")), "未展示：牌局已推进，原发言对应的动作已过时")
		return
	var parsed = AIProtocol.table_talk(result.content, ai_dialogue.map(func(item): return item.text))
	if parsed.has("error"):
		ai_trace.resolve(str(result.get("trace_id", "")), "未展示：" + parsed.error)
		return
	var line: String = parsed.text
	if line.is_empty():
		ai_trace.resolve(str(result.get("trace_id", "")), "本次保持沉默")
		return
	ai_trace.resolve(str(result.get("trace_id", "")), "已展示桌边发言")
	ai_dialogue.append({"seat": speech_actor, "name": game.seats[speech_actor].name, "text": line, "event": speech_event})
	if ai_dialogue.size() > 8: ai_dialogue.pop_front()
	session_stamp = ""
	table_view.sync_speech(ai_dialogue)
	_update_ai_bar()
	_save_session()

func _update_ai_bar() -> void:
	if ai_bar == null: return
	ai_bar.visible = not ai_error.is_empty() or not ai_local_hand.is_empty()
	ai_recovery.visible = not ai_error.is_empty()
	if not ai_error.is_empty(): ai_bar.text = "连接暂停 · " + ai_error
	else: ai_bar.text = "本手部分 AI 已由本地电脑接管 · 点击查看"
	for button in ai_recovery.get_children(): button.disabled = paused or _modal_open()

func _open_ai_dialogue() -> void:
	var lines: Array = []
	if ai_error != "": lines.append(ai_error + "\n返回牌桌后重试、接管或配置服务。")
	for id in ai_local_hand: lines.append(game.seats[id].name + "：本手由本地电脑接管，下手恢复在线。")
	for line in ai_dialogue: lines.append("%s：%s" % [line.name, line.text])
	_open_info("本手 AI 发言与状态", "\n\n".join(lines))

func _retry_ai() -> void:
	if paused or _modal_open(): return
	ai_error = ""
	_request_ai()

func _take_over_ai() -> void:
	if game == null or game.actor <= 0 or paused or _modal_open(): return
	ai_local_hand[game.actor] = true
	ai_error = ""
	_cancel_ai()
	_bot_step()

func _open_ai_settings() -> void:
	_open_settings()
	settings._select_page(6)

func _finish_ai_hand() -> void:
	if game == null or game.phase != "complete": return
	# Stop late speech from modifying a history record already saved.
	if speech_client != null: speech_client.cancel()
	var identity = "%s:%d" % [session_id, game.hand_number]
	if ai_hand_recorded == identity: return
	ai_hand_recorded = identity
	var changed = false
	for id in range(1, game.seats.size()):
		if not ai_seats[id - 1].enabled: continue
		var previous = AIMemory.normalize(ai_memories.get(str(id), {}))
		var updated = AIMemory.observe(previous, game.view_for(id), id, identity)
		ai_memories[str(id)] = updated
		var companion_id = ai_seats[id - 1].companion_id
		if ai_store.companions.has(companion_id) and updated != previous:
			ai_store.companions[companion_id].memory = updated
			changed = true
	if changed and ai_store.save() != OK: settings_status = "陪练记忆保存失败，请检查存储空间"

func _ai_session_state() -> Dictionary:
	return {"seats": AIConfig.seats(ai_seats), "memories": ai_memories.duplicate(true), "dialogue": ai_dialogue.duplicate(true), "local_hand": ai_local_hand.keys(), "recorded": ai_hand_recorded, "spoken": ai_spoken.keys()}

func _restore_ai_state(raw: Variant) -> void:
	_cancel_ai()
	var state: Dictionary = raw if raw is Dictionary else {}
	ai_seats = AIConfig.seats(state.get("seats", []))
	_reset_ai_memory()
	if state.get("memories") is Dictionary:
		for id in range(1, 9):
			if ai_seats[id - 1].companion_id == "": ai_memories[str(id)] = AIMemory.normalize(state.memories.get(str(id), ai_memories[str(id)]))
	for i in range(8):
		var companion_id = ai_seats[i].companion_id
		if companion_id == "": continue
		if ai_store.companions.has(companion_id):
			ai_seats[i].name = ai_store.companions[companion_id].name
			ai_seats[i].persona = ai_store.companions[companion_id].persona
		else:
			# A deleted companion must not be resurrected by an older saved table.
			ai_seats[i].companion_id = ""
			ai_memories[str(i + 1)] = AIMemory.normalize({})
	ai_hand_recorded = AIConfig.clean(state.get("recorded", ""), 100)
	ai_dialogue = []
	ai_spoken.clear()
	if state.get("spoken") is Array:
		for id in state.spoken:
			if History._integer(id, 1, game.seats.size() - 1): ai_spoken[int(id)] = true
	if state.get("dialogue") is Array:
		for line in state.dialogue.slice(0, 8):
			if line is Dictionary and History._integer(line.get("seat"), 1, game.seats.size() - 1) and History._integer(line.get("event"), 0, game.events.size()):
				ai_dialogue.append({"seat": int(line.seat), "event": int(line.event), "name": AIConfig.clean(line.get("name", ""), 12), "text": AIConfig.clean(line.get("text", ""), 48)})
				ai_spoken[int(line.seat)] = true
	ai_local_hand.clear()
	if state.get("local_hand") is Array:
		for id in state.local_hand:
			if History._integer(id, 1, game.seats.size() - 1): ai_local_hand[int(id)] = true
	ai_error = ""

func _apply_ai_settings(values: Dictionary) -> bool:
	var seats = AIConfig.seats(values.get("ai_seats", ai_seats))
	var service = AIConfig.service(values.get("ai_service", ai_service))
	var profiles = AIServices.normalize(values.get("ai_profiles", []), service)
	var keys: Dictionary = values.get("ai_keys", {"default": values.get("ai_key", ai_key)}).duplicate()
	for seat in seats:
		if seat.enabled and AIConfig.validate(AIServices.resolve(profiles, seat.service_id)) != "":
			settings.summary.text = seat.name + "：请在 AI 服务中配置所选模型档案。"
			return false
	if (values.get("ai_live_coach", false) or values.get("ai_review_coach", false)) and AIConfig.validate(AIServices.resolve(profiles, str(values.get("coach_service_id", "default")))) != "":
		settings.summary.text = "请先选择可用的教练模型档案。"
		return false
	var used: Array = []
	var pending = 0
	for seat in seats:
		if seat.companion_id.begins_with("new:"): pending += 1
		elif seat.enabled and seat.companion_id != "":
			if seat.companion_id in used:
				settings.summary.text = "同一陪练只能占一个座位，请选择不同身份。"
				return false
			used.append(seat.companion_id)
	if ai_store.companions.size() + pending > 32:
		settings.summary.text = "最多保存 32 位陪练，请先删除不用的档案。"
		return false
	var old_library = ai_store.companions.duplicate(true)
	for i in range(8):
		var seat = seats[i]
		var old = ai_seats[i]
		if seat.companion_id.begins_with("new:"):
			seat.companion_id = ai_store.create(seat, Profiles.resolve(values.get("opponents", opponent_profiles), i + 1, int(values.get("difficulty", difficulty))), ai_memories.get(str(i + 1), {}))
			if seat.companion_id == "":
				ai_store.companions = old_library
				ai_store.save()
				settings.summary.text = "陪练档案保存失败，请检查存储空间。"
				return false
		elif seat.companion_id != old.companion_id:
			ai_memories[str(i + 1)] = AIMemory.normalize(ai_store.companions.get(seat.companion_id, {}).get("memory", {}))
		if ai_store.companions.has(seat.companion_id):
			var saved = ai_store.companions[seat.companion_id]
			saved.name = seat.name
			saved.persona = seat.persona
			saved.service_id = seat.service_id
			var profile = Profiles.resolve(values.get("opponents", opponent_profiles), i + 1, int(values.get("difficulty", difficulty)))
			saved.difficulty = profile.difficulty
			saved.aggression = profile.aggression
	if ai_store.companions != old_library and ai_store.save() != OK:
		ai_store.companions = old_library
		settings.summary.text = "陪练档案保存失败，请检查存储空间。"
		return false
	var vault_error = AIVault.save(profiles, keys) if not smoke_mode and "--capture-test" not in OS.get_cmdline_user_args() else ""
	if vault_error != "":
		ai_store.companions = old_library
		ai_store.save()
		settings.summary.text = vault_error
		return false
	ai_profiles = profiles
	ai_keys = keys
	ai_live_coach = values.get("ai_live_coach", false)
	ai_review_coach = values.get("ai_review_coach", false)
	coach_service_id = str(values.get("coach_service_id", "default"))
	ai_seats = seats
	ai_service = AIConfig.service(values.get("ai_service", ai_service))
	ai_key = str(keys.get("default", "")).strip_edges()
	ai_error = ""
	_cancel_ai()
	_apply_ai_names()
	session_stamp = ""
	return true

func _ai_library_action(action: String, id: String, name: String) -> void:
	if not ai_store.companions.has(id): return
	if action in ["clear", "delete"]:
		_request_confirmation("清空陪练记忆？" if action == "clear" else "删除这位陪练？", "会立即更新档案和当前牌桌；此操作不可撤销。已保存的历史牌局仍然保留。", "确认", _edit_ai_library.bind(action, id, name))
	else: _edit_ai_library(action, id, name)

func _edit_ai_library(action: String, id: String, name: String) -> void:
	if not ai_store.companions.has(id): return
	var old = ai_store.companions.duplicate(true)
	if action == "delete": ai_store.companions.erase(id)
	elif action == "clear": ai_store.companions[id].memory = AIMemory.normalize({})
	elif action == "rename":
		name = AIConfig.clean(name, 12)
		if name == "": return
		ai_store.companions[id].name = name
	if ai_store.save() != OK:
		ai_store.companions = old
		settings.ai_page.status.text = "档案操作保存失败，请检查存储空间。"
		return
	for i in range(8):
		if ai_seats[i].companion_id == id:
			if action == "delete": ai_seats[i].companion_id = ""
			elif action == "rename": ai_seats[i].name = name
			if action in ["clear", "delete"]: ai_memories[str(i + 1)] = AIMemory.normalize({})
		var draft = settings.opponent_editor.ai_seats[i]
		if draft.companion_id == id:
			if action == "delete": draft.companion_id = ""
			elif action == "rename": draft.name = name
	settings.ai_library = ai_store.companions
	settings.ai_page.fill_library(ai_store.companions)
	settings.opponent_editor.companions = ai_store.companions.duplicate(true)
	settings.opponent_editor._render()
	_apply_ai_names()
	_save_preferences()
	session_stamp = ""
	_save_session()

func _build_ui() -> void:
	theme = UI.make_theme(mobile_layout)
	safe_root = Control.new()
	safe_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(safe_root)
	margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 20)
	safe_root.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	top = _row(12)
	layout.add_child(top)
	mark = Badge.new()
	mark.custom_minimum_size = Vector2(42, 42)
	top.add_child(mark)
	brand = VBoxContainer.new()
	brand.add_child(UI.label("SOMNICARD", 23, UI.GOLD))
	brand.add_child(UI.label("专注每一手决策", 13, UI.MUTED))
	top.add_child(brand)
	header = UI.label("德州扑克练习室", 20, UI.TEXT)
	header.clip_text = true
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(header)
	unit_picker = UnitSwitch.new()
	unit_picker.select(1 if use_bb else 0)
	unit_picker.custom_minimum_size = Vector2(110, 48)
	unit_picker.tooltip_text = "切换整桌和下注输入的显示单位，实际筹码不变"
	unit_picker.item_selected.connect(_unit_changed)
	top.add_child(unit_picker)
	pause_button = UI.button("暂停", _toggle_pause)
	top.add_child(pause_button)
	speed_picker = OptionButton.new()
	speed_picker.custom_minimum_size = Vector2(112, 48)
	for text in ["慢速", "标准速度", "快速"]: speed_picker.add_item(text)
	speed_picker.select(speed_index)
	speed_picker.item_selected.connect(_speed_changed)
	add_child(speed_picker)
	speed_picker.hide()
	advice_button = UI.button("教练", _open_advice, UI.GREEN)
	top.add_child(advice_button)
	more_button = UI.button("更多", _open_menu)
	top.add_child(more_button)
	subhead = _row(12)
	layout.add_child(subhead)
	var content = _row(16)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(content)
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 10)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(main)
	table_view = TableView.new()
	table_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(table_view)
	table_view.set_preferences(felt_theme, four_color, motion)
	dock = UI.panel(Color("10252d"), 16, 14)
	main.add_child(dock)
	controls = VBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	dock.add_child(controls)
	turn_label = UI.label("选择桌型，开始练习", 20, UI.GOLD)
	turn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(turn_label)
	sizing_row = _row(10)
	controls.add_child(sizing_row)
	sizing_row.add_child(UI.label("本轮加到", 17, UI.MUTED))
	amount_input = SpinBox.new()
	amount_input.custom_minimum_size = Vector2(134, 46)
	amount_input.value_changed.connect(_amount_changed)
	sizing_row.add_child(amount_input)
	minus_button = UI.button("−1 BB", _adjust_bb.bind(-1), Color("243a40"), 46)
	plus_button = UI.button("+1 BB", _adjust_bb.bind(1), Color("243a40"), 46)
	sizing_row.add_child(minus_button)
	amount_slider = HSlider.new()
	amount_slider.custom_minimum_size = Vector2(110, 46)
	amount_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	amount_slider.value_changed.connect(func(value): _set_target(int(value)))
	sizing_row.add_child(amount_slider)
	sizing_row.add_child(plus_button)
	amount_note = UI.label("", 16, UI.MUTED)
	amount_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(amount_note)
	quick_row = GridContainer.new()
	quick_row.columns = 8
	quick_row.add_theme_constant_override("h_separation", 7)
	quick_row.add_theme_constant_override("v_separation", 10)
	controls.add_child(quick_row)
	_add_quick("最小", _quick_minimum)
	for bb in [2.0, 2.5, 3.0, 4.0]:
		_add_quick(("%.1f" % bb).trim_suffix(".0") + " BB", _quick_bb.bind(bb))
	for pair in [["⅓ 底池", 1.0 / 3.0], ["½ 底池", 0.5], ["满池", 1.0]]:
		_add_quick(pair[0], _quick_pot.bind(pair[1]))
	actions = _row(10)
	controls.add_child(actions)
	fold_button = UI.button("弃牌", func(): _human_action("fold"), Color("2e3b42"), 56)
	call_button = UI.button("过牌", func(): _human_action("check_call"), UI.GREEN, 56)
	raise_button = UI.button("加注", _submit_raise, Color("8c6938"), 56)
	all_in_button = UI.button("全押", _submit_all_in, Color("633c46"), 56)
	next_button = UI.button("下一手", _next_hand, UI.GREEN, 56)
	review_hand_button = UI.button("复盘本手", _review_current_hand, Color("8c6938"), 56)
	for button in [fold_button, call_button, raise_button, all_in_button, next_button, review_hand_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
	bet_open_button = UI.button("加注…", _open_bet, Color("8c6938"), 60)
	bet_open_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(bet_open_button)
	bet_open_button.hide()
	fold_button.tooltip_text = "弃牌（快捷键 F）"
	call_button.tooltip_text = "过牌或跟注（空格）"
	raise_button.tooltip_text = "提交上方选定的本轮总额；R 键可聚焦输入框"
	sidebar = UI.panel(Color("102027"), 16, 16)
	sidebar.custom_minimum_size.x = 276
	content.add_child(sidebar)
	sidebar.hide()
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 12)
	sidebar.add_child(side)
	side.add_child(UI.label("牌局讲解", 21, UI.GOLD))
	explanation = UI.label("", 17)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.custom_minimum_size = Vector2(244, 158)
	side.add_child(explanation)
	side.add_child(HSeparator.new())
	side.add_child(UI.label("本手记录", 19, UI.MUTED))
	log_view = RichTextLabel.new()
	log_view.scroll_following = true
	log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_view.add_theme_font_size_override("normal_font_size", 16)
	log_view.add_theme_color_override("default_color", UI.TEXT)
	side.add_child(log_view)
	fast_fold = CheckBox.new()
	fast_fold.text = "弃牌后快进电脑行动"
	fast_fold.button_pressed = fast_fold_enabled
	side.add_child(fast_fold)
	fast_fold.hide()
	side.add_child(UI.label("D 庄家 · SB 小盲 · BB 大盲\n虚拟筹码 · 离线电脑对战", 14, UI.MUTED))
	bot_timer = Timer.new()
	bot_timer.one_shot = true
	bot_timer.timeout.connect(_bot_step)
	add_child(bot_timer)
	coach = Coach.new()
	safe_root.add_child(coach)
	coach.settings_requested.connect(func(): _open_settings(); settings._select_page(3))
	coach.details_requested.connect(_open_advice)
	coach.review_requested.connect(_review_current_hand)
	coach.configure(_settings_values())
	_build_home()
	_build_lobby()
	training_store = TrainingStore.new("user://training/profile.json" if _session_enabled() else "")
	review = Review.new()
	safe_root.add_child(review)
	review.training_store = training_store
	review.practice_requested.connect(_practice_from_review)
	review.closed.connect(_close_review)
	training = Training.new()
	safe_root.add_child(training)
	training.store = training_store
	training.closed.connect(_close_training)
	training.replay_requested.connect(_training_replay_requested)
	review.units_changed.connect(_review_units_changed)
	review.table_view.set_preferences(felt_theme, four_color, motion)
	review.set_teaching(live_teaching, review_teaching)
	review.ai_coach.configure(_settings_values())
	training.ai_coach.configure(_settings_values())
	review.teaching_changed.connect(_teaching_changed)
	settings = Settings.new()
	safe_root.add_child(settings)
	settings.data_page.store = training_store
	settings.applied.connect(_apply_settings)
	settings.cancelled.connect(_close_settings)
	confirmation = Confirmation.new()
	safe_root.add_child(confirmation)
	confirmation.accepted.connect(_accept_confirmation)
	confirmation.cancelled.connect(_cancel_confirmation)
	_build_sheets()
	_build_ai()
	_build_product()

func _build_product() -> void:
	feedback_player = preload("res://scripts/ui/game_feedback.gd").new()
	add_child(feedback_player)
	_apply_feedback_preferences()
	learning_center = preload("res://scripts/ui/learning_center.gd").new()
	safe_root.add_child(learning_center)
	learning_center.store = training_store
	learning_center.closed.connect(_close_product)
	learning_center.practice_requested.connect(func(topic):
		learning_center.hide()
		_open_training()
		var selected_topic = "面对下注" if topic in ["跟注犹豫", "诈唬判断"] else topic
		for i in range(training.topic_picker.item_count):
			if training.topic_picker.get_item_text(i) == selected_topic: training.topic_picker.select(i))
	support_center = preload("res://scripts/ui/support_center.gd").new()
	safe_root.add_child(support_center)
	support_center.closed.connect(_close_product)
	support_center.destination.connect(func(name):
		support_center.hide()
		if name == "academy": _open_product("academy")
		else:
			_open_settings()
			settings._select_page(6 if name == "ai" else 5))
	confirmation.z_index = 30

func _apply_feedback_preferences() -> void:
	if feedback_player != null: feedback_player.configure({"sound": sound_level, "haptics": haptics_enabled})
	if not smoke_mode: Engine.max_fps = 30 if performance_mode == 1 else 60

func _open_product(name: String) -> void:
	bot_timer.stop()
	_cancel_ai()
	amount_input.apply()
	coach.collapse()
	_restore_background_focus()
	if name == "academy": learning_center.open()
	else: support_center.open()
	_sync_modal_focus()
	_refresh()

func _close_product() -> void:
	_update_home()
	_sync_modal_focus()
	_refresh()
	_schedule_bot()

func _build_home() -> void:
	home = Home.new()
	safe_root.add_child(home)
	home.destination.connect(_home_destination)
	resume_button = home.primary
	resume_status = home.status

func _home_destination(destination: String) -> void:
	match destination:
		"play":
			if game != null: _continue_table()
			elif _session_enabled() and FileAccess.file_exists("user://session.json"): _resume_session()
			else: _open_lobby()
		"new": _open_lobby()
		"training": _open_training()
		"history": _open_history()
		"settings": _open_settings()
		"help": _open_product("help")
		"academy": _open_product("academy")

func _open_home() -> void:
	bot_timer.stop()
	amount_input.apply()
	_save_session()
	coach.collapse()
	lobby.hide()
	home.show()
	_update_home()
	_sync_modal_focus()
	_refresh()

func _update_home() -> void:
	var detail = "%d 人桌 · 第 %d 手 · %s" % [player_count, game.hand_number, PHASES.get(game.phase, "准备中")] if game != null else ""
	home.update_session(game != null, _session_enabled() and FileAccess.file_exists("user://session.json"), detail)
	if training_store != null: home.update_learning(training_store.data)
	if not settings_status.is_empty(): home.status.text = settings_status
	if session_save_error: home.status.text = "当前牌桌保存失败，请检查存储空间。"

func _continue_table() -> void:
	if game == null: return
	home.hide()
	_sync_modal_focus()
	_refresh()
	_schedule_bot()

func _return_text() -> String:
	return "返回选桌" if lobby.visible else "返回主界面" if home.visible else "返回牌桌"

func _build_lobby() -> void:
	lobby = ColorRect.new()
	lobby.color = Color("0b1920")
	lobby.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_root.add_child(lobby)
	lobby_panel = UI.panel(UI.PANEL, 22, 20)
	var inset = MarginContainer.new()
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: inset.add_theme_constant_override("margin_" + edge, 12)
	lobby.add_child(inset)
	inset.add_child(lobby_panel)
	var outer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 18)
	lobby_panel.add_child(outer)
	var head = _row(12)
	outer.add_child(head)
	cancel_button = UI.button("‹ 返回", _close_lobby)
	head.add_child(cancel_button)
	head.add_child(UI.label("新建牌桌", 28, UI.GOLD))
	lobby_scroll = TouchScroll.new()
	lobby_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(lobby_scroll)
	lobby_shell = VBoxContainer.new()
	lobby_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lobby_shell.add_theme_constant_override("separation", 18)
	lobby_scroll.add_child(lobby_shell)
	lobby_welcome = VBoxContainer.new()
	lobby_shell.add_child(lobby_welcome)
	lobby_welcome.add_child(UI.label("01   选择桌型", 22, UI.GOLD))
	lobby_welcome.add_child(UI.label("人数包含你和电脑对手", 17, UI.MUTED))
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	lobby_column = col
	lobby_shell.add_child(col)
	var presets = _row(12)
	col.add_child(presets)
	for count in [2, 6, 9]:
		var button = UI.button("%d 人桌" % count, _select_count.bind(count), UI.GREEN, 64)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		presets.add_child(button)
		preset_buttons[count] = button
	var custom = _row(16)
	col.add_child(custom)
	custom.add_child(UI.label("任意人数", 18, UI.MUTED))
	count_picker = OptionButton.new()
	for count in range(2, 10): count_picker.add_item("%d 人 · 你 + %d 个电脑" % [count, count - 1])
	count_picker.custom_minimum_size.y = 54
	count_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_picker.item_selected.connect(func(index): _select_count(index + 2))
	custom.add_child(count_picker)
	col.add_child(UI.label("02   初始筹码", 22, UI.GOLD))
	depth_picker = OptionButton.new()
	for bb in [50, 100, 200]: depth_picker.add_item("%d BB / 人" % bb)
	depth_picker.select([50, 100, 200].find(starting_bb))
	depth_picker.custom_minimum_size.y = 54
	depth_picker.item_selected.connect(func(_i): _update_table_summary())
	col.add_child(depth_picker)
	col.add_child(UI.label("03   电脑对手", 22, UI.GOLD))
	lobby_extras = VBoxContainer.new()
	col.add_child(lobby_extras)
	lobby_extras.add_child(UI.button("配置每位对手  ›", _open_opponents, Color("243a40"), 58))
	var hint = UI.label("每位电脑可单独设置难度和激进程度。
教练与外观在主界面的“设置”中调整。", 17, UI.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint)
	lobby_note = UI.label("", 17, UI.MUTED)
	lobby_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(lobby_note)
	lobby_buttons = VBoxContainer.new()
	outer.add_child(lobby_buttons)
	start_button = UI.button("开始对局", _commit_table, UI.GREEN, 64)
	lobby_buttons.add_child(start_button)
	_select_count(selected_count)
	lobby.hide()

func _update_table_summary() -> void:
	var depth = [50, 100, 200][depth_picker.selected]
	lobby_note.text = "%d 人桌 · 每人 %d BB · 盲注 5 / 10
%s" % [selected_count, depth, "现有牌桌将被替换，开始前需要确认。" if game != null or (_session_enabled() and FileAccess.file_exists("user://session.json")) else "虚拟筹码 · 无前注 · 无抽水"]

func _select_count(count: int) -> void:
	selected_count = clampi(count, 2, 9)
	count_picker.select(selected_count - 2)
	for key in preset_buttons:
		preset_buttons[key].add_theme_stylebox_override("normal", UI.surface(UI.GREEN if key == selected_count else Color("243a40"), 8, 12, UI.GOLD if key == selected_count else Color.TRANSPARENT))
	start_button.text = ("开始 %d 人桌" if game == null else "重开 %d 人桌") % selected_count
	_update_table_summary()

func _open_lobby() -> void:
	bot_timer.stop()
	amount_input.apply()
	_restore_background_focus()
	lobby.show()
	_block_background_focus(self)
	cancel_button.text = "‹ 主界面" if home.visible else "‹ 返回牌桌"
	lobby_scroll.reset_scroll()
	if game != null:
		selected_count = player_count
		depth_picker.select([50, 100, 200].find(starting_bb))
	_select_count(selected_count)
	start_button.grab_focus()
	if game != null: _refresh()

func _close_lobby() -> void:
	selected_count = player_count
	depth_picker.select([50, 100, 200].find(starting_bb))
	_restore_background_focus()
	lobby.hide()
	if home.visible: _update_home()
	_sync_modal_focus()
	_refresh()
	_schedule_bot()

func _commit_table() -> void:
	var count = selected_count
	var depth = [50, 100, 200][depth_picker.selected]
	if game != null or (_session_enabled() and FileAccess.file_exists("user://session.json")):
		_request_confirmation("重开 %d 人练习桌？" % count, "所有座位将重置为 %d BB。当前牌桌的进度会被替换，已完成的历史牌局会保留。" % depth, "重置并入座", _apply_new_table.bind(count, depth))
	else: _apply_new_table(count, depth)

func _apply_new_table(count: int, depth: int) -> void:
	starting_bb = depth
	_start_table(count)
	_save_preferences()

func _start_table(count: int) -> void:
	_cancel_ai()
	bot_timer.stop()
	_restore_background_focus()
	player_count = clampi(count, 2, 9)
	last_table_count = player_count
	selected_count = player_count
	paused = false
	lobby.hide()
	home.hide()
	session_id = "%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	ai_trace.clear()
	session_stamp = ""
	var stacks = []
	stacks.resize(player_count)
	stacks.fill(starting_bb * 10)
	coach.key = ""
	coach.collapse()
	game = Table.new(stacks)
	bots.clear()
	for id in range(1, player_count):
		var p = Profiles.resolve(opponent_profiles, id, difficulty)
		bots[id] = LocalBot.new(-1, p.aggression, p.difficulty)
		game.seats[id]["style"] = bots[id].style_name()
	_reset_ai_memory()
	_apply_ai_names()
	saved_hand = -1
	decision_key = ""
	_next_hand()

func _next_hand() -> void:
	if game == null or paused or _modal_open(): return
	if game.phase == "complete" and (game.seats[0].stack == 0 or game.seats.filter(func(s): return s.stack > 0).size() < 2):
		_request_confirmation("补码重开本桌？", "所有座位将恢复为 %d BB，重新开始 %d 人练习桌。已完成的历史牌局会保留。" % [starting_bb, player_count], "补码并重开", _apply_new_table.bind(player_count, starting_bb))
		return
	_cancel_ai()
	ai_dialogue.clear()
	ai_spoken.clear()
	ai_local_hand.clear()
	ai_error = ""
	var err = game.start_hand()
	if not err.is_empty():
		turn_label.text = err
		return
	opponent_changes = [{"event": 0, "profiles": Profiles.snapshot(opponent_profiles, player_count, difficulty)}]
	save_status = ""
	decision_key = ""
	_refresh()
	_schedule_bot()

func _human_action(action: String, amount: int = 0, confirmed: bool = false) -> void:
	if game == null or game.actor != 0 or paused or _modal_open(): return
	if action == "check_call": action = "check" if game.legal_actions(0).check else "call"
	var seat = game.seats[0]
	var commits_stack = action == "all_in" or (action == "raise" and amount == seat.street_bet + seat.stack) or (action == "call" and game.legal_actions(0).call_amount == seat.stack)
	if confirm_all_in and commits_stack and not confirmed:
		var stamp = _action_stamp()
		_request_confirmation("投入全部剩余筹码？", "本次将投入 %s，本轮总额为 %s。确认后不能撤回；可在设置中关闭全押确认。" % [_money(seat.stack), _money(seat.street_bet + seat.stack)], "确认全押", func():
			if stamp == _action_stamp(): _human_action(action, amount, true))
		return
	var decision_before = game.view_for(0)
	var err = game.act(0, action, amount)
	if not err.is_empty():
		turn_label.text = err
		return
	_refresh()
	if coach_after and live_teaching:
		review.open_live(decision_before, use_bb)
		review.title.text = "刚才的决策 · 行动后讲解"
		review.close_button.text = "继续对局"
		_sync_modal_focus()
		_refresh()
	else: _schedule_bot()

func _submit_raise() -> void:
	amount_input.apply()
	if bet_sheet.visible: bet_sheet.close()
	_human_action("raise", selected_raise)

func _schedule_bot() -> void:
	bot_timer.stop()
	if not smoke_mode and game != null and game.actor > 0 and not paused and not _modal_open() and not ai_client.busy and ai_error.is_empty():
		bot_timer.start(0.08 if game.seats[0].folded and fast_fold.button_pressed else SPEEDS[speed_index])

func _bot_step() -> void:
	if game == null or game.actor <= 0 or paused or _modal_open(): return
	if ai_seats[game.actor - 1].enabled and not ai_local_hand.has(game.actor):
		_request_ai()
		return
	var decision = bots.get(game.actor, bot).choose(game.view_for(game.actor))
	var err = game.act(game.actor, decision.action, decision.get("amount", 0))
	if not err.is_empty():
		turn_label.text = "电脑操作失败：" + err
		return
	_refresh()
	_schedule_bot()

func _toggle_pause() -> void:
	if _modal_open(): return
	paused = not paused
	if paused: _cancel_ai()
	bot_timer.stop()
	_refresh()
	_schedule_bot()

func _speed_changed(index: int) -> void:
	speed_index = index
	_save_preferences()
	_schedule_bot()

func _toggle_sidebar() -> void:
	_open_info("本手行动记录", explanation.text + "\n\n" + log_view.text)

func _unit_changed(index: int) -> void:
	# Commit any typed value in the OLD unit before switching display units.
	amount_input.apply()
	use_bb = index == 1
	review.set_units(use_bb)
	unit_picker.select(index)
	sheet_units.select(index)
	_refresh()
	_save_preferences()

func _quick_bb(bb_amount: float) -> void:
	if game == null or game.actor != 0: return
	var requested = roundi(bb_amount * game.big_blind)
	_set_target(Sizing.from_bb(bb_amount, game.big_blind, game.legal_actions(0)))
	if selected_raise != requested: amount_note.text += " · 已调整至合法范围"

func _quick_minimum() -> void:
	if game != null and game.actor == 0:
		_set_target(game.legal_actions(0).min_raise_to)

func _adjust_bb(delta: int) -> void:
	if game != null: _set_target(selected_raise + delta * game.big_blind)

func _block_background_focus(node: Node) -> void:
	# A mouse-blocking overlay alone does not trap Tab navigation. Keep background
	# controls out of the keyboard focus chain until this modal is dismissed.
	if node == _top_modal(): return
	if node is Control and not background_focus.has(node):
		background_focus[node] = node.focus_mode
		node.focus_mode = Control.FOCUS_NONE
	for child in node.get_children(): _block_background_focus(child)

func _restore_background_focus() -> void:
	for node in background_focus:
		if is_instance_valid(node): node.focus_mode = background_focus[node]
	background_focus.clear()

func _quick_pot(fraction: float) -> void:
	if game == null or game.actor != 0: return
	var view = game.view_for(0)
	var requested = view.current_bet + roundi((view.pot + view.legal.to_call) * fraction)
	_set_target(Sizing.from_pot(fraction, view))
	if selected_raise != requested: amount_note.text += " · 已调整至合法范围"

func _set_target(requested: int) -> void:
	if game == null or game.actor != 0: return
	var target = Sizing.clamp_target(requested, game.legal_actions(0))
	if target == 0: return
	selected_raise = target
	_sync_amount()
	if requested != target: amount_note.text += " · 已调整至合法范围"

func _amount_changed(value: float) -> void:
	if game == null or game.actor != 0: return
	_set_target(roundi(value * (game.big_blind if use_bb else 1)))

func _sync_amount() -> void:
	var legal = game.legal_actions(0)
	if legal.is_empty(): return
	var factor = float(game.big_blind if use_bb else 1)
	amount_input.set_block_signals(true)
	amount_input.step = 1.0 / factor
	amount_input.suffix = "BB" if use_bb else ""
	amount_input.min_value = mini(legal.min_raise_to, legal.max_raise_to) / factor
	amount_input.max_value = legal.max_raise_to / factor
	amount_input.value = selected_raise / factor
	# SpinBox defers its text refresh. Keep the editor synchronized immediately so
	# apply() during a rapid unit switch cannot reparse the previous displayed value.
	amount_input.get_line_edit().text = ("%.1f BB" % (selected_raise / factor)) if use_bb else str(selected_raise)
	amount_input.set_block_signals(false)
	amount_slider.set_block_signals(true)
	amount_slider.min_value = mini(legal.min_raise_to, legal.max_raise_to)
	amount_slider.max_value = legal.max_raise_to
	amount_slider.step = 1
	amount_slider.value = selected_raise
	amount_slider.set_block_signals(false)
	raise_button.text = ("下注 " if game.current_bet == 0 else "加注到 ") + _money(selected_raise)
	amount_note.text = "本次再投入 " + _money(maxi(0, selected_raise - game.seats[0].street_bet))
	if not legal.raise:
		amount_note.text = "当前不可加注；请跟注、过牌或弃牌。"
		raise_button.text = "不可加注"
	elif legal.max_raise_to < legal.min_raise_to: amount_note.text = "筹码不足最小加注，仅可全押到 " + _money(legal.max_raise_to)

func _refresh() -> void:
	if game == null: return
	if paused or _modal_open(): _cancel_ai()
	var view = game.view_for(0)
	var done = view.phase == "complete"
	if feedback_player != null: feedback_player.sync(game, session_id, paused or _modal_open() or smoke_mode)
	header.text = "%d 人桌 · 第 %d 手" % [player_count, view.hand]
	header.tooltip_text = "ID " + History.hand_id(game.record_state())
	pause_button.text = "继续" if paused else "暂停"
	table_view.update_table(view, use_bb, paused or _modal_open())
	table_view.sync_speech(ai_dialogue)
	if done:
		_save_record()
		turn_label.text = "你 · " + table_view.Outcome.net_text(view, 0, use_bb) + " · " + ("摊牌结束" if view.result.showdown else "本手结束")
		if save_status.contains("失败"): turn_label.text += "\n" + save_status
	elif paused or _modal_open(): turn_label.text = "牌局已暂停"
	elif view.seats[0].folded: turn_label.text = "你已弃牌 · 正在观看其余玩家" + ("（快进）" if fast_fold.button_pressed else "")
	else: turn_label.text = "轮到你行动" if view.actor == 0 else "%s 准备行动…" % view.seats[view.actor].name
	_update_ai_bar()
	if ai_client != null and ai_client.busy: turn_label.text = game.seats[game.actor].name + " · 在线思考中…"
	_update_controls(view)
	coach.sync(view, use_bb, live_teaching and (not coach_after or done), not paused and not _modal_open())
	_update_explanation(view)
	_update_log(view)
	_save_session()
	if session_save_error: turn_label.text += " · 当前进度保存失败，请检查存储空间"
	if settings_status != "": turn_label.text += " · " + settings_status

func _update_controls(view: Dictionary) -> void:
	var legal = view.legal
	var active = not legal.is_empty() and not paused and (not _modal_open() or _top_modal() == bet_sheet)
	advice_button.disabled = not active or _modal_open()
	advice_button.hide()
	advice_button.tooltip_text = "根据当时信息分析，返回后自己选择行动" if live_teaching else "打开教学设置"
	var done = view.phase == "complete"
	fold_button.disabled = not active
	call_button.disabled = not active
	raise_button.disabled = not active or not legal.get("raise", false)
	all_in_button.disabled = not active or not legal.get("all_in", false)
	bet_open_button.disabled = raise_button.disabled
	amount_input.editable = not raise_button.disabled
	amount_slider.editable = not raise_button.disabled
	minus_button.disabled = raise_button.disabled
	plus_button.disabled = raise_button.disabled
	for button in quick_buttons: button.disabled = raise_button.disabled
	next_button.visible = done
	review_hand_button.visible = done
	review_hand_button.disabled = _modal_open()
	next_button.disabled = paused or _modal_open()
	next_button.text = "补码重开本桌" if game.seats[0].stack == 0 or game.seats.filter(func(s): return s.stack > 0).size() < 2 else "下一手 · 保留筹码"
	for button in [fold_button, call_button, raise_button, all_in_button]: button.visible = not done
	sizing_row.visible = not done
	quick_row.visible = not done
	amount_note.visible = not done
	if portrait:
		sizing_row.visible = true
		quick_row.visible = true
		amount_note.visible = true
		bet_open_button.visible = not done
	if not legal.is_empty():
		call_button.text = "过牌" if legal.check else ("跟注\n" if portrait else "跟注 ") + _money(legal.call_amount)
		if legal.call and legal.call_amount == view.seats[0].stack: call_button.text = ("跟注全押\n" if portrait else "跟注全押 ") + _money(legal.call_amount)
		all_in_button.text = "全押 " + _money(view.seats[0].stack)
		var key = "%d:%s:%d:%d" % [view.hand, view.phase, view.current_bet, view.seats[0].stack]
		if key != decision_key:
			selected_raise = Sizing.clamp_target(legal.min_raise_to, legal)
			decision_key = key
		_sync_amount()
		for i in range(quick_buttons.size()):
			quick_buttons[i].visible = i == 0 or (i in [1, 2, 3] if view.board.is_empty() else i in [5, 6, 7])
	else:
		amount_note.text = "等待当前玩家行动 · 快捷按钮仅填入金额，点击加注后才提交"

func _update_explanation(view: Dictionary) -> void:
	if not live_teaching:
		explanation.text = "对局教学已关闭 · 下方保留公开行动记录。"
		return
	if view.phase == "complete":
		explanation.text = "每人选出最佳五张，逐个结算主池和边池。同牌力平分，多出的零头按庄家左侧顺序分配。\n可向下查看各玩家牌型与分池结果。" if view.result.showdown else "只剩一位玩家未弃牌，无需摊牌即可赢得底池。无人跟注的多余投入已退回。"
	elif view.actor == 0:
		var legal = view.legal
		explanation.text = "可以免费过牌。" if legal.check else "需要跟注 %s。" % _money(legal.call_amount)
		explanation.text += "\nBB 是大盲：本桌 1 BB = 10 筹码。快捷档位只选金额，不会自动下注。\n底池比例：先计入跟注，再按比例加注；不足最小加注会自动调整。"
	else:
		explanation.text = "电脑按座位顺序独立行动，不共享底牌。金色边框标出当前行动者。\n翻牌前由大盲后第一个玩家行动；翻牌后从庄家左侧开始。\n可切换速度，或暂停后查看记录。"

func _update_log(view: Dictionary) -> void:
	var lines = ["牌局 ID  " + History.hand_id(game.record_state())]
	for event in view.events: lines.append(_event_text(event))
	if view.phase == "complete" and view.result.showdown:
		for id in view.result.ranks:
			var rank = view.result.ranks[id]
			lines.append("%s：%s\n最佳五张 %s" % [view.seats[id].name, rank.name, _cards_text(rank.cards)])
		for index in range(view.result.pots.size()):
			var pot = view.result.pots[index]
			var shares = []
			for id in pot.shares: shares.append("%s +%s" % [view.seats[id].name, _money(pot.shares[id])])
			lines.append("%s %s：%s" % ["主池" if index == 0 else "边池 %d" % index, _money(pot.amount), "，".join(shares)])
	log_view.text = "\n\n".join(lines)

func _save_record() -> void:
	_finish_ai_hand()
	if saved_hand == game.hand_number: return
	if smoke_mode:
		save_status = "测试模式"
		saved_hand = game.hand_number
		return
	var record = game.completed_record()
	record["seat_names"] = game.seats.map(func(s): return s.name)
	record["ai_dialogue"] = ai_dialogue.duplicate(true)
	record["online_seats"] = ai_seats.slice(0, player_count - 1).map(func(p): return p.enabled)
	record["id"] = History.hand_id(record)
	record["difficulty"] = difficulty
	record["bot_version"] = LocalBot.VERSION
	record["opponents"] = Profiles.snapshot(opponent_profiles, player_count, difficulty)
	record["opponent_changes"] = opponent_changes.duplicate(true)
	record["table_size"] = player_count
	record["saved_at"] = Time.get_datetime_string_from_system().replace("T", " ")
	if History.save(record, "%s-%04d.json" % [session_id, game.hand_number]) != OK:
		save_status = "保存失败 · 请检查存储空间；返回此页会重试"
		return
	saved_hand = game.hand_number
	save_status = "记录已保存"
	if training.store != null: training.store.suggest_hand(record)

func _event_text(event: Dictionary) -> String:
	var name_text = game.seats[event.seat].name if event.has("seat") else ""
	match event.kind:
		"start": return "第 %d 手 · %s 为庄家" % [event.hand, game.seats[event.button].name]
		"blind": return "%s 下盲注 %s" % [name_text, _money(event.amount)]
		"action":
			var text = name_text + " " + ACTIONS[event.action]
			if event.action == "raise": text += "到 " + _money(event.to)
			elif event.action == "call": text += " " + _money(event.paid)
			if event.all_in: text += "（全押）"
			return text
		"street": return "%s  %s" % [PHASES[event.phase], _cards_text(event.board)]
		"refund": return "%s 收回未被跟注的 %s" % [name_text, _money(event.amount)]
		"finish": return "摊牌结算" if event.showdown else "弃牌结束 · 分配底池"
	return ""

func _money(chips: int) -> String:
	return UI.money(chips, game.big_blind, use_bb)

func _cards_text(cards: Array) -> String:
	var words = []
	for card in cards: words.append(Eval.card_text(card))
	return " ".join(words)

func _row(separation: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	return row

func _add_quick(text: String, callback: Callable) -> void:
	var button = UI.button(text, callback, Color("20383e"), 56)
	button.add_theme_font_size_override("font_size", 16)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = "仅填入本轮下注总额；必要时调整到合法范围，之后点击加注确认。"
	quick_buttons.append(button)
	quick_row.add_child(button)

func _load_preferences() -> void:
	if smoke_mode or "--capture-test" in OS.get_cmdline_user_args(): return
	var prefs = Preferences.load_values("user://preferences.cfg", show_sidebar)
	sound_level = prefs.sound
	haptics_enabled = prefs.haptics
	performance_mode = prefs.performance
	selected_count = prefs.players
	last_table_count = selected_count
	starting_bb = prefs.depth
	use_bb = prefs.bb
	speed_index = prefs.speed
	fast_fold_enabled = prefs.fast_fold
	show_sidebar = prefs.sidebar
	felt_theme = prefs.felt
	four_color = prefs.four_color
	motion = prefs.motion
	confirm_all_in = prefs.confirm_all_in
	live_teaching = prefs.live_teaching
	review_teaching = prefs.review_teaching
	difficulty = prefs.difficulty
	opponent_profiles = prefs.opponents
	ai_profiles = prefs.ai_profiles
	ai_keys = AIVault.load_keys(ai_profiles)
	ai_key = str(ai_keys.get("default", ""))
	ai_live_coach = prefs.ai_live_coach
	ai_review_coach = prefs.ai_review_coach
	coach_service_id = prefs.coach_service_id
	ai_service = prefs.ai_service
	ai_seats = prefs.ai_seats
	coach_after = prefs.coach_after
	coach_auto = prefs.coach_auto
	coach_detail = prefs.coach_detail
	coach_side = prefs.coach_side

func _save_preferences() -> void:
	if smoke_mode or "--capture-test" in OS.get_cmdline_user_args(): return
	var values = _settings_values()
	values["players"] = last_table_count
	values["depth"] = starting_bb
	settings_status = "" if Preferences.save_values(values) == OK else "设置保存失败，请检查存储空间"
	if settings_status != "":
		if home.visible: home.status.text = settings_status
		elif lobby.visible: lobby_note.text += "\n" + settings_status
		else: turn_label.text += " · " + settings_status

func _system_back(now_ms: int = -1) -> void:
	# Notification may arrive before or after the BACK key event on Android 16.
	# Deduplicate notifications themselves instead of depending on key ordering.
	var now = Time.get_ticks_msec() if now_ms < 0 else now_ms
	if now - last_system_back_ms < 350: return
	last_system_back_ms = now
	_back()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		_back()
		get_viewport().set_input_as_handled()
		return
	if _modal_open():
		get_viewport().set_input_as_handled()
		return
	if get_viewport().gui_get_focus_owner() is LineEdit: return
	match event.keycode:
		KEY_F: _human_action("fold")
		KEY_SPACE: _human_action("check_call")
		KEY_R:
			if portrait: _open_bet()
			if amount_input.editable: amount_input.get_line_edit().grab_focus()
		KEY_P: _toggle_pause()
		_: return
	get_viewport().set_input_as_handled()

func _open_history() -> void:
	bot_timer.stop()
	amount_input.apply()
	_restore_background_focus()
	review.open_history(use_bb)
	review.close_button.text = _return_text()
	_block_background_focus(self)
	review.close_button.grab_focus()
	_refresh()

func _open_advice() -> void:
	if game == null: return
	if game.phase == "complete":
		_review_current_hand()
		return
	if game.actor != 0: return
	if coach_after:
		turn_label.text = "先行动，再看教练已开启；本次操作后会显示讲解。"
		return
	if not live_teaching:
		_open_settings()
		settings._select_page(3)
		return
	amount_input.apply()
	bot_timer.stop()
	_restore_background_focus()
	review.open_live(game.view_for(0), use_bb)
	review.close_button.text = "返回牌桌"
	_block_background_focus(self)
	_refresh()

func _open_help() -> void:
	_open_product("help")
	support_center.show_topic(1)

func _review_current_hand() -> void:
	if game == null or game.phase != "complete": return
	var current_record = game.completed_record()
	current_record["seat_names"] = game.seats.map(func(s): return s.name)
	current_record["ai_dialogue"] = ai_dialogue.duplicate(true)
	var rebuilt = History.replay(current_record)
	if rebuilt.has("error"):
		turn_label.text = rebuilt.error
		return
	_open_history()
	review.open_replay(rebuilt, use_bb)
	review.next_decision()
	review._select_portrait_tab(true)
	if review.teaching_enabled(): review._analyze()

func _close_review() -> void:
	if training_replay:
		training_replay = false
		training.show()
		_sync_modal_focus()
		return
	_sync_modal_focus()
	_refresh()
	_schedule_bot()

func _review_units_changed(bb: bool) -> void:
	_unit_changed(1 if bb else 0)
	unit_picker.select(1 if bb else 0)

func _session_enabled() -> bool:
	return not smoke_mode and DisplayServer.get_name() != "headless" and "--capture-test" not in OS.get_cmdline_user_args()

func _save_session() -> void:
	if not _session_enabled() or game == null or game.phase == "idle": return
	var stamp = "%s:%d:%d:%d" % [session_id, game.hand_number, game.events.size(), saved_hand]
	if stamp == session_stamp: return
	session_save_error = Session.save(game, session_id, starting_bb, saved_hand, "user://", Profiles.snapshot(opponent_profiles, player_count, difficulty), opponent_changes, opponent_profiles, difficulty, _ai_session_state()) != OK
	if not session_save_error: session_stamp = stamp

func _resume_session() -> void:
	var rebuilt = Session.restore()
	if rebuilt.has("error"):
		resume_status.text = "无法恢复：" + rebuilt.error + "。仍可新开练习桌或查看已完成的历史。"
		return
	bot_timer.stop()
	_restore_background_focus()
	game = rebuilt.game
	if rebuilt.record.get("opponent_settings") is Dictionary:
		opponent_profiles = rebuilt.record.opponent_settings.profiles
		difficulty = rebuilt.record.opponent_settings.difficulty
	elif rebuilt.record.get("opponents") is Array:
		for i in range(mini(game.seats.size() - 1, rebuilt.record.opponents.size())):
			opponent_profiles[i] = Profiles.normalize(rebuilt.record.opponents)[i]
	opponent_changes = rebuilt.record.get("opponent_changes", []).duplicate(true) if rebuilt.record.get("opponent_changes") is Array else []
	player_count = game.seats.size()
	last_table_count = player_count
	selected_count = player_count
	starting_bb = int(rebuilt.record.starting_bb)
	depth_picker.select([50, 100, 200].find(starting_bb))
	session_id = rebuilt.record.session_id
	saved_hand = int(rebuilt.record.saved_hand)
	save_status = "记录已保存" if saved_hand == game.hand_number else ""
	session_stamp = ""
	decision_key = ""
	bots.clear()
	for id in range(1, player_count):
		var p = Profiles.resolve(opponent_profiles, id, difficulty)
		bots[id] = LocalBot.new(-1, p.aggression, p.difficulty)
		game.seats[id]["style"] = bots[id].style_name()
	_restore_ai_state(rebuilt.record.get("ai_state", {}))
	_apply_ai_names()
	paused = true
	lobby.hide()
	home.hide()
	_refresh()
	_save_preferences()

func _notification(what: int) -> void:
	if not is_node_ready(): return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_ai()
		if review != null: review.ai_coach.stop()
		if training != null: training.ai_coach.stop()
		if settings != null:
			settings.ai_page.stop(false)
			settings._cancel_names()
			settings.arena_page.arena.pause()
		if training != null and training.visible and not smoke_mode: training.suspend()
		if review != null and review.visible: review._stop_play()
		if not smoke_mode and game != null and not paused:
			paused = true
			bot_timer.stop()
			if confirmation.visible: confirmation.cancel()
			if bet_sheet.visible: bet_sheet.close()
			_refresh()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_system_back()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_preferences()
		get_tree().quit()

func _top_modal() -> Control:
	for overlay in [confirmation, learning_center, support_center, settings, training, review, info_sheet, menu_sheet, bet_sheet, lobby, home]:
		if overlay != null and overlay.visible: return overlay
	return null

func _modal_open() -> bool:
	return _top_modal() != null

func _back() -> void:
	if confirmation.visible: confirmation.cancel()
	elif learning_center != null and learning_center.visible: learning_center.back_action()
	elif support_center != null and support_center.visible: support_center.back_action()
	elif settings.visible: settings.back_action()
	elif training.visible: training.back_action()
	elif review.visible: review.back_action()
	elif info_sheet.visible: info_sheet.close()
	elif menu_sheet.visible: menu_sheet.close()
	elif bet_sheet.visible: bet_sheet.close()
	elif coach.expanded: coach.collapse()
	elif lobby.visible: _close_lobby()
	elif home.visible: _request_confirmation("退出 Somnicard？", "当前牌桌与已完成的记录会保留在本机。", "退出", func(): _save_session(); get_tree().quit())
	else: _open_home()

func _sync_modal_focus() -> void:
	_restore_background_focus()
	if _modal_open():
		_block_background_focus(self)
		if confirmation.visible: confirmation.cancel_button.grab_focus()
		elif learning_center != null and learning_center.visible: learning_center.back_button.grab_focus()
		elif support_center != null and support_center.visible: support_center.back_button.grab_focus()
		elif settings.visible: settings.cancel_button.grab_focus()
		elif training.visible: training.close_button.grab_focus()
		elif review.visible: review.close_button.grab_focus()
		elif info_sheet.visible: info_sheet.close_button.grab_focus()
		elif menu_sheet.visible: menu_sheet.close_button.grab_focus()
		elif bet_sheet.visible: bet_sheet.close_button.grab_focus()
		elif lobby.visible: start_button.grab_focus()
		elif home.visible: home.primary.grab_focus()

func _settings_values() -> Dictionary:
	return {"sound": sound_level, "haptics": haptics_enabled, "performance": performance_mode, "bb": use_bb, "speed": speed_index, "fast_fold": fast_fold_enabled, "sidebar": show_sidebar,
		"felt": felt_theme, "four_color": four_color, "motion": motion, "confirm_all_in": confirm_all_in,
		"live_teaching": live_teaching, "review_teaching": review_teaching, "difficulty": difficulty, "opponents": opponent_profiles.duplicate(true),
		"coach_after": coach_after, "coach_auto": coach_auto, "coach_detail": coach_detail, "coach_side": coach_side,
		"ai_service": ai_service.duplicate(true), "ai_seats": ai_seats.duplicate(true), "ai_key": ai_key,
		"ai_profiles": AIServices.normalize(ai_profiles, ai_service), "ai_keys": ai_keys.duplicate(), "coach_service_id": coach_service_id,
		"ai_live_coach": ai_live_coach, "ai_review_coach": ai_review_coach}

func _open_settings() -> void:
	bot_timer.stop()
	amount_input.apply()
	_restore_background_focus()
	settings.player_count = selected_count if lobby.visible or game == null else player_count
	settings.ai_library = ai_store.companions
	settings.open(_settings_values())
	settings.context.text = "当前牌桌暂停中 · 保存后返回原来的位置" if game != null else "应用于本机的所有练习桌"
	_sync_modal_focus()
	_refresh()

func _apply_settings(values: Dictionary) -> void:
	if not _apply_ai_settings(values): return
	sound_level = int(values.get("sound", 1))
	haptics_enabled = bool(values.get("haptics", false))
	performance_mode = int(values.get("performance", 0))
	_apply_feedback_preferences()
	# Commit typed text in its original unit, then update presentation atomically.
	amount_input.apply()
	use_bb = values.bb
	speed_index = values.speed
	fast_fold_enabled = values.fast_fold
	show_sidebar = values.sidebar
	felt_theme = values.felt
	four_color = values.four_color
	motion = values.motion
	confirm_all_in = values.confirm_all_in
	live_teaching = values.get("live_teaching", true)
	review_teaching = values.get("review_teaching", true)
	difficulty = values.get("difficulty", 1)
	coach_after = values.get("coach_after", false)
	coach_auto = values.get("coach_auto", false)
	coach_detail = values.get("coach_detail", 0)
	coach_side = values.get("coach_side", 1)
	opponent_profiles = Profiles.normalize(values.get("opponents", opponent_profiles))
	for id in bots:
		var p = Profiles.resolve(opponent_profiles, id, difficulty)
		bots[id].difficulty = p.difficulty
		bots[id].style = p.aggression
		game.seats[id]["style"] = bots[id].style_name()
	_apply_ai_names()
	if game != null:
		var current_profiles = Profiles.snapshot(opponent_profiles, player_count, difficulty)
		if game.phase != "complete" and (opponent_changes.is_empty() or opponent_changes.back().get("profiles") != current_profiles):
			var change = {"event": game.events.size(), "profiles": current_profiles}
			if not opponent_changes.is_empty() and opponent_changes.back().get("event") == game.events.size(): opponent_changes[-1] = change
			else: opponent_changes.append(change)
		session_stamp = ""
		_save_session()
	coach.configure(_settings_values())
	review.set_teaching(live_teaching, review_teaching)
	review.ai_coach.configure(_settings_values())
	training.ai_coach.configure(_settings_values())
	unit_picker.select(1 if use_bb else 0)
	speed_picker.select(speed_index)
	fast_fold.button_pressed = fast_fold_enabled
	sidebar.hide()
	table_view.set_preferences(felt_theme, four_color, motion)
	review.table_view.set_preferences(felt_theme, four_color, motion)
	review.set_units(use_bb)
	_save_preferences()
	settings.ai_page.stop()
	settings.ai_page.key.text = ""
	settings.initial.erase("ai_key")
	settings.initial.erase("ai_keys")
	settings.ai_page.secrets.clear()
	settings.arena_page.secrets.clear()
	settings.arena_page.arena.pause()
	settings.hide()
	_close_settings()

func _close_settings() -> void:
	if home.visible: _update_home()
	_sync_modal_focus()
	_refresh()
	_schedule_bot()

func _teaching_changed(live: bool, enabled: bool) -> void:
	if live: live_teaching = enabled
	else: review_teaching = enabled
	_save_preferences()
	_refresh()

func _request_confirmation(heading: String, message: String, action_text: String, callback: Callable) -> void:
	bot_timer.stop()
	_restore_background_focus()
	confirmation_action = callback
	confirmation.open(heading, message, action_text)
	_sync_modal_focus()
	_refresh()

func _cancel_confirmation() -> void:
	confirmation_action = Callable()
	_sync_modal_focus()
	_refresh()
	_schedule_bot()

func _accept_confirmation() -> void:
	var callback = confirmation_action
	confirmation_action = Callable()
	_sync_modal_focus()
	if callback.is_valid(): callback.call()
	_refresh()
	_schedule_bot()

func _action_stamp() -> String:
	return "%s:%d:%d:%d" % [session_id, game.hand_number, game.events.size(), game.actor] if game != null else ""

func _smoke_test() -> void:
	_start_table(2)
	var steps = 0
	while game.phase != "complete" and steps < 100:
		if game.actor == 0: call_button.pressed.emit()
		else:
			var legal = game.legal_actions(game.actor)
			game.act(game.actor, "check" if legal.check else "call")
			_refresh()
		steps += 1
	if game.phase != "complete" or not game.result.showdown or game.chip_total() != starting_bb * 20:
		printerr("UI_SMOKE_FAILED")
		get_tree().quit(1)
		return
	next_button.pressed.emit()
	if game.hand_number != 2:
		get_tree().quit(1)
		return
	print("UI_SMOKE_OK: lobby, four streets, showdown, next hand")
	get_tree().quit()


func _update_scale() -> void:
	var window = get_window()
	var target = Vector2i(540, 960)
	if window.content_scale_size != target: window.content_scale_size = target

func _resize_ui() -> void:
	if not layout_ready: return
	# Resizing preserves the amount being edited and never submits it.
	if game != null and game.actor == 0: amount_input.apply()
	_update_scale()
	call_deferred("_arrange_ui")

func _arrange_ui() -> void:
	if not is_inside_tree(): return
	var previous_focus = get_viewport().gui_get_focus_owner()
	safe_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if OS.has_feature("mobile"):
		var safe = DisplayServer.get_display_safe_area()
		var pixels = Vector2(get_window().size)
		var scale_factor = size / pixels
		safe_root.offset_left = maxf(0, safe.position.x) * scale_factor.x
		safe_root.offset_top = maxf(0, safe.position.y) * scale_factor.y
		safe_root.offset_right = -maxf(0, pixels.x - safe.end.x) * scale_factor.x
		safe_root.offset_bottom = -maxf(0, pixels.y - safe.end.y) * scale_factor.y
	# One portrait surface on every platform. Wide/maximized desktop windows
	# add side gutters instead of changing the table or expanding its overlays.
	var available_width = safe_root.size.x
	var gutter = maxf(0, (available_width - 540) / 2)
	safe_root.offset_left += gutter
	safe_root.offset_right -= gutter
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 12)
	mark.hide()
	brand.hide()
	more_button.show()
	subhead.hide()
	_move(header, top, 0)
	advice_button.hide()
	_move(sizing_row, bet_sheet.content, 0)
	_move(amount_note, bet_sheet.content, 1)
	_move(quick_row, bet_sheet.content, 2)
	_move(amount_slider, bet_sheet.content, 3)
	_move(all_in_button, bet_sheet.footer, 0)
	_move(raise_button, bet_sheet.footer, 1)
	quick_row.columns = 4
	minus_button.hide()
	plus_button.hide()
	bet_open_button.visible = game == null or game.phase != "complete"
	for button in [fold_button, call_button, bet_open_button, raise_button, all_in_button]: button.custom_minimum_size.y = 72
	sidebar.hide()
	table_view.set_portrait(true)
	settings.set_portrait(true)
	confirmation.set_portrait(true)
	review.set_portrait(true)
	lobby_welcome.custom_minimum_size.x = 0
	for i in range(lobby_welcome.get_child_count()): lobby_welcome.get_child(i).visible = i in [0, 1]
	lobby_note.custom_minimum_size = Vector2(0, 60)
	if game != null: _refresh()
	_sync_modal_focus()
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree() and previous_focus.focus_mode != Control.FOCUS_NONE:
		previous_focus.grab_focus()

func _move(node: Node, parent: Node, index: int) -> void:
	if node.get_parent() != parent: node.reparent(parent)
	parent.move_child(node, mini(index, parent.get_child_count() - 1))

func _build_sheets() -> void:
	bet_sheet = Sheet.new()
	bet_sheet.preferred_height = 500
	safe_root.add_child(bet_sheet)
	bet_sheet.closed.connect(_close_sheet)
	sheet_units = OptionButton.new()
	sheet_units.add_item("筹码金额")
	sheet_units.add_item("大盲 BB")
	sheet_units.select(1 if use_bb else 0)
	sheet_units.custom_minimum_size.y = 48
	sheet_units.item_selected.connect(_unit_changed)
	bet_sheet.content.add_child(sheet_units)
	sheet_units.hide()
	var hint = UI.label("加到 = 本轮总投入；选择金额后点下方确认。", 16, UI.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bet_sheet.content.add_child(hint)
	menu_sheet = Sheet.new()
	safe_root.add_child(menu_sheet)
	menu_sheet.closed.connect(_close_sheet)
	for pair in [["牌桌设置", _open_settings], ["新建牌桌", _open_lobby], ["历史牌局与复盘", _open_history], ["训练室", _open_training], ["玩法帮助", _open_help], ["本手行动记录", _toggle_sidebar], ["返回主界面 · 保留牌桌", _open_home]]:
		menu_sheet.content.add_child(UI.button(pair[0], func(): menu_sheet.close(); pair[1].call(), Color("243a40"), 56))
	info_sheet = Sheet.new()
	info_sheet.touch_scroll = true
	safe_root.add_child(info_sheet)
	info_sheet.closed.connect(_close_sheet)
	info_text = RichTextLabel.new()
	info_text.fit_content = true
	info_text.add_theme_color_override("default_color", UI.TEXT)
	info_text.add_theme_font_size_override("normal_font_size", 22)
	info_sheet.content.add_child(info_text)
	# The sheet is reused for seat details and action records. Keep one action,
	# and update its target on each opening instead of accumulating callbacks.
	info_opponent_button = UI.button("配置这位对手", func():
		if info_sheet.visible and game != null and info_opponent_id > 0 and info_opponent_id < game.seats.size():
			_open_opponents(info_opponent_id), UI.GREEN)
	info_sheet.content.add_child(info_opponent_button)
	info_opponent_button.hide()
	ai_inspector = preload("res://scripts/ui/ai_inspector.gd").new()
	info_sheet.content.add_child(ai_inspector)
	ai_inspector.clear_requested.connect(func(): ai_trace.clear())
	ai_inspector.navigated.connect(func(detail):
		info_text.visible = not detail
		info_opponent_button.visible = not detail and info_opponent_id > 0
		info_sheet.scroll.reset_scroll())
	table_view.seat_selected.connect(_seat_details)
	# Confirmation remains above every sheet, including nested all-in prompts.
	safe_root.move_child(confirmation, -1)

func _open_bet() -> void:
	if game == null or paused or _modal_open() or not game.legal_actions(0).get("raise", false): return
	bot_timer.stop()
	bet_sheet.open("选择下注金额")
	sheet_units.select(1 if use_bb else 0)
	_sync_modal_focus()
	_refresh()

func _submit_all_in() -> void:
	if bet_sheet.visible: bet_sheet.close()
	_human_action("all_in")

func _open_menu() -> void:
	bot_timer.stop()
	menu_sheet.open("牌桌菜单")
	_sync_modal_focus()
	_refresh()

func _open_info(heading: String, message: String, opponent_id: int = -1) -> void:
	bot_timer.stop()
	info_text.text = message
	info_text.show()
	ai_inspector.hide()
	info_opponent_id = opponent_id
	info_opponent_button.visible = game != null and opponent_id > 0 and opponent_id < game.seats.size()
	info_sheet.open(heading)
	_sync_modal_focus()
	_refresh()

func _seat_details(id: int) -> void:
	if game == null or _modal_open() or id < 0 or id >= game.seats.size(): return
	var seat = game.view_for(0).seats[id]
	var model_note = ""
	if id > 0 and ai_seats[id - 1].enabled:
		var service = _seat_service(id)
		model_note = "\nAI 模型：" + service.model
	_open_info(seat.name + " · 座位详情", table_view.seat_nodes[id].panel.tooltip_text + model_note + "\n\n" + table_view.seat_nodes[id].status.text + "\n底牌：" + (_cards_text(seat.hole) if not seat.hole.is_empty() else "未公开"), id)
	if id > 0 and (ai_seats[id - 1].enabled or not ai_trace.for_seat(id).is_empty()):
		ai_inspector.open(ai_trace.for_seat(id), ai_dialogue, game.hand_number, game.phase == "complete", id)
		info_sheet.preferred_height = 880
		info_sheet._layout()
	else:
		info_sheet.preferred_height = 610
		info_sheet._layout()

func _close_sheet() -> void:
	if game != null and game.actor == 0: amount_input.apply()
	_sync_modal_focus()
	_refresh()
	_schedule_bot()

func _process(_delta: float) -> void:
	if coach != null and table_view != null and dock != null:
		coach.place(Rect2(table_view.global_position - safe_root.global_position, table_view.size), dock.global_position.y - safe_root.global_position.y, table_view.board_row.get_global_rect().end.y - safe_root.global_position.y)

func _open_training() -> void:
	bot_timer.stop()
	training_origin = {}
	training.use_bb = use_bb
	training.difficulty = difficulty
	training.opponent_profiles = opponent_profiles.duplicate(true)
	training.speed = SPEEDS[speed_index]
	training.table_view.set_preferences(felt_theme, four_color, motion)
	training.return_text = "‹ " + _return_text()
	training._select_hub_page(0)
	training.open_hub()
	_sync_modal_focus()
	_refresh()

func _practice_from_review(record: Dictionary, point: int) -> void:
	bot_timer.stop()
	training_origin = {"record": record.duplicate(true), "index": review.index}
	review.hide()
	training.use_bb = use_bb
	training.difficulty = difficulty
	training.opponent_profiles = opponent_profiles.duplicate(true)
	training.speed = SPEEDS[speed_index]
	training.table_view.set_preferences(felt_theme, four_color, motion)
	training.open_case(record, point)
	_sync_modal_focus()
	_refresh()

func _training_replay_requested(payload: Dictionary) -> void:
	var record: Dictionary = payload.get("record", payload)
	var rebuilt = History.replay(record)
	if rebuilt.has("error"):
		training.status.text = rebuilt.error
		return
	training.hide()
	training_replay = true
	if payload.has("original"):
		review.open_comparison([{"record": payload.original, "label": "原牌局"}, {"record": record, "label": "重打分支 · " + ("未知牌重采样" if payload.mode == "sampled" else "保留原牌")}], 1, use_bb)
	else: review.open_replay(rebuilt, use_bb)
	review.close_button.text = "返回训练"
	_sync_modal_focus()

func _close_training() -> void:
	if not training_origin.is_empty():
		var rebuilt = History.replay(training_origin.record)
		if not rebuilt.has("error"):
			review.open_replay(rebuilt, use_bb)
			review.seek(training_origin.index)
		training_origin = {}
	_sync_modal_focus()
	_refresh()
	_schedule_bot()

func _open_opponents(seat: int = 1) -> void:
	if info_sheet.visible: info_sheet.close()
	_open_settings()
	settings._select_page(4)
	settings.opponent_editor.select(seat)

func _seat_service(id: int) -> Dictionary:
	return AIServices.resolve(ai_profiles, ai_seats[id - 1].service_id, ai_service)

func _seat_key(id: int) -> String:
	var key_id = ai_seats[id - 1].service_id
	return str(ai_keys.get(key_id, ai_key if key_id == "default" else ""))
