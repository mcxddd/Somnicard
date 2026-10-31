extends SceneTree
const Academy = preload("res://scripts/product/academy.gd")
const Store = preload("res://scripts/poker/training_store.gd")
const Backup = preload("res://scripts/poker/training_backup.gd")
const Prefs = preload("res://scripts/ui/preferences.gd")
var checks = 0
var failures = 0
func _initialize() -> void: call_deferred("run")
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)
func settle() -> void:
	for i in range(12): await process_frame
func run() -> void:
	var store = Store.new("")
	verify(Academy.progress(store.data).questions == 0, "legacy profile starts without invented completion")
	verify(Academy.valid({}) and Academy.question_ids().size() == 60, "bounded authored curriculum")
	var completed = 0
	for l in range(Academy.LESSONS.size()):
		for q in range(Academy.LESSONS[l].questions.size()):
			var item = Academy.LESSONS[l].questions[q]
			verify(item.choices.size() == 3 and item.reason.length() > 20, "each decision has choices and a concrete explanation")
			var wrong = Academy.answer(store, l, q, (item.correct + 1) % 3)
			verify(not wrong.correct and Academy.progress(store.data).questions == completed, "wrong choice does not grant completion")
			verify(Academy.answer(store, l, q, item.correct).correct, "correct response earns knowledge point")
			Academy.answer(store, l, q, (item.correct + 2) % 3)
			completed += 1
			verify(Academy.progress(store.data).questions == completed, "later revision does not erase completed point")
	verify(Academy.progress(store.data).lessons == Academy.LESSONS.size() and Store.valid(store.data), "all course progress is valid and complete")
	verify(not Academy.valid({"fake:0": {"correct": true, "tries": 1, "date": ""}}), "unknown course ids rejected")
	for invalid in [NAN, INF, -1, 0, 1.5, 100001]:
		verify(not Academy.valid({Academy.question_ids()[0]: {"correct": true, "tries": invalid, "date": ""}}), "invalid retry count rejected before integer cast")
	verify(not Academy.valid({"start:0": {"correct": "true", "tries": 1, "date": ""}}), "incorrect imported types rejected")
	verify(Academy.answer(store, -1, 0, 0).has("error") and Academy.answer(store, 0, 0, 4).has("error"), "invalid selection rejected")
	var folder = "user://product-tests-" + Store.uid()
	DirAccess.make_dir_recursive_absolute(folder)
	var path = folder.path_join("backup.json")
	verify(Backup.export_file(path, store, folder.path_join("empty")) == "", "export includes learning progress")
	var imported = Store.new("")
	var result = Backup.import_file(path, imported, folder.path_join("hands"))
	verify(not result.has("error") and Academy.progress(imported.data).lessons == Academy.LESSONS.size(), "learning progress survives backup roundtrip")
	verify(not Backup.import_file(path, imported, folder.path_join("hands")).has("error") and Academy.progress(imported.data).questions == Academy.question_ids().size(), "reimport does not inflate completed questions")
	_test_missed_backup(path, folder)
	var config = folder.path_join("preferences.cfg")
	var p = Prefs.DEFAULTS.duplicate()
	p.sound = 2; p.haptics = true; p.performance = 1
	verify(Prefs.save_values(p, config) == OK, "new settings persist")
	var loaded = Prefs.load_values(config)
	verify(loaded.sound == 2 and loaded.haptics and loaded.performance == 1, "all feedback settings roundtrip")
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	ui.smoke_mode = true
	await settle()
	for screen in [Vector2i(360, 640), Vector2i(720, 1600)]:
		root.size = screen
		await settle()
		ui._open_product("academy")
		await settle()
		verify(ui.learning_center.visible and ui.modals.top() == ui.learning_center, "learning owns input without starting game")
		verify(ui.learning_center.back_button.has_focus(), "learning owns keyboard focus")
		ui.learning_center.start_lesson(0)
		await settle()
		verify(root.get_visible_rect().grow(1).encloses(ui.learning_center.next_button.get_global_rect()), "next remains reachable")
		ui.learning_center.choose(0)
		verify(not ui.learning_center.answered and ui.learning_center.next_button.disabled, "wrong answer explains without advancing")
		ui.learning_center.choose(1)
		verify(ui.learning_center.answered and not ui.learning_center.next_button.disabled, "correct answer unlocks next")
		ui.learning_center._next()
		verify(ui.learning_center.question == 1, "next advances one question")
		ui.modals.back()
		verify(ui.learning_center.visible and ui.learning_center.lesson == -1, "back returns course list")
		ui.modals.back()
		verify(not ui.learning_center.visible and ui.home.visible, "second back returns home")
		ui._open_product("help")
		ui.support_center.show_topic(4)
		verify(ui.support_center.topic == 4 and ui.modals.top() == ui.support_center, "privacy has its own readable page")
		ui.modals.back(); ui.modals.back()
		verify(not ui.support_center.visible and ui.home.primary.has_focus(), "support restores home focus")
		_test_review_ui(ui)
	ui._open_product("academy")
	ui.learning_center.practice_requested.emit("跟注犹豫")
	verify(ui.training.visible and not ui.learning_center.visible and ui.training.hub.topic_picker.get_item_text(ui.training.hub.topic_picker.selected) == "面对下注", "course hands off to matching topic")
	ui.training.hide(); ui._open_home()
	ui._open_settings(); ui.settings._select_page(1)
	ui.settings.controls.sound.select(0)
	ui.settings.controls.haptics.set_pressed_no_signal(true)
	ui.settings.controls.performance.select(1)
	var changed = ui.settings.values()
	ui._apply_settings(changed)
	verify(ui.prefs.sound_level == 0 and ui.prefs.haptics_enabled and ui.prefs.performance_mode == 1, "feedback settings apply together")
	verify(ui.feedback_player.volume == 0, "mute stops audio")
	var table = preload("res://scripts/poker/table.gd").new([100, 100])
	table.start_hand(0)
	var fx = ui.feedback_player
	fx.active = true
	fx.sync(table, "feedback-test", false)
	verify(fx.last_cue == "deal", "new hand emits one deal cue")
	fx.last_cue = ""
	fx.sync(table, "feedback-test", false)
	verify(fx.last_cue == "", "refresh without an action does not repeat a cue")
	table.act(0, "call")
	fx.sync(table, "feedback-test", false)
	verify(fx.last_cue == "chips", "opponent turn uses a short action cue")
	table.act(1, "fold")
	fx.sync(table, "feedback-test", false)
	verify(fx.last_cue == "win", "net win emits settlement cue")
	fx.last_cue = ""
	fx.sync(table, "feedback-test", false)
	verify(fx.last_cue == "", "repainting settlement does not replay win sound")
	table.start_hand(0)
	fx.sync(table, "feedback-test", true)
	verify(fx.last_cue == "", "blocked view does not play hidden hand cues")
	table.act(0, "fold")
	fx.sync(table, "feedback-test", false)
	verify(fx.last_cue == "", "net loss does not play celebration cue")
	fx._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	fx.cue("turn")
	verify(not fx.active and fx.last_cue == "", "background suppresses feedback")
	fx._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	verify(fx.active, "foreground restores feedback")
	var diagnostic = ui.support_center.diagnostics()
	verify(not diagnostic.contains("Bearer") and not diagnostic.contains("endpoint") and not diagnostic.contains("user://"), "diagnostic does not include credentials, endpoints or file paths")
	ui.queue_free()
	await settle()
	for file in [path, config]: DirAccess.remove_absolute(file)
	DirAccess.remove_absolute(folder)
	print("PRODUCT_TESTS: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)

func _test_missed_backup(path: String, folder: String) -> void:
	# Newer incoming, newer previous, equal-date previous, and legacy inference.
	var cases = [
		[{"correct": true, "tries": 9, "date": "2026-10-01", "missed": true}, {"correct": false, "tries": 2, "date": "2026-10-02", "missed": false}, false, "2026-10-02"],
		[{"correct": true, "tries": 3, "date": "2026-10-03", "missed": false}, {"correct": false, "tries": 8, "date": "2026-10-02", "missed": true}, false, "2026-10-03"],
		[{"correct": true, "tries": 3, "date": "2026-10-02", "missed": false}, {"correct": false, "tries": 8, "date": "2026-10-02", "missed": true}, false, "2026-10-02"],
		[{"correct": true, "tries": 9, "date": "2026-10-01", "missed": true}, {"correct": false, "tries": 1, "date": "2026-10-02"}, false, "2026-10-02"],
		[{"correct": true, "tries": 1, "date": "2026-10-02"}, {"correct": false, "tries": 8, "date": "2026-10-02", "missed": true}, false, "2026-10-02"],
		[{"correct": true, "tries": 1, "date": "2026-10-01", "missed": false}, {"correct": false, "tries": 2, "date": "2026-10-02"}, true, "2026-10-02"]
	]
	for row in cases:
		var previous = Store.new("")
		var incoming = Store.new("")
		previous.data["academy"] = {"start:0": row[0].duplicate()}
		incoming.data["academy"] = {"start:0": row[1].duplicate()}
		verify(Backup.export_file(path, incoming, folder.path_join("empty")) == "", "export review-state merge fixture")
		var result = Backup.import_file(path, previous, folder.path_join("hands"))
		var merged: Dictionary = previous.data.academy["start:0"]
		verify(not result.has("error") and merged.missed == row[2] and merged.date == row[3], "review state follows latest date with previous winning ties")
		verify(merged.correct and merged.tries == maxi(int(row[0].tries), int(row[1].tries)), "review merge preserves completion OR and retry maximum")
		verify(not Backup.import_file(path, previous, folder.path_join("hands")).has("error") and previous.data.academy["start:0"].missed == row[2], "repeated merge preserves resolved legacy review state")
	var empty = Store.new("")
	verify(not Backup.import_file(path, empty, folder.path_join("hands")).has("error") and Academy.missed(empty.data) == ["start:0"], "first import retains legacy review inference")

func _test_review_ui(ui) -> void:
	# Isolate fixtures from the persistent profile used by the existing UI checks.
	var original_store = ui.learning_center.store
	var store = Store.new("")
	ui.learning_center.store = store
	var ids = Academy.question_ids()
	for i in range(7): store.data.get_or_add("academy", {})[ids[i]] = {"correct": true, "tries": 2, "date": "", "missed": true}
	ui._open_product("academy")
	verify(ui.learning_center.body.get_children().any(func(c): return c is Button and c.text == "错题复习 · 7 题"), "overview offers review before courses")
	ui.home.update_learning(store.data)
	verify(ui.home.learning.text.contains("有 7 道错题待复习"), "home prioritizes pending review count")
	ui.learning_center.start_review()
	verify(ui.learning_center.review_queue == ids.slice(0, 5) and ui.learning_center.title.text == "错题复习", "review is course-ordered and capped at five")
	verify(root.get_visible_rect().grow(1).encloses(ui.learning_center.next_button.get_global_rect()), "review next remains reachable in portrait")
	for i in range(5):
		var l: int = ui.learning_center.lesson
		var q: int = ui.learning_center.question
		var correct: int = Academy.LESSONS[l].questions[q].correct
		if i == 1:
			ui.learning_center.choose((correct + 1) % 3)
			verify(ui.learning_center.next_button.disabled and not ui.learning_center.answered, "review mistake requires retry")
		ui.learning_center.choose(correct)
		verify(store.data.academy[ids[i]].missed == (i == 1) and store.data.academy[ids[i]].tries == (4 if i == 1 else 3), "only first-try review success clears missed and every try counts")
		ui.learning_center._next()
	verify(ui.learning_center.lesson == -1 and ui.learning_center.review_queue.is_empty() and Academy.missed(store.data) == [ids[1], ids[5], ids[6]], "review returns to overview and leaves failed plus unvisited questions")
	ui.learning_center.start_review()
	ui.learning_center.back_action()
	verify(ui.learning_center.lesson == -1 and Academy.missed(store.data).size() == 3, "back exits review without clearing pending questions")
	ui.learning_center.start_review()
	for i in range(3):
		ui.learning_center.choose(Academy.LESSONS[ui.learning_center.lesson].questions[ui.learning_center.question].correct)
		ui.learning_center._next()
	verify(Academy.missed(store.data).is_empty() and not ui.learning_center.body.get_children().any(func(c): return c is Button and c.text.begins_with("错题复习")), "short final group clears remaining review and hides entry")
	ui.home.update_learning(store.data)
	verify(ui.home.learning.text.contains("接着学："), "home restores normal learning suggestion after review")
	ui.learning_center.start_lesson(0)
	for q in range(Academy.LESSONS[0].questions.size()):
		verify(ui.learning_center.question == q and ui.learning_center.subtitle.text.contains("%d / %d" % [q + 1, Academy.LESSONS[0].questions.size()]), "lesson navigation and counter use actual question count")
		ui.learning_center.choose(Academy.LESSONS[0].questions[q].correct)
		ui.learning_center._next()
	verify(ui.learning_center.title.text == "这一课，掌握了" and ui.learning_center.subtitle.text.contains("%d 个知识点已完成" % Academy.LESSONS[0].questions.size()), "lesson completes after all five decisions")
	for l in range(Academy.LESSONS.size()):
		for q in range(Academy.LESSONS[l].questions.size()): Academy.answer(store, l, q, Academy.LESSONS[l].questions[q].correct)
	ui.learning_center._overview()
	ui.home.update_learning(store.data)
	verify(ui.learning_center.next_button.text == "进入主题训练" and ui.learning_center.subtitle.text.contains("60 / 60") and ui.home.learning.text.contains("基础路线已完成"), "fully completed curriculum offers training and completed home copy")
	ui.modals.back()
	ui.learning_center.store = original_store
