extends SceneTree
var checks = 0
var failures = 0
var table
func _initialize() -> void: call_deferred("run")
func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + message)
func settle() -> void:
	for i in range(12): await process_frame
	if table != null: table.motion_layer._process(2.0)
	await process_frame
func count_flights(kind: String) -> int:
	return table.motion_layer.flights.filter(func(f): return f.kind == kind).size()
func cards_visible() -> bool:
	return table.seat_nodes.all(func(s): return s.cards.all(func(c): return c.modulate.a == 1.0))
func passive(ui) -> void:
	var legal = ui.game.legal_actions(ui.game.actor)
	ui.game.act(ui.game.actor, "check" if legal.check else "call")
	ui._refresh()
func finish(ui) -> void:
	while ui.game.phase != "complete": passive(ui)
func run() -> void:
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	ui.smoke_mode = true
	root.size = Vector2i(390, 844)
	await settle()
	var settings = ui._settings_values()
	settings.motion = true
	settings.performance = 0
	settings.coach_auto = false
	settings.live_teaching = false
	ui._apply_settings(settings)
	table = ui.screen.table_view
	ui._start_table(6)
	var layer = table.motion_layer
	var active = ui.game.seats.filter(func(s): return s.in_hand).size()
	verify(table.effects and count_flights("deal") == 2 * active, "new six-seat hand queues two cards per active seat")
	verify(layer.pending.size() == 2 * active and not cards_visible(), "destinations wait invisibly for arrival")
	verify(layer.mouse_filter == Control.MOUSE_FILTER_IGNORE and table.get_child(-1) == layer, "nonblocking motion layer stays above new seats")
	for index in range(layer.flights.size()):
		var id = (ui.game.button + 1 + index % active) % active
		verify(layer.flights[index].to == table.seat_nodes[id].cards[index / active] and is_equal_approx(-layer.flights[index].age, index * 0.05), "deal is clockwise in two staggered rounds")
	verify(layer.actor == table.seat_nodes[ui.game.actor].panel, "current actor has halo")
	var before = ui.game.record_state()
	layer._process(0.2)
	var arrived = table.seat_nodes[1].cards[0]
	var waiting = table.seat_nodes[0].cards[1]
	for i in range(5): table.update_table(ui.game.view_for(0), true)
	verify(arrived.modulate.a == 1.0 and waiting.modulate.a == 0.0, "repeated updates preserve arrived and waiting cards")
	verify(ui.game.record_state() == before, "visual updates do not mutate poker state")
	table.update_table(ui.game.view_for(0), true, true)
	layer._process(0.01)
	verify(layer.paused and layer.actor != null, "paused actor retains fixed halo")
	table.update_table(ui.game.view_for(0), true)
	await settle()
	verify(cards_visible() and layer.pending.is_empty() and layer.flights.is_empty(), "deal settles with every card visible and no flights")
	while ui.game.phase == "preflop":
		var previous = table.view
		var origins = []
		for seat in previous.seats:
			if seat.street_bet > 0: origins.append(table.seat_nodes[seat.id].bet.get_global_rect().get_center() - layer.global_position)
		passive(ui)
		if ui.game.phase != "preflop":
			verify(not origins.is_empty() and count_flights("collect") == origins.size(), "street transition collects every previous positive wager")
			verify(layer.flights.all(func(f): return f.from in origins and f.duration == 0.28), "collection starts at previous wager locations")
	await settle()
	while ui.game.phase != "river": passive(ui)
	await settle()
	ui.game.act(ui.game.actor, "raise", 20)
	ui._refresh()
	while ui.game.phase != "complete": passive(ui)
	var winners = ui.game.result.payouts.values().filter(func(p): return p > 0).size()
	verify(count_flights("payout") == winners, "complete queues one payout per positive winner")
	verify(count_flights("collect") > 0 and layer.flights.filter(func(f): return f.kind == "payout").all(func(f): return is_equal_approx(f.age, -0.28)), "payout waits for collection without blocking result")
	verify(layer.actor == null, "complete has no actor halo")
	verify(not table.result_label.text.is_empty() and ui.screen.next_button.visible, "result and next-hand control are immediately available")
	var flight_count = layer.flights.size()
	ui._refresh()
	verify(layer.flights.size() == flight_count, "same complete snapshot does not repeat payouts")
	layer._process(0.29)
	verify(count_flights("collect") == 0 and count_flights("payout") == winners, "payout begins after collection ends")
	await settle()
	verify(layer.flights.is_empty() and not layer.is_processing(), "idle completed layer stops processing")
	ui._next_hand()
	verify(count_flights("deal") == 12, "next hand starts a fresh deal")
	finish(ui)
	ui._next_hand()
	for i in range(8): ui._refresh()
	await settle()
	verify(cards_visible() and layer.pending.is_empty() and layer.flights.is_empty(), "rapid hands and refreshes leave no invisible cards")
	ui._start_table(6)
	verify(count_flights("deal") == 12, "replacement fixture starts with active flights")
	ui._start_table(2)
	await settle()
	verify(cards_visible() and layer.pending.is_empty() and layer.flights.is_empty(), "seat replacement clears flights before old nodes are freed")
	ui._start_table(6)
	finish(ui)
	ui._next_hand()
	table.hide()
	verify(layer.flights.is_empty() and cards_visible() and layer.actor == null, "hiding cancels flights and restores all cards")
	table.show()
	finish(ui)
	ui._next_hand()
	table.set_portrait(true)
	verify(layer.flights.is_empty() and cards_visible(), "portrait rearrangement cancels flights")
	finish(ui)
	ui._next_hand()
	table.effects = false
	verify(layer.flights.is_empty() and cards_visible() and layer.actor == null, "effects switch immediately cancels all visuals")
	table.effects = true
	for option in ["motion", "performance"]:
		finish(ui)
		ui._next_hand()
		settings.motion = option != "motion"
		settings.performance = 1 if option == "performance" else 0
		ui._apply_settings(settings)
		verify(layer.flights.is_empty() and cards_visible() and layer.actor == null, option + " switch cancels an ongoing deal")
		finish(ui)
		ui._next_hand()
		verify(layer.flights.is_empty() and cards_visible() and not table.motion, option + " disables new-hand flights")
		verify(not ui.review.table_view.motion and not ui.training.case_page.table_view.motion, option + " disables existing review and training card animations")
	settings.motion = true
	settings.performance = 0
	ui._apply_settings(settings)
	for other in [ui.review.table_view, ui.training.case_page.table_view]:
		other.show()
		other.update_table(ui.game.view_for(0), true)
		verify(not other.effects and other.motion_layer.flights.is_empty() and other.motion_layer.actor == null, "review and training never enable live-table effects")
	ui.queue_free()
	await process_frame
	print("TABLE_MOTION_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
