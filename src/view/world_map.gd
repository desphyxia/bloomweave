class_name WorldMap
extends Control
## The world map: a region drawn as a quilt of fabric patches, with each
## valley a round embroidered badge (its outline in miniature, its name and
## stars) on a running-stitch path. Past the last valley a stitched star
## gate leads to the next region, shown misty until there is one to open.
## Fits the screen without scrolling: 2 columns in portrait, 4 in landscape.
## Emits "level:<id>" through `chosen`, and `closed` for the Back button.

signal chosen(level_id: String)
signal closed

const INK := Color(0.2, 0.22, 0.18)
const THREAD := Color(0.42, 0.3, 0.2)
const ACCENT := Color(0.76, 0.27, 0.42)
const GOLD := Color(0.95, 0.72, 0.2)
const CLOTH := Color(0.96, 0.93, 0.85)
const PATCHES := [Color(0.72, 0.78, 0.58), Color(0.8, 0.76, 0.56), Color(0.66, 0.74, 0.6),
	Color(0.78, 0.72, 0.6), Color(0.7, 0.76, 0.66), Color(0.82, 0.8, 0.64)]
const TOP := 64.0       # room for the title bar
const BOTTOM := 18.0

var data: GameData
var progress: Progress
var region_index := 0
var can_close := true

var _title: Label
var _stars: Label
var _back: Button
var _badges: Array = []   # [{id, centre, r, open, minis}]
var _gate := Vector2.ZERO
var _mist := Rect2()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 10
	bar.offset_right = -10
	bar.offset_top = 8
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bar.add_child(row)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_title)
	_stars = Label.new()
	_stars.add_theme_font_size_override("font_size", 17)
	_stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_stars)
	_back = Button.new()
	_back.text = "Back"
	_back.focus_mode = Control.FOCUS_NONE
	_back.custom_minimum_size = Vector2(80, 38)
	_back.pressed.connect(func() -> void: closed.emit())
	row.add_child(_back)
	visible = false


func open(p_data: GameData, p_progress: Progress, p_can_close: bool) -> void:
	data = p_data
	progress = p_progress
	can_close = p_can_close
	_back.visible = can_close
	var region: Dictionary = data.regions[region_index]
	_title.text = region.get("name", "Valleys")
	_stars.text = "★ %d / %d" % [progress.region_stars(region), region.levels.size() * 3]
	visible = true
	_layout()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and visible and data:
		_layout()
		queue_redraw()


# --- Layout --------------------------------------------------------------------

func _layout() -> void:
	_badges.clear()
	var region: Dictionary = data.regions[region_index]
	var ids: Array = region.levels
	var portrait := size.x < size.y
	var cols := 2 if portrait else 4
	var rows := int(ceil(ids.size() / float(cols)))
	var area := Rect2(Vector2(0, TOP), Vector2(size.x, size.y - TOP - BOTTOM))
	# The grid takes most of the height; the gate and the misty land the rest.
	var grid_h := area.size.y * (0.76 if portrait else 0.7)
	var cell := Vector2(area.size.x / cols, grid_h / rows)
	var r := minf(cell.x * 0.3, cell.y * 0.3)
	for i in ids.size():
		var row := i / cols
		var col := i % cols
		if row % 2 == 1:
			col = cols - 1 - col   # snake, so the path winds back and forth
		var c := area.position + Vector2((col + 0.5) * cell.x, (row + 0.42) * cell.y)
		_badges.append({"id": ids[i], "centre": c, "r": r, "open": progress.is_unlocked(ids[i]),
			"minis": _mini_shape(ids[i])})
	var below := area.position.y + grid_h
	var rest := area.end.y - below
	# The gate sits under the last valley, so the path runs straight down.
	var last_x: float = _badges[-1].centre.x if not _badges.is_empty() else size.x / 2.0
	_gate = Vector2(last_x, below + rest * 0.3)
	_mist = Rect2(Vector2(size.x * 0.05, below + rest * 0.52), Vector2(size.x * 0.9, rest * 0.46))


## A valley's hexes for its badge: [[centre (unit space), colour], ...],
## scaled to fit a unit circle.
func _mini_shape(id: String) -> Array:
	var v := data.valley(id)
	var hexes := []
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var landmark := ValleyGame.landmark_plot(v)
	var restored := bool(progress.stars(id).get("restored", false))
	for base: Vector2i in ValleyGame.outline_plots(v):
		var col := Color(0.62, 0.74, 0.5) if restored else Color(0.86, 0.8, 0.66)
		if base == landmark:
			col = Color(0.93, 0.62, 0.28)
		for h in PlotGrid.plot_hexes(base):
			hexes.append([Hex.to_world(h), col])
	for o: Dictionary in v.get("obstacles", []):
		var col := Color(0.42, 0.62, 0.8)
		if o.kind == "cliff":
			col = Color(0.5, 0.48, 0.45)
		elif o.kind == "ruins":
			col = Color(0.6, 0.55, 0.45)
		for b: Array in o.plots:
			for h in PlotGrid.plot_hexes(Vector2i(int(b[0]), int(b[1]))):
				hexes.append([Hex.to_world(h), col])
	for e: Array in hexes:
		lo = lo.min(e[0])
		hi = hi.max(e[0])
	var mid := (lo + hi) / 2.0
	var span := maxf(hi.x - lo.x, hi.y - lo.y) + 2.0
	var out := []
	for e: Array in hexes:
		out.append([((e[0] as Vector2) - mid) / span * 2.0, e[1], 2.0 / span])
	return out


# --- Drawing ---------------------------------------------------------------------

func _draw() -> void:
	if data == null:
		return
	_draw_quilt()
	var thread_w := 3.0
	# The stitched path from valley to valley, and on to the gate.
	for i in _badges.size():
		var a: Vector2 = _badges[i].centre
		var b: Vector2 = _badges[i + 1].centre if i + 1 < _badges.size() else _gate
		if absf(a.x - b.x) < 1.0:
			# Down to the next row: loop round the outside of the badges so the
			# thread never crosses a valley's name.
			var out := 1.0 if a.x > size.x / 2.0 else -1.0
			var bulge := Vector2(out * (float(_badges[i].r) + 22.0), 0)
			var pts := [a, a + bulge, b + bulge, b]
			for k in 3:
				draw_dashed_line(pts[k], pts[k + 1], THREAD, thread_w, 10.0, true)
		else:
			draw_dashed_line(a, b, THREAD, thread_w, 10.0, true)
	_draw_gate()
	for bd: Dictionary in _badges:
		_draw_badge(bd)


func _draw_quilt() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.84, 0.82, 0.72))
	var tile := maxf(size.x, size.y) / 7.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026 + region_index
	var y := 0.0
	while y < size.y:
		var x := -rng.randf() * tile * 0.5
		while x < size.x:
			var w := tile * rng.randf_range(0.7, 1.3)
			var col: Color = PATCHES[rng.randi() % PATCHES.size()]
			draw_rect(Rect2(x + 2, y + 2, w - 4, tile - 4), col)
			draw_rect(Rect2(x + 6, y + 6, w - 12, tile - 12), Color(1, 1, 1, 0.0))
			# Running-stitch seams round each patch.
			var r := Rect2(x + 5, y + 5, w - 10, tile - 10)
			for e in [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end],
					[r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]:
				draw_dashed_line(e[0], e[1], Color(0.45, 0.4, 0.3, 0.45), 1.5, 6.0)
			x += w
		y += tile


func _draw_badge(bd: Dictionary) -> void:
	var c: Vector2 = bd.centre
	var r: float = bd.r
	var open: bool = bd.open
	var stars := progress.stars(bd.id)
	draw_circle(c + Vector2(2, 3), r + 3, Color(0, 0, 0, 0.18))
	draw_circle(c, r + 3, THREAD if open else Color(0.5, 0.48, 0.44))
	draw_circle(c, r, CLOTH if open else Color(0.8, 0.78, 0.74))
	# The next valley to restore gets a pink ring.
	if open and not stars.get("restored", false):
		draw_arc(c, r + 7, 0.0, TAU, 48, ACCENT, 3.0, true)
	# Stitched rim.
	var n := 36
	for k in n:
		if k % 2 == 0:
			var a0 := TAU * k / n
			var a1 := TAU * (k + 1) / n
			draw_line(c + Vector2.from_angle(a0) * (r - 5), c + Vector2.from_angle(a1) * (r - 5), THREAD.lightened(0.2), 1.5, true)
	# The valley's outline in miniature.
	var fit := r * 0.66
	for e: Array in bd.minis:
		var p: Vector2 = c + Vector2(0, -r * 0.06) + (e[0] as Vector2) * fit
		var hr: float = float(e[2]) * fit * 1.02
		var pts := PackedVector2Array()
		for k in 6:
			pts.append(p + Hex.corner_offset(k, hr))
		var col: Color = e[1]
		draw_colored_polygon(pts, col if open else col.lerp(Color(0.7, 0.68, 0.64), 0.7))
	if not open:
		_draw_padlock(c, r * 0.32)
	# Name and stars under the badge.
	var font := get_theme_default_font()
	var fs := int(clampf(r * 0.3, 12.0, 18.0))
	var name: String = data.valley(bd.id).get("name", bd.id)
	var w := font.get_string_size(name, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	var label_pos := c + Vector2(-w / 2.0, r + fs + 6)
	draw_string_outline(font, label_pos, name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0.98, 0.96, 0.9))
	draw_string(font, label_pos, name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK if open else Color(0.4, 0.38, 0.34))
	var sr := fs * 0.45
	var keys := ["restored", "residents", "visitor"]
	for k in 3:
		var sc := c + Vector2((k - 1) * sr * 2.4, r + fs + 6 + sr * 1.6)
		_draw_star(sc, sr, bool(stars.get(keys[k], false)))


func _draw_star(c: Vector2, r: float, on: bool) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		pts.append(c + Vector2.from_angle(-PI / 2.0 + PI * k / 5.0) * (r if k % 2 == 0 else r * 0.45))
	if on:
		draw_colored_polygon(pts, GOLD)
	else:
		draw_colored_polygon(pts, Color(0.98, 0.96, 0.9, 0.8))
	pts.append(pts[0])
	draw_polyline(pts, Color(0.45, 0.32, 0.1) if on else Color(0.55, 0.5, 0.42), 1.2, true)


func _draw_padlock(c: Vector2, s: float) -> void:
	var body := Rect2(c + Vector2(-s, -s * 0.2), Vector2(s * 2.0, s * 1.5))
	draw_arc(c + Vector2(0, -s * 0.2), s * 0.65, PI, TAU, 16, Color(0.35, 0.33, 0.3), s * 0.28, true)
	draw_rect(body, Color(0.45, 0.42, 0.38))
	draw_circle(c + Vector2(0, s * 0.45), s * 0.18, Color(0.22, 0.2, 0.18))


## The star gate: two stitched posts and an arch; beyond, the misty land of
## the next region.
func _draw_gate() -> void:
	var region: Dictionary = data.regions[region_index]
	var need := int(region.get("gate_stars", 0))
	var have := progress.region_stars(region)
	var opened := progress.region_open(data.regions, region_index + 1)
	var font := get_theme_default_font()
	# Misty land.
	var m := _mist
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	draw_rect(m, Color(0.9, 0.9, 0.88, 0.55))
	for k in 14:
		var p := m.position + Vector2(rng.randf() * m.size.x, rng.randf() * m.size.y)
		draw_circle(p, m.size.y * rng.randf_range(0.3, 0.5), Color(0.95, 0.95, 0.93, 0.5))
	var has_next := region_index + 1 < data.regions.size()
	var next_name := "?"
	if has_next:
		var nxt: Dictionary = data.regions[region_index + 1]
		next_name = "?" if nxt.get("hidden", false) else str(nxt.name)
	var fs := 34
	var qw := font.get_string_size(next_name, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	draw_string(font, m.get_center() + Vector2(-qw / 2.0, fs * 0.35), next_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.5, 0.5, 0.48, 0.8))
	# Gate.
	var g := _gate
	var s := clampf(size.x / 18.0, 18.0, 30.0)
	var post := Color(0.48, 0.36, 0.24)
	for side in [-1.0, 1.0]:
		draw_rect(Rect2(g + Vector2(side * s * 1.4 - s * 0.2, -s), Vector2(s * 0.4, s * 2.0)), post)
	draw_arc(g + Vector2(0, -s), s * 1.4, PI, TAU, 24, post, s * 0.3, true)
	if not opened:
		for k in 4:
			var y := g.y - s * 0.6 + k * s * 0.45
			draw_dashed_line(Vector2(g.x - s * 1.2, y), Vector2(g.x + s * 1.2, y), THREAD, 2.0, 5.0)
	var text := "The way on is open" if opened else "★ %d / %d to open" % [have, need]
	var tfs := 15
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, tfs).x
	var tp := g + Vector2(-tw / 2.0, s * 1.0 + tfs + 4)
	draw_string_outline(font, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, 6, Color(0.98, 0.96, 0.9))
	draw_string(font, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, INK)


# --- Input -------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or mb.pressed:
		return
	for bd: Dictionary in _badges:
		if mb.position.distance_to(bd.centre) <= float(bd.r) + 8.0 and bd.open:
			chosen.emit(bd.id)
			return
