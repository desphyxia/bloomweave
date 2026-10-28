class_name Textile
extends RefCounted
## Materials and meshes for the quilt look: puffy fabric patches, thread,
## satin-stitch flowers and rows of running stitches. Results are cached so
## the board can reuse them cheaply.

const FABRIC := preload("res://src/view/shaders/fabric.gdshader")
const FABRIC_GHOST := preload("res://src/view/shaders/fabric_ghost.gdshader")
const SATIN := preload("res://src/view/shaders/satin.gdshader")
const SATIN_GHOST := preload("res://src/view/shaders/satin_ghost.gdshader")
const THREAD := preload("res://src/view/shaders/thread.gdshader")

const GHOST_OPACITY := 0.72
# Colours are passed as-is: the Compatibility renderer (web and mobile) lights
# them without a linear conversion, the same way StandardMaterial3D looks.
const FABRIC_KEYS := ["weave_scale", "weave_strength", "fuzz", "fleck", "sheen", "rough"]

var _cache := {}


# --- Materials ----------------------------------------------------------------

## Woven fabric. `params` may hold weave_scale, weave_strength, fuzz, fleck,
## fleck_color, sheen and rough (see data/biomes.json).
func fabric(color: Color, params: Dictionary = {}, ghost: bool = false) -> ShaderMaterial:
	var key := "fabric|%s|%s|%s" % [color.to_html(), JSON.stringify(params), ghost]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = FABRIC_GHOST if ghost else FABRIC
	m.set_shader_parameter("base_color", color)
	for k: String in FABRIC_KEYS:
		if params.has(k):
			m.set_shader_parameter(k, float(params[k]))
	if params.has("fleck_color"):
		m.set_shader_parameter("fleck_color", Color(params.fleck_color))
	m.set_shader_parameter("opacity", GHOST_OPACITY)
	_cache[key] = m
	return m


func satin(color: Color, ghost: bool = false) -> ShaderMaterial:
	var key := "satin|%s|%s" % [color.to_html(), ghost]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = SATIN_GHOST if ghost else SATIN
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("opacity", GHOST_OPACITY)
	_cache[key] = m
	return m


func thread(color: Color) -> ShaderMaterial:
	var key := "thread|%s" % color.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = THREAD
	m.set_shader_parameter("color", color)
	_cache[key] = m
	return m


# --- Patch shape --------------------------------------------------------------

## 0 at the centre of a flat-top hex of corner radius `radius`, 1 on its
## edges (distance to the nearest edge, in hex terms).
static func hex_t(local: Vector2, radius: float) -> float:
	var apothem := radius * Hex.SQRT3 / 2.0
	var t := 0.0
	for deg in [30.0, 90.0, 150.0]:
		var n := Vector2(cos(deg_to_rad(deg)), sin(deg_to_rad(deg)))
		t = maxf(t, absf(local.dot(n)) / apothem)
	return t


## Height of a puffy patch at a local point: `edge_h` on the edges, rising
## to `edge_h + puff` in the middle, like a stuffed quilt square.
static func patch_height(local: Vector2, radius: float, edge_h: float, puff: float) -> float:
	var t := clampf(hex_t(local, radius), 0.0, 1.0)
	return edge_h + puff * (1.0 - t * t * t)


## A domed hex patch with short side walls down to y = 0.
func patch_mesh(radius: float, edge_h: float, puff: float, subdiv: int = 6) -> ArrayMesh:
	var key := "patch|%.3f|%.3f|%.3f|%d" % [radius, edge_h, puff, subdiv]
	if _cache.has(key):
		return _cache[key]
	var mesh := _patch_top(radius, edge_h, puff, subdiv, false)
	if _first_normal_y(mesh) < 0.0:
		mesh = _patch_top(radius, edge_h, puff, subdiv, true)
	# Side walls (explicit outward normals, so they stay crisp).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		var a := Hex.corner_offset(i, radius)
		var b := Hex.corner_offset(i + 1, radius)
		var n := Vector3((a.x + b.x) / 2.0, 0.0, (a.y + b.y) / 2.0).normalized()
		var quad := [Vector3(a.x, edge_h, a.y), Vector3(b.x, edge_h, b.y),
			Vector3(b.x, 0.0, b.y), Vector3(a.x, 0.0, a.y)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.add_vertex(quad[idx])
	st.commit(mesh)
	_cache[key] = mesh
	return mesh


func _patch_top(radius: float, edge_h: float, puff: float, n: int, flip: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		var c0 := Hex.corner_offset(i, radius)
		var c1 := Hex.corner_offset(i + 1, radius)
		var pt := func(u: int, v: int) -> Vector3:
			var p := (c0 * u + c1 * v) / float(n)
			var t := float(u + v) / float(n)
			return Vector3(p.x, edge_h + puff * (1.0 - t * t * t), p.y)
		for u in n:
			for v in n - u:
				var tri := [pt.call(u, v), pt.call(u + 1, v), pt.call(u, v + 1)]
				_add_tri(st, tri, flip)
				if u + v < n - 1:
					_add_tri(st, [pt.call(u + 1, v), pt.call(u + 1, v + 1), pt.call(u, v + 1)], flip)
	st.index()
	st.generate_normals()
	return st.commit()


static func _add_tri(st: SurfaceTool, tri: Array, flip: bool) -> void:
	if flip:
		st.add_vertex(tri[0])
		st.add_vertex(tri[2])
		st.add_vertex(tri[1])
	else:
		st.add_vertex(tri[0])
		st.add_vertex(tri[1])
		st.add_vertex(tri[2])


static func _first_normal_y(mesh: ArrayMesh) -> float:
	var arrays := mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	# The highest vertex is the patch centre; its normal should point up.
	var best := 0
	for i in verts.size():
		if verts[i].y > verts[best].y:
			best = i
	return normals[best].y


# --- Thread -------------------------------------------------------------------

## A round thread following each polyline in `lines` (Arrays of Vector3),
## with rounded joints. UV.x runs along the thread for the twist pattern.
func tube_mesh(lines: Array, radius: float, sides: int = 8) -> ArrayMesh:
	if lines.is_empty():
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for line: Array in lines:
		var run := 0.0
		for s in line.size() - 1:
			var a: Vector3 = line[s]
			var b: Vector3 = line[s + 1]
			var dir := (b - a).normalized()
			var side := dir.cross(Vector3.UP).normalized()
			if side.length() < 0.01:
				side = Vector3.RIGHT
			var up := side.cross(dir).normalized()
			var length := a.distance_to(b)
			for k in sides:
				var a0 := TAU * k / sides
				var a1 := TAU * (k + 1) / sides
				var n0 := side * cos(a0) + up * sin(a0)
				var n1 := side * cos(a1) + up * sin(a1)
				var quad := [
					[a + n0 * radius, n0, Vector2(run, float(k) / sides)],
					[b + n0 * radius, n0, Vector2(run + length, float(k) / sides)],
					[b + n1 * radius, n1, Vector2(run + length, float(k + 1) / sides)],
					[a + n1 * radius, n1, Vector2(run, float(k + 1) / sides)],
				]
				for idx in [0, 1, 2, 0, 2, 3]:
					st.set_normal(quad[idx][1])
					st.set_uv(quad[idx][2])
					st.add_vertex(quad[idx][0])
			run += length
	var mesh := st.commit()
	# Round the joints with small beads.
	var bead := SphereMesh.new()
	bead.radius = radius
	bead.height = radius * 2.0
	bead.radial_segments = sides
	bead.rings = 4
	var joints := SurfaceTool.new()
	joints.begin(Mesh.PRIMITIVE_TRIANGLES)
	for line: Array in lines:
		for p: Vector3 in line:
			joints.append_from(bead, 0, Transform3D(Basis(), p))
	joints.commit(mesh)
	return mesh


## Running stitches: `per_edge` short dashes along each segment [a, b].
func stitches(segments: Array, per_edge: int, dash: float, radius: float, color: Color) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	if segments.is_empty():
		return mmi
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = dash
	capsule.radial_segments = 6
	capsule.rings = 2
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = capsule
	mm.instance_count = segments.size() * per_edge
	var idx := 0
	for seg: Array in segments:
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		var y := (b - a).normalized()
		var x := y.cross(Vector3.UP).normalized()
		var z := x.cross(y).normalized()
		var basis := Basis(x, y, z)
		for k in per_edge:
			var f := (k + 0.5) / per_edge
			mm.set_instance_transform(idx, Transform3D(basis, a.lerp(b, f)))
			idx += 1
	mmi.multimesh = mm
	mmi.material_override = thread(color)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


# --- Flowers ------------------------------------------------------------------

## An embroidered flower: two satin leaves, five satin petals and a
## French-knot centre. One mesh with three surfaces, cached per colour.
func flower_mesh(petal_color: Color, ghost: bool = false) -> ArrayMesh:
	var key := "flower|%s|%s" % [petal_color.to_html(), ghost]
	if _cache.has(key):
		return _cache[key]
	var mesh := ArrayMesh.new()
	var blob := SphereMesh.new()
	blob.radius = 0.5
	blob.height = 1.0
	blob.radial_segments = 10
	blob.rings = 5
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	for a in [0.6, 0.6 + PI]:
		var b := Basis(Vector3.UP, -a).scaled(Vector3(0.34, 0.05, 0.14))
		leaves.append_from(blob, 0, Transform3D(b, Vector3(cos(a) * 0.17, 0.02, sin(a) * 0.17)))
	leaves.commit(mesh)
	var petals := SurfaceTool.new()
	petals.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 5:
		var a := TAU * i / 5.0
		var b := Basis(Vector3.UP, -a).scaled(Vector3(0.2, 0.07, 0.13))
		petals.append_from(blob, 0, Transform3D(b, Vector3(cos(a) * 0.1, 0.06, sin(a) * 0.1)))
	petals.commit(mesh)
	var knot := SurfaceTool.new()
	knot.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in [Vector3(0.0, 0.1, 0.0), Vector3(0.03, 0.09, 0.02), Vector3(-0.03, 0.09, 0.02), Vector3(0.0, 0.09, -0.035)]:
		knot.append_from(blob, 0, Transform3D(Basis().scaled(Vector3.ONE * 0.06), p))
	knot.commit(mesh)
	mesh.surface_set_material(0, satin(Color(0.35, 0.55, 0.3), ghost))
	mesh.surface_set_material(1, satin(petal_color, ghost))
	mesh.surface_set_material(2, satin(Color(0.96, 0.75, 0.25), ghost))
	_cache[key] = mesh
	return mesh
