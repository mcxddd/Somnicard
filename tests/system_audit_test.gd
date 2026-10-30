extends SceneTree
## Cross-feature acceptance checks; test credentials are never sent to a service.
const Preferences = preload("res://scripts/ui/preferences.gd")
const Services = preload("res://scripts/ai/services.gd")
var checks = 0
var failures = 0
func _initialize() -> void: call_deferred("run")
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)
func settle() -> void:
	for i in range(8): await process_frame
func run() -> void:
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	ui.smoke_mode = true
	ui.ai.profiles = Services.normalize([
		{"id": "default", "label": "记住的模型", "service": {"endpoint": "https://a.invalid/v1", "model": "model-a"}, "remember": true},
		{"id": "second", "label": "临时模型", "service": {"endpoint": "https://b.invalid/v1", "model": "model-b"}, "remember": false}])
	ui.ai.service = ui.ai.profiles[0].service
	ui.ai.keys = {"default": "AUDIT_KEY_A", "second": "AUDIT_KEY_B"}
	ui.ai.key = "AUDIT_KEY_A"
	ui._open_settings()
	var page = ui.settings.ai_page
	verify(page.remember.button_pressed and page.profile_values()[0].remember, "opening settings retains remembered profile option")
	for i in range(3):
		page._switch_profile(1)
		verify(not page.remember.button_pressed and page.key.text == "AUDIT_KEY_B" and page.model.text == "model-b", "switch to temporary profile preserves its key/model/remember flag")
		page._switch_profile(0)
		verify(page.remember.button_pressed and page.key.text == "AUDIT_KEY_A" and page.model.text == "model-a", "switch back preserves the remembered profile independently")
	page._switch_profile(1)
	page.key.text = "CHANGED_DRAFT"
	page.key.text_changed.emit(page.key.text)
	ui.settings.cancel()
	verify(ui.ai.keys.second == "AUDIT_KEY_B" and ui.ai.profiles[0].remember and not ui.ai.profiles[1].remember, "cancel does not alter live credentials or profile flags")
	verify(page.secrets.is_empty() and page.key.text.is_empty(), "cancel clears credential drafts")
	ui._open_settings()
	var public_values = ui.settings.values()
	var path = "user://system-audit-prefs.cfg"
	verify(Preferences.save_values(public_values, path) == OK, "multi-profile settings serialize")
	var saved = Preferences.load_values(path)
	verify(saved.ai_profiles[0].remember and not saved.ai_profiles[1].remember, "remember flags survive settings roundtrip")
	verify(not FileAccess.get_file_as_string(path).contains("AUDIT_KEY"), "settings persistence excludes all profile credentials")
	DirAccess.remove_absolute(path)
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(1280, 800)]:
		root.size = dimensions
		await settle()
		for category in range(ui.settings.CATEGORIES.size()):
			ui.settings._select_page(category)
			await settle()
			verify(ui.settings.pages.filter(func(p): return p.visible).size() == 1, "each category displays one page")
			for control in [ui.settings.apply_button, ui.settings.cancel_button, ui.settings.back_button]:
				verify(root.get_visible_rect().grow(1).encloses(control.get_global_rect()), "category controls remain inside portrait viewport")
	ui.settings.cancel()
	# Reopening seat configuration must never grow the overlay tree.
	ui._start_table(9)
	var initial_nodes = ui.info_sheet.content.get_child_count()
	for i in range(24):
		ui._seat_details(i % 8 + 1)
		ui.info_opponent_button.pressed.emit()
		ui.settings.cancel()
		verify(ui.info_sheet.content.get_child_count() == initial_nodes, "repeated seat configuration does not accumulate widgets")
		verify(ui.settings.opponent_editor.selected == i % 8 + 1, "seat configuration retains its intended target")
	# Training uses a shorter table than normal play; wagers must not cover public cards.
	ui.training.history_directory = "user://audit-empty-history"
	ui._open_training()
	while ui.training.scan_cursor >= 0: await process_frame
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844)]:
		root.size = dimensions
		for fixture in ui.training.Practice.fixtures():
			for point in ui.training.Practice.points(ui.History.replay(fixture)):
				if point.view.phase != "flop": continue
				ui.training.open_case(fixture, point.point)
				await settle()
				var table = ui.training.table_view
				for seat in table.seat_nodes:
					if not seat.bet.visible: continue
					var bet_rect = seat.bet.get_content_rect()
					bet_rect.position += seat.bet.global_position
					for card in table.board_row.get_children():
						if card.card_id >= 0: verify(not bet_rect.intersects(card.get_global_rect()), "training wager must not cover community cards: %s seats=%d seat=%d bet=%s board=%s table=%s" % [dimensions, table.seat_nodes.size(), table.seat_nodes.find(seat), bet_rect, card.get_global_rect(), table.size])
		for count in range(2, 10):
			var stacks: Array = []
			stacks.resize(count); stacks.fill(1000)
			var sample = ui.Table.new(stacks, 5, 10, 4311 + count)
			sample.start_hand(0)
			while sample.phase != "complete": sample.act(sample.actor, "check" if sample.legal_actions(sample.actor).check else "call")
			var record = sample.completed_record()
			var points = ui.training.Practice.points(ui.History.replay(record)).filter(func(p): return p.view.phase == "flop")
			ui.training.open_case(record, points[0].point)
			var table = ui.training.table_view
			var state: Dictionary = ui.training.game.view_for(0)
			for seat in state.seats: seat.street_bet = 125
			table.update_table(state, true)
			await settle()
			for id in range(count):
				var wager: Rect2 = table.seat_nodes[id].bet.get_global_rect()
				verify(table.get_global_rect().encloses(wager), "compact wager stays within table")
				for seat in table.seat_nodes: verify(not wager.intersects(seat.panel.get_global_rect()), "compact wager avoids all player panels: count=%d wager=%d panel=%d rect=%s" % [count, id, table.seat_nodes.find(seat), wager])
				for card in table.board_row.get_children(): verify(not wager.intersects(card.get_global_rect()), "compact wager avoids every community-card slot")
				for other in range(id + 1, count): verify(not wager.intersects(table.seat_nodes[other].bet.get_global_rect()), "compact wagers do not overlap each other: count=%d pair=%d/%d rect=%s/%s" % [count,id,other,wager,table.seat_nodes[other].bet.get_global_rect()])
	ui.queue_free()
	await process_frame
	print("SYSTEM_AUDIT_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
