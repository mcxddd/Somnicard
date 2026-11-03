extends Control
const UserPrefs = preload("res://scripts/app/user_prefs.gd")
var prefs = UserPrefs.new()
const ModalStack = preload("res://scripts/app/modal_stack.gd")
var modals = ModalStack.new()
const TableScreen = preload("res://scripts/ui/table_screen.gd")
var screen = TableScreen.new()
const TableStorage = preload("res://scripts/app/table_storage.gd")
var storage = TableStorage.new()
const BetControl = preload("res://scripts/app/bet_control.gd")
var bet = BetControl.new()
const Table = preload("res://scripts/poker/table.gd")
const Eval = preload("res://scripts/poker/evaluator.gd")
const Names = preload("res://scripts/poker/player_names.gd")
const Profiles = preload("res://scripts/poker/opponent_profiles.gd")
const LocalBot = preload("res://scripts/poker/local_bot.gd")
const UI = preload("res://scripts/ui/style.gd")
const History = preload("res://scripts/poker/history.gd")
const HistoryFilter = preload("res://scripts/poker/history_filter.gd")
const Review = preload("res://scripts/ui/review.gd")
const Session = preload("res://scripts/poker/session.gd")
const Settings = preload("res://scripts/ui/settings.gd")
const Confirmation = preload("res://scripts/ui/confirm.gd")
const Home = preload("res://scripts/ui/home.gd")
var home
const Onboarding = preload("res://scripts/ui/onboarding.gd")
var onboarding
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
var seat_names: Array = Names.normalize([])
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
	add_child(modals)
	add_child(screen)
	screen.host = self
	storage.host = self
	add_child(storage)
	bet.host = self
	add_child(bet)
	get_window().title = "Somnicard %s · 德州扑克练习" % ProjectSettings.get_setting("application/config/version")
	smoke_mode = "--smoke-test" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless"
	_clear_retired_data()
	var first_launch = not smoke_mode and "--capture-test" not in OS.get_cmdline_user_args() and Onboarding.needed(History.DIRECTORY)
	_update_scale()
	prefs.show_sidebar = not mobile_layout
	_load_preferences()
	_update_scale()
	_build_ui()
	modals.setup(self)
	layout_ready = true
	get_window().size_changed.connect(_resize_ui)
	resized.connect(_resize_ui)
	screen.arrange()
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	for page in [settings, review, training, learning_center, support_center, screen.lobby]:
		page.visibility_changed.connect(func(): UI.fade_in(page))
	_open_home()
	if first_launch:
		onboarding.open()
		modals.sync_focus()
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
	coach.settings_requested.connect(func(): _open_settings(); settings._select_page(2))
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
	review.table_view.set_preferences(prefs.felt_theme, prefs.four_color, prefs.motion and prefs.performance_mode == 0)
	training.case_page.table_view.set_preferences(prefs.felt_theme, prefs.four_color, prefs.motion and prefs.performance_mode == 0)
	review.analysis_view.set_teaching(prefs.live_teaching, prefs.review_teaching)
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
		training.hub.start_set(TrainingStore.topic_name(topic)))
	support_center = preload("res://scripts/ui/support_center.gd").new()
	screen.safe_root.add_child(support_center)
	onboarding = Onboarding.new()
	onboarding.z_index = 40
	screen.safe_root.add_child(onboarding)
	onboarding.finished.connect(func(): modals.sync_focus())
	support_center.closed.connect(_close_product)
	support_center.destination.connect(func(name):
		support_center.hide()
		if name == "academy": _open_product("academy")
		else:
			_open_settings()
			settings._select_page(4))
	confirmation.z_index = 30

func _apply_feedback_preferences() -> void:
	if feedback_player != null: feedback_player.configure({"sound": prefs.sound_level, "haptics": prefs.haptics_enabled})
	if not smoke_mode: Engine.max_fps = 30 if prefs.performance_mode == 1 else 60
	# Tests measure layout, so interface motion stays off in headless runs.
	UI.motion = prefs.motion and prefs.performance_mode == 0 and not smoke_mode and "--capture-test" not in OS.get_cmdline_user_args()

func _open_product(name: String) -> void:
	bot_timer.stop()
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
	home.update_recent(_recent_summary())
	if not settings_status.is_empty(): home.status.text = settings_status
	if storage.session_save_error: home.status.text = "当前牌桌保存失败，请检查存储空间。"

## The last 30 saved hands, training mastery and the run of active days, for the home card.
func _recent_summary() -> Dictionary:
	var out = {"hands": 0, "net_bb": 0.0, "vpip": 0.0, "mastery": -1.0, "streak": 0}
	var days = {}
	if storage.enabled():
		var vpip = 0
		for file in History.files().slice(0, 30):
			var item = HistoryFilter.summary(History.read_record(History.DIRECTORY.path_join(file)), file)
			if not item.valid_result: continue
			out.hands += 1
			out.net_bb += float(item.net) / item.big_blind
			vpip += int(item.vpip)
			if not item.day.is_empty(): days[item.day] = true
		if out.hands > 0: out.vpip = float(vpip) / out.hands
	if training_store != null:
		var kept = 0
		var scored = 0
		for topic in training_store.mastery().values():
			kept += topic.kept
			scored += topic.scored
		if scored > 0: out.mastery = float(kept) / scored
		for attempt in training_store.data.get("attempts", []): days[str(attempt.get("date", "")).left(10)] = true
	# Count back from today; a streak still stands if the last active day was yesterday.
	var day = Time.get_unix_time_from_system() + Time.get_time_zone_from_system().bias * 60
	if not days.has(Time.get_date_string_from_unix_time(int(day))): day -= 86400
	while days.has(Time.get_date_string_from_unix_time(int(day))):
		out.streak += 1
		day -= 86400
	return out

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
	var levels = {}
	for id in range(1, selected_count):
		var level = Profiles.LEVELS[Profiles.resolve(opponent_profiles, id, difficulty).difficulty]
		levels[level] = levels.get(level, 0) + 1
	var mix = "、".join(levels.keys().map(func(k): return "%s × %d" % [k, levels[k]]))
	screen.lobby_note.text = "%d 人桌 · 每人 %d BB · 盲注 5 / 10 · 对手 %s
%s" % [selected_count, depth, mix, "现有牌桌将被替换，开始前需要确认。" if game != null or (storage.enabled() and FileAccess.file_exists("user://session.json")) else "虚拟筹码 · 无前注 · 无抽水"]

func _select_count(count: int) -> void:
	selected_count = clampi(count, 2, Table.MAX_SEATS)
	screen.count_picker.select(selected_count - 2)
	screen.update_lobby_opponents(selected_count)
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
	bot_timer.stop()
	modals.restore_background()
	player_count = clampi(count, 2, Table.MAX_SEATS)
	last_table_count = player_count
	selected_count = player_count
	paused = false
	screen.lobby.hide()
	home.hide()
	storage.session_id = "%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
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
	_apply_names()
	storage.saved_hand = -1
	bet.decision_key = ""
	_next_hand()

func _next_hand() -> void:
	if game == null or paused or modals.is_open(): return
	if game.phase == "complete" and (game.seats[0].stack == 0 or game.seats.filter(func(s): return s.stack > 0).size() < 2):
		_request_confirmation("补码重开本桌？", "所有座位将恢复为 %d BB，重新开始 %d 人练习桌。已完成的历史牌局会保留。" % [starting_bb, player_count], "补码并重开", _apply_new_table.bind(player_count, starting_bb))
		return
	var err = game.start_hand()
	if not err.is_empty():
		screen.turn_label.text = err
		return
	opponent_changes = [{"event": 0, "profiles": Profiles.snapshot(opponent_profiles, player_count, difficulty)}]
	storage.save_status = ""
	bet.decision_key = ""
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
	_human_action("raise", bet.selected_raise)

func _schedule_bot() -> void:
	bot_timer.stop()
	if not smoke_mode and game != null and game.actor > 0 and not paused and not modals.is_open():
		bot_timer.start(0.08 if game.seats[0].folded and screen.fast_fold.button_pressed else SPEEDS[prefs.speed_index])

func _bot_step() -> void:
	if game == null or game.actor <= 0 or paused or modals.is_open(): return
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

func _refresh() -> void:
	if game == null: return
	var view = game.view_for(0)
	var done = view.phase == "complete"
	if feedback_player != null: feedback_player.sync(game, storage.session_id, paused or modals.is_open() or smoke_mode)
	screen.header.text = "%d 人桌 · 第 %d 手" % [player_count, view.hand]
	screen.header.tooltip_text = "ID " + History.hand_id(game.record_state())
	screen.pause_button.text = "继续" if paused else "暂停"
	screen.pause_button.glyph = "play" if paused else "pause"
	screen.pause_button.tooltip_text = screen.pause_button.text
	screen.table_view.update_table(view, prefs.use_bb, paused or modals.is_open())
	if done:
		storage.save_record()
		var hand_name = view.result.ranks[0].name + " · " if view.result.showdown and view.result.ranks.has(0) else ""
		screen.turn_label.text = "你 · " + hand_name + screen.table_view.Outcome.net_text(view, 0, prefs.use_bb) + " · " + ("摊牌结束" if view.result.showdown else "本手结束")
		if storage.save_status.contains("失败"): screen.turn_label.text += "\n" + storage.save_status
	elif paused or modals.is_open(): screen.turn_label.text = "牌局已暂停"
	elif view.seats[0].folded: screen.turn_label.text = "你已弃牌 · 正在观看其余玩家" + ("（快进）" if screen.fast_fold.button_pressed else "")
	else: screen.turn_label.text = _last_action_text(view) + "轮到你行动" if view.actor == 0 else "%s 准备行动…" % view.seats[view.actor].name
	_update_controls(view)
	coach.sync(view, prefs.use_bb, prefs.live_teaching and (not prefs.coach_after or done), not paused and not modals.is_open())
	screen.update_explanation(view)
	screen.update_log(view)
	storage.save_session()
	if storage.session_save_error: screen.turn_label.text += " · 当前进度保存失败，请检查存储空间"
	if settings_status != "": screen.turn_label.text += " · " + settings_status

## "小夏 加注到 3 BB，" — the action you are answering, so the table needs no log.
func _last_action_text(view: Dictionary) -> String:
	for i in range(view.events.size() - 1, -1, -1):
		var event = view.events[i]
		if event.kind == "street": return ""
		if event.kind == "action" and event.seat != 0: return screen._event_text(event) + "，"
	return ""

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
		# Show the cheapest legal raise so the player knows the price before opening sizing.
		var verb = "下注" if view.current_bet == 0 else "加注"
		if not legal.get("raise", false): screen.bet_open_button.text = verb
		elif legal.max_raise_to < legal.min_raise_to: screen.bet_open_button.text = "全押\n" + _money(legal.max_raise_to)
		else: screen.bet_open_button.text = verb + ("\n最少 " if view.current_bet == 0 else "\n最少到 ") + _money(legal.min_raise_to)
		bet.sync(view)
		for i in range(screen.quick_buttons.size()):
			screen.quick_buttons[i].visible = i in [0, 2, 3, 4] if view.board.is_empty() else i >= 5
	else:
		screen.amount_note.text = "等待当前玩家行动 · 快捷按钮仅填入金额，点击加注后才提交"

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
	seat_names = saved.seat_names

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

func _input(event: InputEvent) -> void:
	# Keyboard and gamepad navigation show the focus ring; pointer input hides it.
	if event is InputEventKey or event is InputEventJoypadButton: UI.show_focus(true)
	elif event is InputEventMouseButton or event is InputEventScreenTouch: UI.show_focus(false)

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
		settings._select_page(2)
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
	var rebuilt = History.replay(current_record)
	if rebuilt.has("error"):
		screen.turn_label.text = rebuilt.error
		return
	_open_history()
	review.open_replay(rebuilt, prefs.use_bb)
	review.next_decision()
	review._select_portrait_tab(true)
	if review.analysis_view.teaching_enabled(): review.analysis_view._analyze()

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
	for id in range(1, game.seats.size()): seat_names[id - 1] = game.seats[id].name
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
	bet.decision_key = ""
	bots.clear()
	for id in range(1, player_count):
		var p = Profiles.resolve(opponent_profiles, id, difficulty)
		bots[id] = LocalBot.new(-1, p.aggression, p.difficulty)
		game.seats[id]["style"] = bots[id].style_name()
	_apply_names()
	paused = true
	screen.lobby.hide()
	home.hide()
	_refresh()
	_save_preferences()

func _notification(what: int) -> void:
	if not is_node_ready(): return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
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
	values.merge({"difficulty": difficulty, "opponents": opponent_profiles.duplicate(true), "seat_names": seat_names.duplicate()})
	return values

func _open_settings() -> void:
	bot_timer.stop()
	screen.amount_input.apply()
	modals.restore_background()
	settings.player_count = selected_count if screen.lobby.visible or game == null else player_count
	settings.open(_settings_values())
	settings.context.text = "当前牌桌暂停中 · 保存后返回原来的位置" if game != null else "应用于本机的所有练习桌"
	modals.sync_focus()
	_refresh()

func _apply_settings(values: Dictionary) -> void:
	# Commit typed text in its original unit, then update presentation atomically.
	screen.amount_input.apply()
	prefs.assign(values)
	_apply_feedback_preferences()
	difficulty = values.get("difficulty", 1)
	opponent_profiles = Profiles.normalize(values.get("opponents", opponent_profiles))
	seat_names = Names.normalize(values.get("seat_names", seat_names))
	for id in bots:
		var p = Profiles.resolve(opponent_profiles, id, difficulty)
		bots[id].difficulty = p.difficulty
		bots[id].style = p.aggression
		game.seats[id]["style"] = bots[id].style_name()
	_apply_names()
	if game != null:
		var current_profiles = Profiles.snapshot(opponent_profiles, player_count, difficulty)
		if game.phase != "complete" and (opponent_changes.is_empty() or opponent_changes.back().get("profiles") != current_profiles):
			var change = {"event": game.events.size(), "profiles": current_profiles}
			if not opponent_changes.is_empty() and opponent_changes.back().get("event") == game.events.size(): opponent_changes[-1] = change
			else: opponent_changes.append(change)
		storage.session_stamp = ""
		storage.save_session()
	coach.configure(_settings_values())
	review.analysis_view.set_teaching(prefs.live_teaching, prefs.review_teaching)
	screen.unit_picker.select(1 if prefs.use_bb else 0)
	screen.speed_picker.select(prefs.speed_index)
	screen.fast_fold.button_pressed = prefs.fast_fold_enabled
	screen.sidebar.hide()
	screen.table_view.set_preferences(prefs.felt_theme, prefs.four_color, prefs.motion and prefs.performance_mode == 0)
	review.table_view.set_preferences(prefs.felt_theme, prefs.four_color, prefs.motion and prefs.performance_mode == 0)
	training.case_page.table_view.set_preferences(prefs.felt_theme, prefs.four_color, prefs.motion and prefs.performance_mode == 0)
	review.set_units(prefs.use_bb)
	_save_preferences()
	_resize_ui()
	settings.hide()
	_close_settings()

func _close_settings() -> void:
	if home.visible: _update_home()
	if screen.lobby.visible: screen.update_lobby_opponents(selected_count)
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
	# A smaller logical surface draws everything larger on the same screen.
	var target = [Vector2i(590, 1049), Vector2i(540, 960), Vector2i(510, 907)][clampi(prefs.text_size, 0, 2)]
	if window.content_scale_size != target: window.content_scale_size = target

func _resize_ui() -> void:
	if not layout_ready: return
	# Resizing preserves the amount being edited and never submits it.
	if game != null and game.actor == 0: screen.amount_input.apply()
	_update_scale()
	screen.call_deferred("arrange")

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
	info_opponent_id = opponent_id
	screen.info_opponent_button.visible = game != null and opponent_id > 0 and opponent_id < game.seats.size()
	screen.info_sheet.open(heading)
	modals.sync_focus()
	_refresh()

func _seat_details(id: int) -> void:
	if game == null or modals.is_open() or id < 0 or id >= game.seats.size(): return
	var seat = game.view_for(0).seats[id]
	var bio = Names.BIOS[id - 1] + "\n\n" if id > 0 else ""
	_open_info(seat.name + " · 座位详情", bio + screen.table_view.seat_nodes[id].panel.tooltip_text + "\n\n" + screen.table_view.seat_nodes[id].status.text + "\n底牌：" + (_cards_text(seat.hole) if not seat.hole.is_empty() else "未公开"), id)
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
	training.case_page.table_view.set_preferences(prefs.felt_theme, prefs.four_color, prefs.motion and prefs.performance_mode == 0)
	training.return_text = "‹ " + _return_text()
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
	training.case_page.table_view.set_preferences(prefs.felt_theme, prefs.four_color, prefs.motion and prefs.performance_mode == 0)
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
		review.analysis_view.open_comparison([{"record": payload.original, "label": "原牌局"}, {"record": record, "label": "重打分支 · " + ("未知牌重采样" if payload.mode == "sampled" else "保留原牌")}], 1, prefs.use_bb)
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
	settings._select_page(3)
	settings.opponent_editor.select(seat)

func _apply_names() -> void:
	if game == null: return
	for id in range(1, game.seats.size()):
		game.seats[id].name = seat_names[id - 1]
		game.seats[id]["style"] = bots[id].style_name()

func _clear_retired_data() -> void:
	if smoke_mode or "--capture-test" in OS.get_cmdline_user_args(): return
	for path in ["user://ai/companions.json", "user://ai/credentials.bin", "user://ai/arena.json"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
