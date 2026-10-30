extends SceneTree
## Capture the actual rendered launch scene for local layout inspection.

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var instance = scene.instantiate()
	root.add_child(instance)
	instance.bot_timer.stop()
	instance.smoke_mode = true
	var target = "preflop"
	var players = 2
	var capture_lobby = "--home" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-state="):
			target = arg.trim_prefix("--capture-state=")
		if arg.begins_with("--players="): players = int(arg.trim_prefix("--players="))
		if arg == "--lobby": capture_lobby = true
	instance._select_count(players)
	if not capture_lobby: instance._start_table(players)
	elif "--home" not in OS.get_cmdline_user_args(): instance._open_lobby()
	var steps = 0
	while not capture_lobby and instance.game.phase != target and instance.game.phase != "complete" and steps < 100:
		var legal = instance.game.legal_actions(instance.game.actor)
		instance.game.act(instance.game.actor, "check" if legal.check else "call")
		steps += 1
	while not capture_lobby and instance.game.actor > 0 and steps < 200:
		var legal = instance.game.legal_actions(instance.game.actor)
		instance.game.act(instance.game.actor, "check" if legal.check else "call")
		steps += 1
	if not capture_lobby: instance._refresh()
	if "--home-active" in OS.get_cmdline_user_args():
		instance._start_table(players)
		instance._open_home()
	if "--chips" in OS.get_cmdline_user_args(): instance._unit_changed(0)
	if "--history" in OS.get_cmdline_user_args(): instance._open_history()
	if "--history-demo" in OS.get_cmdline_user_args():
		instance.review.history_directory = "res://.local/capture-hands"
		for i in range(12):
			var count: int = [2, 6, 9][i % 3]
			var stacks: Array = []
			for seat in range(count): stacks.append(1000)
			var sample = instance.Table.new(stacks, 5, 10, 114 + i)
			sample.hand_number = i
			sample.start_hand(0)
			while sample.phase != "complete":
				var legal = sample.legal_actions(sample.actor)
				if sample.actor == 0 and i % 4 == 0 and legal.all_in: sample.act(0, "all_in")
				else: sample.act(sample.actor, "check" if legal.check else "call")
			var record = sample.completed_record()
			record.saved_at = Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system()) + int(Time.get_time_zone_from_system().bias) * 60 - i * 86400).replace("T", " ")
			instance.History.save(record, "%d.json" % (1900000000 - i), instance.review.history_directory)
		instance._open_history()
		while instance.review.scan_cursor >= 0: await process_frame
		instance.review.filter_panel.show()
	if "--help" in OS.get_cmdline_user_args(): instance._open_help()
	if "--product-help" in OS.get_cmdline_user_args(): instance._open_product("help")
	if "--academy" in OS.get_cmdline_user_args():
		instance._open_product("academy")
		if "--academy-question" in OS.get_cmdline_user_args(): instance.learning_center.start_lesson(2)
		if "--academy-answer" in OS.get_cmdline_user_args(): instance.learning_center.choose(1)
	if "--settings" in OS.get_cmdline_user_args():
		if "--opponents-demo" in OS.get_cmdline_user_args():
			var settings = instance._settings_values()
			for i in range(8): settings.opponents[i] = {"difficulty": i % 3, "aggression": int(i / 3)}
			instance._apply_settings(settings)
		instance._open_settings()
		if "--settings-index" not in OS.get_cmdline_user_args(): instance.settings._select_page(1)
		if "--teaching-settings" in OS.get_cmdline_user_args(): instance.settings._select_page(3)
		if "--opponents" in OS.get_cmdline_user_args():
			instance.settings._select_page(4)
			if "--ratings" in OS.get_cmdline_user_args():
				var editor = instance.settings.opponent_editor
				editor.get_child(editor.get_child_count() - 1).show()
				for frame in range(8): await process_frame
				instance.settings.scroll.reset_scroll(9999)
	if "--ai-demo" in OS.get_cmdline_user_args():
		for i in range(8): instance.ai_seats[i].enabled = true
		instance._apply_ai_names()
		instance.ai_dialogue = [{"seat": 1, "name": "小夏", "text": "这注我跟了，别急着收筹码。", "event": instance.game.events.size()}]
		instance._refresh()
		if "--ai-settings" in OS.get_cmdline_user_args():
			instance._open_settings()
			instance.settings._select_page(6)
		if "--ai-opponents" in OS.get_cmdline_user_args():
			instance._open_settings()
			instance.settings._select_page(4)
	if "--ai-presets" in OS.get_cmdline_user_args():
		instance._open_settings()
		instance.settings._select_page(6)
		instance.settings.ai_page._preset(1)
	if "--ai-catalog" in OS.get_cmdline_user_args():
		instance._open_settings()
		instance.settings._select_page(6)
		instance.settings.ai_page._preset(5)
		var catalog = preload("res://scripts/ai/catalog.gd").parse(JSON.parse_string(FileAccess.get_file_as_string("res://.local/commandcode-models.json")))
		instance.settings.ai_page._models_received(catalog)
		print("LIVE_CATALOG: ", catalog.models.size(), " selectable; ", catalog.skipped, " excluded")
	if "--ai-name-demo" in OS.get_cmdline_user_args():
		instance.ai_seats[0].enabled = true
		instance._open_settings()
		instance.settings._select_page(4)
		var editor = instance.settings.opponent_editor
		editor.offer_names(["深寻澜", "深海舟", "寻光者"], 1)
		editor.name_status.text = "选择一个昵称，或继续手动填写。保存设置后生效。"
		for frame in range(8): await process_frame
		instance.settings.scroll.reset_scroll(roundi(editor.name_edit.global_position.y - instance.settings.scroll.get_child(0).global_position.y - 30))
	if "--gto-facing" in OS.get_cmdline_user_args():
		instance._start_table(2)
		while instance.game.phase != "river":
			var legal = instance.game.legal_actions(instance.game.actor)
			instance.game.act(instance.game.actor, "check" if legal.check else "call")
		if instance.game.actor == 1: instance.game.act(1, "raise", 20)
		instance._refresh()
		instance._open_advice()
		while instance.review.job != null: await process_frame
		instance.review.expanded_details = true
		instance.review._render_details()
		for frame in range(8): await process_frame
		if "--gto-rows" in OS.get_cmdline_user_args(): instance.review.analysis_scroll.reset_scroll(roundi(instance.review.strategy_rows.global_position.y - instance.review.analysis_scroll.get_child(0).global_position.y))
	if "--midnight" in OS.get_cmdline_user_args():
		instance.table_view.set_preferences(1, true, false)
		instance.review.table_view.set_preferences(1, true, false)
	if "--confirm" in OS.get_cmdline_user_args(): instance._human_action("all_in")
	if "--bet" in OS.get_cmdline_user_args(): instance._open_bet()
	if "--menu" in OS.get_cmdline_user_args(): instance._open_menu()
	if "--seat" in OS.get_cmdline_user_args(): instance._seat_details(1)
	if "--seat-repeat" in OS.get_cmdline_user_args():
		for id in [2, 2, 5, 1, 2]:
			instance._seat_details(id)
			instance.info_opponent_button.pressed.emit()
			instance.settings.cancel()
		instance._seat_details(2)
	if "--coach" in OS.get_cmdline_user_args():
		instance.coach.expand()
		while instance.coach.job != null: await process_frame
	if "--teach" in OS.get_cmdline_user_args():
		instance._open_advice()
		while instance.review.job != null: await process_frame
		if "--ranges" in OS.get_cmdline_user_args():
			instance.review.expanded_details = true
			instance.review._render_details()
			instance.review.range_button.pressed.emit()
			await process_frame
			instance.review.analysis_scroll.scroll_vertical = roundi(instance.review.range_button.position.y)
	if "--review" in OS.get_cmdline_user_args():
		while instance.game.phase != "complete":
			var legal = instance.game.legal_actions(instance.game.actor)
			instance.game.act(instance.game.actor, "check" if legal.check else "call")
		instance._open_history()
		var rebuilt = instance.History.replay(instance.game.completed_record())
		instance.review.open_replay(rebuilt, true)
		instance.review._jump_street(1)
		instance.review.next_decision()
		instance.review._analyze()
		while instance.review.job != null: await process_frame
		if "--review-end" in OS.get_cmdline_user_args(): instance.review.seek(instance.review.frames.size() - 1)
		if "--review-chips" in OS.get_cmdline_user_args(): instance.review.set_units(false)
		if "--analysis" in OS.get_cmdline_user_args(): instance.review._select_portrait_tab(true)
		if "--detail" in OS.get_cmdline_user_args():
			instance.review.expanded_details = true
			instance.review._render_details()
	if "--training" in OS.get_cmdline_user_args():
		instance.training.history_directory = "res://.local/capture-hands"
		instance._open_training()
		while instance.training.scan_cursor >= 0: await process_frame
		if "--lesson" in OS.get_cmdline_user_args():
			instance.training.source_picker.select(4)
			if players == 9:
				var fixture = instance.training.Practice.fixtures()[2]
				instance.training.open_case(fixture, 0)
				if instance.training.game == null:
					var rebuilt = instance.History.replay(fixture)
					instance.training.open_case(fixture, instance.training.Practice.points(rebuilt)[0].point)
			else: instance.training.start_set()
			if "--lesson-flop" in OS.get_cmdline_user_args():
				var stacks: Array = []
				stacks.resize(players); stacks.fill(1000)
				var sample = instance.Table.new(stacks, 5, 10, 4311 + players)
				sample.start_hand(0)
				while sample.phase != "complete": sample.act(sample.actor, "check" if sample.legal_actions(sample.actor).check else "call")
				var record = sample.completed_record()
				var points = instance.training.Practice.points(instance.History.replay(record)).filter(func(p): return p.view.phase == "flop")
				instance.training.open_case(record, points[0].point)
				if "--all-wagers" in OS.get_cmdline_user_args() and "--capture-test" in OS.get_cmdline_user_args():
					var snapshot: Dictionary = instance.training.game.view_for(0)
					for seat in snapshot.seats: seat.street_bet = 125
					instance.training.table_view.update_table(snapshot, true)
			if "--answer" in OS.get_cmdline_user_args():
				instance.training.submit("check_call")
				while instance.training.job != null: await process_frame
			if "--branch" in OS.get_cmdline_user_args():
				instance.training.begin_branch()
				while instance.training.builder != null: await process_frame
	for frame in range(24):
		await process_frame
	if "--detail-body" in OS.get_cmdline_user_args():
		instance.review.analysis_scroll.reset_scroll(280)
		await process_frame
	if "--range-selected" in OS.get_cmdline_user_args():
		var review = instance.review
		review.expanded_details = true
		review._render_details()
		if not review.range_box.visible: review.range_button.pressed.emit()
		for frame in range(8): await process_frame
		review.analysis_scroll.reset_scroll(roundi(review.range_box.position.y + review.range_grid.position.y + 100))
		for frame in range(8): await process_frame
		var grid = review.range_grid
		var cell = grid.size / 13
		var row = clampi(int((review.analysis_scroll.get_global_rect().get_center().y - grid.global_position.y) / cell.y), 0, 12)
		var at = grid.global_position + cell * Vector2(3.5, row + 0.5)
		for down in [true, false]:
			var event = InputEventScreenTouch.new()
			event.position = at
			event.pressed = down
			root.push_input(event, true)
		for frame in range(8): await process_frame
	if "--training-stats" in OS.get_cmdline_user_args(): instance.training._select_hub_page(2)
	if "--data-settings" in OS.get_cmdline_user_args(): instance.settings._select_page(5)
	if "--ai-options" in OS.get_cmdline_user_args():
		var ai_page = instance.settings.ai_page
		instance.settings.scroll.reset_scroll(roundi(ai_page.model_picker.global_position.y - instance.settings.scroll.get_child(0).global_position.y - 36))
		for frame in range(8): await process_frame
	if "--ai-coach" in OS.get_cmdline_user_args():
		instance.ai_live_coach = true
		instance.review.ai_coach.configure(instance._settings_values())
		instance._open_advice()
		while instance.review.job != null: await process_frame
		if "--coach-answer-demo" in OS.get_cmdline_user_args() and "--capture-test" in OS.get_cmdline_user_args():
			var widget = instance.review.ai_coach
			widget.current_question = "为什么推荐这个操作？"
			widget.request_fingerprint = widget.fingerprint
			widget._received({"content": JSON.stringify({"action": widget.data.local_analysis.action, "reason": "对手当前的下注价格需要结合你的手牌和公开行动来判断。跟注保留了对手较弱的继续范围，贸然加注则可能只留下更强的牌。", "alternative": "如果后续出现明显更强的进攻，先重新评估跟注价格；不要因为已经投入筹码就一直跟到底。", "next": "观察对手后续下注的大小和公共牌变化，再重新判断。"})})
			widget.status.text = "测试用演示回复 · 未调用模型"
		for frame in range(8): await process_frame
		instance.review.analysis_scroll.reset_scroll(roundi(instance.review.ai_coach.global_position.y - instance.review.analysis_scroll.get_child(0).global_position.y - 6))
		for frame in range(8): await process_frame
	if "--arena" in OS.get_cmdline_user_args():
		instance._open_settings()
		instance.settings._select_page(7)
		if "--arena-evidence" in OS.get_cmdline_user_args(): instance.settings.arena_page.published.show()
		for frame in range(8): await process_frame
	if "--model-bank" in OS.get_cmdline_user_args():
		instance._open_settings()
		instance.settings._select_page(6)
		instance.settings.ai_page._preset(5)
		for frame in range(8): await process_frame
	if "--model-selector" in OS.get_cmdline_user_args():
		instance._open_settings()
		instance.settings._select_page(6)
		var page = instance.settings.ai_page
		page.models = []
		for i in range(90): page.models.append({"id": "provider/model-%03d-extended-context" % i, "name": "对话模型 %03d" % i, "api": "chat"})
		page._render_models()
		page._open_models()
		for frame in range(12): await process_frame
	if "--request-inspector" in OS.get_cmdline_user_args():
		var entry = {"id": "capture", "context": {"seat": 1, "hand": instance.game.hand_number, "phase": "flop", "event": 10, "purpose": "decision"}, "model": "demonstration-model", "url": "https://example.invalid/v1/chat/completions", "attempt": 2, "limit": 16384, "state": "complete", "finish_reason": "stop", "elapsed_ms": 1680, "http_status": 200, "usage": {"input_tokens": 1260, "output_tokens": 156, "reasoning_tokens": 128}, "request": {"model": "demonstration-model", "messages": [{"role": "user", "content": "演示请求记录，非真实服务调用"}]}, "response": '{"action":"call","amount":0}'}
		instance.ai_trace.append(entry)
		instance._seat_details(1)
		if "--request-detail" in OS.get_cmdline_user_args(): instance.ai_inspector._detail(entry)
		for frame in range(12): await process_frame
	if "--layout-metrics" in OS.get_cmdline_user_args():
		var ai_page = instance.settings.ai_page
		for pair in [["scroll", instance.settings.scroll], ["page", ai_page], ["hint", ai_page.provider_hint], ["models", ai_page.model_picker]]:
			print("LAYOUT ", pair[0], " ", pair[1].get_global_rect(), " min=", pair[1].get_combined_minimum_size())
	if target == "complete": await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.local")
	var file_name = "lobby" if capture_lobby else "%d-%s" % [players, target]
	if "--review" in OS.get_cmdline_user_args(): file_name += "-review" + ("-end" if "--review-end" in OS.get_cmdline_user_args() else "")
	if "--history" in OS.get_cmdline_user_args(): file_name = "history"
	if "--history-demo" in OS.get_cmdline_user_args(): file_name = "history-demo"
	if "--help" in OS.get_cmdline_user_args(): file_name = "help"
	if "--settings" in OS.get_cmdline_user_args(): file_name = "settings"
	if "--confirm" in OS.get_cmdline_user_args(): file_name = "confirm"
	if "--midnight" in OS.get_cmdline_user_args(): file_name += "-midnight"
	for flag in ["ai-coach", "arena", "model-bank", "gto-facing", "gto-rows", "ai-presets", "ai-catalog", "ai-options", "ai-name-demo", "ai-demo", "ai-settings", "ai-opponents", "home", "home-active", "settings-index", "data-settings", "training-stats", "bet", "menu", "seat", "seat-repeat", "analysis", "detail", "detail-body", "chips", "teach", "ranges", "range-selected", "teaching-settings", "opponents", "opponents-demo", "ratings", "coach", "training", "lesson", "answer", "branch"]:
		if "--" + flag in OS.get_cmdline_user_args(): file_name += "-" + flag
	if instance.portrait: file_name += "-portrait"
	var error := root.get_texture().get_image().save_png("res://.local/" + file_name + "-preview.png")
	quit(error)
