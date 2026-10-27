class_name PieceIcon
extends Control
## Draws a trefoil piece as three small hexes, in slot order and layout.

var biomes: Array = []:
	set(value):
		biomes = value
		queue_redraw()
var data: GameData
var dimmed := false:
	set(value):
		dimmed = value
		queue_redraw()
var empty_text := ""


func _draw() -> void:
	if biomes.is_empty():
		if empty_text != "":
			var font := get_theme_default_font()
			var fs := 18
			var w := font.get_string_size(empty_text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
			draw_string(font, Vector2((size.x - w) / 2.0, size.y / 2.0 + fs / 3.0), empty_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.36, 0.33, 0.28, 0.8))
		return
	var hexes := PlotGrid.plot_hexes(Vector2i.ZERO)
	var centers: Array[Vector2] = []
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for h in hexes:
		var c := Hex.to_world(h)
		centers.append(c)
		lo = lo.min(c - Vector2(1.0, Hex.SQRT3 / 2.0))
		hi = hi.max(c + Vector2(1.0, Hex.SQRT3 / 2.0))
	var mid := (lo + hi) / 2.0
	var extent := hi - lo
	# Fit the trefoil's bounding box into the control, with a small margin.
	var r := minf(size.x / (extent.x + 0.3), size.y / (extent.y + 0.3))
	var origin := size / 2.0
	for i in 3:
		var c := origin + (centers[i] - mid) * r
		var pts := PackedVector2Array()
		for k in 6:
			pts.append(c + Hex.corner_offset(k, r * 0.96))
		var col := data.biome_color(biomes[i]) if data else Color.GRAY
		if dimmed:
			col = col.lerp(Color(0.85, 0.83, 0.78), 0.55)
		draw_colored_polygon(pts, col)
		pts.append(pts[0])
		draw_polyline(pts, Color(0.18, 0.22, 0.18, 0.9), 2.0, true)
