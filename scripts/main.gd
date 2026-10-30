extends Control
const TableAI = preload("res://scripts/ai/table_ai.gd")
var ai = TableAI.new()
const UserPrefs = preload("res://scripts/app/user_prefs.gd")
var prefs = UserPrefs.new()
const ModalStack = preload("res://scripts/app/modal_stack.gd")
var modals = ModalStack.new()
const TableScreen = preload("res://scripts/ui/table_screen.gd")
var screen = TableScreen.new()
const TableStorage = preload("res://scripts/app/table_storage.gd")
var storage = TableStorage.new()
const AIConfig = preload("res://scripts/ai/config.gd")
const AIServices = preload("res://scripts/ai/services.gd")
const AIVault = preload("res://scripts/ai/vault.gd")
const Table = preload("res://scripts/poker/table.gd")
const Eval = preload("res://scripts/poker/evaluator.gd")
const Profiles = preload("res://scripts/poker/opponent_profiles.gd")
const LocalBot = preload("res://scripts/poker/local_bot.gd")
const UI = preload("res://scripts/ui/style.gd")
const Sizing = preload("res://scripts/ui/bet_sizing.gd")
const History = preload("res://scripts/poker/history.gd")
const Review = preload("res://scripts/ui/review.gd")
const Session = preload("res://scripts/poker/session.gd")
const Settings = preload("res://scripts/ui/settings.gd")
const Confirmation = preload("res://scripts/ui/confirm.gd")
const Home = preload("res://scripts/ui/home.gd")
var home
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
var selected_raise: int = 20
var decision_key: String = ""
var mobile_layout: bool = true
var review
var resume_button: Button
var resume_status: Label
var settings
var confirmation
var confirmation_action: Callable
var coach
var difficulty: int = 1
var opponent_profiles: Array = Profiles.normalize([])
var opponent_changes: Array = []
var last_table_count: int = 2
var settings_status: String = ""
const portrait: bool = true
var info_opponent_id: int = -1
var layout_ready: bool = false
var learning_center
var support_center
var feedback_player

func _ready() -> void:
	ai.host = self
	add_child(ai)
	add_child(modals)
	add_child(screen)
	screen.host = self
	storage.host = self
	add_child(storage)
	get_window().title = "Somnicard %s · 德州扑克练习" % ProjectSettings.get_setting("application/config/version", "1.4.1")
	smoke_mode = "--smoke-test" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless"
	_update_scale()
	prefs.show_sidebar = not mobile_layout
	_load_preferences()
	_build_ui()
	modals.setup(self)
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

func _build_ui() -> void:
	theme = UI.make_theme(mobile_layout)
	screen.build_table()
	bot_timer = Timer.new()
	bot_timer.one_shot = true
	bot_timer.timeout.connect(_bot_step)
	add_child(bot_timer)
	coach = Coach.new()
	screen.safe_root.add_child(coach)
	coach.settings_requested.connect(func(): _open_settings(); settings._select_page(3))
	coach.details_requested.connect(_open_advice)
	coach.review_requested.connect(_review_current_hand)
	coach.configure(_settings_values())
	_build_home()
	screen.build_lobby()
	training_store = TrainingStore.new("user://training/profile.json" if storage.enabled() else "")
	review = Review.new()
	screen.safe_root.add_child(review)
	review.training_store = training_store
	review.practice_requested.connect(_practice_from_review)
	review.closed.connect(_close_review)
	training = Training.new()
	screen.safe_root.add_child(training)
	training.store = training_store
	training.closed.connect(_close_training)
	training.replay_requested.connect(_training_replay_requested)
	review.units_changed.connect(_review_units_changed)
	review.table_view.set_preferences(prefs.felt_theme, prefs.four_color, prefs.motion)
	review.set_teaching(prefs.live_teaching, prefs.review_teaching)
	review.ai_coach.configure(_settings_values())
	training.ai_coach.configure(_settings_values())
	review.teaching_changed.connect(_teaching_changed)
	settings = Settings.new()
	screen.safe_root.add_child(settings)
	settings.data_page.store = training_store
	settings.applied.connect(_apply_settings)
	settings.cancelled.connect(_close_settings)
	confirmation = Confirmation.new()
	screen.safe_root.add_child(confirmation)
	confirmation.accepted.connect(_accept_confirmation)
	confirmation.cancelled.connect(_cancel_confirmation)
	screen.build_sheets()
	ai.build()
	_build_product()

func _build_product() -> void:
	feedback_player = preload("res://scripts/ui/game_feedback.gd").new()
	add_child(feedback_player)
	_apply_feedback_preferences()
	learning_center = preload("res://scripts/ui/learning_center.gd").new()
	screen.safe_root.add_child(learning_center)
	learning_center.store = training_store
	learning_center.closed.connect(_close_product)
	learning_center.practice_requested.connect(func(topic):
		learning_center.hide()
		_open_training()
		var selected_topic = "面对下注" if topic in ["跟注犹豫", "诈唬判断"] else topic
		for i in range(training.topic_picker.item_count):
			if training.topic_picker.get_item_text(i) == selected_topic: training.topic_picker.select(i))
	support_center = preload("res://scripts/ui/support_center.gd").new()
	screen.safe_root.add_child(support_center)
	support_center.closed.connect(_close_product)
	support_center.destination.connect(func(name):
		support_center.hide()
		if name == "academy": _open_product("academy")
		else:
			_open_settings()
			settings._select_page(6 if name == "ai" else 5))
	confirmation.z_index = 30

func _apply_feedback_preferences() -> void:
	if feedback_player != null: feedback_player.configure({"sound": prefs.sound_level, "haptics": prefs.haptics_enabled})
	if not smoke_mode: Engine.max_fps = 30 if prefs.performance_mode == 1 else 60

func _open_product(name: String) -> void:
	bot_timer.stop()
	ai.cancel()
	screen.amount_input.apply()
	coach.collapse()
	modals.restore_background()
	if name == "academy": learning_center.open()
	else: support_center.open()
	modals.sync_focus()
	_refresh()

func _close_product() -> void:
	_update_home()
	modals.sync_focus()
	_refresh()
	_schedule_bot()

func _build_home() -> void:
	home = Home.new()
	screen.safe_root.add_child(home)
	home.destination.connect(_home_destination)
	resume_button = home.primary
	resume_status = home.status

func _home_destination(destination: String) -> void:
	match destination:
		"play":
			if game != null: _continue_table()
			elif storage.enabled() and FileAccess.file_exists("user://session.json"): _resume_session()
			else: _open_lobby()
		"new": _open_lobby()
		"training": _open_training()
		"history": _open_history()
		"settings": _open_settings()
		"help": _open_product("help")
		"academy": _open_product("academy")

func _open_home() -> void:
	bot_timer.stop()
	screen.amount_input.apply()
	storage.save_session()
	coach.collapse()
	screen.lobby.hide()
	home.show()
	_update_home()
	modals.sync_focus()
	_refresh()

func _update_home() -> void:
	var detail = "%d 人桌 · 第 %d 手 · %s" % [player_count, game.hand_number, PHASES.get(game.phase, "准备中")] if game != null else ""
	home.update_session(game != null, storage.enabled() and FileAccess.file_exists("user://session.json"), detail)
	if training_store != null: home.update_learning(training_store.data)
	if not settings_status.is_empty(): home.status.text = settings_status
	if storage.session_save_error: home.status.text = "当前牌桌保存失败，请检查存储空间。"

func _continue_table() -> void:
	if game == null: return
	home.hide()
	modals.sync_focus()
	_refresh()
	_schedule_bot()

func _return_text() -> String:
	return "返回选桌" if screen.lobby.visible else "返回主界面" if home.visible else "返回牌桌"

func _update_table_summary() -> void:
	var depth = [50, 100, 200][screen.depth_picker.selected]
	screen.lobby_note.text = "%d 人桌 · 每人 %d BB · 盲注 5 / 10
%s" % [selected_count, depth, "现有牌桌将被替换，开始前需要确认。" if game != null or (storage.enabled() and FileAccess.file_exists("user://session.json")) else "虚拟筹码 · 无前注 · 无抽水"]

func _select_count(count: int) -> void:
	selected_count = clampi(count, 2, 9)
	screen.count_picker.select(selected_count - 2)
	for key in screen.preset_buttons:
		screen.preset_buttons[key].add_theme_stylebox_override("normal", UI.surface(UI.GREEN if key == selected_count else Color("243a40"), 8, 12, UI.GOLD if key == selected_count else Color.TRANSPARENT))
	screen.start_button.text = ("开始 %d 人桌" if game == null else "重开 %d 人桌") % selected_count
	_update_table_summary()

func _open_lobby() -> void:
	bot_timer.stop()
	screen.amount_input.apply()
	modals.restore_background()
	screen.lobby.show()
	modals.block_background(self)
	screen.cancel_button.text = "‹ 主界面" if home.visible else "‹ 返回牌桌"
	screen.lobby_scroll.reset_scroll()
	if game != null:
		selected_count = player_count
		screen.depth_picker.select([50, 100, 200].find(starting_bb))
	_select_count(selected_count)
	screen.start_button.grab_focus()
	if game != null: _refresh()

func _close_lobby() -> void:
	selected_count = player_count
	screen.depth_picker.select([50, 100, 200].find(starting_bb))
	modals.restore_background()
	screen.lobby.hide()
	if home.visible: _update_home()
	modals.sync_focus()
	_refresh()
	_schedule_bot()

func _commit_table() -> void:
	var count = selected_count
	var depth = [50, 100, 200][screen.depth_picker.selected]
	if game != null or (storage.enabled() and FileAccess.file_exists("user://session.json")):
		_request_confirmation("重开 %d 人练习桌？" % count, "所有座位将重置为 %d BB。当前牌桌的进度会被替换，已完成的历史牌局会保留。" % depth, "重置并入座", _apply_new_table.bind(count, depth))
	else: _apply_new_table(count, depth)

func _apply_new_table(count: int, depth: int) -> void:
	starting_bb = depth
	_start_table(count)
	_save_preferences()

func _start_table(count: int) -> void:
	ai.cancel()
	bot_timer.stop()
	modals.restore_background()
	player_count = clampi(count, 2, 9)
	last_table_count = player_count
	selected_count = player_count
	paused = false
	screen.lobby.hide()
	home.hide()
	storage.session_id = "%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	ai.trace.clear()
	storage.session_stamp = ""
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
	ai.reset_memory()
	ai.apply_names()
	storage.saved_hand = -1
	decision_key = ""
	_next_hand()

func _next_hand() -> void:
	if game == null or paused or modals.is_open(): return
	if game.phase == "complete" and (game.seats[0].stack == 0 or game.seats.filter(func(s): return s.stack > 0).size() < 2):
		_request_confirmation("补码重开本桌？", "所有座位将恢复为 %d BB，重新开始 %d 人练习桌。已完成的历史牌局会保留。" % [starting_bb, player_count], "补码并重开", _apply_new_table.bind(player_count, starting_bb))
		return
	ai.cancel()
	ai.dialogue.clear()
	ai.spoken.clear()
	ai.local_hand.clear()
	ai.error = ""
	var err = game.start_hand()
	if not err.is_empty():
		screen.turn_label.text = err
		return
	opponent_changes = [{"event": 0, "profiles": Profiles.snapshot(opponent_profiles, player_count, difficulty)}]
	storage.save_status = ""
	decision_key = ""
	_refresh()
	_schedule_bot()

func _human_action(action: String, amount: int = 0, confirmed: bool = false) -> void:
	if game == null or game.actor != 0 or paused or modals.is_open(): return
	if action == "check_call": action = "check" if game.legal_actions(0).check else "call"
	var seat = game.seats[0]
	var commits_stack = action == "all_in" or (action == "raise" and amount == seat.street_bet + seat.stack) or (action == "call" and game.legal_actions(0).call_amount == seat.stack)
	if prefs.confirm_all_in and commits_stack and not confirmed:
		var stamp = _action_stamp()
		_request_confirmation("投入全部剩余筹码？", "本次将投入 %s，本轮总额为 %s。确认后不能撤回；可在设置中关闭全押确认。" % [_money(seat.stack), _money(seat.street_bet + seat.stack)], "确认全押", func():
			if stamp == _action_stamp(): _human_action(action, amount, true))
		return
	var decision_before = game.view_for(0)
	var err = game.act(0, action, amount)
	if not err.is_empty():
		screen.turn_label.text = err
		return
	_refresh()
	if prefs.coach_after and prefs.live_teaching:
		review.open_live(decision_before, prefs.use_bb)
		review.title.text = "刚才的决策 · 行动后讲解"
		review.close_button.text = "继续对局"
		modals.sync_focus()
		_refresh()
	else: _schedule_bot()

func _submit_raise() -> void:
	screen.amount_input.apply()
	if screen.bet_sheet.visible: screen.bet_sheet.close()
	_human_action("raise", selected_raise)

func _schedule_bot() -> void:
	bot_timer.stop()
	if not smoke_mode and game != null and game.actor > 0 and not paused and not modals.is_open() and not ai.client.busy and ai.error.is_empty():
		bot_timer.start(0.08 if game.seats[0].folded and screen.fast_fold.button_pressed else SPEEDS[prefs.speed_index])

func _bot_step() -> void:
	if game == null or game.actor <= 0 or paused or modals.is_open(): return
	if ai.seats[game.actor - 1].enabled and not ai.local_hand.has(game.actor):
		ai.request()
		return
	var decision = bots.get(game.actor, bot).choose(game.view_for(game.actor))
	var err = game.act(game.actor, decision.action, decision.get("amount", 0))
	if not err.is_empty():
		screen.turn_label.text = "电脑操作失败：" + err
		return
	_refresh()
	_schedule_bot()

func _toggle_pause() -> void:
	if modals.is_open(): return
	paused = not paused
	if paused: ai.cancel()
	bot_timer.stop()
	_refresh()
	_schedule_bot()

func _speed_changed(index: int) -> void:
	prefs.speed_index = index
	_save_preferences()
	_schedule_bot()

func _toggle_sidebar() -> void:
	_open_info("本手行动记录", screen.explanation.text + "\n\n" + screen.log_view.text)

func _unit_changed(index: int) -> void:
	# Commit any typed value in the OLD unit before switching display units.
	screen.amount_input.apply()
	prefs.use_bb = index == 1
	review.set_units(prefs.use_bb)
	screen.unit_picker.select(index)
	screen.sheet_units.select(index)
	_refresh()
	_save_preferences()

func _quick_bb(bb_amount: float) -> void:
	if game == null or game.actor != 0: return
	var requested = roundi(bb_amount * game.big_blind)
	_set_target(Sizing.from_bb(bb_amount, game.big_blind, game.legal_actions(0)))
	if selected_raise != requested: screen.amount_note.text += " · 已调整至合法范围"

func _quick_minimum() -> void:
	if game != null and game.actor == 0:
		_set_target(game.legal_actions(0).min_raise_to)

func _adjust_bb(delta: int) -> void:
	if game != null: _set_target(selected_raise + delta * game.big_blind)

func _quick_pot(fraction: float) -> void:
	if game == null or game.actor != 0: return
	var view = game.view_for(0)
	var requested = view.current_bet + roundi((view.pot + view.legal.to_call) * fraction)
	_set_target(Sizing.from_pot(fraction, view))
	if selected_raise != requested: screen.amount_note.text += " · 已调整至合法范围"

func _set_target(requested: int) -> void:
	if game == null or game.actor != 0: return
	var target = Sizing.clamp_target(requested, game.legal_actions(0))
	if target == 0: return
	selected_raise = target
	_sync_amount()
	if requested != target: screen.amount_note.text += " · 已调整至合法范围"

func _amount_changed(value: float) -> void:
	if game == null or game.actor != 0: return
	_set_target(roundi(value * (game.big_blind if prefs.use_bb else 1)))

func _sync_amount() -> void:
	var legal = game.legal_actions(0)
	if legal.is_empty(): return
	var factor = float(game.big_blind if prefs.use_bb else 1)
	screen.amount_input.set_block_signals(true)
	screen.amount_input.step = 1.0 / factor
	screen.amount_input.suffix = "BB" if prefs.use_bb else ""
	screen.amount_input.min_value = mini(legal.min_raise_to, legal.max_raise_to) / factor
	screen.amount_input.max_value = legal.max_raise_to / factor
	screen.amount_input.value = selected_raise / factor
	# SpinBox defers its text refresh. Keep the editor synchronized immediately so
	# apply() during a rapid unit switch cannot reparse the previous displayed value.
	screen.amount_input.get_line_edit().text = ("%.1f BB" % (selected_raise / factor)) if prefs.use_bb else str(selected_raise)
	screen.amount_input.set_block_signals(false)
	screen.amount_slider.set_block_signals(true)
	screen.amount_slider.min_value = mini(legal.min_raise_to, legal.max_raise_to)
	screen.amount_slider.max_value = legal.max_raise_to
	screen.amount_slider.step = 1
	screen.amount_slider.value = selected_raise
	screen.amount_slider.set_block_signals(false)
	screen.raise_button.text = ("下注 " if game.current_bet == 0 else "加注到 ") + _money(selected_raise)
	screen.amount_note.text = "本次再投入 " + _money(maxi(0, selected_raise - game.seats[0].street_bet))
	if not legal.raise:
		screen.amount_note.text = "当前不可加注；请跟注、过牌或弃牌。"
		screen.raise_button.text = "不可加注"
	elif legal.max_raise_to < legal.min_raise_to: screen.amount_note.text = "筹码不足最小加注，仅可全押到 " + _money(legal.max_raise_to)

func _refresh() -> void:
	if game == null: return
	if paused or modals.is_open(): ai.cancel()
	var view = game.view_for(0)
	var done = view.phase == "complete"
	if feedback_player != null: feedback_player.sync(game, storage.session_id, paused or modals.is_open() or smoke_mode)
	screen.header.text = "%d 人桌 · 第 %d 手" % [player_count, view.hand]
	screen.header.tooltip_text = "ID " + History.hand_id(game.record_state())
	screen.pause_button.text = "继续" if paused else "暂停"
	screen.table_view.update_table(view, prefs.use_bb, paused or modals.is_open())
	screen.table_view.sync_speech(ai.dialogue)
	if done:
		storage.save_record()
		screen.turn_label.text = "你 · " + screen.table_view.Outcome.net_text(view, 0, prefs.use_bb) + " · " + ("摊牌结束" if view.result.showdown else "本手结束")
		if storage.save_status.contains("失败"): screen.turn_label.text += "\n" + storage.save_status
	elif paused or modals.is_open(): screen.turn_label.text = "牌局已暂停"
	elif view.seats[0].folded: screen.turn_label.text = "你已弃牌 · 正在观看其余玩家" + ("（快进）" if screen.fast_fold.button_pressed else "")
	else: screen.turn_label.text = "轮到你行动" if view.actor == 0 else "%s 准备行动…" % view.seats[view.actor].name
	ai.update_bar()
	if ai.client != null and ai.client.busy: screen.turn_label.text = game.seats[game.actor].name + " · 在线思考中…"
	_update_controls(view)
	coach.sync(view, prefs.use_bb, prefs.live_teaching and (not prefs.coach_after or done), not paused and not modals.is_open())
	_update_explanation(view)
	_update_log(view)
	storage.save_session()
	if storage.session_save_error: screen.turn_label.text += " · 当前进度保存失败，请检查存储空间"
	if settings_status != "": screen.turn_label.text += " · " + settings_status

func _update_controls(view: Dictionary) -> void:
	var legal = view.legal
	var active = not legal.is_empty() and not paused and (not modals.is_open() or modals.top() == screen.bet_sheet)
	screen.advice_button.disabled = not active or modals.is_open()
	screen.advice_button.hide()
	screen.advice_button.tooltip_text = "根据当时信息分析，返回后自己选择行动" if prefs.live_teaching else "打开教学设置"
	var done = view.phase == "complete"
	screen.fold_button.disabled = not active
	screen.call_button.disabled = not active
	screen.raise_button.disabled = not active or not legal.get("raise", false)
	screen.all_in_button.disabled = not active or not legal.get("all_in", false)
	screen.bet_open_button.disabled = screen.raise_button.disabled
	screen.amount_input.editable = not screen.raise_button.disabled
	screen.amount_slider.editable = not screen.raise_button.disabled
	screen.minus_button.disabled = screen.raise_button.disabled
	screen.plus_button.disabled = screen.raise_button.disabled
	for button in screen.quick_buttons: button.disabled = screen.raise_button.disabled
	screen.next_button.visible = done
	screen.review_hand_button.visible = done
	screen.review_hand_button.disabled = modals.is_open()
	screen.next_button.disabled = paused or modals.is_open()
	screen.next_button.text = "补码重开本桌" if game.seats[0].stack == 0 or game.seats.filter(func(s): return s.stack > 0).size() < 2 else "下一手 · 保留筹码"
	for button in [screen.fold_button, screen.call_button, screen.raise_button, screen.all_in_button]: button.visible = not done
	screen.sizing_row.visible = not done
	screen.quick_row.visible = not done
	screen.amount_note.visible = not done
	if portrait:
		screen.sizing_row.visible = true
		screen.quick_row.visible = true
		screen.amount_note.visible = true
		screen.bet_open_button.visible = not done
	if not legal.is_empty():
		screen.call_button.text = "过牌" if legal.check else ("跟注\n" if portrait else "跟注 ") + _money(legal.call_amount)
		if legal.call and legal.call_amount == view.seats[0].stack: screen.call_button.text = ("跟注全押\n" if portrait else "跟注全押 ") + _money(legal.call_amount)
		screen.all_in_button.text = "全押 " + _money(view.seats[0].stack)
		var key = "%d:%s:%d:%d" % [view.hand, view.phase, view.current_bet, view.seats[0].stack]
		if key != decision_key:
			selected_raise = Sizing.clamp_target(legal.min_raise_to, legal)
			decision_key = key
		_sync_amount()
		for i in range(screen.quick_buttons.size()):
			screen.quick_buttons[i].visible = i == 0 or (i in [1, 2, 3] if view.board.is_empty() else i in [5, 6, 7])
	else:
		screen.amount_note.text = "等待当前玩家行动 · 快捷按钮仅填入金额，点击加注后才提交"

func _update_explanation(view: Dictionary) -> void:
	if not prefs.live_teaching:
		screen.explanation.text = "对局教学已关闭 · 下方保留公开行动记录。"
		return
	if view.phase == "complete":
		screen.explanation.text = "每人选出最佳五张，逐个结算主池和边池。同牌力平分，多出的零头按庄家左侧顺序分配。\n可向下查看各玩家牌型与分池结果。" if view.result.showdown else "只剩一位玩家未弃牌，无需摊牌即可赢得底池。无人跟注的多余投入已退回。"
	elif view.actor == 0:
		var legal = view.legal
		screen.explanation.text = "可以免费过牌。" if legal.check else "需要跟注 %s。" % _money(legal.call_amount)
		screen.explanation.text += "\nBB 是大盲：本桌 1 BB = 10 筹码。快捷档位只选金额，不会自动下注。\n底池比例：先计入跟注，再按比例加注；不足最小加注会自动调整。"
	else:
		screen.explanation.text = "电脑按座位顺序独立行动，不共享底牌。金色边框标出当前行动者。\n翻牌前由大盲后第一个玩家行动；翻牌后从庄家左侧开始。\n可切换速度，或暂停后查看记录。"

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
	screen.log_view.text = "\n\n".join(lines)

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
	return UI.money(chips, game.big_blind, prefs.use_bb)

func _cards_text(cards: Array) -> String:
	var words = []
	for card in cards: words.append(Eval.card_text(card))
	return " ".join(words)

func _load_preferences() -> void:
	if smoke_mode or "--capture-test" in OS.get_cmdline_user_args(): return
	var saved = Preferences.load_values("user://preferences.cfg", prefs.show_sidebar)
	prefs.load(saved)
	selected_count = saved.players
	last_table_count = selected_count
	starting_bb = saved.depth
	difficulty = saved.difficulty
	opponent_profiles = saved.opponents
	ai.profiles = saved.ai_profiles
	ai.keys = AIVault.load_keys(ai.profiles)
	ai.key = str(ai.keys.get("default", ""))
	ai.live_coach = saved.ai_live_coach
	ai.review_coach = saved.ai_review_coach
	ai.coach_service_id = saved.coach_service_id
	ai.service = saved.ai_service
	ai.seats = saved.ai_seats

func _save_preferences() -> void:
	if smoke_mode or "--capture-test" in OS.get_cmdline_user_args(): return
	var values = _settings_values()
	values["players"] = last_table_count
	values["depth"] = starting_bb
	settings_status = "" if Preferences.save_values(values) == OK else "设置保存失败，请检查存储空间"
	if settings_status != "":
		if home.visible: home.status.text = settings_status
		elif screen.lobby.visible: screen.lobby_note.text += "\n" + settings_status
		else: screen.turn_label.text += " · " + settings_status

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		modals.back()
		get_viewport().set_input_as_handled()
		return
	if modals.is_open():
		get_viewport().set_input_as_handled()
		return
	if get_viewport().gui_get_focus_owner() is LineEdit: return
	match event.keycode:
		KEY_F: _human_action("fold")
		KEY_SPACE: _human_action("check_call")
		KEY_R:
			if portrait: _open_bet()
			if screen.amount_input.editable: screen.amount_input.get_line_edit().grab_focus()
		KEY_P: _toggle_pause()
		_: return
	get_viewport().set_input_as_handled()

func _open_history() -> void:
	bot_timer.stop()
	screen.amount_input.apply()
	modals.restore_background()
	review.open_history(prefs.use_bb)
	review.close_button.text = _return_text()
	modals.block_background(self)
	review.close_button.grab_focus()
	_refresh()

func _open_advice() -> void:
	if game == null: return
	if game.phase == "complete":
		_review_current_hand()
		return
	if game.actor != 0: return
	if prefs.coach_after:
		screen.turn_label.text = "先行动，再看教练已开启；本次操作后会显示讲解。"
		return
	if not prefs.live_teaching:
		_open_settings()
		settings._select_page(3)
		return
	screen.amount_input.apply()
	bot_timer.stop()
	modals.restore_background()
	review.open_live(game.view_for(0), prefs.use_bb)
	review.close_button.text = "返回牌桌"
	modals.block_background(self)
	_refresh()

func _open_help() -> void:
	_open_product("help")
	support_center.show_topic(1)

func _review_current_hand() -> void:
	if game == null or game.phase != "complete": return
	var current_record = game.completed_record()
	current_record["seat_names"] = game.seats.map(func(s): return s.name)
	current_record["ai_dialogue"] = ai.dialogue.duplicate(true)
	var rebuilt = History.replay(current_record)
	if rebuilt.has("error"):
		screen.turn_label.text = rebuilt.error
		return
	_open_history()
	review.open_replay(rebuilt, prefs.use_bb)
	review.next_decision()
	review._select_portrait_tab(true)
	if review.teaching_enabled(): review._analyze()

func _close_review() -> void:
	if training_replay:
		training_replay = false
		training.show()
		modals.sync_focus()
		return
	modals.sync_focus()
	_refresh()
	_schedule_bot()

func _review_units_changed(bb: bool) -> void:
	_unit_changed(1 if bb else 0)
	screen.unit_picker.select(1 if bb else 0)

func _resume_session() -> void:
	var rebuilt = Session.restore()
	if rebuilt.has("error"):
		resume_status.text = "无法恢复：" + rebuilt.error + "。仍可新开练习桌或查看已完成的历史。"
		return
	bot_timer.stop()
	modals.restore_background()
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
	screen.depth_picker.select([50, 100, 200].find(starting_bb))
	storage.session_id = rebuilt.record.session_id
	storage.saved_hand = int(rebuilt.record.saved_hand)
	storage.save_status = "记录已保存" if storage.saved_hand == game.hand_number else ""
	storage.session_stamp = ""
	decision_key = ""
	bots.clear()
	for id in range(1, player_count):
		var p = Profiles.resolve(opponent_profiles, id, difficulty)
		bots[id] = LocalBot.new(-1, p.aggression, p.difficulty)
		game.seats[id]["style"] = bots[id].style_name()
	ai.restore_state(rebuilt.record.get("ai_state", {}))
	ai.apply_names()
	paused = true
	screen.lobby.hide()
	home.hide()
	_refresh()
	_save_preferences()

func _notification(what: int) -> void:
	if not is_node_ready(): return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		ai.cancel()
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
			if screen.bet_sheet.visible: screen.bet_sheet.close()
			_refresh()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		modals.system_back()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_preferences()
		get_tree().quit()

func _settings_values() -> Dictionary:
	var values = prefs.values()
	values.merge({"difficulty": difficulty, "opponents": opponent_profiles.duplicate(true),
		"ai_service": ai.service.duplicate(true), "ai_seats": ai.seats.duplicate(true), "ai_key": ai.key,
		"ai_profiles": AIServices.normalize(ai.profiles, ai.service), "ai_keys": ai.keys.duplicate(), "coach_service_id": ai.coach_service_id,
		"ai_live_coach": ai.live_coach, "ai_review_coach": ai.review_coach})
	return values

func _open_settings() -> void:
	bot_timer.stop()
	screen.amount_input.apply()
	modals.restore_background()
	settings.player_count = selected_count if screen.lobby.visible or game == null else player_count
	settings.ai_library = ai.store.companions
	settings.open(_settings_values())
	settings.context.text = "当前牌桌暂停中 · 保存后返回原来的位置" if game != null else "应用于本机的所有练习桌"
	modals.sync_focus()
	_refresh()

func _apply_settings(values: Dictionary) -> void:
	if not ai.apply_settings(values): return
	# Commit typed text in its original unit, then update presentation atomically.
	screen.amount_input.apply()
	prefs.assign(values)
	_apply_feedback_preferences()
	difficulty = values.get("difficulty", 1)
	opponent_profiles = Profiles.normalize(values.get("opponents", opponent_profiles))
	for id in bots:
		var p = Profiles.resolve(opponent_profiles, id, difficulty)
		bots[id].difficulty = p.difficulty
		bots[id].style = p.aggression
		game.seats[id]["style"] = bots[id].style_name()
	ai.apply_names()
	if game != null:
		var current_profiles = Profiles.snapshot(opponent_profiles, player_count, difficulty)
		if game.phase != "complete" and (opponent_changes.is_empty() or opponent_changes.back().get("profiles") != current_profiles):
			var change = {"event": game.events.size(), "profiles": current_profiles}
			if not opponent_changes.is_empty() and opponent_changes.back().get("event") == game.events.size(): opponent_changes[-1] = change
			else: opponent_changes.append(change)
		storage.session_stamp = ""
		storage.save_session()
	coach.configure(_settings_values())
	review.set_teaching(prefs.live_teaching, prefs.review_teaching)
	review.ai_coach.configure(_settings_values())
	training.ai_coach.configure(_settings_values())
	screen.unit_picker.select(1 if prefs.use_bb else 0)
	screen.speed_picker.select(prefs.speed_index)
	screen.fast_fold.button_pressed = prefs.fast_fold_enabled
	screen.sidebar.hide()
	screen.table_view.set_preferences(prefs.felt_theme, prefs.four_color, prefs.motion)
	review.table_view.set_preferences(prefs.felt_theme, prefs.four_color, prefs.motion)
	review.set_units(prefs.use_bb)
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
	modals.sync_focus()
	_refresh()
	_schedule_bot()

func _teaching_changed(live: bool, enabled: bool) -> void:
	if live: prefs.live_teaching = enabled
	else: prefs.review_teaching = enabled
	_save_preferences()
	_refresh()

func _request_confirmation(heading: String, message: String, action_text: String, callback: Callable) -> void:
	bot_timer.stop()
	modals.restore_background()
	confirmation_action = callback
	confirmation.open(heading, message, action_text)
	modals.sync_focus()
	_refresh()

func _cancel_confirmation() -> void:
	confirmation_action = Callable()
	modals.sync_focus()
	_refresh()
	_schedule_bot()

func _accept_confirmation() -> void:
	var callback = confirmation_action
	confirmation_action = Callable()
	modals.sync_focus()
	if callback.is_valid(): callback.call()
	_refresh()
	_schedule_bot()

func _action_stamp() -> String:
	return "%s:%d:%d:%d" % [storage.session_id, game.hand_number, game.events.size(), game.actor] if game != null else ""

func _smoke_test() -> void:
	_start_table(2)
	var steps = 0
	while game.phase != "complete" and steps < 100:
		if game.actor == 0: screen.call_button.pressed.emit()
		else:
			var legal = game.legal_actions(game.actor)
			game.act(game.actor, "check" if legal.check else "call")
			_refresh()
		steps += 1
	if game.phase != "complete" or not game.result.showdown or game.chip_total() != starting_bb * 20:
		printerr("UI_SMOKE_FAILED")
		get_tree().quit(1)
		return
	screen.next_button.pressed.emit()
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
	if game != null and game.actor == 0: screen.amount_input.apply()
	_update_scale()
	call_deferred("_arrange_ui")

func _arrange_ui() -> void:
	if not is_inside_tree(): return
	var previous_focus = get_viewport().gui_get_focus_owner()
	screen.safe_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if OS.has_feature("mobile"):
		var safe = DisplayServer.get_display_safe_area()
		var pixels = Vector2(get_window().size)
		var scale_factor = size / pixels
		screen.safe_root.offset_left = maxf(0, safe.position.x) * scale_factor.x
		screen.safe_root.offset_top = maxf(0, safe.position.y) * scale_factor.y
		screen.safe_root.offset_right = -maxf(0, pixels.x - safe.end.x) * scale_factor.x
		screen.safe_root.offset_bottom = -maxf(0, pixels.y - safe.end.y) * scale_factor.y
	# One portrait surface on every platform. Wide/maximized desktop windows
	# add side gutters instead of changing the table or expanding its overlays.
	var available_width = screen.safe_root.size.x
	var gutter = maxf(0, (available_width - 540) / 2)
	screen.safe_root.offset_left += gutter
	screen.safe_root.offset_right -= gutter
	for edge in ["left", "right", "top", "bottom"]: screen.margin.add_theme_constant_override("margin_" + edge, 12)
	screen.mark.hide()
	screen.brand.hide()
	screen.more_button.show()
	screen.subhead.hide()
	screen.move(screen.header, screen.top, 0)
	screen.advice_button.hide()
	screen.move(screen.sizing_row, screen.bet_sheet.content, 0)
	screen.move(screen.amount_note, screen.bet_sheet.content, 1)
	screen.move(screen.quick_row, screen.bet_sheet.content, 2)
	screen.move(screen.amount_slider, screen.bet_sheet.content, 3)
	screen.move(screen.all_in_button, screen.bet_sheet.footer, 0)
	screen.move(screen.raise_button, screen.bet_sheet.footer, 1)
	screen.quick_row.columns = 4
	screen.minus_button.hide()
	screen.plus_button.hide()
	screen.bet_open_button.visible = game == null or game.phase != "complete"
	for button in [screen.fold_button, screen.call_button, screen.bet_open_button, screen.raise_button, screen.all_in_button]: button.custom_minimum_size.y = 72
	screen.sidebar.hide()
	screen.table_view.set_portrait(true)
	settings.set_portrait(true)
	confirmation.set_portrait(true)
	review.set_portrait(true)
	screen.lobby_welcome.custom_minimum_size.x = 0
	for i in range(screen.lobby_welcome.get_child_count()): screen.lobby_welcome.get_child(i).visible = i in [0, 1]
	screen.lobby_note.custom_minimum_size = Vector2(0, 60)
	if game != null: _refresh()
	modals.sync_focus()
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree() and previous_focus.focus_mode != Control.FOCUS_NONE:
		previous_focus.grab_focus()

func _open_bet() -> void:
	if game == null or paused or modals.is_open() or not game.legal_actions(0).get("raise", false): return
	bot_timer.stop()
	screen.bet_sheet.open("选择下注金额")
	screen.sheet_units.select(1 if prefs.use_bb else 0)
	modals.sync_focus()
	_refresh()

func _submit_all_in() -> void:
	if screen.bet_sheet.visible: screen.bet_sheet.close()
	_human_action("all_in")

func _open_menu() -> void:
	bot_timer.stop()
	screen.menu_sheet.open("牌桌菜单")
	modals.sync_focus()
	_refresh()

func _open_info(heading: String, message: String, opponent_id: int = -1) -> void:
	bot_timer.stop()
	screen.info_text.text = message
	screen.info_text.show()
	screen.ai_inspector.hide()
	info_opponent_id = opponent_id
	screen.info_opponent_button.visible = game != null and opponent_id > 0 and opponent_id < game.seats.size()
	screen.info_sheet.open(heading)
	modals.sync_focus()
	_refresh()

func _seat_details(id: int) -> void:
	if game == null or modals.is_open() or id < 0 or id >= game.seats.size(): return
	var seat = game.view_for(0).seats[id]
	var model_note = ""
	if id > 0 and ai.seats[id - 1].enabled:
		var service = ai.seat_service(id)
		model_note = "\nAI 模型：" + service.model
	_open_info(seat.name + " · 座位详情", screen.table_view.seat_nodes[id].panel.tooltip_text + model_note + "\n\n" + screen.table_view.seat_nodes[id].status.text + "\n底牌：" + (_cards_text(seat.hole) if not seat.hole.is_empty() else "未公开"), id)
	if id > 0 and (ai.seats[id - 1].enabled or not ai.trace.for_seat(id).is_empty()):
		screen.ai_inspector.open(ai.trace.for_seat(id), ai.dialogue, game.hand_number, game.phase == "complete", id)
		screen.info_sheet.preferred_height = 880
		screen.info_sheet._layout()
	else:
		screen.info_sheet.preferred_height = 610
		screen.info_sheet._layout()

func _close_sheet() -> void:
	if game != null and game.actor == 0: screen.amount_input.apply()
	modals.sync_focus()
	_refresh()
	_schedule_bot()

func _process(_delta: float) -> void:
	if coach != null and screen.table_view != null and screen.dock != null:
		coach.place(Rect2(screen.table_view.global_position - screen.safe_root.global_position, screen.table_view.size), screen.dock.global_position.y - screen.safe_root.global_position.y, screen.table_view.board_row.get_global_rect().end.y - screen.safe_root.global_position.y)

func _open_training() -> void:
	bot_timer.stop()
	training_origin = {}
	training.use_bb = prefs.use_bb
	training.difficulty = difficulty
	training.opponent_profiles = opponent_profiles.duplicate(true)
	training.speed = SPEEDS[prefs.speed_index]
	training.table_view.set_preferences(prefs.felt_theme, prefs.four_color, prefs.motion)
	training.return_text = "‹ " + _return_text()
	training._select_hub_page(0)
	training.open_hub()
	modals.sync_focus()
	_refresh()

func _practice_from_review(record: Dictionary, point: int) -> void:
	bot_timer.stop()
	training_origin = {"record": record.duplicate(true), "index": review.index}
	review.hide()
	training.use_bb = prefs.use_bb
	training.difficulty = difficulty
	training.opponent_profiles = opponent_profiles.duplicate(true)
	training.speed = SPEEDS[prefs.speed_index]
	training.table_view.set_preferences(prefs.felt_theme, prefs.four_color, prefs.motion)
	training.open_case(record, point)
	modals.sync_focus()
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
		review.open_comparison([{"record": payload.original, "label": "原牌局"}, {"record": record, "label": "重打分支 · " + ("未知牌重采样" if payload.mode == "sampled" else "保留原牌")}], 1, prefs.use_bb)
	else: review.open_replay(rebuilt, prefs.use_bb)
	review.close_button.text = "返回训练"
	modals.sync_focus()

func _close_training() -> void:
	if not training_origin.is_empty():
		var rebuilt = History.replay(training_origin.record)
		if not rebuilt.has("error"):
			review.open_replay(rebuilt, prefs.use_bb)
			review.seek(training_origin.index)
		training_origin = {}
	modals.sync_focus()
	_refresh()
	_schedule_bot()

func _open_opponents(seat: int = 1) -> void:
	if screen.info_sheet.visible: screen.info_sheet.close()
	_open_settings()
	settings._select_page(4)
	settings.opponent_editor.select(seat)
