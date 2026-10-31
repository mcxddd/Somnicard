extends Control
const UI = preload("res://scripts/ui/style.gd")
const Card = preload("res://scripts/ui/card_view.gd")
var flights: Array = []
var pending: Dictionary = {}
var actor: Control
var paused: bool = false
var breath: float = 0.0
var outline: StyleBoxFlat

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline = UI.surface(Color.TRANSPARENT, 10, 0, UI.GOLD)
	outline.set_border_width_all(3)
	set_process(false)

func deal(origin: Control, target: Control, delay: float) -> void:
	var card = Card.new()
	card.card_id = -1
	card.motion = false
	card.hide()
	add_child(card)
	pending[target] = true
	target.modulate.a = 0.0
	flights.append({"kind": "deal", "from": origin, "to": target, "duration": 0.18, "age": -delay, "card": card})
	set_process(true)

func chips(kind: String, origin: Variant, target: Control, duration: float, delay: float = 0.0) -> void:
	flights.append({"kind": kind, "from": origin, "to": target, "duration": duration, "age": -delay})
	set_process(true)
	queue_redraw()

func set_actor(panel: Control, stopped: bool) -> void:
	if actor != panel: breath = 0.0
	actor = panel
	paused = stopped
	set_process(not flights.is_empty() or (actor != null and not paused))
	queue_redraw()

func clear() -> void:
	for target in pending:
		if is_instance_valid(target): target.modulate.a = 1.0
	pending.clear()
	for flight in flights:
		if flight.has("card"):
			flight.card.hide()
			flight.card.queue_free()
	flights.clear()
	actor = null
	set_process(false)
	queue_redraw()

func _point(value: Variant) -> Vector2:
	if value is Vector2: return value
	return value.get_global_rect().get_center() - global_position

func _at(flight: Dictionary) -> Vector2:
	var progress = clampf(flight.age / flight.duration, 0.0, 1.0)
	return _point(flight.from).lerp(_point(flight.to), progress)

func _process(delta: float) -> void:
	if not paused: breath = fmod(breath + delta, 1.2)
	for index in range(flights.size() - 1, -1, -1):
		var flight = flights[index]
		flight.age += delta
		if flight.age >= flight.duration:
			if flight.kind == "deal":
				flight.to.modulate.a = 1.0
				pending.erase(flight.to)
				flight.card.hide()
				flight.card.queue_free()
			flights.remove_at(index)
		elif flight.kind == "deal" and flight.age >= 0.0:
			flight.card.size = flight.to.size
			flight.card.position = _at(flight) - flight.card.size / 2
			flight.card.show()
	queue_redraw()
	set_process(not flights.is_empty() or (actor != null and not paused))

func _draw() -> void:
	if actor != null:
		outline.border_color = Color(UI.GOLD, 0.6 if paused else 0.675 - 0.325 * cos(breath * TAU / 1.2))
		var rect = actor.get_global_rect()
		rect.position -= global_position
		draw_style_box(outline, rect.grow(2))
	for flight in flights:
		if flight.kind != "deal" and flight.age >= 0.0: _chips(_at(flight), UI.GOLD, 3)

func _oval(middle: Vector2, radii: Vector2) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(48): points.append(middle + Vector2.from_angle(TAU * i / 48.0) * radii)
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
