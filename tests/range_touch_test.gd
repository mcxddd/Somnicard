extends SceneTree
const Grid = preload("res://scripts/ui/range_grid.gd")
const Scroll = preload("res://scripts/ui/touch_scroll.gd")
var checks = 0
var failures = 0
var emissions: Array = []

func _initialize() -> void: call_deferred("run")
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)
func settle() -> void:
	for i in range(8): await process_frame

func button(at: Vector2, down: bool, touch: bool, device: int = 0, finger: int = 0) -> void:
	var e
	if touch:
		e = InputEventScreenTouch.new()
		e.index = finger
	else:
		e = InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.device = device
	e.position = at
	e.pressed = down
	root.push_input(e, true)

func move(from: Vector2, to: Vector2, touch: bool) -> void:
	var e = InputEventScreenDrag.new() if touch else InputEventMouseMotion.new()
	if touch: e.index = 0
	else: e.button_mask = MOUSE_BUTTON_MASK_LEFT
	e.position = to
	e.relative = to - from
	root.push_input(e, true)

func swipe(at: Vector2, delta: Vector2, touch: bool) -> void:
	button(at, true, touch)
	for i in range(1, 5): move(at + delta * (i - 1) / 4, at + delta * i / 4, touch)
	button(at + delta, false, touch)

func run() -> void:
	root.size = Vector2i(540, 960)
	var host = Control.new()
	root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll = Scroll.new()
	scroll.position = Vector2(30, 50)
	scroll.size = Vector2(450, 300)
	host.add_child(scroll)
	var body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	var top = Control.new()
	top.custom_minimum_size.y = 80
	body.add_child(top)
	var grid = Grid.new()
	body.add_child(grid)
	var bottom = Control.new()
	bottom.custom_minimum_size.y = 220
	body.add_child(bottom)
	grid.set_range({"AKs": 0.25, "QQ": 0.5, "22": 0.25})
	grid.selected.connect(func(hand, mass): emissions.append([hand, mass]))
	await settle()
	for touch in [false, true]:
		scroll.reset_scroll()
		scroll.released_at = -1000
		grid.set_range({"AKs": 0.25, "QQ": 0.5, "22": 0.25})
		emissions.clear()
		await settle()
		var cell = grid.size / 13
		var at = grid.global_position + cell * Vector2(1.5, 0.5)
		button(at, true, touch)
		verify(emissions.is_empty() and grid.selected_hand.is_empty(), "press alone never selects (touch=%s)" % touch)
		move(at, at + Vector2(2, 2), touch)
		button(at + Vector2(2, 2), false, touch)
		verify(emissions == [["AKs", 0.25]] and grid.selected_hand == "AKs", "small-jitter release selects correct cell once (touch=%s)" % touch)
		if touch:
			button(at, true, false, -1)
			button(at, false, false, -1)
			verify(emissions.size() == 1, "emulated mouse does not duplicate a native touch")
		at = grid.global_position + cell * Vector2(6.5, 4.5)
		var old_scroll = scroll.scroll_vertical
		swipe(at, Vector2(0, -90), touch)
		verify(scroll.scroll_vertical > old_scroll and emissions.size() == 1 and grid.selected_hand == "AKs", "upward grid swipe scrolls without selecting (touch=%s)" % touch)
		await settle()
		at = scroll.get_global_rect().get_center()
		old_scroll = scroll.scroll_vertical
		swipe(at, Vector2(0, 60), touch)
		verify(scroll.scroll_vertical < old_scroll and emissions.size() == 1, "downward grid swipe preserves selection (touch=%s)" % touch)
		scroll.reset_scroll()
		scroll.released_at = -1000
		await settle()
		at = grid.global_position + cell * Vector2(4.5, 2.5)
		swipe(at, Vector2(65, 0), touch)
		verify(emissions.size() == 1, "horizontal movement never selects a different cell (touch=%s)" % touch)
		button(at, true, touch)
		move(at, at + Vector2(60, 0), touch)
		move(at + Vector2(60, 0), at, touch)
		button(at, false, touch)
		verify(emissions.size() == 1, "returning to origin cannot turn a drag into a tap (touch=%s)" % touch)
		button(at, true, touch)
		button(Vector2(510, 420), false, touch)
		verify(emissions.size() == 1, "release outside clipped grid is ignored (touch=%s)" % touch)
		button(at, true, touch)
		grid.set_range({"AA": 1.0})
		button(at, false, touch)
		verify(emissions.size() == 1 and grid.selected_hand.is_empty(), "opponent change cancels pending tap (touch=%s)" % touch)
		button(at, true, touch)
		grid.hide()
		grid.show()
		button(at, false, touch)
		verify(emissions.size() == 1, "hidden/reopened grid cannot commit stale touch")
	# Two fingers must not be interpreted as a single-cell selection.
	scroll.reset_scroll()
	scroll.released_at = -1000
	await settle()
	var at = grid.global_position + grid.size / 13 * Vector2(2.5, 2.5)
	var count = emissions.size()
	button(at, true, true)
	button(at + Vector2(40, 0), true, true, 0, 1)
	button(at, false, true)
	button(at + Vector2(40, 0), false, true, 0, 1)
	verify(emissions.size() == count, "multi-touch cancels selection")
	host.queue_free()
	await process_frame
	await review_flow()
	print("RANGE_TOUCH_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func review_flow() -> void:
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	ui.smoke_mode = true
	ui._start_table(6)
	while ui.game.actor != 0:
		var legal = ui.game.legal_actions(ui.game.actor)
		ui.game.act(ui.game.actor, "check" if legal.check else "call")
	ui._refresh()
	var before = ui.game.record_state()
	ui._open_advice()
	var review = ui.review
	while review.job != null: await process_frame
	review.expanded_details = true
	review._render_details()
	review.range_button.pressed.emit()
	await settle()
	await inspect_ranges(review)
	verify(ui.game.record_state() == before, "range inspection never acts on live table")
	review.analysis_scroll.released_at = -1000
	review.range_button.pressed.emit()
	verify(not review.range_selection.is_visible_in_tree(), "collapsing ranges also hides the readout")
	while ui.game.phase != "complete":
		var legal = ui.game.legal_actions(ui.game.actor)
		ui.game.act(ui.game.actor, "check" if legal.check else "call")
	var record = ui.game.completed_record()
	review.open_replay(ui.History.replay(record), true)
	review._jump_street(1)
	review.next_decision()
	review._analyze()
	while review.job != null: await process_frame
	review._select_portrait_tab(true)
	review.expanded_details = true
	review._render_details()
	review.range_button.pressed.emit()
	await settle()
	await inspect_ranges(review)
	verify(review.current_record == record, "range inspection never modifies replay record")
	ui.queue_free()
	await process_frame

func inspect_ranges(review) -> void:
	for screen in [Vector2i(360, 640), Vector2i(390, 844)]:
		root.size = screen
		await settle()
		review.analysis_scroll.reset_scroll(roundi(review.range_box.position.y + review.range_grid.position.y + 100))
		review.analysis_scroll.released_at = -1000
		await settle()
		var viewport = review.analysis_scroll.get_global_rect()
		var grid = review.range_grid
		var center = viewport.get_center()
		var local = center - grid.global_position
		var cell = grid.size / 13
		var row = clampi(int(local.y / cell.y), 0, 12)
		var col = 3
		var at = grid.global_position + cell * Vector2(col + 0.5, row + 0.5)
		verify(viewport.has_point(at), "tap fixture targets visible range row")
		var offset = review.analysis_scroll.scroll_vertical
		button(at, true, true)
		button(at, false, true)
		await settle()
		var expected = grid._name(row, col)
		var mass: float = grid.classes.get(expected, 0.0)
		verify(grid.selected_hand == expected and review.range_selection.text.contains("%.2f%%" % (mass * 100)), "coach tap shows the selected probability (live=%s)" % review.live_mode)
		verify(review.range_selection.is_visible_in_tree() and review.analysis_panel.get_global_rect().encloses(review.range_selection.get_global_rect()), "probability stays visible inside portrait overlay")
		verify(not viewport.intersects(review.range_selection.get_global_rect()), "selected probability is outside scrolling region")
		verify(offset == review.analysis_scroll.scroll_vertical, "selection never jumps the scroll position")
		var selected = review.range_selection.text
		var pinned = review.range_selection.global_position
		swipe(viewport.get_center(), Vector2(0, -45), true)
		await settle()
		verify(review.range_selection.text == selected and review.range_selection.global_position == pinned, "scroll leaves selection and fixed readout intact")
		review._select_range(1)
		verify(grid.selected_hand.is_empty() and not review.range_selection.text.contains(expected + " ·"), "switching opponents clears old hand probability")
		if review.live_mode:
			verify(not review.slider.visible and not review.transport.visible, "live coaching frees space from inapplicable replay controls")
		else:
			verify(review.analysis_panel.get_global_rect().end.y <= review.slider.global_position.y, "fixed readout does not obscure playback controls")
