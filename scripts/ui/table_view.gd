extends Control
signal seat_selected(id: int)
## Responsive felt and clockwise seat layout, with the human fixed at the bottom.
const UI = preload("res://scripts/ui/style.gd")
const Eval = preload("res://scripts/poker/evaluator.gd")
const Card = preload("res://scripts/ui/card_view.gd")
const Badge = preload("res://scripts/ui/seat_badge.gd")
const Money = preload("res://scripts/ui/money_display.gd")
const BetMarker = preload("res://scripts/ui/bet_marker.gd")
const Outcome = preload("res://scripts/ui/outcome.gd")
var last_result_key: String = ""
var result_tween: Tween
const POSITIONS = {
	2: [Vector2(0.5, 0.13)],
	3: [Vector2(0.23, 0.20), Vector2(0.77, 0.20)],
	4: [Vector2(0.10, 0.44), Vector2(0.50, 0.13), Vector2(0.90, 0.44)],
	5: [Vector2(0.10, 0.48), Vector2(0.33, 0.13), Vector2(0.67, 0.13), Vector2(0.90, 0.48)],
	6: [Vector2(0.10, 0.55), Vector2(0.25, 0.13), Vector2(0.50, 0.13), Vector2(0.75, 0.13), Vector2(0.90, 0.55)],
	7: [Vector2(0.10, 0.69), Vector2(0.10, 0.34), Vector2(0.34, 0.13), Vector2(0.66, 0.13), Vector2(0.90, 0.34), Vector2(0.90, 0.69)],
	8: [Vector2(0.10, 0.69), Vector2(0.10, 0.34), Vector2(0.30, 0.13), Vector2(0.50, 0.13), Vector2(0.70, 0.13), Vector2(0.90, 0.34), Vector2(0.90, 0.69)],
	9: [Vector2(0.10, 0.69), Vector2(0.10, 0.35), Vector2(0.20, 0.12), Vector2(0.40, 0.12), Vector2(0.60, 0.12), Vector2(0.80, 0.12), Vector2(0.90, 0.35), Vector2(0.90, 0.69)]}
var seat_nodes: Array = []
var center: VBoxContainer
var phase_label: Label
var pot_label
var board_row: HBoxContainer
var result_label: Label
var view: Dictionary = {}
var felt_theme: int = 0
var four_color: bool = false
var motion: bool = true
var display_bb: bool = true
var display_paused: bool = false
var portrait: bool = false
var speech_bubble
var speech_seat: int = -1
var speech_key = ""
var speech_hand = -1
var speech_until = 0

func _ready() -> void:
	custom_minimum_size = Vector2(850, 490)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	center = VBoxContainer.new()
	center.add_theme_constant_override("separation", 7)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	phase_label = UI.label("", 16, UI.MUTED, true)
	center.add_child(phase_label)
	pot_label = Money.new()
	center.add_child(pot_label)
	pot_label.configure("pot", 30)
	board_row = HBoxContainer.new()
	board_row.alignment = BoxContainer.ALIGNMENT_CENTER
	board_row.add_theme_constant_override("separation", 8)
	center.add_child(board_row)
	for i in range(5): board_row.add_child(_card(-2))
	result_label = UI.label("", 16, UI.TEXT, true)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.custom_minimum_size.y = 24
	center.add_child(result_label)
	resized.connect(_layout)
	speech_bubble = preload("res://scripts/ui/speech_bubble.gd").new()
	add_child(speech_bubble)
	speech_bubble.z_index = 4
	speech_bubble.tapped.connect(func(): seat_selected.emit(speech_seat))

func update_table(new_view: Dictionary, use_bb: bool, paused: bool = false) -> void:
	view = new_view
	if speech_hand != int(view.hand):
		clear_speech()
		speech_hand = int(view.hand)
	display_bb = use_bb
	display_paused = paused
	while seat_nodes.size() < view.seats.size():
		seat_nodes.append(_make_seat())
	while seat_nodes.size() > view.seats.size():
		var entry = seat_nodes.pop_back()
		remove_child(entry.panel)
		entry.panel.queue_free()
		remove_child(entry.bet)
		entry.bet.queue_free()
	var last_actions = {}
	for event in view.events:
		if event.kind == "action": last_actions[event.seat] = event
	for seat in view.seats:
		var node = seat_nodes[seat.id]
		var active = view.actor == seat.id
		var won = view.phase == "complete" and view.result.payouts.get(seat.id, 0) > 0
		var border = UI.GOLD if active else Color("50b898") if won else Color.TRANSPARENT
		var style = UI.surface(Color("203b38") if active else Color("10262c"), 10, 6, border)
		style.set_border_width_all(1 if active or won else 0)
		node.panel.add_theme_stylebox_override("panel", style)
		node.panel.modulate.a = 0.55 if seat.folded or not seat.in_hand else 1.0
		node.name.text = "你" if seat.id == 0 else seat.name
		node.name.add_theme_color_override("font_color", UI.GOLD if active else UI.TEXT)
		node.badge.visible = seat.id == view.button
		node.badge.text = "D"
		node.badge.tint = UI.GOLD
		node.blind.visible = seat.id in [view.small_blind_seat, view.big_blind_seat]
		node.blind.text = "SB" if seat.id == view.small_blind_seat else "BB"
		node.blind.tint = Color("86bbb1") if seat.id == view.small_blind_seat else UI.BLUE
		for badge in [node.badge, node.blind]: badge.queue_redraw()
		node.bet.update_amount(seat.street_bet, view.big_blind, use_bb)
		node.bet.visible = seat.street_bet > 0 and view.phase != "complete"
		for card_index in range(2):
			var card = node.cards[card_index]
			card.motion = motion
			card.set_card(seat.hole[card_index] if not seat.hole.is_empty() else -1 if seat.in_hand else -2, four_color)
		node.stack.set_amount(seat.stack, view.big_blind, use_bb)
		# A quiet seat needs no repeated waiting label; the active outline carries turn order.
		var status = ""
		if not seat.in_hand: status = "已出局"
		elif view.phase == "complete":
			status = Outcome.net_text(view, seat.id, use_bb)
		elif seat.folded: status = "已弃牌"
		elif seat.stack == 0: status = "全押"
		elif active:
			status = "已暂停" if paused else "轮到你" if seat.id == 0 else "思考中"
		elif last_actions.has(seat.id) and last_actions[seat.id].phase == view.phase:
			status = {"fold": "弃牌", "check": "过牌", "call": "跟注", "raise": "加注"}[last_actions[seat.id].action]
		node.status.text = status
		node.status.add_theme_color_override("font_color", UI.GOLD if active else Color("7cd7b7") if won else UI.MUTED)
		# No hidden cards are stored in UI metadata or tooltips.
		node.panel.tooltip_text = "%s%s\n剩余筹码 %s · 本轮投入 %s" % [seat.name, " · " + seat.get("style", "") if seat.has("style") else "", UI.money(seat.stack, view.big_blind, use_bb), UI.money(seat.street_bet, view.big_blind, use_bb)]
		if view.phase == "complete":
			node.panel.tooltip_text += "\n分得 " + UI.money(view.result.payouts.get(seat.id, 0), view.big_blind, use_bb) + " · " + Outcome.net_text(view, seat.id, use_bb)
			if view.result.ranks.has(seat.id): node.panel.tooltip_text += "\n牌型：" + view.result.ranks[seat.id].name
	phase_label.text = {"preflop": "翻牌前", "flop": "翻牌", "turn": "转牌", "river": "河牌", "complete": "本手结束"}.get(view.phase, "")
	pot_label.caption = "总底池" if view.phase != "complete" else "已分配"
	pot_label.set_amount(view.pot if view.phase != "complete" else view.result.pot, view.big_blind, use_bb)
	for index in range(5):
		var card = board_row.get_child(index)
		card.motion = motion
		card.set_card(view.board[index] if index < view.board.size() else -2, four_color)
	result_label.text = ""
	if view.phase == "complete":
		result_label.text = Outcome.summary(view)
		result_label.add_theme_color_override("font_color", Color("7cd7b7") if Outcome.net(view, 0) > 0 else Color("f2a3a9") if Outcome.net(view, 0) < 0 else UI.GOLD)
		var result_key = str(view.hand) + JSON.stringify(view.result)
		if result_key != last_result_key:
			last_result_key = result_key
			if result_tween != null: result_tween.kill()
			if motion:
				result_label.modulate.a = 0.0
				result_tween = create_tween()
				result_tween.tween_property(result_label, "modulate:a", 1.0, 0.45)
				for entry in seat_nodes:
					entry.status.modulate.a = 0.2
					result_tween.parallel().tween_property(entry.status, "modulate:a", 1.0, 0.65)
	else:
		last_result_key = ""
		if result_tween != null: result_tween.kill()
		result_label.modulate.a = 1.0
		for entry in seat_nodes: entry.status.modulate.a = 1.0
	if not motion:
		if result_tween != null: result_tween.kill()
		result_label.modulate.a = 1.0
		for entry in seat_nodes: entry.status.modulate.a = 1.0
	_layout()
	_layout_speech()
	call_deferred("_layout_speech")

func clear_speech() -> void:
	speech_key = ""
	speech_seat = -1
	if speech_bubble != null: speech_bubble.hide()

func sync_speech(lines: Array, pinned: bool = false) -> void:
	if view.is_empty() or speech_bubble == null: return
	var eligible = lines.filter(func(line): return line is Dictionary and preload("res://scripts/poker/history.gd")._integer(line.get("seat"), 1, seat_nodes.size() - 1) and preload("res://scripts/poker/history.gd")._integer(line.get("event"), 0, view.events.size()) and line.get("text") is String)
	if not pinned:
		eligible = eligible.filter(func(line): return view.phase != "complete" and not view.events.slice(int(line.event)).any(func(event): return event.get("kind") == "street" or (event.get("kind") == "action" and event.get("seat") == line.seat)))
	if eligible.is_empty():
		clear_speech()
		return
	var line = eligible.back()
	var key = "%s:%s:%s:%s" % [view.hand, line.seat, line.event, line.text]
	if key == speech_key: return
	speech_key = key
	speech_seat = int(line.seat)
	speech_until = 0 if pinned else Time.get_ticks_msec() + 6500
	speech_bubble.set_text(str(line.text), minf(196, size.x * 0.48))
	speech_bubble.show()
	_layout_speech()
	call_deferred("_layout_speech")

func _process(_delta: float) -> void:
	if speech_bubble != null and speech_bubble.visible and speech_until > 0 and Time.get_ticks_msec() > speech_until: speech_bubble.hide()

func _layout_speech() -> void:
	if speech_bubble == null or speech_key.is_empty() or speech_seat < 1 or speech_seat >= seat_nodes.size(): return
	if size.x < 200 or (speech_until > 0 and Time.get_ticks_msec() > speech_until):
		speech_bubble.hide()
		return
	speech_bubble.set_text(speech_bubble.label.text, minf(196, size.x * 0.48))
	var speaker: Rect2 = seat_nodes[speech_seat].panel.get_rect()
	var extent: Vector2 = speech_bubble.size
	var obstacles: Array[Rect2] = []
	for node in seat_nodes:
		obstacles.append(node.panel.get_rect().grow(4))
		if node.bet.visible: obstacles.append(node.bet.get_rect().grow(4))
	var board = board_row.get_global_rect()
	board.position -= global_position
	obstacles.append(board.grow(5))
	var pot = pot_label.get_content_rect()
	pot.position += pot_label.global_position - global_position
	obstacles.append(pot.grow(8))
	if result_label.visible:
		var result = result_label.get_global_rect()
		result.position -= global_position
		obstacles.append(result.grow(3))
	var origin = speaker.get_center() - extent / 2
	var xs: Array[float] = [origin.x, 6.0, size.x - extent.x - 6]
	var ys: Array[float] = [origin.y, 6.0, size.y - extent.y - 6]
	for obstacle in obstacles:
		xs.append(obstacle.position.x - extent.x - 7)
		xs.append(obstacle.end.x + 7)
		ys.append(obstacle.position.y - extent.y - 7)
		ys.append(obstacle.end.y + 7)
	var candidates: Array[Vector2] = []
	for x in xs:
		for y in ys:
			var rect = Rect2(Vector2(x, y), extent)
			if Rect2(Vector2(4, 4), size - Vector2(8, 8)).encloses(rect) and not obstacles.any(func(o): return o.intersects(rect)):
				candidates.append(rect.position)
	if candidates.is_empty():
		# A compact training surface may lack room. Keep the transcript accessible
		# from the seat instead of covering cards or wagers.
		speech_bubble.hide()
		return
	candidates.sort_custom(func(a, b): return a.distance_squared_to(origin) < b.distance_squared_to(origin))
	speech_bubble.position = candidates[0]
	speech_bubble.show()
	var toward = speech_bubble.get_rect().get_center()
	speech_bubble.aim(toward.clamp(speaker.position + Vector2(5, 5), speaker.end - Vector2(5, 5)))

func _make_seat() -> Dictionary:
	var panel = UI.panel(Color("10282c"), 10, 6)
	add_child(panel)
	var id = seat_nodes.size()
	var bet = BetMarker.new()
	add_child(bet)
	panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			seat_selected.emit(id))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	panel.add_child(col)
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	col.add_child(top)
	var badge = Badge.new()
	badge.custom_minimum_size = Vector2(24, 24)
	top.add_child(badge)
	var blind = Badge.new()
	blind.custom_minimum_size = Vector2(24, 24)
	top.add_child(blind)
	var name_label = UI.label("", 16, UI.TEXT, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	top.add_child(name_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	col.add_child(row)
	var cards = []
	for index in range(2):
		var card = Card.new()
		card.custom_minimum_size = Vector2(40, 54) if seat_nodes.is_empty() else Vector2(30, 40)
		row.add_child(card)
		cards.append(card)
	var stack = Money.new()
	row.add_child(stack)
	var status = UI.label("", 14, UI.MUTED, true)
	status.custom_minimum_size.y = 20
	status.clip_text = true
	col.add_child(status)
	# Let a tap anywhere in the seat reach its panel, including labels and cards.
	_pass_input(col)
	return {"panel": panel, "name": name_label, "cards": cards, "stack": stack, "status": status, "badge": badge, "blind": blind, "bet": bet}

func _pass_input(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control: _pass_input(child)

func set_portrait(value: bool) -> void:
	portrait = value
	custom_minimum_size = Vector2(0, 580) if portrait else Vector2(850, 490)
	if not view.is_empty(): update_table(view, display_bb, display_paused)
	else: _layout()

func _layout() -> void:
	if center == null: return
	if portrait:
		_layout_portrait()
		return
	var hero_size = Vector2(260, 122)
	var opponent_size = Vector2(170, 108)
	var spacious = size.x >= 1250
	if spacious:
		hero_size = Vector2(290, 134)
		opponent_size = Vector2(210, 118)
	for id in range(seat_nodes.size()):
		var panel = seat_nodes[id].panel
		seat_nodes[id].name.add_theme_font_size_override("font_size", 19 if spacious else 16)
		for card in seat_nodes[id].cards:
			card.show()
			card.custom_minimum_size = Vector2(46, 64) if id == 0 and spacious else Vector2(40, 54) if id == 0 else Vector2(36, 47) if spacious else Vector2(30, 40)
		seat_nodes[id].stack.configure("stack", 24 if spacious else 20)
		seat_nodes[id].status.add_theme_font_size_override("font_size", 17 if spacious else 14)
		panel.size = hero_size if id == 0 else opponent_size
		var location = Vector2(size.x * 0.5, size.y - hero_size.y / 2 - 5) if id == 0 else POSITIONS[seat_nodes.size()][id - 1] * size
		panel.position = (location - panel.size / 2).clamp(Vector2(4, 4), size - panel.size - Vector2(4, 4))
	for card in board_row.get_children(): card.custom_minimum_size = Vector2(62, 86)
	board_row.add_theme_constant_override("separation", 8)
	pot_label.configure("pot", 32)
	center.size = Vector2(390, 200)
	center.position = Vector2((size.x - center.size.x) / 2, size.y * 0.45 - 95)
	_layout_speech()
	queue_redraw()

func _layout_portrait() -> void:
	var count = seat_nodes.size()
	var positions = []
	if count <= 3:
		positions = [Vector2(0.5, 0.12)] if count == 2 else [Vector2(0.25, 0.14), Vector2(0.75, 0.14)]
	elif count == 4:
		positions = [Vector2(0.14, 0.48), Vector2(0.5, 0.10), Vector2(0.86, 0.48)]
	elif count == 5:
		positions = [Vector2(0.14, 0.55), Vector2(0.29, 0.10), Vector2(0.71, 0.10), Vector2(0.86, 0.55)]
	elif count == 6:
		positions = [Vector2(0.14, 0.62), Vector2(0.14, 0.27), Vector2(0.5, 0.10), Vector2(0.86, 0.27), Vector2(0.86, 0.62)]
	elif count == 8:
		positions = [Vector2(0.14, 0.65), Vector2(0.14, 0.30), Vector2(0.21, 0.10), Vector2(0.5, 0.10), Vector2(0.79, 0.10), Vector2(0.86, 0.30), Vector2(0.86, 0.65)]
		if size.y < 660:
			# Preserve a wager lane under the three top seats on the training table.
			positions[1].y = 0.34
			positions[5].y = 0.34
	else:
		# Clockwise order, with two top seats and paired side rails for full tables.
		var left_count = int((count - 3) / 2)
		var right_count = count - 3 - left_count
		for i in range(left_count): positions.append(Vector2(0.14, 0.68 - i * (0.42 / maxf(1, left_count - 1))))
		positions.append(Vector2(0.29, 0.10))
		positions.append(Vector2(0.71, 0.10))
		for i in range(right_count): positions.append(Vector2(0.86, 0.26 + i * (0.42 / maxf(1, right_count - 1))))
	for id in range(count):
		var node = seat_nodes[id]
		var hero = id == 0
		var heads_up = count == 2
		node.name.add_theme_font_size_override("font_size", 20 if hero or heads_up else 18)
		node.stack.configure("stack", 30 if hero else 26 if heads_up else 21)
		node.status.add_theme_font_size_override("font_size", 16 if hero else 14)
		# The action dock already explains the human turn and outcome.
		node.status.visible = not hero
		node.stack.show()
		node.stack.custom_minimum_size.x = 54 if not hero and not heads_up else 84
		node.stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for card in node.cards:
			card.visible = view.seats[id].in_hand and (hero or not view.seats[id].folded)
			card.custom_minimum_size = Vector2(52, 74) if hero else Vector2(44, 60) if heads_up else Vector2(26, 38)
		var panel: Control = node.panel
		panel.size = Vector2(240, 116) if hero else Vector2(250, 130) if heads_up else Vector2(128, 96)
		var location = Vector2(size.x / 2, size.y - 62) if hero else positions[id - 1] * size
		if not hero and positions[id - 1].x < 0.2: location.x = 4 + panel.size.x / 2
		if not hero and positions[id - 1].x > 0.8: location.x = size.x - 4 - panel.size.x / 2
		panel.position = (location - panel.size / 2).clamp(Vector2(4, 4), size - panel.size - Vector2(4, 4))
	for card in board_row.get_children(): card.custom_minimum_size = Vector2(58, 80) if count == 2 else Vector2(44, 64)
	board_row.add_theme_constant_override("separation", 4)
	pot_label.configure("pot", 30)
	center.size = Vector2(350, 200) if count == 2 else Vector2(248, 185)
	center.position = Vector2((size.x - center.size.x) / 2, size.y * 0.47 - 70 if count == 2 else size.y * 0.43 - 92)
	_layout_bets()
	call_deferred("_layout_bets")
	_layout_speech()
	queue_redraw()

func _layout_bets() -> void:
	for id in range(seat_nodes.size()):
		var node = seat_nodes[id]
		var rect: Rect2 = node.panel.get_rect()
		var at: Vector2
		if id == 0: at = Vector2(size.x / 2 - 52, rect.position.y - 30)
		elif seat_nodes.size() == 2 or rect.get_center().y < size.y * 0.20:
			at = Vector2(rect.get_center().x - 52, rect.end.y + 4)
			if seat_nodes.size() in [7, 9]: at.x = clampf(at.x, 135, size.x - 239)
		elif size.y >= 660:
			# On the normal portrait surface each wager belongs just below its seat.
			# Leave the entire centre lane to the shared cards and pot.
			at = Vector2(rect.get_center().x - 52, rect.end.y + 3)
		elif rect.get_center().x < size.x / 2:
			at = Vector2(rect.end.x + 3, rect.end.y - 32)
		else: at = Vector2(rect.position.x - 107, rect.end.y - 32)
		var pot_rect: Rect2 = pot_label.get_content_rect()
		pot_rect.position += pot_label.global_position - global_position
		pot_rect = pot_rect.grow(8)
		if Rect2(at, Vector2(104, 28)).intersects(pot_rect): at.y = pot_rect.position.y - 30
		node.bet.position = at.clamp(Vector2.ZERO, size - Vector2(104, 28))
		node.bet.size = Vector2(104, 28)
	# Training uses a shorter surface: wager lanes can cross the board or each other.
	# Resolve only collisions using the nearest clear slot beside the same seat.
	var board_rect = board_row.get_global_rect()
	board_rect.position -= global_position
	board_rect = board_rect.grow(3)
	var pot_rect = pot_label.get_content_rect()
	pot_rect.position += pot_label.global_position - global_position
	pot_rect = pot_rect.grow(8)
	for id in range(seat_nodes.size()):
		var marker = seat_nodes[id].bet
		if not marker.visible or _wager_position_clear(marker.get_rect(), marker, board_rect, pot_rect): continue
		var rect: Rect2 = seat_nodes[id].panel.get_rect()
		var candidates: Array = [Vector2(marker.position.x, board_rect.end.y + 1),
			Vector2(marker.position.x, board_rect.position.y - 29),
			Vector2(rect.get_center().x - 52, rect.end.y + 3),
			Vector2(rect.position.x - 108, rect.get_center().y - 14),
			Vector2(rect.end.x + 4, rect.get_center().y - 14)]
		var origin: Vector2 = marker.position
		for dx in [-112, -56, 0, 56, 112]:
			for dy in [-96, -64, -32, 0, 32, 64, 96]: candidates.append(origin + Vector2(dx, dy))
		# Narrow gaps need exact obstacle edges; a coarse offset grid can miss them.
		var edges: Array[Rect2] = [board_rect, pot_rect]
		for seat in seat_nodes:
			edges.append(seat.panel.get_rect())
			if seat.bet != marker and seat.bet.visible: edges.append(seat.bet.get_rect())
		var xs: Array[float] = [origin.x, 4.0, size.x - 108.0]
		var ys: Array[float] = [origin.y, 4.0, size.y - 32.0]
		for obstacle in edges:
			xs.append(obstacle.position.x - 108)
			xs.append(obstacle.end.x + 4)
			ys.append(obstacle.position.y - 32)
			ys.append(obstacle.end.y + 4)
		for x in xs:
			for y in ys: candidates.append(Vector2(x, y))
		candidates.sort_custom(func(a, b): return a.distance_squared_to(origin) < b.distance_squared_to(origin))
		for candidate in candidates:
			var target = Rect2(candidate, Vector2(104, 28))
			if not _wager_position_clear(target, marker, board_rect, pot_rect): continue
			marker.position = candidate
			break

func _wager_position_clear(target: Rect2, marker: Control, board_rect: Rect2, pot_rect: Rect2) -> bool:
	if not Rect2(Vector2.ZERO, size).encloses(target) or target.intersects(board_rect) or target.intersects(pot_rect): return false
	if seat_nodes.any(func(s): return target.intersects(s.panel.get_rect())): return false
	return not seat_nodes.any(func(s): return s.bet != marker and s.bet.visible and target.intersects(s.bet.get_rect()))

func _draw() -> void:
	var rect = Rect2(Vector2(24, 20), size - Vector2(48, 40))
	var middle = rect.get_center()
	var radii = rect.size / 2
	var felt = Color("123b34") if felt_theme == 0 else Color("193249")
	# Layered rail and subtle felt grain stay behind every control and card.
	for layer in [[1.0, Color("08151b")], [0.99, Color("253b3b")], [0.98, Color("71634a")], [0.974, Color("132827")], [0.955, felt.darkened(0.12)]]:
		draw_colored_polygon(_oval(middle, radii * layer[0]), layer[1])
	for i in range(10):
		var scale = 0.95 - i * 0.055
		draw_colored_polygon(_oval(middle - Vector2(0, radii.y * 0.03), radii * scale), Color(felt.lightened(0.1), 0.055))
	var inner = radii * 0.95
	for y in range(-int(inner.y) + 3, int(inner.y) - 3, 7):
		var span = inner.x * sqrt(maxf(0, 1.0 - pow(float(y) / inner.y, 2)))
		draw_line(middle + Vector2(-span + 2, y), middle + Vector2(span - 2, y), Color(0.65, 0.83, 0.72, 0.018), 1)
	draw_polyline(_oval(middle, radii * 0.955), Color("54735f"), 1.0, true)
	var font = get_theme_default_font()
	var brand = "S O M N I C A R D"
	var label_size = font.get_string_size(brand, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	draw_string(font, middle + Vector2(-label_size.x / 2, radii.y * 0.38), brand, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.75, 0.55, 0.15))

func _oval(middle: Vector2, radii: Vector2) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(128): points.append(middle + Vector2.from_angle(TAU * i / 128.0) * radii)
	return points

func _chips(at: Vector2, color: Color, count: int) -> void:
	for layer in range(count):
		var middle = at + Vector2(layer * 2, -layer * 4)
		draw_colored_polygon(_oval(middle + Vector2(0, 3), Vector2(14, 8)), color.darkened(0.65))
		draw_colored_polygon(_oval(middle, Vector2(14, 8)), color.darkened(0.25))
		draw_polyline(_oval(middle, Vector2(10, 5)), color.lightened(0.1), 1.0, true)
		for i in range(6):
			var direction = Vector2.from_angle(i * TAU / 6)
			draw_line(middle + direction * Vector2(11, 6), middle + direction * Vector2(14, 8), UI.TEXT, 2, true)

func _card(card: int) -> Control:
	var node = Card.new()
	node.custom_minimum_size = Vector2(62, 86)
	node.card_id = card
	return node

func set_preferences(felt: int, colors: bool, animations: bool) -> void:
	felt_theme = felt
	four_color = colors
	motion = animations
	if not view.is_empty(): update_table(view, display_bb, display_paused)
	else: queue_redraw()

func _position(id: int) -> String:
	var tags = []
	if id == view.button: tags.append("D")
	if id == view.small_blind_seat: tags.append("SB")
	if id == view.big_blind_seat: tags.append("BB")
	return "/".join(tags)
