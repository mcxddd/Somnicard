extends ScrollContainer
## Drag on the cards themselves; movement cancels activation and keeps inertia.
var pointer: int = -2
var origin: Vector2
var last: Vector2
var dragging: bool = false
var velocity: float = 0.0
var offset: float = 0.0
var released_at: int = -1000

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_deadzone = 12
	get_v_scroll_bar().custom_minimum_size.x = 10
	visibility_changed.connect(func():
		velocity = 0
		pointer = -2
		dragging = false)

func can_activate() -> bool:
	return not dragging and Time.get_ticks_msec() - released_at > 80

func reset_scroll(value: int = 0) -> void:
	velocity = 0
	pointer = -2
	dragging = false
	offset = value
	scroll_vertical = value

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		pointer = -2
		velocity = 0
		return
	if event is InputEventScreenTouch:
		if event.pressed: _begin(event.position, event.index)
		elif pointer == event.index: _end()
	elif event is InputEventScreenDrag and pointer == event.index:
		_drag(event.position, event.velocity.y)
	elif event is InputEventMouseButton and event.device != -1 and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: _begin(event.position, -1)
		elif pointer == -1: _end()
	elif event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if get_global_rect().has_point(event.position): velocity = 0
	elif event is InputEventMouseMotion and pointer == -1:
		_drag(event.position, event.velocity.y)

func _begin(at: Vector2, id: int) -> void:
	if pointer != -2 or not get_global_rect().has_point(at): return
	# Keep direct scrollbar interaction native.
	if get_v_scroll_bar().visible and get_v_scroll_bar().get_global_rect().has_point(at): return
	pointer = id
	origin = at
	last = at
	dragging = false
	velocity = 0
	offset = scroll_vertical

func _drag(at: Vector2, speed: float) -> void:
	if not dragging and absf(at.y - origin.y) < 12: return
	if not dragging:
		dragging = true
		propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
	offset += last.y - at.y
	_apply_offset()
	velocity = clampf(-speed, -2200, 2200)
	last = at
	get_viewport().set_input_as_handled()

func _end() -> void:
	pointer = -2
	if dragging:
		released_at = Time.get_ticks_msec()
		propagate_notification(Control.NOTIFICATION_SCROLL_END)
		get_viewport().set_input_as_handled()
	dragging = false

func _apply_offset() -> void:
	var bar = get_v_scroll_bar()
	offset = clampf(offset, 0, maxf(0, bar.max_value - bar.page))
	scroll_vertical = roundi(offset)

func _process(delta: float) -> void:
	if not is_visible_in_tree() or pointer != -2 or absf(velocity) < 5: return
	offset += velocity * delta
	_apply_offset()
	velocity = move_toward(velocity, 0, 2800 * delta)
