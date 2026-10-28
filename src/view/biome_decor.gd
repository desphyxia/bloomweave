class_name BiomeDecor
extends RefCounted
## Sewn-on details for each biome patch. Every tile gets its own layout,
## counts and sizes (seeded by its hex, so the placement preview matches the
## placed tile), a slightly different fabric shade, and now and then a rare
## extra. All details on one tile are merged into a single mesh.
##
##   forest  - felt pines and round trees, shrubs; rare mushroom or log
##   meadow  - stitched grass tufts and small daisy-stitch wildflowers; rare
##             rabbit or stone
##   wetland - thread reeds with cattails, felt lily pads, wavy running-stitch
##             ripples; rare frog on a lily pad or a duck
##   heath   - French-knot heather in mixed purples, gorse; rare boulder or
##             birch

const FLOWER_COLORS := [Color(1.0, 0.98, 0.94), Color(0.99, 0.9, 0.45), Color(0.96, 0.66, 0.78),
	Color(0.78, 0.68, 0.95), Color(0.62, 0.78, 0.98)]

var textile: Textile
var edge_h: float
var puff: float
var _prims := {}


func _init(p_textile: Textile, p_edge_h: float, p_puff: float) -> void:
	textile = p_textile
	edge_h = p_edge_h
	puff = p_puff


## A slightly lighter or darker shade of a biome colour, fixed per tile.
static func tile_tint(h: Vector2i, color: Color) -> Color:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(h) ^ 0x5eed
	var step := rng.randi_range(-2, 2) * 0.035
	var c := color.lightened(step) if step > 0.0 else color.darkened(-step)
	c.h = fposmod(c.h + rng.randf_range(-0.012, 0.012), 1.0)
	return c


func build(h: Vector2i, biome: String, ghost: bool) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(h)
	var b := _Builder.new()
	var used: Array[Vector3] = []   # (x, z, radius) of things already placed
	match biome:
		"forest":
			_forest(b, rng, used, ghost)
		"meadow":
			_meadow(b, rng, used, ghost)
		"wetland":
			_wetland(b, rng, used, ghost)
		"heath":
			_heath(b, rng, used, ghost)
	return b.commit()


# --- Biomes -------------------------------------------------------------------

func _forest(b: _Builder, rng: RandomNumberGenerator, used: Array[Vector3], ghost: bool) -> void:
	var greens := [Color(0.2, 0.38, 0.22), Color(0.25, 0.44, 0.24), Color(0.3, 0.48, 0.27)]
	for i in rng.randi_range(3, 6):
		var s := rng.randf_range(0.75, 1.3)
		var p := _spot(rng, used, 0.15 * s, 0.72)
		if not p.is_finite():
			break
		var at := p
		var green: Color = greens[rng.randi() % greens.size()]
		if rng.randf() < 0.7:
			var tiers := 2 if rng.randf() < 0.6 else 3
			for t in tiers:
				var r := (0.19 - t * 0.045) * s
				var y := _y(at) + (0.12 + t * 0.14) * s
				b.add("felt" + green.to_html(), _felt(green, ghost), _cone(), _xf(at, y, Vector3(r, 0.3 * s, r)))
		else:
			var trunk := Color(0.45, 0.32, 0.2)
			b.add("felt" + trunk.to_html(), _felt(trunk, ghost), _cylinder(), _xf(at, _y(at) + 0.08 * s, Vector3(0.035 * s, 0.16 * s, 0.035 * s)))
			var crown := green.lightened(0.15)
			b.add("felt" + crown.to_html(), _felt(crown, ghost), _sphere(), _xf(at, _y(at) + 0.25 * s, Vector3(0.36, 0.3, 0.36) * s))
	for i in rng.randi_range(1, 4):
		var p := _spot(rng, used, 0.07, 0.78)
		if not p.is_finite():
			break
		var shrub := Color(0.32, 0.5, 0.3)
		b.add("felt" + shrub.to_html(), _felt(shrub, ghost), _sphere(), _xf(p, _y(p) + 0.03, Vector3(0.15, 0.09, 0.15)))
	var roll := rng.randf()
	if roll < 0.14:
		var p := _spot(rng, used, 0.08, 0.7)
		if p.is_finite():
			var stem := Color(0.96, 0.93, 0.86)
			var cap := Color(0.82, 0.22, 0.2)
			b.add("felt" + stem.to_html(), _felt(stem, ghost), _cylinder(), _xf(p, _y(p) + 0.04, Vector3(0.03, 0.08, 0.03)))
			b.add("felt" + cap.to_html(), _felt(cap, ghost), _sphere(), _xf(p, _y(p) + 0.09, Vector3(0.12, 0.07, 0.12)))
			for k in 3:
				var d: Vector2 = p + Vector2.from_angle(TAU * k / 3.0) * 0.03
				b.add("felt" + stem.to_html(), _felt(stem, ghost), _sphere(), _xf(d, _y(p) + 0.12, Vector3.ONE * 0.022))
	elif roll < 0.24:
		var p := _spot(rng, used, 0.16, 0.6)
		if p.is_finite():
			var bark := Color(0.5, 0.36, 0.24)
			var basis := Basis(Vector3.UP, rng.randf() * PI) * Basis(Vector3.FORWARD, PI / 2.0)
			b.add("felt" + bark.to_html(), _felt(bark, ghost), _cylinder(), Transform3D(basis.scaled(Vector3(0.055, 0.32, 0.055)), Vector3(p.x, _y(p) + 0.04, p.y)))


func _meadow(b: _Builder, rng: RandomNumberGenerator, used: Array[Vector3], ghost: bool) -> void:
	var grass := [Color(0.42, 0.6, 0.28), Color(0.5, 0.66, 0.3), Color(0.36, 0.54, 0.26)]
	for i in rng.randi_range(4, 7):
		var p := _spot(rng, used, 0.08, 0.8)
		if not p.is_finite():
			break
		var col: Color = grass[rng.randi() % grass.size()]
		var blades := rng.randi_range(4, 7)
		var spin := rng.randf() * TAU
		for k in blades:
			var a := spin + TAU * k / blades
			var tilt := rng.randf_range(0.25, 0.55)
			var length := rng.randf_range(0.14, 0.24)
			var basis := Basis(Vector3.UP, -a) * Basis(Vector3.BACK, tilt)
			var top := Vector3(p.x, _y(p), p.y) + basis.y * length * 0.5
			b.add("thread" + col.to_html(), _thread(col, ghost), _capsule(), Transform3D(basis.scaled(Vector3(0.014, length, 0.014)), top))
	for i in rng.randi_range(5, 9):
		var p := _spot(rng, used, 0.06, 0.82)
		if not p.is_finite():
			break
		var col: Color = FLOWER_COLORS[rng.randi() % FLOWER_COLORS.size()]
		var y := _y(p) + 0.012
		var spin := rng.randf() * TAU
		var size := rng.randf_range(1.1, 1.6)
		for k in 5:
			var a := spin + TAU * k / 5.0
			var off: Vector2 = p + Vector2.from_angle(a) * 0.032 * size
			var basis := Basis(Vector3.UP, -a).scaled(Vector3(0.05, 0.016, 0.028) * size)
			b.add("satin" + col.to_html(), _satin(col, ghost), _sphere(), Transform3D(basis, Vector3(off.x, y, off.y)))
		var heart := Color(0.96, 0.75, 0.25)
		b.add("satin" + heart.to_html(), _satin(heart, ghost), _sphere(), _xf(p, y + 0.008, Vector3.ONE * 0.026 * size))
	var roll := rng.randf()
	if roll < 0.1:
		_rabbit(b, rng, used, ghost)
	elif roll < 0.2:
		_stone(b, rng, used, ghost, 0.08)


func _wetland(b: _Builder, rng: RandomNumberGenerator, used: Array[Vector3], ghost: bool) -> void:
	# Ripples: arcs of short running stitches on the silk.
	var ripple := Color(0.36, 0.56, 0.74)
	for i in rng.randi_range(2, 4):
		var c := Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4))
		var r := rng.randf_range(0.12, 0.3)
		var a0 := rng.randf() * TAU
		var span := rng.randf_range(1.2, 2.4)
		var dashes := int(span * r / 0.05) + 2
		for k in dashes:
			if k % 2 == 1:
				continue
			var a := a0 + span * k / dashes
			var p := c + Vector2.from_angle(a) * r
			if Textile.hex_t(p, 1.0) > 0.85:
				continue
			var dir := Vector2.from_angle(a + PI / 2.0)
			var basis := Basis(Vector3.UP, -dir.angle()) * Basis(Vector3.FORWARD, PI / 2.0)
			b.add("thread" + ripple.to_html(), _thread(ripple, ghost), _capsule(), Transform3D(basis.scaled(Vector3(0.016, span * r / dashes * 0.9, 0.012)), Vector3(p.x, _y(p) + 0.006, p.y)))
	# Lily pads.
	var pads: Array[Vector2] = []
	for i in rng.randi_range(1, 3):
		var p := _spot(rng, used, rng.randf_range(0.1, 0.15), 0.7)
		if not p.is_finite():
			break
		pads.append(p)
		var r: float = used[-1].z
		var pad := Color(0.34, 0.56, 0.32) if rng.randf() < 0.6 else Color(0.42, 0.62, 0.36)
		b.add("felt" + pad.to_html(), _felt(pad, ghost), _cylinder(), _xf(p, _y(p) + 0.008, Vector3(r * 2.0, 0.012, r * 2.0)))
		if rng.randf() < 0.35:
			var bloom := Color(0.97, 0.78, 0.86) if rng.randf() < 0.5 else Color(1.0, 0.98, 0.95)
			for k in 5:
				var off: Vector2 = p + Vector2.from_angle(TAU * k / 5.0) * 0.025
				b.add("satin" + bloom.to_html(), _satin(bloom, ghost), _sphere(), _xf(off, _y(p) + 0.03, Vector3(0.045, 0.03, 0.045)))
	# Reed clumps.
	var reed := Color(0.48, 0.55, 0.3)
	var cattail := Color(0.45, 0.3, 0.18)
	for i in rng.randi_range(1, 3):
		var p := _spot(rng, used, 0.09, 0.75)
		if not p.is_finite():
			break
		for k in rng.randi_range(3, 6):
			var off: Vector2 = p + Vector2(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.05, 0.05))
			var length := rng.randf_range(0.26, 0.46)
			var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, rng.randf_range(0.0, 0.18))
			var base := Vector3(off.x, _y(off), off.y)
			b.add("thread" + reed.to_html(), _thread(reed, ghost), _capsule(), Transform3D(basis.scaled(Vector3(0.012, length, 0.012)), base + basis.y * length * 0.5))
			if rng.randf() < 0.5:
				b.add("felt" + cattail.to_html(), _felt(cattail, ghost), _capsule(), Transform3D(basis.scaled(Vector3(0.032, 0.1, 0.032)), base + basis.y * (length - 0.04)))
	var roll := rng.randf()
	if roll < 0.1 and not pads.is_empty():
		var p := pads[0]
		var frog := Color(0.4, 0.66, 0.3)
		b.add("felt" + frog.to_html(), _felt(frog, ghost), _sphere(), _xf(p, _y(p) + 0.05, Vector3(0.09, 0.06, 0.08)))
		for side in [-1.0, 1.0]:
			var eye: Vector2 = p + Vector2(0.025, side * 0.025)
			b.add("felt" + frog.to_html(), _felt(frog, ghost), _sphere(), _xf(eye, _y(p) + 0.085, Vector3.ONE * 0.03))
	elif roll < 0.17:
		var p := _spot(rng, used, 0.08, 0.6)
		if p.is_finite():
			var white := Color(0.97, 0.96, 0.92)
			var beak := Color(0.95, 0.62, 0.2)
			b.add("felt" + white.to_html(), _felt(white, ghost), _sphere(), _xf(p, _y(p) + 0.04, Vector3(0.14, 0.08, 0.09)))
			var head: Vector2 = p + Vector2(0.055, 0.0)
			b.add("felt" + white.to_html(), _felt(white, ghost), _sphere(), _xf(head, _y(p) + 0.1, Vector3.ONE * 0.055))
			b.add("felt" + beak.to_html(), _felt(beak, ghost), _sphere(), _xf(head + Vector2(0.035, 0.0), _y(p) + 0.095, Vector3(0.04, 0.015, 0.025)))


func _heath(b: _Builder, rng: RandomNumberGenerator, used: Array[Vector3], ghost: bool) -> void:
	var purples := [Color(0.45, 0.27, 0.52), Color(0.58, 0.32, 0.6), Color(0.7, 0.42, 0.68)]
	for i in rng.randi_range(4, 7):
		var p := _spot(rng, used, 0.09, 0.8)
		if not p.is_finite():
			break
		for k in rng.randi_range(6, 11):
			var col: Color = purples[rng.randi() % purples.size()]
			var off: Vector2 = p + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 0.09)
			b.add("felt" + col.to_html(), _felt(col, ghost), _sphere(), _xf(off, _y(off) + 0.03, Vector3.ONE * rng.randf_range(0.07, 0.11)))
	var gorse := Color(0.93, 0.78, 0.3)
	var spines := Color(0.3, 0.42, 0.26)
	for i in rng.randi_range(0, 2):
		var p := _spot(rng, used, 0.08, 0.75)
		if not p.is_finite():
			break
		b.add("felt" + spines.to_html(), _felt(spines, ghost), _sphere(), _xf(p, _y(p) + 0.03, Vector3(0.15, 0.08, 0.15)))
		for k in rng.randi_range(4, 7):
			var off: Vector2 = p + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 0.06)
			b.add("felt" + gorse.to_html(), _felt(gorse, ghost), _sphere(), _xf(off, _y(off) + 0.07, Vector3.ONE * 0.04))
	var roll := rng.randf()
	if roll < 0.12:
		_stone(b, rng, used, ghost, 0.13)
	elif roll < 0.18:
		var p := _spot(rng, used, 0.12, 0.6)
		if p.is_finite():
			var bark := Color(0.94, 0.93, 0.88)
			var leaves := Color(0.6, 0.74, 0.36)
			b.add("felt" + bark.to_html(), _felt(bark, ghost), _cylinder(), _xf(p, _y(p) + 0.12, Vector3(0.03, 0.24, 0.03)))
			b.add("felt" + leaves.to_html(), _felt(leaves, ghost), _sphere(), _xf(p, _y(p) + 0.3, Vector3(0.22, 0.26, 0.22)))


func _rabbit(b: _Builder, rng: RandomNumberGenerator, used: Array[Vector3], ghost: bool) -> void:
	var p := _spot(rng, used, 0.08, 0.6)
	if not p.is_finite():
		return
	var fur := Color(0.72, 0.6, 0.48) if rng.randf() < 0.6 else Color(0.66, 0.64, 0.62)
	var face := Vector2.from_angle(rng.randf() * TAU)
	var y := _y(p)
	b.add("felt" + fur.to_html(), _felt(fur, ghost), _sphere(), _xf(p, y + 0.05, Vector3(0.11, 0.09, 0.09)))
	var head: Vector2 = p + face * 0.06
	b.add("felt" + fur.to_html(), _felt(fur, ghost), _sphere(), _xf(head, y + 0.1, Vector3.ONE * 0.06))
	for side in [-1.0, 1.0]:
		var ear: Vector2 = head + face.orthogonal() * side * 0.015
		b.add("felt" + fur.to_html(), _felt(fur, ghost), _capsule(), _xf(ear, y + 0.16, Vector3(0.018, 0.08, 0.018)))
	var tail := Color(0.97, 0.96, 0.93)
	b.add("felt" + tail.to_html(), _felt(tail, ghost), _sphere(), _xf(p - face * 0.055, y + 0.06, Vector3.ONE * 0.035))


func _stone(b: _Builder, rng: RandomNumberGenerator, used: Array[Vector3], ghost: bool, size: float) -> void:
	var p := _spot(rng, used, size, 0.65)
	if not p.is_finite():
		return
	var grey := Color(0.62, 0.6, 0.57).darkened(rng.randf() * 0.15)
	var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(size * 2.0, size * 1.1, size * 1.6))
	b.add("felt" + grey.to_html(), _felt(grey, ghost), _sphere(), Transform3D(basis, Vector3(p.x, _y(p) + size * 0.3, p.y)))


# --- Helpers ------------------------------------------------------------------

## A free spot on the patch (local x, z), at least `radius` from other
## details and inside the hex (hex_t <= max_t). Records it in `used`.
## Returns Vector2.INF when the patch is too full.
func _spot(rng: RandomNumberGenerator, used: Array[Vector3], radius: float, max_t: float) -> Vector2:
	for _try in 24:
		var p := Vector2(rng.randf_range(-0.85, 0.85), rng.randf_range(-0.8, 0.8))
		if Textile.hex_t(p, 1.0) > max_t:
			continue
		var ok := true
		for u in used:
			if p.distance_to(Vector2(u.x, u.y)) < radius + u.z:
				ok = false
				break
		if ok:
			used.append(Vector3(p.x, p.y, radius))
			return p
	return Vector2.INF


func _y(local: Vector2) -> float:
	return Textile.patch_height(local, 1.0, edge_h, puff)


static func _xf(at: Vector2, y: float, scale: Vector3) -> Transform3D:
	return Transform3D(Basis().scaled(scale), Vector3(at.x, y, at.y))


func _felt(c: Color, ghost: bool) -> Material:
	return textile.fabric(c, {"fuzz": 0.35, "weave_strength": 0.0, "rough": 1.0}, ghost)


func _satin(c: Color, ghost: bool) -> Material:
	return textile.satin(c, ghost)


func _thread(c: Color, ghost: bool) -> Material:
	return textile.satin(c, true) if ghost else textile.thread(c)


## Unit primitives (size 1), scaled per use.
func _sphere() -> Mesh:
	if not _prims.has("sphere"):
		var m := SphereMesh.new()
		m.radius = 0.5
		m.height = 1.0
		m.radial_segments = 8
		m.rings = 4
		_prims.sphere = m
	return _prims.sphere


func _cone() -> Mesh:
	if not _prims.has("cone"):
		var m := CylinderMesh.new()
		m.top_radius = 0.0
		m.bottom_radius = 1.0
		m.height = 1.0
		m.radial_segments = 8
		m.rings = 1
		_prims.cone = m
	return _prims.cone


func _cylinder() -> Mesh:
	if not _prims.has("cylinder"):
		var m := CylinderMesh.new()
		m.top_radius = 0.5
		m.bottom_radius = 0.5
		m.height = 1.0
		m.radial_segments = 10
		m.rings = 1
		_prims.cylinder = m
	return _prims.cylinder


func _capsule() -> Mesh:
	if not _prims.has("capsule"):
		var m := CapsuleMesh.new()
		m.radius = 0.5
		m.height = 1.0
		m.radial_segments = 6
		m.rings = 2
		_prims.capsule = m
	return _prims.capsule


## Collects primitives into one mesh, one surface per material.
class _Builder:
	var _surfaces := {}  # key -> [SurfaceTool, Material]

	func add(key: String, mat: Material, mesh: Mesh, xf: Transform3D) -> void:
		if not _surfaces.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			_surfaces[key] = [st, mat]
		(_surfaces[key][0] as SurfaceTool).append_from(mesh, 0, xf)

	func commit() -> ArrayMesh:
		if _surfaces.is_empty():
			return null
		var mesh := ArrayMesh.new()
		var i := 0
		for key: String in _surfaces:
			(_surfaces[key][0] as SurfaceTool).commit(mesh)
			mesh.surface_set_material(i, _surfaces[key][1])
			i += 1
		return mesh
