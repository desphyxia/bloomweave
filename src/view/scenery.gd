class_name Scenery
extends Node3D
## The land around the valley, in the same quilt style as the board:
##   - faded land: grey, washed-out cloth around the plots that gains colour
##     next to restored hexes
##   - quilted hills ringing the valley, with felt trees, sheep, cottages and
##     a silk stream running down into the valley; hills and stream regain
##     colour as the valley is restored
##   - distant fabric hills and slow felt clouds under a soft sky
##   - animals that move in also appear on the hills; a finished valley gets
##     birds and chimney smoke
## Purely visual; reads the game state but never changes it.

const FADED := Color(0.58, 0.57, 0.55)
const START_FADE := 0.95        # how washed-out the land is before restoring
const FADE_MARGIN := 2          # rings of faded hexes beyond the valley
const FADED_EDGE := 0.04
const FADED_PUFF := 0.05
const STEPS := 6                # colour steps, so materials can be shared
const STREAM_ANGLE := -2.2      # where the stream comes down from (radians)

var game: ValleyGame
var data: GameData
var textile := Textile.new()

var _faded: Array[Vector2i] = []  # hexes of faded land, in mesh order
var _faded_mesh: ArrayMesh        # one hex patch, copied per hex
var _faded_land_mi: MeshInstance3D
var _patch_arrays: Array = []     # [vertices, normals] of one patch (all surfaces)
var _domes: Array = []          # [center Vector2, radius, height, base y]
var _stream: MeshInstance3D
var _clouds: Node3D
var _life: Node3D               # animals on the hills, birds, smoke
var _birds: Node3D
var _smoke: Array = []          # [MeshInstance3D, origin Vector3, phase]
var _cottages: Array[Vector3] = []
var _inner_r := 10.0            # world radius where the hills begin
var _valley_r := 8.0            # world radius of the valley's plots
var _time := 0.0


func _ready() -> void:
	_faded_mesh = textile.patch_mesh(1.0, FADED_EDGE, FADED_PUFF, 3)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in _faded_mesh.get_surface_count():
		var arr := _faded_mesh.surface_get_arrays(i)
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		if idx.is_empty():
			verts.append_array(v)
			normals.append_array(n)
		else:
			for k in idx:
				verts.append(v[k])
				normals.append(n[k])
	_patch_arrays = [verts, normals]


func _process(delta: float) -> void:
	_time += delta
	if _clouds:
		_clouds.rotation.y += delta * 0.006
	if _birds and _birds.visible:
		_birds.rotation.y -= delta * 0.25
		for i in _birds.get_child_count():
			var b := _birds.get_child(i) as Node3D
			b.position.y = 7.0 + sin(_time * 1.3 + i) * 0.4
			b.scale.x = 1.0 + sin(_time * 9.0 + i * 2.0) * 0.35
	for s: Array in _smoke:
		var puff := s[0] as MeshInstance3D
		var t := fposmod(_time * 0.25 + s[2], 1.0)
		puff.position = (s[1] as Vector3) + Vector3(t * 0.6, t * 2.2, 0)
		puff.scale = Vector3.ONE * (0.15 + t * 0.35) * (1.0 - t * 0.6)


func setup(p_game: ValleyGame) -> void:
	game = p_game
	data = game.data
	for c in get_children():
		c.queue_free()
	_faded.clear()
	_domes.clear()
	_smoke.clear()
	_cottages.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	_ground()
	_faded_land(rng)
	_quilted_hills(rng)
	_stream_mesh()
	_distant_hills(rng)
	_make_clouds(rng)
	_life = Node3D.new()
	add_child(_life)
	_birds = Node3D.new()
	_birds.visible = false
	add_child(_birds)
	refresh()


## Recolour everything that depends on how much has been restored.
func refresh() -> void:
	_rebuild_faded_land()
	# The whole landscape (ground, hills, woods, sheep, cottages, stream,
	# distant hills) is washed out at first and regains colour as the valley
	# is restored. Scenery has its own Textile, so this never touches the board.
	var restored := float(game.placed.size()) / maxf(game.plots.size(), 1.0)
	var fade := START_FADE * (1.0 - restored)
	for m: Variant in textile._cache.values():
		if m is ShaderMaterial and m != _faded_land_mi.material_override:
			(m as ShaderMaterial).set_shader_parameter("wash", fade)


## An animal that moved in also shows up on the hills.
func on_settled(id: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	for k in 2:
		var a := rng.randf() * TAU
		var p := _hill_point(a, rng.randf_range(0.2, 0.6))
		var fig := _felt_animal(id, 0.75 if k == 0 else 0.55)
		fig.position = p
		fig.rotation.y = -a + PI / 2.0
		_life.add_child(fig)
		fig.scale = Vector3.ONE * 0.01
		create_tween().tween_property(fig, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.8 + k * 0.3)


## The finished valley: birds circle overhead and the cottages light their fires.
func on_finished() -> void:
	_birds.visible = true
	for c in _birds.get_children():
		c.queue_free()
	var mat := textile.satin(Color(0.25, 0.22, 0.2))
	var wing := CapsuleMesh.new()
	wing.radius = 0.04
	wing.height = 0.5
	for i in 6:
		var bird := Node3D.new()
		var a := TAU * i / 6.0
		bird.position = Vector3(cos(a) * (6.0 + i % 3), 7.0, sin(a) * (6.0 + i % 3))
		for side in [-1.0, 1.0]:
			var w := MeshInstance3D.new()
			w.mesh = wing
			w.material_override = mat
			w.rotation = Vector3(0, 0, side * 1.2)
			w.position = Vector3(side * 0.17, 0.05, 0)
			bird.add_child(w)
		_birds.add_child(bird)
	var puff := SphereMesh.new()
	puff.radius = 0.5
	puff.height = 1.0
	puff.radial_segments = 8
	puff.rings = 4
	var smoke_mat := textile.fabric(Color(0.9, 0.9, 0.88), {"fuzz": 0.4, "weave_strength": 0.0})
	for c in _cottages:
		for k in 3:
			var mi := MeshInstance3D.new()
			mi.mesh = puff
			mi.material_override = smoke_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_life.add_child(mi)
			_smoke.append([mi, c, k / 3.0])


# --- Ground and faded land ----------------------------------------------------

func _ground() -> void:
	var g := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 120.0
	m.bottom_radius = 120.0
	m.height = 0.04
	m.radial_segments = 48
	g.mesh = m
	g.position.y = -0.03
	g.material_override = textile.fabric(Color(0.6, 0.66, 0.48), {"weave_scale": 3.0, "weave_strength": 0.1, "fuzz": 0.15})
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(g)


func _faded_land(rng: RandomNumberGenerator) -> void:
	var valley := {}
	var max_d := 0
	for base in game.plots:
		for h in PlotGrid.plot_hexes(base):
			valley[h] = true
			max_d = maxi(max_d, Hex.distance(Vector2i.ZERO, h))
	var outer := max_d + FADE_MARGIN
	var tufts := BiomeDecor._Builder.new()
	var blade := CapsuleMesh.new()
	blade.radius = 0.5
	blade.height = 1.0
	blade.radial_segments = 4
	blade.rings = 1
	var dry := textile.fabric(Color(0.58, 0.55, 0.46), {"fuzz": 0.3, "weave_strength": 0.0})
	for q in range(-outer, outer + 1):
		for r in range(-outer, outer + 1):
			var h := Vector2i(q, r)
			if valley.has(h) or Hex.distance(Vector2i.ZERO, h) > outer:
				continue
			var p := Hex.to_world(h)
			_faded.append(h)
			# A few dry, frayed tufts.
			for k in rng.randi_range(1, 3):
				var off := Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.5, 0.5))
				var y := Textile.patch_height(off, 1.0, FADED_EDGE, FADED_PUFF)
				for b in 3:
					var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, rng.randf_range(0.3, 0.7))
					var top := Vector3(p.x + off.x, y, p.y + off.y) + basis.y * 0.07
					tufts.add("dry", dry, blade, Transform3D(basis.scaled(Vector3(0.018, 0.14, 0.018)), top))
	_faded_land_mi = MeshInstance3D.new()
	_faded_land_mi.material_override = textile.fabric(Color.WHITE, {"weave_scale": 18.0, "weave_strength": 0.14, "fuzz": 0.22, "rough": 1.0})
	_faded_land_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_faded_land_mi)
	var t := MeshInstance3D.new()
	t.mesh = tufts.commit()
	t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(t)
	_inner_r = (outer + 0.5) * 1.5
	_valley_r = (max_d + 0.6) * 1.5


## All faded hexes as one mesh (one draw call), coloured per hex through
## vertex colours.
func _rebuild_faded_land() -> void:
	var src_v: PackedVector3Array = _patch_arrays[0]
	var src_n: PackedVector3Array = _patch_arrays[1]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for h in _faded:
		var p := Hex.to_world(h)
		var off := Vector3(p.x, 0.0, p.y)
		var col := _faded_color(h)
		for k in src_v.size():
			verts.append(src_v[k] + off)
			normals.append(src_n[k])
			colors.append(col)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_faded_land_mi.mesh = mesh


## Faded cloth regains some of the colour of the nearest restored hex:
## more right next to it, a little two hexes away.
func _faded_color(h: Vector2i) -> Color:
	var level := 0.0
	var biome := ""
	for d in [1, 2]:
		for n in _ring(h, d):
			if game.board.has(n):
				biome = game.board[n]
				level = 0.55 if d == 1 else 0.25
				break
		if biome != "":
			break
	return FADED if biome == "" else FADED.lerp(data.biome_color(biome), level)


static func _ring(h: Vector2i, d: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if d == 1:
		return Hex.neighbors(h)
	var cur := h + Hex.DIRECTIONS[4] * d
	for side in 6:
		for _step in d:
			out.append(cur)
			cur = cur + Hex.DIRECTIONS[side]
	return out


# --- Hills ------------------------------------------------------------------

func _quilted_hills(rng: RandomNumberGenerator) -> void:
	var greens := [Color(0.5, 0.66, 0.4), Color(0.58, 0.7, 0.42), Color(0.44, 0.6, 0.38),
		Color(0.62, 0.68, 0.45), Color(0.52, 0.62, 0.36)]
	var dome := SphereMesh.new()
	dome.radius = 0.5
	dome.height = 1.0
	dome.radial_segments = 28
	dome.rings = 14
	var count := 20
	var seams: Array = []
	# All hills go into one mesh (one draw call); colour rides on the vertices.
	var hills := MeshBatch.new()
	hills.textile = textile
	for i in count:
		var a := TAU * i / count + rng.randf_range(-0.1, 0.1)
		var dist := _inner_r + rng.randf_range(5.0, 9.0)
		var radius := rng.randf_range(4.5, 7.0)
		var height := rng.randf_range(2.0, 4.2) * (1.4 if i % 4 == 0 else 1.0)
		var c := Vector2(cos(a), sin(a)) * dist
		var y0 := -height * 0.35
		_domes.append([c, radius, height, y0])
		hills.add(dome, Transform3D(Basis().scaled(Vector3(radius * 2.0, height * 2.0, radius * 2.0)), Vector3(c.x, y0, c.y)),
			Color.WHITE, textile.fabric(greens[i % greens.size()], {"weave_scale": 6.0, "weave_strength": 0.12, "fuzz": 0.18}))
		# Quilting: running stitches round the hill at two heights.
		for frac in [0.25, 0.7]:
			var yh: float = frac * (height + y0)
			var rr := radius * sqrt(maxf(1.0 - pow((yh - y0) / height, 2.0), 0.0))
			var n := 28
			for k in n:
				var a0 := TAU * k / n
				var a1 := TAU * (k + 1) / n
				var p0 := Vector3(c.x + cos(a0) * rr, yh + 0.03, c.y + sin(a0) * rr)
				var p1 := Vector3(c.x + cos(a1) * rr, yh + 0.03, c.y + sin(a1) * rr)
				if _surface(Vector2(p0.x, p0.z)) <= yh + 0.05:
					seams.append([p0, p1])
	var hills_mi := MeshInstance3D.new()
	hills_mi.mesh = hills.commit()
	add_child(hills_mi)
	add_child(textile.stitches(seams, 1, 0.5, 0.035, Color(0.3, 0.36, 0.24)))
	_hill_details(rng)


## Height of the hills at a point on the ground (0 where there are none).
func _surface(p: Vector2) -> float:
	var y := 0.0
	for d: Array in _domes:
		var dist := p.distance_to(d[0])
		var radius: float = d[1]
		if dist < radius:
			y = maxf(y, d[3] + d[2] * sqrt(1.0 - pow(dist / radius, 2.0)))
	return y


## A point on the hills at angle `a`, `t` of the way up from the inner edge.
func _hill_point(a: float, t: float) -> Vector3:
	var dist := _inner_r + 2.0 + t * 8.0
	var p := Vector2(cos(a), sin(a)) * dist
	return Vector3(p.x, _surface(p), p.y)


func _hill_details(rng: RandomNumberGenerator) -> void:
	var b := MeshBatch.new()
	b.textile = textile
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 8
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 10
	ball.rings = 5
	var post := CylinderMesh.new()
	post.top_radius = 0.5
	post.bottom_radius = 0.5
	post.height = 1.0
	post.radial_segments = 6
	var box := BoxMesh.new()
	var felt := {"fuzz": 0.35, "weave_strength": 0.0, "rough": 1.0}
	var tree_greens := [Color(0.22, 0.38, 0.22), Color(0.28, 0.44, 0.25), Color(0.34, 0.5, 0.3)]
	# Woods: clusters of felt trees.
	for cluster in 9:
		var a := rng.randf() * TAU
		if absf(angle_difference(a, STREAM_ANGLE)) < 0.25:
			continue
		var t := rng.randf_range(0.1, 0.9)
		for k in rng.randi_range(4, 8):
			var p3 := _hill_point(a + rng.randf_range(-0.12, 0.12), clampf(t + rng.randf_range(-0.15, 0.15), 0.0, 1.0))
			var s := rng.randf_range(0.8, 1.5)
			var green: Color = tree_greens[rng.randi() % tree_greens.size()]
			var mat := textile.fabric(green, felt)
			if rng.randf() < 0.6:
				b.add(cone, Transform3D(Basis().scaled(Vector3(0.45, 1.1, 0.45) * s), p3 + Vector3(0, 0.5 * s, 0)), Color.WHITE, mat)
				b.add(cone, Transform3D(Basis().scaled(Vector3(0.32, 0.8, 0.32) * s), p3 + Vector3(0, 0.95 * s, 0)), Color.WHITE, mat)
			else:
				b.add(post, Transform3D(Basis().scaled(Vector3(0.1, 0.5, 0.1) * s), p3 + Vector3(0, 0.25 * s, 0)), Color.WHITE, textile.fabric(Color(0.45, 0.32, 0.2), felt))
				b.add(ball, Transform3D(Basis().scaled(Vector3(0.9, 0.8, 0.9) * s), p3 + Vector3(0, 0.75 * s, 0)), Color.WHITE, mat)
	# Sheep.
	var wool := textile.fabric(Color(0.96, 0.95, 0.9), {"fuzz": 0.5, "weave_strength": 0.0})
	var face := textile.fabric(Color(0.2, 0.18, 0.17), felt)
	for k in 7:
		var a := rng.randf() * TAU
		var p3 := _hill_point(a, rng.randf_range(0.05, 0.5))
		var dir := Vector3(cos(a + PI / 2.0), 0, sin(a + PI / 2.0))
		b.add(ball, Transform3D(Basis().scaled(Vector3(0.42, 0.3, 0.3)), p3 + Vector3(0, 0.2, 0)), Color.WHITE, wool)
		b.add(ball, Transform3D(Basis().scaled(Vector3.ONE * 0.16), p3 + dir * 0.22 + Vector3(0, 0.25, 0)), Color.WHITE, face)
	# Cottages with red roofs and chimneys.
	var wall := textile.fabric(Color(0.95, 0.92, 0.84), {"weave_scale": 20.0, "weave_strength": 0.1})
	var roof := textile.fabric(Color(0.72, 0.32, 0.26), {"weave_scale": 12.0, "weave_strength": 0.15})
	var prism := CylinderMesh.new()
	prism.top_radius = 0.5
	prism.bottom_radius = 0.5
	prism.height = 1.0
	prism.radial_segments = 3
	for k in 3:
		var a := STREAM_ANGLE + 0.5 + k * 1.9
		var p3 := _hill_point(a, 0.15)
		var spin := Basis(Vector3.UP, -a)
		b.add(box, Transform3D(spin.scaled(Vector3(0.9, 0.6, 0.7)), p3 + Vector3(0, 0.3, 0)), Color.WHITE, wall)
		var roof_basis := spin * Basis(Vector3.RIGHT, PI / 2.0) * Basis(Vector3.UP, PI / 6.0)
		b.add(prism, Transform3D(roof_basis.scaled(Vector3(0.95, 0.95, 0.95)), p3 + Vector3(0, 0.82, 0)), Color.WHITE, roof)
		var chimney := p3 + spin * Vector3(0.25, 1.0, 0.1)
		b.add(box, Transform3D(spin.scaled(Vector3(0.14, 0.35, 0.14)), chimney), Color.WHITE, roof)
		_cottages.append(chimney + Vector3(0, 0.25, 0))
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	add_child(mi)


## A silk stream that comes down from the hills and ends in a small pool at
## the valley's edge.
func _stream_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	var start := _inner_r + 9.0
	var end := _valley_r + 0.4
	var steps := 40
	for i in steps + 1:
		var t := float(i) / steps
		var dist := lerpf(start, end, t)
		var a := STREAM_ANGLE + sin(t * 7.0) * 0.08
		var p := Vector2(cos(a), sin(a)) * dist
		var y := maxf(_surface(p), FADED_EDGE + FADED_PUFF) + 0.05
		pts.append(Vector3(p.x, y, p.y))
	for i in steps:
		var a := pts[i]
		var b := pts[i + 1]
		var dir := (b - a).normalized()
		var side := Vector3(-dir.z, 0, dir.x).normalized()
		var w0 := lerpf(0.25, 0.45, float(i) / steps)
		var w1 := lerpf(0.25, 0.45, float(i + 1) / steps)
		var quad := [a + side * w0, b + side * w1, b - side * w1, a - side * w0]
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_normal(Vector3.UP)
			st.add_vertex(quad[idx])
	var mesh := st.commit()
	# Pool where it meets the valley (a separate surface: appending a primitive
	# to hand-built vertices in one SurfaceTool drops the hand-built ones).
	var pool := CylinderMesh.new()
	pool.top_radius = 1.0
	pool.bottom_radius = 1.0
	pool.height = 0.02
	pool.radial_segments = 20
	var ps := SurfaceTool.new()
	ps.begin(Mesh.PRIMITIVE_TRIANGLES)
	ps.append_from(pool, 0, Transform3D(Basis().scaled(Vector3(0.8, 1.0, 0.6)), pts[-1]))
	ps.commit(mesh)
	_stream = MeshInstance3D.new()
	_stream.mesh = mesh
	_stream.material_override = textile.fabric(Color(0.5, 0.76, 0.9), {"weave_scale": 30.0, "weave_strength": 0.05, "sheen": 1.0, "rough": 0.3})
	_stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_stream)


func _distant_hills(rng: RandomNumberGenerator) -> void:
	var dome := SphereMesh.new()
	dome.radius = 0.5
	dome.height = 1.0
	dome.radial_segments = 20
	dome.rings = 8
	var layers := [[38.0, Color(0.5, 0.6, 0.5)], [52.0, Color(0.6, 0.67, 0.62)], [70.0, Color(0.72, 0.76, 0.74)]]
	for layer: Array in layers:
		var b := MeshBatch.new()
		b.textile = textile
		var mat := textile.fabric(layer[1], {"weave_scale": 2.0, "weave_strength": 0.08, "fuzz": 0.1})
		for i in 16:
			var a := TAU * i / 16.0 + rng.randf_range(-0.15, 0.15)
			var dist: float = layer[0] + rng.randf_range(-4.0, 4.0)
			var radius := rng.randf_range(9.0, 15.0)
			var height: float = rng.randf_range(5.0, 11.0) * float(layer[0]) / 40.0
			b.add(dome, Transform3D(Basis().scaled(Vector3(radius * 2.0, height * 2.0, radius * 2.0)), Vector3(cos(a) * dist, -height * 0.3, sin(a) * dist)), Color.WHITE, mat)
		var mi := MeshInstance3D.new()
		mi.mesh = b.commit()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _make_clouds(rng: RandomNumberGenerator) -> void:
	_clouds = Node3D.new()
	add_child(_clouds)
	var b := MeshBatch.new()
	b.textile = textile
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 12
	ball.rings = 6
	var mat := textile.fabric(Color(0.98, 0.97, 0.95), {"fuzz": 0.35, "weave_strength": 0.0})
	for i in 7:
		var a := TAU * i / 7.0 + rng.randf()
		var dist := rng.randf_range(26.0, 46.0)
		var c := Vector3(cos(a) * dist, rng.randf_range(13.0, 19.0), sin(a) * dist)
		for k in rng.randi_range(3, 5):
			var off := Vector3(rng.randf_range(-3.0, 3.0), rng.randf_range(-0.4, 0.6), rng.randf_range(-1.5, 1.5))
			var s := rng.randf_range(2.5, 4.5)
			b.add(ball, Transform3D(Basis().scaled(Vector3(s * 1.4, s * 0.7, s)), c + off), Color.WHITE, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_clouds.add_child(mi)


# --- Helpers ------------------------------------------------------------------

func _felt_animal(id: String, size: float) -> Node3D:
	var node := Node3D.new()
	var col := Color(0.62, 0.44, 0.28) if id == "deer" else Color(0.36, 0.27, 0.21)
	var felt := {"fuzz": 0.4, "weave_strength": 0.0, "rough": 1.0}
	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.14 * size
	bm.height = 0.55 * size
	body.mesh = bm
	body.rotation.z = PI / 2.0
	body.position.y = (0.45 if id == "deer" else 0.18) * size
	body.material_override = textile.fabric(col, felt)
	node.add_child(body)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.11 * size
	hm.height = 0.22 * size
	head.mesh = hm
	head.position = Vector3(0.26, 0.68 if id == "deer" else 0.26, 0) * size
	head.material_override = textile.fabric(col.lightened(0.12), felt)
	node.add_child(head)
	return node


static func _greyed(c: Color, amount: float) -> Color:
	var grey := Color(c.get_luminance(), c.get_luminance(), c.get_luminance())
	return c.lerp(grey, clampf(amount, 0.0, 1.0)).lerp(FADED, amount * 0.25)
