extends Control
## 169 hand classes; color is probability PER COMBO, not total class mass.
signal selected(hand: String, probability: float)
var classes: Dictionary = {}
var counts: Dictionary = {}
var maximum: float = 0.001
var selected_hand: String = ""
var font: Font
const TAP_SLOP = 12.0
var _pointer: int = -2
var _origin: Vector2
var _pressed_hand: String = ""
var _touches: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(0, 390)
	font = ThemeDB.fallback_font
	resized.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_PASS
	visibility_changed.connect(func():
		_cancel_tap()
		_touches.clear())

func set_range(values: Dictionary, available: Dictionary = {}) -> void:
	_cancel_tap()
	classes = values
	counts = available
	maximum = 0.000001
	for name_text in classes: maximum = maxf(maximum, classes[name_text] / _combos(name_text))
	selected_hand = ""
	queue_redraw()

func _combos(hand: String) -> float:
	if not counts.is_empty(): return maxf(1, counts.get(hand, 0))
	return 6.0 if hand.length() == 2 else 4.0 if hand.ends_with("s") else 12.0

func _name(row: int, col: int) -> String:
	var ranks = "AKQJT98765432"
	return ranks[mini(row, col)] + ranks[maxi(row, col)] + ("" if row == col else "s" if col > row else "o")

func _draw() -> void:
	if font == null: return
	var cell = Vector2(size.x / 13.0, size.y / 13.0)
	for row in range(13):
		for col in range(13):
			var hand = _name(row, col)
			var strength = float(classes.get(hand, 0.0)) / _combos(hand) / maximum
			var rect = Rect2(Vector2(col, row) * cell + Vector2.ONE, cell - Vector2(2, 2))
			draw_rect(rect, Color("182c34").lerp(Color("3e9d80"), sqrt(strength)))
			if hand == selected_hand: draw_rect(rect, Color("edc987"), false, 2)
			var font_size = 14
			var text_size = font.get_string_size(hand, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			draw_string(font, rect.position + Vector2((rect.size.x - text_size.x) / 2, (rect.size.y + text_size.y) / 2 - 4), hand, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("eef5ee"))

func _gui_input(event: InputEvent) -> void:
	# Start only after Godot hit-tests this grid, including its clipped region.
	# Emulated mouse events are ignored: native touches have their own lifecycle.
	if event is InputEventMouseButton and event.device != -1 and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_begin_tap(event.position, -1)
	elif event is InputEventScreenTouch and event.pressed and _touches.size() == 1:
		_begin_tap(event.position, event.index)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = true
			if _touches.size() > 1: _cancel_tap()
		else:
			_touches.erase(event.index)
			if _pointer == event.index: _finish_tap(event.position)
	elif event is InputEventScreenDrag and _pointer == event.index:
		if event.position.distance_to(_origin) > TAP_SLOP: _cancel_tap()
	elif event is InputEventMouseMotion and event.device != -1 and _pointer == -1:
		if event.position.distance_to(_origin) > TAP_SLOP: _cancel_tap()
	elif event is InputEventMouseButton and event.device != -1:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _pointer == -1:
			_finish_tap(event.position)
		elif event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]: _cancel_tap()

func _notification(what: int) -> void:
	# The parent scroll owns vertical drags and inertia, even when it consumes
	# motion/release before this control receives them. Never re-arm on release.
	if what == NOTIFICATION_SCROLL_BEGIN or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_tap()
		# ScrollContainer can consume the matching release before _input sees it.
		_touches.clear()

func _begin_tap(local: Vector2, pointer: int) -> void:
	_cancel_tap()
	if not _can_select(): return
	_pressed_hand = _hand_at(local)
	if _pressed_hand.is_empty(): return
	_pointer = pointer
	_origin = get_global_transform_with_canvas() * local

func _finish_tap(at: Vector2) -> void:
	var hand = _pressed_hand
	var origin = _origin
	_cancel_tap()
	var local = get_global_transform_with_canvas().affine_inverse() * at
	if hand.is_empty() or hand != _hand_at(local) or at.distance_to(origin) > TAP_SLOP or not _can_select(): return
	var ancestor = get_parent()
	while ancestor is Control:
		if ancestor.clip_contents and not Rect2(Vector2.ZERO, ancestor.size).has_point(ancestor.get_global_transform_with_canvas().affine_inverse() * at): return
		ancestor = ancestor.get_parent()
	selected_hand = hand
	selected.emit(hand, classes.get(hand, 0.0))
	queue_redraw()
	get_viewport().set_input_as_handled()

func _can_select() -> bool:
	var ancestor = get_parent()
	while ancestor != null:
		if ancestor.has_method("can_activate") and not ancestor.can_activate(): return false
		ancestor = ancestor.get_parent()
	return true

func _hand_at(local: Vector2) -> String:
	if size.x <= 0 or size.y <= 0 or not Rect2(Vector2.ZERO, size).has_point(local): return ""
	return _name(int(local.y * 13 / size.y), int(local.x * 13 / size.x))

func _cancel_tap() -> void:
	_pointer = -2
	_pressed_hand = ""
