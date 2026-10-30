extends RefCounted
## Original vector poker chip, shared by wager and pot displays.
static func oval(at: Vector2, radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(48): points.append(at + Vector2.from_angle(TAU * i / 48.0) * Vector2(radius, radius * 0.76))
	return points

static func draw_chip(canvas: CanvasItem, at: Vector2, radius: float, tint: Color, layers: int = 2) -> void:
	canvas.draw_colored_polygon(oval(at + Vector2(1, 4), radius + 1), Color(0, 0, 0, 0.22))
	for layer in range(layers):
		var centre = at - Vector2(0, layer * 3)
		canvas.draw_colored_polygon(oval(centre + Vector2(0, 2), radius), tint.darkened(0.5))
		canvas.draw_colored_polygon(oval(centre, radius), tint)
		for i in range(6):
			var angle = TAU * i / 6.0
			var wedge = PackedVector2Array()
			for pair in [[-0.15, 0.92], [0.15, 0.92], [0.15, 0.67], [-0.15, 0.67]]:
				wedge.append(centre + Vector2.from_angle(angle + pair[0]) * Vector2(radius, radius * 0.76) * pair[1])
			canvas.draw_colored_polygon(wedge, Color("e8ddc5"))
		canvas.draw_polyline(oval(centre, radius * 0.53), Color(0.96, 0.89, 0.73, 0.7), 0.8, true)
		canvas.draw_circle(centre, radius * 0.12, Color("ead7aa"), true, -1, true)
