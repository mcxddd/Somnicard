extends SceneTree
const Bot = preload("res://scripts/poker/local_bot.gd")
const Table = preload("res://scripts/poker/table.gd")
const Profiles = preload("res://scripts/poker/opponent_profiles.gd")
const Preferences = preload("res://scripts/ui/preferences.gd")
const Session = preload("res://scripts/poker/session.gd")
const Practice = preload("res://scripts/poker/practice.gd")
var checks = 0
var failures = 0

func _initialize() -> void: call_deferred("run")
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)

func run() -> void:
	var bad = Profiles.normalize([{"difficulty": 3, "aggression": -1}, {"difficulty": 1.5, "aggression": "2"}, null])
	verify(bad == Profiles.normalize([]), "malformed profiles safely default")
	var timeline = {"opponent_changes": [{"event": 20, "profiles": [{"difficulty": 2, "aggression": 2}]}, {"event": 0, "profiles": [{"difficulty": 0, "aggression": 1}]}]}
	verify(Profiles.record_snapshot(timeline, 10)[0].difficulty == 0, "historical setup excludes future configuration")
	verify(Profiles.record_snapshot(timeline, 30)[0].difficulty == 2, "latest applicable setup independent of metadata ordering")
	var chosen = Profiles.normalize([{"difficulty": 2.0, "aggression": 2.0}])
	verify(Profiles.resolve(chosen, 1, 0) == {"difficulty": 2, "aggression": 2}, "JSON numeric values preserve custom profile")
	verify(Profiles.resolve(chosen, 8, 0).difficulty == 0, "unset seats inherit difficulty")
	var path = "user://opponent-prefs-test-%d.cfg" % Time.get_ticks_usec()
	var prefs = Preferences.DEFAULTS.duplicate()
	prefs.opponents = chosen
	verify(Preferences.save_values(prefs, path) == OK and Preferences.load_values(path).opponents == chosen, "all eight seats persist")
	DirAccess.remove_absolute(path)
	# All levels/styles, arbitrary table sizes, short unequal stacks: no illegal
	# amounts, omniscient reads, mutation, or money creation.
	for players in range(2, 7):
		for level in range(3):
			var stacks: Array = []
			for id in range(players): stacks.append([35, 70, 130, 270][id % 4])
			var game = Table.new(stacks, 5, 10, 42000 + players * 3 + level)
			game.start_hand()
			var moves = 0
			while game.phase != "complete" and moves < 300:
				var view = game.view_for(game.actor)
				var before = view.duplicate(true)
				var action = Bot.new(5000 + moves, moves % 3, level).choose(view)
				verify(view == before, "policy leaves observer view immutable")
				for seat in view.seats:
					if seat.id != view.actor: seat.hole = [50, 51]
				verify(action == Bot.new(5000 + moves, moves % 3, level).choose(view), "policy ignores hidden cards")
				verify(game.act(game.actor, action.action, action.get("amount", 0)).is_empty(), "legal mixed-stack action")
				moves += 1
			var total = 0
			for stack in stacks: total += stack
			verify(game.phase == "complete" and game.chip_total() == total, "arbitrary table settles and conserves chips")
	# A private royal flush must never be folded facing an all-in. Board runout
	# reaches the river by legal actions; replace only hero's observer cards.
	var river = Table.new([1000, 1000], 5, 10, 99)
	river.start_hand(0)
	while river.phase != "river":
		var legal = river.legal_actions(river.actor)
		river.act(river.actor, "check" if legal.check else "call")
	river.act(river.actor, "all_in")
	var nuts = river.view_for(river.actor)
	nuts.board = [8, 9, 10, 28, 13]
	nuts.seats[nuts.actor].hole = [11, 12]
	for level in range(3):
		for seed_value in range(20):
			verify(Bot.new(seed_value, seed_value % 3, level).choose(nuts).action == "call", "private nuts continue versus all-in")
	# Matched decisions, same random seeds: aggression has observable behavior,
	# independently in ALL difficulty levels. This is not a win-rate assertion.
	# 200 BB is outside the precomputed charts, so every level uses its own heuristics here.
	var opening = Table.new([2000, 2000])
	opening.start_hand(0)
	var view = opening.view_for(0)
	view.seats[0].hole = [11, 23] # KQ offsuit
	for level in range(3):
		var raises = [0, 0, 0]
		for style in range(3):
			for sample in range(400): raises[style] += int(Bot.new(10000 + sample, style, level).choose(view).action == "raise")
		verify(raises[1] < raises[0] and raises[0] < raises[2], "passive < balanced < aggressive raise frequency level " + str(level))
	# Inside the 100 BB chart, styles still bend advanced play across all starting hands.
	var charted = Table.new([1000, 1000, 1000, 1000, 1000, 1000])
	charted.start_hand(0)
	charted.act(charted.actor, "fold")
	charted.act(charted.actor, "fold")
	var chart_view = charted.view_for(charted.actor)
	var chart_raises = [0, 0, 0]
	for style in range(3):
		for sample in range(1326):
			var a = 0
			var combo = sample
			while combo >= 51 - a:
				combo -= 51 - a
				a += 1
			chart_view.seats[chart_view.actor].hole = [a, a + 1 + combo]
			chart_raises[style] += int(Bot.new(20000 + sample, style, 2).choose(chart_view).action == "raise")
	verify(chart_raises[1] < chart_raises[0] and chart_raises[0] < chart_raises[2], "chart play: passive < balanced < aggressive raise frequency")
	verify(Bot._private_draw([0, 14], [21, 22, 23, 24]) == 0.0, "board-only straight draw is not private semi-bluff")
	verify(Bot._private_draw([12, 23], [0, 5, 8]) >= 0.20, "private flush draw recognized")
	# Settings drafts, per-seat overrides, resize/count changes and training.
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	ui.smoke_mode = true
	_test_seat_sheet(ui)
	ui._start_table(6)
	ui._open_opponents(5)
	var editor = ui.settings.opponent_editor
	verify(editor.selected == 5 and editor.count == 6, "direct edit fifth opponent")
	editor.level.item_selected.emit(3)
	editor.aggression.item_selected.emit(2)
	verify(ui.bots[5].difficulty == 1 and ui.bots[5].style == 0, "draft never changes running bots")
	ui.settings.cancel()
	ui._open_opponents(5)
	verify(editor.level.selected == 0 and editor.aggression.selected == 0, "cancel discards opponent draft")
	editor.level.item_selected.emit(3)
	editor.aggression.item_selected.emit(2)
	ui.settings.apply_button.pressed.emit()
	verify(ui.bots[5].difficulty == 2 and ui.bots[5].style == 2 and ui.bots[1].difficulty == 1, "apply edits only chosen opponent")
	var values = ui._settings_values()
	values.difficulty = 0
	ui._apply_settings(values)
	verify(ui.bots[1].difficulty == 0 and ui.bots[5].difficulty == 2, "global default respects explicit overrides")
	ui._start_table(2)
	ui._start_table(6)
	verify(ui.bots[5].difficulty == 2 and ui.bots[5].style == 2, "seat configuration survives downsizing table")
	var folder = "user://opponent-session-%d" % Time.get_ticks_usec()
	verify(Session.save(ui.game, "123-456", 100, -1, folder, Profiles.snapshot(ui.opponent_profiles, 6, 0), ui.opponent_changes, ui.opponent_profiles, 0) == OK, "save session with per-seat snapshot")
	var restored = Session.restore(folder + "/session.json")
	verify(not restored.has("error") and restored.record.opponents[4].difficulty == 2 and restored.record.opponents[0].difficulty == 0, "resume preserves resolved settings")
	verify(restored.record.opponent_settings.profiles[0].difficulty == -1 and restored.record.opponent_settings.profiles[4].difficulty == 2, "resume keeps default inheritance and inactive-seat configuration")
	DirAccess.remove_absolute(folder + "/session.json")
	DirAccess.remove_absolute(folder)
	ui._open_opponents(1)
	for screen in [Vector2i(360, 640), Vector2i(412, 915)]:
		root.size = screen
		for frame in range(6): await process_frame
		var rect = ui.settings.get_global_rect()
		verify(rect.encloses(ui.settings.apply_button.get_global_rect()), "apply button remains reachable in portrait")
		verify(rect.encloses(ui.settings.back_button.get_global_rect()), "settings category return remains reachable")
	editor.roster.get_child(3).pressed.emit()
	verify(editor.selected == 4, "roster button edits its own seat")
	root.size = Vector2i(360, 640)
	for frame in range(6): await process_frame
	var scroll = ui.settings.scroll
	scroll.reset_scroll()
	for frame in range(6): await process_frame
	var start = scroll.global_position + Vector2(60, 180)
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	root.push_input(press, true)
	for step in range(1, 8):
		var drag = InputEventMouseMotion.new()
		drag.position = start - Vector2(0, step * 20)
		drag.relative = Vector2(0, -20)
		root.push_input(drag, true)
	var release = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = start - Vector2(0, 140)
	root.push_input(release, true)
	verify(scroll.scroll_vertical > 0 and editor.selected == 4, "upward drag scrolls settings without choosing a seat")
	ui.settings.cancel()
	ui._open_training()
	var fixture = Practice.fixtures()[2]
	var rebuilt = ui.History.replay(fixture)
	var point = Practice.points(rebuilt)[0].point
	fixture["opponent_changes"] = [{"event": 0, "profiles": Profiles.snapshot(ui.opponent_profiles, 6, 1)}]
	ui.training.open_case(fixture, point)
	verify(ui.training.case_page.bots[5].difficulty == 2 and ui.training.case_page.bots[5].style == 2, "training uses archived opponent configuration")
	ui.training.case_page._persist()
	verify(ui.training.store.data.session.opponents[4].difficulty == 2, "training continuation saves configuration")
	ui.queue_free()
	await process_frame
	print("OPPONENT_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _seat_buttons(ui) -> Array:
	return ui.screen.info_sheet.content.get_children().filter(func(c): return c is Button and c.text == "配置这位对手" and c.is_visible_in_tree())

func _test_seat_sheet(ui) -> void:
	ui._start_table(6)
	var before = ui.game.record_state()
	for cycle in range(12):
		var id: int = [2, 2, 5, 1][cycle % 4]
		ui._seat_details(id)
		var buttons = _seat_buttons(ui)
		verify(buttons.size() == 1, "repeated seat details contain exactly one configuration action")
		if not buttons.is_empty(): buttons[0].pressed.emit()
		verify(ui.settings.visible and not ui.screen.info_sheet.visible and ui.settings.opponent_editor.selected == id, "configuration action selects the currently viewed opponent")
		if cycle % 2 == 0: ui.settings.cancel()
		else: ui.settings.apply_button.pressed.emit()
		ui._seat_details(0)
		verify(_seat_buttons(ui).is_empty(), "hero details never retain opponent configuration actions")
		ui.modals.back()
		ui._toggle_sidebar()
		verify(ui.screen.info_sheet.visible and _seat_buttons(ui).is_empty(), "action record sheet never retains opponent configuration actions")
		ui.modals.back()
	verify(ui.game.record_state() == before, "opening and closing configuration preserves the hand")
