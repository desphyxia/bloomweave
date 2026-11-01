class_name RegionView
extends Node3D
## The region overview in 3D: one quilted landscape where the region's
## valleys lie in their real shapes, in miniature, along a winding silk
## river, joined in order by a running-stitch path that ends at a star
## gate with mist beyond. Restored valleys show the board they were
## restored with; open ones pale cloth; locked ones misty grey.
## Fixed tilted camera (no zoom or rotation); drag to pan along the region
## when it doesn't fit; tap a valley to play it. Sits far from the game
## board and has its own camera, so both can exist at once.

signal chosen(level_id: String)

const ORIGIN := Vector3(0, 0, -600)   # well away from the game board
const MINI := 0.3                      # valleys at 30% of their real size
const STEP := 5.6                      # along the river, between valleys
const RIVER_GAP := 1.3                 # from the river to a valley's edge
const PITCH := deg_to_rad(52.0)
const TAP_SLOP := 12.0
const PATH_THREAD := Color(0.42, 0.3, 0.2)
const ACCENT := Color(0.76, 0.27, 0.42)

var data: GameData
var progress: Progress
var region_index := 0
var camera: Camera3D
var textile := Textile.new()

var _world: Node3D
var _valleys: Array = []   # [{id, centre (local), radius, open}]
var _along := Vector3(0, 0, -1)
var _across := Vector3(1, 0, 0)
var _length := 0.0
var _focus := 0.0          # how far along the region the camera looks
var _press := Vector2.ZERO
var _last := Vector2.ZERO
var _down := false
var _dragging := false


func _ready() -> void:
	position = ORIGIN
	camera = Camera3D.new()
	camera.fov = 45.0
	add_child(camera)
	visible = false
	set_process_unhandled_input(false)


func open(p_data: GameData, p_progress: Progress) -> void:
	data = p_data
	progress = p_progress
	visible = true
	set_process_unhandled_input(true)
	_build()
	# Start where the player is: the next valley to restore.
	_focus = 0.0
	for v: Dictionary in _valleys:
		if v.open and not progress.stars(v.id).get("restored", false):
			_focus = _along_of(v.centre)
			break
	_place_camera()
	camera.make_current()


func close() -> void:
	visible = false
	set_process_unhandled_input(false)


# --- Building ------------------------------------------------------------------

func _build() -> void:
	if _world:
		_world.queue_free()
	_world = Node3D.new()
	add_child(_world)
	var vp := get_viewport().get_visible_rect().size
	var portrait := vp.x < vp.y
	# Portrait: the region runs up the screen; landscape: across it.
	_along = Vector3(0, 0, -1) if portrait else Vector3(1, 0, 0)
	_across = Vector3(1, 0, 0) if portrait else Vector3(0, 0, 1)
	var region: Dictionary = data.regions[region_index]
	var ids: Array = region.levels
	_valleys.clear()
	var patches := MeshBatch.new()
	patches.textile = textile
	var details := MeshBatch.new()
	details.textile = textile
	var patch := textile.patch_mesh(1.0, 0.12, 0.21)
	for i in ids.size():
		var info := _valley_info(ids[i])
		var side := -1.0 if i % 2 == 0 else 1.0
		var off: float = side * (RIVER_GAP + info.radius)
		var centre: Vector3 = _along * (i * STEP) + _across * off
		var open := progress.is_unlocked(ids[i])
		_valleys.append({"id": ids[i], "centre": centre, "radius": info.radius, "open": open})
		_add_valley(patches, details, patch, ids[i], info, centre, open)
	_length = (ids.size() - 1) * STEP
	var mesh_a := MeshInstance3D.new()
	mesh_a.mesh = patches.commit()
	_world.add_child(mesh_a)
	var mesh_b := MeshInstance3D.new()
	mesh_b.mesh = details.commit()
	_world.add_child(mesh_b)
	_add_ground_and_hills()
	_add_river()
	_add_path()
	_add_labels()
	_add_gate()


## A valley's hexes (relative to its middle, in mini scale) and its radius.
func _valley_info(id: String) -> Dictionary:
	var v := data.valley(id)
	var cells := []
	for base: Vector2i in ValleyGame.outline_plots(v):
		for h in PlotGrid.plot_hexes(base):
			cells.append([h, "plot", base])
	for o: Dictionary in v.get("obstacles", []):
		for b: Array in o.plots:
			for h in PlotGrid.plot_hexes(Vector2i(int(b[0]), int(b[1]))):
				cells.append([h, str(o.kind), Vector2i(int(b[0]), int(b[1]))])
	var mid := Vector2.ZERO
	for c: Array in cells:
		mid += Hex.to_world(c[0])
	mid /= maxf(cells.size(), 1.0)
	var radius := 0.0
	for c: Array in cells:
		radius = maxf(radius, (Hex.to_world(c[0]) - mid).length() + 1.0)
	return {"cells": cells, "mid": mid, "radius": radius * MINI, "landmark": ValleyGame.landmark_plot(v)}


func _add_valley(patches: MeshBatch, details: MeshBatch, patch: Mesh, id: String, info: Dictionary,
		centre: Vector3, open: bool) -> void:
	var board := progress.board(id)
	var restored := not board.is_empty()
	var felt := {"fuzz": 0.35, "weave_strength": 0.0, "rough": 1.0}
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 10
	ball.rings = 5
	for c: Array in info.cells:
		var h: Vector2i = c[0]
		var p2 := (Hex.to_world(h) - (info.mid as Vector2)) * MINI
		var at := centre + Vector3(p2.x, 0, p2.y)
		var kind: String = c[1]
		var col := Color(0.88, 0.84, 0.72)
		var fab := {"weave_scale": 16.0, "weave_strength": 0.1, "fuzz": 0.05, "rough": 1.0}
		var lift := 1.0
		match kind:
			"lake":
				col = Color(0.4, 0.64, 0.8)
				fab = {"weave_scale": 40.0, "weave_strength": 0.05, "sheen": 1.2, "rough": 0.25}
				lift = 0.4
			"cliff":
				col = Color(0.55, 0.53, 0.5)
				lift = 4.0
			"ruins":
				col = Color(0.58, 0.64, 0.46)
			_:
				if restored and board.has(h):
					var biome: String = board[h]
					col = BiomeDecor.tile_tint(h, data.biome_color(biome))
					fab = data.biomes.get(biome, {}).get("fabric", fab)
				elif c[2] == info.landmark:
					col = Color(0.93, 0.66, 0.36)
		if not open:
			col = col.lerp(Color(0.6, 0.6, 0.6), 0.85)
		var xf := Transform3D(Basis.from_scale(Vector3(MINI, MINI * lift, MINI)), at)
		patches.add(patch, xf, col, textile.fabric(Color.WHITE, fab))
		# A few felt trees on restored forest, for life at this size.
		if restored and kind == "plot" and board.get(h, "") == "forest":
			details.add(ball, Transform3D(Basis.from_scale(Vector3.ONE * 0.22), at + Vector3(0, 0.16, 0)),
				Color.WHITE, textile.fabric(Color(0.28, 0.45, 0.26), felt))
	# The Old Oak at the landmark.
	var lm := Vector2.ZERO
	for h in PlotGrid.plot_hexes(info.landmark):
		lm += Hex.to_world(h) / 3.0
	var lp2 := (lm - (info.mid as Vector2)) * MINI
	var oak := centre + Vector3(lp2.x, 0.1, lp2.y)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.5
	trunk.bottom_radius = 0.5
	trunk.height = 1.0
	trunk.radial_segments = 6
	var green := Color(0.3, 0.5, 0.26) if open else Color(0.62, 0.64, 0.6)
	details.add(trunk, Transform3D(Basis.from_scale(Vector3(0.1, 0.5, 0.1)), oak + Vector3(0, 0.25, 0)),
		Color.WHITE, textile.fabric(Color(0.45, 0.32, 0.2), felt))
	details.add(ball, Transform3D(Basis.from_scale(Vector3(0.75, 0.6, 0.75)), oak + Vector3(0, 0.7, 0)),
		Color.WHITE, textile.fabric(green, felt))
	# The next valley to restore gets a pink stitched ring.
	if open and not progress.stars(id).get("restored", false):
		var segs: Array = []
		var r: float = info.radius + 0.35
		for k in 40:
			var a0 := TAU * k / 40.0
			var a1 := TAU * (k + 1) / 40.0
			segs.append([centre + Vector3(cos(a0) * r, 0.06, sin(a0) * r), centre + Vector3(cos(a1) * r, 0.06, sin(a1) * r)])
		_world.add_child(textile.stitches(segs, 1, 0.5, 0.05, ACCENT))


func _add_ground_and_hills() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	ground.mesh = plane
	ground.position = _along * (_length / 2.0) + Vector3(0, -0.02, 0)
	ground.material_override = textile.fabric(Color(0.62, 0.7, 0.5), {"weave_scale": 6.0, "weave_strength": 0.12, "fuzz": 0.2, "rough": 1.0})
	_world.add_child(ground)
	var hills := MeshBatch.new()
	hills.textile = textile
	var dome := SphereMesh.new()
	dome.radius = 0.5
	dome.height = 1.0
	dome.radial_segments = 24
	dome.rings = 12
	var greens := [Color(0.5, 0.66, 0.4), Color(0.58, 0.7, 0.42), Color(0.44, 0.6, 0.38), Color(0.62, 0.68, 0.45)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 404 + region_index
	var widest := 0.0
	for v: Dictionary in _valleys:
		widest = maxf(widest, absf(_across_of(v.centre)) + float(v.radius))
	var t := -8.0
	while t < _length + 14.0:
		for side in [-1.0, 1.0]:
			var r := rng.randf_range(2.5, 4.5)
			var h := rng.randf_range(1.0, 2.4)
			var at: Vector3 = _along * t + _across * side * (widest + r * 0.7 + rng.randf_range(0.5, 2.5))
			hills.add(dome, Transform3D(Basis.from_scale(Vector3(r * 2, h * 2, r * 2)), at + Vector3(0, -h * 0.3, 0)),
				Color.WHITE, textile.fabric(greens[rng.randi() % greens.size()], {"weave_scale": 6.0, "weave_strength": 0.12, "fuzz": 0.18}))
		t += rng.randf_range(3.0, 4.5)
	# Knolls between the valleys on each side, away from the river.
	for i in range(1, _valleys.size() - 1):
		var a: Vector3 = _valleys[i - 1].centre
		var b: Vector3 = _valleys[i + 1].centre
		var gap := (a + b) / 2.0
		var r := 1.2
		var clear := true
		for v: Dictionary in _valleys:
			clear = clear and gap.distance_to(v.centre) > float(v.radius) + r
		if clear:
			hills.add(dome, Transform3D(Basis.from_scale(Vector3(r * 2, 1.4, r * 2)), gap + Vector3(0, -0.2, 0)),
				Color.WHITE, textile.fabric(greens[i % greens.size()], {"weave_scale": 6.0, "weave_strength": 0.12, "fuzz": 0.18}))
	var mi := MeshInstance3D.new()
	mi.mesh = hills.commit()
	_world.add_child(mi)


## A silk river winding down the middle, between the valleys.
func _add_river() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	var steps := 80
	for k in steps + 1:
		var t := lerpf(-6.0, _length + 6.0, float(k) / steps)
		pts.append(_along * t + _across * sin(t * 0.55) * 0.5 + Vector3(0, 0.03, 0))
	for k in steps:
		var a := pts[k]
		var b := pts[k + 1]
		var side := (b - a).cross(Vector3.UP).normalized() * 0.42
		var quad := [a + side, b + side, b - side, a - side]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.add_vertex(quad[idx])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = textile.fabric(Color(0.5, 0.74, 0.88), {"weave_scale": 30.0, "weave_strength": 0.05, "sheen": 1.0, "rough": 0.3})
	_world.add_child(mi)


## Running stitches from valley to valley, in order, and on to the gate.
func _add_path() -> void:
	var segs: Array = []
	for i in _valleys.size():
		var a: Vector3 = _valleys[i].centre
		var b: Vector3 = _valleys[i + 1].centre if i + 1 < _valleys.size() else _gate_pos()
		var dir := (b - a).normalized()
		var from := a + dir * float(_valleys[i].radius)
		var to := b - dir * (float(_valleys[i + 1].radius) if i + 1 < _valleys.size() else 1.0)
		segs.append([from + Vector3(0, 0.06, 0), to + Vector3(0, 0.06, 0)])
	# Cut each leg into short pieces so it reads as running stitches.
	var dashes: Array = []
	for sg: Array in segs:
		var a: Vector3 = sg[0]
		var b: Vector3 = sg[1]
		var n := maxi(int(a.distance_to(b) / 0.5), 1)
		for k in n:
			dashes.append([a.lerp(b, float(k) / n), a.lerp(b, (k + 0.55) / n)])
	_world.add_child(textile.stitches(dashes, 1, 0.28, 0.05, PATH_THREAD))


func _add_labels() -> void:
	for v: Dictionary in _valleys:
		var st := progress.stars(v.id)
		var stars := ""
		for k: String in ["restored", "residents", "visitor"]:
			stars += "★" if st.get(k, false) else "☆"
		var label := Label3D.new()
		label.text = "%s\n%s" % [data.valley(v.id).get("name", v.id), stars if v.open else "locked"]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 56
		label.pixel_size = 0.012
		label.outline_size = 14
		label.modulate = Color(0.2, 0.18, 0.15) if v.open else Color(0.45, 0.43, 0.4)
		label.outline_modulate = Color(1, 0.98, 0.92)
		label.no_depth_test = true
		label.position = v.centre + _along * -(float(v.radius) * 0.2) + Vector3(0, 1.6, 0)
		_world.add_child(label)


func _gate_pos() -> Vector3:
	return _along * (_length + STEP * 0.9)


## The star gate at the end of the path and the misty land beyond.
func _add_gate() -> void:
	var region: Dictionary = data.regions[region_index]
	var need := int(region.get("gate_stars", 0))
	var have := progress.region_stars(region)
	var opened := progress.region_open(data.regions, region_index + 1)
	var g := _gate_pos()
	var felt := {"fuzz": 0.3, "weave_strength": 0.05, "rough": 1.0}
	var wood := textile.fabric(Color(0.48, 0.36, 0.24), felt)
	var post := CylinderMesh.new()
	post.top_radius = 0.5
	post.bottom_radius = 0.5
	post.height = 1.0
	post.radial_segments = 8
	var b := MeshBatch.new()
	for side in [-1.0, 1.0]:
		b.add(post, Transform3D(Basis.from_scale(Vector3(0.28, 2.2, 0.28)), g + _across * side * 1.1 + Vector3(0, 1.1, 0)), Color.WHITE, wood)
	var bar := BoxMesh.new()
	var bar_basis := Basis.looking_at(_along, Vector3.UP) * Basis.from_scale(Vector3(2.6, 0.22, 0.22))
	b.add(bar, Transform3D(bar_basis, g + Vector3(0, 2.15, 0)), Color.WHITE, wood)
	if not opened:
		for k in 3:
			b.add(bar, Transform3D(Basis.looking_at(_along, Vector3.UP) * Basis.from_scale(Vector3(2.1, 0.1, 0.08)),
				g + Vector3(0, 0.5 + k * 0.5, 0)), Color.WHITE, textile.fabric(PATH_THREAD, felt))
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	_world.add_child(mi)
	var sign := Label3D.new()
	sign.text = "The way on is open" if opened else "★ %d / %d to open" % [have, need]
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.font_size = 52
	sign.pixel_size = 0.012
	sign.outline_size = 14
	sign.modulate = Color(0.2, 0.18, 0.15)
	sign.outline_modulate = Color(1, 0.98, 0.92)
	sign.no_depth_test = true
	sign.position = g + Vector3(0, 3.0, 0)
	_world.add_child(sign)
	# Mist: soft white drifts over the land beyond, with a "?" for the
	# region not yet known.
	var mist := StandardMaterial3D.new()
	mist.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist.albedo_color = Color(0.97, 0.97, 0.95, 0.55)
	var puff := SphereMesh.new()
	puff.radius = 0.5
	puff.height = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	for k in 16:
		var at := g + _along * rng.randf_range(2.0, 12.0) + _across * rng.randf_range(-9.0, 9.0)
		var s := rng.randf_range(3.0, 6.0)
		var m := MeshInstance3D.new()
		m.mesh = puff
		m.material_override = mist
		m.scale = Vector3(s, s * 0.35, s)
		m.position = at + Vector3(0, 0.4, 0)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(m)
	var q := Label3D.new()
	var next_hidden: bool = region_index + 1 >= data.regions.size() or data.regions[region_index + 1].get("hidden", false)
	q.text = "?" if next_hidden else str(data.regions[region_index + 1].name)
	q.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	q.font_size = 140
	q.pixel_size = 0.014
	q.modulate = Color(0.55, 0.55, 0.52, 0.85)
	q.position = g + _along * 7.0 + Vector3(0, 1.5, 0)
	_world.add_child(q)


# --- Camera ---------------------------------------------------------------------

func _along_of(p: Vector3) -> float:
	return p.dot(_along)


func _across_of(p: Vector3) -> float:
	return p.dot(_across)


func _place_camera() -> void:
	var vp := get_viewport().get_visible_rect().size
	var portrait := vp.x < vp.y
	var widest := 0.0
	for v: Dictionary in _valleys:
		widest = maxf(widest, absf(_across_of(v.centre)) + float(v.radius))
	var span := widest * 2.0 + 2.0
	var dist := 0.0
	if portrait:
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = 50.0
		# Close enough to read: the outer edges of the widest valleys may
		# tuck just past the screen sides.
		dist = span / 2.0 / tan(deg_to_rad(camera.fov / 2.0)) * 0.72
	else:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.fov = 45.0
		dist = span / 2.0 / tan(deg_to_rad(camera.fov / 2.0)) * 0.95
	# Pan from the first valley in the middle of the screen to the gate.
	var lo := -1.0
	var hi := _length + STEP * 1.2
	_focus = clampf(_focus, lo, hi)
	var target := _along * _focus
	# Look from "behind" the across-axis edge, tilted down.
	var back := -_along.cross(Vector3.UP) if not portrait else Vector3(0, 0, 1)
	if not portrait:
		back = Vector3(0, 0, 1)
	var offset := (back * cos(PITCH) + Vector3.UP * sin(PITCH)) * dist
	var cam_pos := global_position + target + offset
	camera.global_transform = Transform3D(Basis.looking_at(-offset, Vector3.UP), cam_pos)


## The ground point under a screen point (region-local), or null.
func _pick(screen: Vector2) -> Variant:
	var o := camera.project_ray_origin(screen)
	var d := camera.project_ray_normal(screen)
	if absf(d.y) < 0.0001:
		return null
	var t := (global_position.y - o.y) / d.y
	if t < 0.0:
		return null
	return o + d * t - global_position


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_down = true
			_dragging = false
			_press = mb.position
			_last = mb.position
		else:
			_down = false
			if not _dragging:
				_tap(mb.position)
		get_viewport().set_input_as_handled()
		return
	var mm := event as InputEventMouseMotion
	if mm and _down:
		if not _dragging and mm.position.distance_to(_press) > TAP_SLOP:
			_dragging = true
		if _dragging:
			var a: Variant = _pick(_last)
			var b: Variant = _pick(mm.position)
			if a != null and b != null:
				_focus -= _along_of((b as Vector3) - (a as Vector3))
				_place_camera()
		_last = mm.position
		get_viewport().set_input_as_handled()


func _tap(screen: Vector2) -> void:
	var p: Variant = _pick(screen)
	if p == null:
		return
	for v: Dictionary in _valleys:
		var c: Vector3 = v.centre
		if Vector2(p.x - c.x, p.z - c.z).length() <= float(v.radius) + 0.4 and v.open:
			chosen.emit(v.id)
			return
