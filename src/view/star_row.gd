class_name StarRow
extends Control
## A level's three stars, drawn (not font glyphs, so they look the same
## everywhere). Earned stars are filled gold, others are outlines; stars
## just earned this game get a soft glow.

const GOLD := Color(0.95, 0.72, 0.2)
const EMPTY := Color(0.55, 0.5, 0.42, 0.7)

var earned: Array = [false, false, false]:
	set(value):
		earned = value
		queue_redraw()
var fresh: Array = [false, false, false]:
	set(value):
		fresh = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(84, 28)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := minf(size.y * 0.46, size.x / 6.4)
	for i in 3:
		var c := Vector2(size.x / 2.0 + (i - 1) * r * 2.25, size.y / 2.0)
		var pts := PackedVector2Array()
		for k in 10:
			var a := -PI / 2.0 + PI * k / 5.0
			pts.append(c + Vector2.from_angle(a) * (r if k % 2 == 0 else r * 0.45))
		var on: bool = earned[i] if i < earned.size() else false
		if i < fresh.size() and fresh[i]:
			draw_circle(c, r * 1.25, Color(GOLD, 0.25))
		if on:
			draw_colored_polygon(pts, GOLD)
		pts.append(pts[0])
		draw_polyline(pts, Color(0.45, 0.32, 0.1) if on else EMPTY, 1.5, true)
