class_name CornerIcon
extends Control
## A bloom recipe. When the valley's blooms need clockwise order, it is drawn
## as a corner: three wedges in the biome colours meeting at a point, the
## bloom's colour in the middle and an arrow showing the reading direction.
## Otherwise order doesn't matter, so it is drawn as an unordered set: three
## biome swatches in a row joined by "+" (a ring would suggest an order).

var biomes: Array = []:
	set(value):
		biomes = value
		queue_redraw()
var bloom_color := Color.WHITE
var clockwise := false
var data: GameData

const INK := Color(0.18, 0.2, 0.17, 0.9)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if biomes.size() != 3 or data == null:
		return
	if not clockwise:
		_draw_set()
		return
	var c := size / 2.0
	var r := minf(size.x, size.y) * (0.36 if clockwise else 0.46)
	for i in 3:
		var a0 := deg_to_rad(-90.0 + 120.0 * i)
		var pts := PackedVector2Array([c])
		for k in 13:
			pts.append(c + Vector2.from_angle(a0 + deg_to_rad(120.0) * k / 12.0) * r)
		draw_colored_polygon(pts, data.biome_color(biomes[i]))
		draw_line(c, c + Vector2.from_angle(a0) * r, INK, 1.5, true)
	draw_arc(c, r, 0.0, TAU, 36, INK, 1.5, true)
	draw_circle(c, r * 0.3, INK)
	draw_circle(c, r * 0.24, bloom_color)
	if clockwise:
		var ar := r + 4.0
		var a_start := deg_to_rad(-60.0)
		var a_end := deg_to_rad(40.0)
		draw_arc(c, ar, a_start, a_end, 12, INK, 1.5, true)
		var tip := c + Vector2.from_angle(a_end) * ar
		var tangent := Vector2.from_angle(a_end + PI / 2.0)
		var back := tip - tangent * 5.0
		var side := Vector2.from_angle(a_end) * 3.0
		draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), INK)


func _draw_set() -> void:
	var r := minf(size.y * 0.42, size.x / 7.5)
	var gap := (size.x - 6.0 * r) / 2.0
	for i in 3:
		var c := Vector2(r + i * (2.0 * r + gap), size.y / 2.0)
		var pts := PackedVector2Array()
		for k in 6:
			pts.append(c + Hex.corner_offset(k, r))
		draw_colored_polygon(pts, data.biome_color(biomes[i]))
		pts.append(pts[0])
		draw_polyline(pts, INK, 1.5, true)
		if i < 2:
			var plus := c + Vector2(r + gap / 2.0, 0)
			draw_line(plus - Vector2(3, 0), plus + Vector2(3, 0), INK, 1.5)
			draw_line(plus - Vector2(0, 3), plus + Vector2(0, 3), INK, 1.5)
