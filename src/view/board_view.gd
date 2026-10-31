class_name BoardView
extends Node3D
## Draws the valley as a quilt: puffy fabric patches, running stitches along
## piece seams, embroidered blooms, thread corridors, animals and the
## placement ghost. Holds no game rules.

const HEX_SIZE := 1.0
const SEAM_H := 0.12    # patch height at its edges, where seams, blooms and trails sit
const PUFF := 0.21      # extra height in the middle of a patch
const TILE_H := 0.2     # picking plane for taps
const FLOWER_SCALE := 1.9
const FLOWER_LIFT := 0.26  # blooms stand this high above the corner
const SLOT_H := 0.035   # thickness of an empty plot's backing cloth
const SLOT_INSET := 0.05  # gap between neighbouring empty plots

const SEAM_THREAD := Color(0.27, 0.22, 0.17)
const TACK_THREAD := Color(0.56, 0.5, 0.41)
const LEGAL_THREAD := Color(0.84, 0.44, 0.26)
const TRAIL_THREAD := Color(0.93, 0.38, 0.56)
const STAR_THREAD := Color(1.0, 0.82, 0.35)
const SLOT_CLOTH := Color(0.74, 0.7, 0.61)
const LEGAL_CLOTH := Color(0.88, 0.84, 0.72)
const SLOT_FABRIC := {"weave_scale": 16.0, "weave_strength": 0.1, "fuzz": 0.05, "rough": 1.0}

var game: ValleyGame
var data: GameData
var textile := Textile.new()
var decor := BiomeDecor.new(textile, SEAM_H, PUFF)

var _patch: ArrayMesh
var _plot_shape: PackedVector2Array  # inset trefoil outline, relative to a plot's base hex
var _slot_mesh: ArrayMesh
var _slots: Node3D
var _tiles: Node3D
var _blooms: Node3D
# Settled pieces and blooms are merged into a few meshes (one surface per
# material) to keep draw calls low on phones. Newly placed ones show as
# separate nodes while they animate, then get merged in.
var _patches: ChunkedBatch
var _details: ChunkedBatch
var _flowers: ChunkedBatch
var _baked_plots := {}   # plot base -> true, already in the batches
var _baked_blooms := {}  # weave point -> true
var _animating := 0
var _decor_cache := {}   # "q,r|biome" -> ArrayMesh
var _buds: Node3D
var _obstacles: Node3D
var _animals: Node3D
var _ghost: Node3D
var _seams: Node3D
var _trails: MeshInstance3D
var _time := 0.0
var _animal_spots := {}  # weave point -> true, so animals don't overlap


func _ready() -> void:
	_patch = textile.patch_mesh(HEX_SIZE, SEAM_H, PUFF)
	_plot_shape = _inset_plot_shape()
	_slot_mesh = _plot_cloth_mesh(_plot_shape)
	for n in ["_slots", "_tiles", "_blooms", "_buds", "_obstacles", "_animals", "_ghost", "_seams"]:
		var node := Node3D.new()
		node.name = n.trim_prefix("_")
		add_child(node)
		set(n, node)
	for n in ["patches", "details", "flowers"]:
		var cb := ChunkedBatch.new()
		cb.name = n + "_batch"
		cb.textile = textile
		add_child(cb)
		set("_" + n, cb)
	_patches.cast_shadows = false
	_flowers.per_chunk = 8
	_trails = MeshInstance3D.new()
	_trails.material_override = textile.thread(TRAIL_THREAD)
	add_child(_trails)


func _process(delta: float) -> void:
	_time += delta
	if _ghost.get_child_count() > 0:
		_ghost.position.y = 0.3 + sin(_time * 3.0) * 0.05


func setup(p_game: ValleyGame) -> void:
	game = p_game
	data = game.data
	_animal_spots.clear()
	for parent in [_slots, _tiles, _blooms, _buds, _obstacles, _animals, _ghost, _seams]:
		for c in parent.get_children():
			c.queue_free()
	_animating = 0
	for cb: ChunkedBatch in [_patches, _details, _flowers]:
		cb.clear()
	_baked_plots.clear()
	_baked_blooms.clear()
	_bake()
	_build_obstacles()
	refresh()


## Redraw everything that depends on the current state.
func refresh() -> void:
	_refresh_slots()
	_refresh_seams()
	_refresh_trails()
	_refresh_buds()


# --- Coordinates -------------------------------------------------------------

static func hex_pos(h: Vector2i, y: float = 0.0) -> Vector3:
	var p := Hex.to_world(h, HEX_SIZE)
	return Vector3(p.x, y, p.y)


static func vertex_pos(v: Vector3i, y: float = SEAM_H) -> Vector3:
	var p := Hex.vertex_world(v, HEX_SIZE)
	return Vector3(p.x, y, p.y)


## The plot under a point on the picking plane, or null.
func plot_at(world: Vector3) -> Variant:
	var h := Hex.from_world(Vector2(world.x, world.z), HEX_SIZE)
	var base := PlotGrid.plot_of(h)
	return base if game.is_in_valley(base) else null


static func _corner3(i: int) -> Vector3:
	var c := Hex.corner_offset(i, HEX_SIZE)
	return Vector3(c.x, 0.0, c.y)


## Height of a placed patch's surface at a point relative to its centre.
static func _surface(local: Vector2) -> float:
	return Textile.patch_height(local, HEX_SIZE, SEAM_H, PUFF)


# --- Slots (empty plots) -------------------------------------------------------

func _refresh_slots() -> void:
	for c in _slots.get_children():
		c.queue_free()
	var legal := {}
	for p in game.legal_plots():
		legal[p] = true
	var plain: Array = []
	var glowing: Array = []
	for base in game.plots:
		if game.placed.has(base):
			continue
		var is_legal := legal.has(base)
		var mi := MeshInstance3D.new()
		mi.mesh = _slot_mesh
		mi.material_override = textile.fabric(LEGAL_CLOTH if is_legal else SLOT_CLOTH, SLOT_FABRIC)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = hex_pos(base)
		_slots.add_child(mi)
		var origin := hex_pos(base, SLOT_H + 0.012)
		var target := glowing if is_legal else plain
		for i in _plot_shape.size():
			var a := _plot_shape[i]
			var b := _plot_shape[(i + 1) % _plot_shape.size()]
			target.append([origin + Vector3(a.x, 0, a.y), origin + Vector3(b.x, 0, b.y)])
	# Each empty plot is one trefoil of backing cloth with a stitched outline;
	# plots you can place on right now get a brighter, thicker thread.
	_slots.add_child(textile.stitches(plain, 3, 0.17, 0.018, TACK_THREAD))
	_slots.add_child(textile.stitches(glowing, 3, 0.19, 0.026, LEGAL_THREAD))


## The outline of a plot (its three hexes), inset by SLOT_INSET, relative
## to the plot's base hex. Every plot has the same shape.
func _inset_plot_shape(inset_by: float = SLOT_INSET) -> PackedVector2Array:
	var base := Vector2i.ZERO
	var origin := Hex.to_world(base, HEX_SIZE)
	var next := {}  # outline corner -> following corner (walking the border)
	for h in PlotGrid.plot_hexes(base):
		var c := Hex.to_world(h, HEX_SIZE) - origin
		for i in 6:
			if PlotGrid.plot_of(Hex.neighbor(h, i)) == base:
				continue
			var a := (c + Hex.corner_offset(i, HEX_SIZE)).snapped(Vector2.ONE * 0.0001)
			var b := (c + Hex.corner_offset(i + 1, HEX_SIZE)).snapped(Vector2.ONE * 0.0001)
			next[a] = b
	var loop := PackedVector2Array()
	var start: Vector2 = next.keys()[0]
	var p := start
	for _i in next.size():
		loop.append(p)
		p = next[p]
		if p == start:
			break
	if inset_by <= 0.0:
		return loop
	var inset := Geometry2D.offset_polygon(loop, -inset_by, Geometry2D.JOIN_MITER)
	return inset[0] if not inset.is_empty() else loop


static func _signed_area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a / 2.0


## A flat slab in the shape of `outline`, `thick` high.
func _plot_cloth_mesh(outline: PackedVector2Array, thick: float = SLOT_H) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := Geometry2D.triangulate_polygon(outline)
	# Wind the top so it faces up whichever way the outline runs.
	var order := [0, 1, 2] if _signed_area(outline) > 0.0 else [0, 2, 1]
	for i in range(0, tris.size(), 3):
		for k in order:
			var v := outline[tris[i + k]]
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(v.x, thick, v.y))
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var n := Vector3(b.y - a.y, 0, -(b.x - a.x)).normalized()
		var quad := [Vector3(a.x, thick, a.y), Vector3(b.x, thick, b.y), Vector3(b.x, 0, b.y), Vector3(a.x, 0, a.y)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.add_vertex(quad[idx])
	return st.commit()


# --- Obstacles ------------------------------------------------------------------

const LAKE_H := 0.06
const LAKE_WATER := Color(0.33, 0.58, 0.74)
const LAKE_FABRIC := {"weave_scale": 44.0, "weave_strength": 0.05, "fuzz": 0.02, "sheen": 1.3, "rough": 0.22}
const SHORE_THREAD := Color(0.88, 0.8, 0.6)


## Obstacle plots: a lake is one flat, glossy silk pool over the whole plot
## (no seams between its hexes), a sandy stitched shore, lily pads, ripples
## and the odd duck. Other kinds show as plain grey cloth for now.
func _build_obstacles() -> void:
	var shape := _inset_plot_shape(0.0)
	var water := _plot_cloth_mesh(shape, LAKE_H)
	var rock := _plot_cloth_mesh(shape, CLIFF_H)
	var details := MeshBatch.new()
	details.textile = textile
	var bases := {}
	for h: Vector2i in game.obstacles:
		bases[PlotGrid.plot_of(h)] = game.obstacles[h]
	var first_lake := true
	for base: Vector2i in bases:
		var kind: String = bases[base]
		var mi := MeshInstance3D.new()
		mi.position = hex_pos(base)
		match kind:
			"lake":
				mi.mesh = water
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.material_override = textile.fabric(LAKE_WATER, LAKE_FABRIC)
				_lake_details(details, base, first_lake)
				first_lake = false
			"cliff":
				mi.mesh = rock
				mi.material_override = textile.fabric(CLIFF_STONE, CLIFF_FABRIC)
				_cliff_details(details, base)
			_:
				mi.mesh = water
				mi.material_override = textile.fabric(Color(0.6, 0.58, 0.55), SLOT_FABRIC)
		_obstacles.add_child(mi)
	# Edging: the obstacle's outer border only, not the seams between its
	# plots. Sandy stitches round a lake, dark ones along the top of a cliff.
	var shore: Array = []
	var crag: Array = []
	for h: Vector2i in game.obstacles:
		var kind: String = game.obstacles[h]
		var y := CLIFF_H + 0.012 if kind == "cliff" else LAKE_H + 0.012
		for i in 6:
			if game.obstacles.get(Hex.neighbor(h, i), "") == kind:
				continue
			var seg := [hex_pos(h, y) + _corner3(i), hex_pos(h, y) + _corner3(i + 1)]
			(crag if kind == "cliff" else shore).append(seg)
	if not shore.is_empty():
		_obstacles.add_child(textile.stitches(shore, 3, 0.16, 0.03, SHORE_THREAD))
	if not crag.is_empty():
		_obstacles.add_child(textile.stitches(crag, 3, 0.16, 0.03, CLIFF_THREAD))
	var batch := MeshInstance3D.new()
	batch.mesh = details.commit()
	_obstacles.add_child(batch)


const CLIFF_H := 0.62
const CLIFF_STONE := Color(0.56, 0.54, 0.5)
const CLIFF_FABRIC := {"weave_scale": 10.0, "weave_strength": 0.18, "fuzz": 0.25, "fleck": 0.12, "fleck_color": "#3f3a35", "rough": 1.0}
const CLIFF_THREAD := Color(0.24, 0.22, 0.2)


## Boulders, a few crags poking up, moss and heather on top of the rock.
func _cliff_details(batch: MeshBatch, base: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(base) ^ 0xc11ff
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 8
	ball.rings = 4
	var spike := CylinderMesh.new()
	spike.top_radius = 0.0
	spike.bottom_radius = 0.5
	spike.height = 1.0
	spike.radial_segments = 5
	var felt := {"fuzz": 0.35, "weave_strength": 0.0, "rough": 1.0}
	var greys := [Color(0.5, 0.48, 0.45), Color(0.62, 0.6, 0.56), Color(0.44, 0.43, 0.42)]
	for h in PlotGrid.plot_hexes(base):
		var c := hex_pos(h, CLIFF_H)
		for k in rng.randi_range(2, 3):
			var off := Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.45, 0.45))
			var sz := rng.randf_range(0.22, 0.4)
			batch.add(ball, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sz, sz * 0.7, sz * 0.85)), c + off),
				Color.WHITE, textile.fabric(greys[rng.randi() % greys.size()], felt))
		if rng.randf() < 0.7:
			var off := Vector3(rng.randf_range(-0.3, 0.3), 0.0, rng.randf_range(-0.3, 0.3))
			var tall := rng.randf_range(0.35, 0.6)
			batch.add(spike, Transform3D(Basis().scaled(Vector3(0.3, tall, 0.26)), c + off + Vector3(0, tall * 0.5, 0)),
				Color.WHITE, textile.fabric(greys[0], felt))
		for k in rng.randi_range(2, 4):
			var off := Vector3(rng.randf_range(-0.6, 0.6), 0.0, rng.randf_range(-0.5, 0.5))
			var col := Color(0.42, 0.55, 0.3) if rng.randf() < 0.6 else Color(0.62, 0.36, 0.62)
			batch.add(ball, Transform3D(Basis().scaled(Vector3(0.14, 0.06, 0.14)), c + off + Vector3(0, 0.02, 0)),
				Color.WHITE, textile.fabric(col, felt))


func _lake_details(batch: MeshBatch, base: Vector2i, with_duck: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(base) ^ 0x1a4e
	var y := LAKE_H + 0.004
	var disc := CylinderMesh.new()
	disc.top_radius = 0.5
	disc.bottom_radius = 0.5
	disc.height = 1.0
	disc.radial_segments = 14
	disc.rings = 1
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 10
	ball.rings = 5
	var dash := CapsuleMesh.new()
	dash.radius = 0.5
	dash.height = 1.0
	dash.radial_segments = 4
	dash.rings = 1
	var felt := {"fuzz": 0.35, "weave_strength": 0.0, "rough": 1.0}
	var ripple := textile.thread(Color(0.62, 0.8, 0.9))
	for h in PlotGrid.plot_hexes(base):
		var c := hex_pos(h, y)
		# Lily pads, some with a flower.
		for k in rng.randi_range(1, 2):
			var off := Vector2(rng.randf_range(-0.45, 0.45), rng.randf_range(-0.4, 0.4))
			var r := rng.randf_range(0.11, 0.17)
			var pad := Color(0.34, 0.56, 0.32) if rng.randf() < 0.6 else Color(0.42, 0.62, 0.36)
			var at := c + Vector3(off.x, 0.0, off.y)
			batch.add(disc, Transform3D(Basis().scaled(Vector3(r * 2.0, 0.012, r * 2.0)), at), Color.WHITE, textile.fabric(pad, felt))
			if rng.randf() < 0.4:
				var petal := Color(0.97, 0.78, 0.86) if rng.randf() < 0.5 else Color(1.0, 0.98, 0.95)
				for p in 5:
					var po := Vector3.RIGHT.rotated(Vector3.UP, TAU * p / 5.0) * 0.025
					batch.add(ball, Transform3D(Basis().scaled(Vector3(0.045, 0.03, 0.045)), at + po + Vector3(0, 0.02, 0)), Color.WHITE, textile.satin(petal))
		# Ripples: short arcs of stitches.
		for k in 2:
			var centre := Vector2(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.35, 0.35))
			var rad := rng.randf_range(0.14, 0.28)
			var a0 := rng.randf() * TAU
			for d in 5:
				var a := a0 + d * 0.32
				var p := centre + Vector2.from_angle(a) * rad
				var basis := Basis(Vector3.UP, -(a + PI / 2.0 + PI / 2.0)) * Basis(Vector3.FORWARD, PI / 2.0)
				batch.add(dash, Transform3D(basis.scaled(Vector3(0.014, rad * 0.22, 0.01)), c + Vector3(p.x, 0.002, p.y)), Color.WHITE, ripple)
	if not with_duck:
		return
	# One felt duck per lake.
	var at := hex_pos(PlotGrid.plot_hexes(base)[rng.randi_range(0, 2)], y)
	var white := Color(0.97, 0.96, 0.92)
	var beak := Color(0.95, 0.62, 0.2)
	batch.add(ball, Transform3D(Basis().scaled(Vector3(0.2, 0.11, 0.13)), at + Vector3(0, 0.05, 0)), Color.WHITE, textile.fabric(white, felt))
	batch.add(ball, Transform3D(Basis().scaled(Vector3.ONE * 0.08), at + Vector3(0.08, 0.13, 0)), Color.WHITE, textile.fabric(white, felt))
	batch.add(ball, Transform3D(Basis().scaled(Vector3(0.055, 0.02, 0.035)), at + Vector3(0.13, 0.125, 0)), Color.WHITE, textile.fabric(beak, felt))


## Border edges of a plot, each [from, to] at height y.
func _plot_outline(base: Vector2i, y: float) -> Array:
	var segs: Array = []
	for h in PlotGrid.plot_hexes(base):
		for i in 6:
			if PlotGrid.plot_of(Hex.neighbor(h, i)) == base:
				continue
			segs.append([hex_pos(h, y) + _corner3(i), hex_pos(h, y) + _corner3(i + 1)])
	return segs


# --- Pieces --------------------------------------------------------------------

func add_piece(base: Vector2i, arranged: Array, animate: bool) -> void:
	if not animate:
		_bake()
		return
	var piece := Node3D.new()
	_tiles.add_child(piece)
	var hexes := PlotGrid.plot_hexes(base)
	for i in 3:
		piece.add_child(_make_tile(hexes[i], arranged[i], false))
	if animate:
		piece.position.y = 0.6
		piece.scale = Vector3(0.92, 0.92, 0.92)
		var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(piece, "position:y", 0.0, 0.35)
		tw.tween_property(piece, "scale", Vector3.ONE, 0.35)
		_track(tw)


func _make_tile(h: Vector2i, biome: String, ghost: bool) -> Node3D:
	var tile := Node3D.new()
	tile.position = hex_pos(h)
	var b: Dictionary = data.biomes.get(biome, {})
	var mi := MeshInstance3D.new()
	mi.mesh = _patch
	var shade := BiomeDecor.tile_tint(h, data.biome_color(biome))
	mi.material_override = textile.fabric(shade, b.get("fabric", {}), ghost)
	tile.add_child(mi)
	var deco := decor.build(h, biome, ghost)
	if deco:
		var d := MeshInstance3D.new()
		d.mesh = deco
		tile.add_child(d)
	return tile


# --- Ghost (placement preview) ----------------------------------------------

func set_ghost(base: Vector2i, arranged: Array, preview: Array) -> void:
	clear_ghost()
	var hexes := PlotGrid.plot_hexes(base)
	for i in 3:
		_ghost.add_child(_make_tile(hexes[i], arranged[i], true))
	var biome_of := {}
	for i in 3:
		biome_of[hexes[i]] = arranged[i]
	for b: Dictionary in preview:
		# Solid, not see-through: transparent layers sort unreliably on phones
		# and the dark outline could end up on top, turning the flower black.
		var f := _make_flower(b.vertex, b.bloom, biome_of, false)
		f.position = vertex_pos(b.vertex, SEAM_H + FLOWER_LIFT + 0.04)
		f.scale = Vector3.ONE * FLOWER_SCALE * 1.1
		_ghost.add_child(f)


func clear_ghost() -> void:
	for c in _ghost.get_children():
		_ghost.remove_child(c)
		c.queue_free()


# --- Seams, blooms, trails, animals -------------------------------------------

## Dark running stitches along every border between placed pieces (and the
## outer edge of the restored area).
func _refresh_seams() -> void:
	for c in _seams.get_children():
		c.queue_free()
	var segs: Array = []
	for base: Vector2i in game.placed:
		segs.append_array(_plot_outline(base, SEAM_H + 0.012))
	_seams.add_child(textile.stitches(segs, 3, 0.15, 0.022, SEAM_THREAD))


func add_bloom(v: Vector3i, bloom_id: String, animate: bool) -> void:
	if not animate:
		_bake()
		return
	var f := _make_flower(v, bloom_id, {}, false)
	f.position = vertex_pos(v, SEAM_H + FLOWER_LIFT)
	_blooms.add_child(f)
	var full := f.scale
	f.scale = Vector3.ONE * 0.01
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.25)
	tw.tween_property(f, "scale", full, 0.5)
	_track(tw)


## Count running drop/bloom animations; when the last one ends, merge
## everything into the batches and drop the separate nodes.
func _track(tw: Tween) -> void:
	_animating += 1
	tw.finished.connect(func() -> void:
		_animating -= 1
		if _animating <= 0:
			_animating = 0
			_bake())


## Add pieces and blooms not yet merged to the batches, rebuild the merged
## meshes and free the loose animation nodes.
func _bake() -> void:
	for c in _tiles.get_children():
		c.queue_free()
	for c in _blooms.get_children():
		c.queue_free()
	for base: Vector2i in game.placed:
		if _baked_plots.has(base):
			continue
		_baked_plots[base] = true
		_patches.next_item()
		_details.next_item()
		for h in PlotGrid.plot_hexes(base):
			var biome: String = game.board[h]
			var b: Dictionary = data.biomes.get(biome, {})
			var xf := Transform3D(Basis(), hex_pos(h))
			var tint := BiomeDecor.tile_tint(h, data.biome_color(biome))
			_patches.add(_patch, xf, tint, textile.fabric(Color.WHITE, b.get("fabric", {})))
			_details.add(_decor_for(h, biome), xf)
	for v: Vector3i in game.blooms:
		if _baked_blooms.has(v):
			continue
		_baked_blooms[v] = true
		_flowers.next_item()
		var f := _make_flower(v, game.blooms[v], {}, false)
		_flowers.add(f.mesh, Transform3D(Basis().scaled(f.scale), vertex_pos(v, SEAM_H + FLOWER_LIFT)))
		f.free()
	for cb: ChunkedBatch in [_patches, _details, _flowers]:
		cb.commit()


func _decor_for(h: Vector2i, biome: String) -> Mesh:
	var key := "%d,%d|%s" % [h.x, h.y, biome]
	if not _decor_cache.has(key):
		_decor_cache[key] = decor.build(h, biome, false)
	return _decor_cache[key]


## A bloom that shows its recipe: two petals point at each of the corner's
## hexes in that hex's biome colour; the centre is the bloom's colour.
## `biome_of` supplies biomes not yet on the board (the ghost piece).
func _make_flower(v: Vector3i, bloom_id: String, biome_of: Dictionary, ghost: bool) -> MeshInstance3D:
	var bloom: Dictionary = data.blooms_by_id.get(bloom_id, {})
	var centre := Hex.vertex_world(v, HEX_SIZE)
	var petals := []
	for h in Hex.vertex_hexes(v):
		var biome: String = biome_of.get(h, game.board.get(h, ""))
		var dir := Hex.to_world(h, HEX_SIZE) - centre
		petals.append([snappedf(dir.angle(), 0.01), data.biome_color(biome)])
	var mi := MeshInstance3D.new()
	# Corners sit in the dip between puffy patches, so blooms stand on a
	# short stem to rise above them.
	mi.mesh = textile.recipe_flower_mesh(petals, Color(bloom.get("color", "#ffffff")), ghost, FLOWER_LIFT / FLOWER_SCALE)
	mi.scale = Vector3.ONE * FLOWER_SCALE
	return mi


## Bloom spots, so every corner where three plots meet shows its state:
##   stitched star - a bloom can still grow here (0-1 of its hexes filled)
##   bud           - two hexes filled; its knots show what the last one needs
##   flower        - bloomed (drawn by add_bloom)
##   nothing       - can no longer bloom
func _refresh_buds() -> void:
	for c in _buds.get_children():
		c.queue_free()
	var seen := {}
	for base in game.plots:
		for v in PlotGrid.plot_weave_points(base):
			if seen.has(v):
				continue
			seen[v] = true
			var filled := 0
			var in_valley := true
			for h in Hex.vertex_hexes(v):
				in_valley = in_valley and game.is_in_valley(PlotGrid.plot_of(h))
				if game.board.has(h):
					filled += 1
			if not in_valley or filled >= 2:
				continue
			var star := MeshInstance3D.new()
			star.mesh = textile.star_mesh(STAR_THREAD)
			star.position = vertex_pos(v, SEAM_H + 0.01 if filled == 1 else SLOT_H + 0.01)
			star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			star.scale = Vector3.ONE * 2.0
			_buds.add_child(star)
	for corner: Dictionary in game.open_corners():
		if corner.needs.is_empty():
			continue
		var colors := []
		for b: String in corner.needs:
			colors.append(data.biome_color(b))
		var mi := MeshInstance3D.new()
		mi.mesh = textile.bud_mesh(colors)
		mi.position = vertex_pos(corner.vertex, SEAM_H)
		mi.scale = Vector3.ONE * 2.1
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_buds.add_child(mi)


## A burst of petals rising from a piece: the perfect-piece celebration.
func celebrate(base: Vector2i) -> void:
	var hexes := PlotGrid.plot_hexes(base)
	var centre := (hex_pos(hexes[0]) + hex_pos(hexes[1]) + hex_pos(hexes[2])) / 3.0
	var petal := SphereMesh.new()
	petal.radius = 0.5
	petal.height = 1.0
	petal.radial_segments = 6
	petal.rings = 3
	for i in 42:
		var mi := MeshInstance3D.new()
		mi.mesh = petal
		mi.material_override = textile.satin(BiomeDecor.FLOWER_COLORS[i % BiomeDecor.FLOWER_COLORS.size()])
		mi.scale = Vector3(0.12, 0.04, 0.08)
		mi.position = centre + Vector3(0, SEAM_H + PUFF, 0)
		mi.rotation.y = randf() * TAU
		add_child(mi)
		var a := TAU * i / 42.0 + randf() * 0.3
		var reach := randf_range(1.2, 2.6)
		var target := centre + Vector3(cos(a) * reach, randf_range(1.0, 2.4), sin(a) * reach)
		var tw := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "position", target, 1.4)
		tw.tween_property(mi, "rotation:y", mi.rotation.y + randf_range(-3.0, 3.0), 1.4)
		tw.tween_property(mi, "scale", Vector3.ONE * 0.001, 1.4).set_delay(0.4)
		tw.chain().tween_callback(mi.queue_free)


## Corridors: a bright embroidered thread along the piece borders between
## linked blooms (bloom -> seam corner -> bloom).
func _refresh_trails() -> void:
	var lines: Array = []
	for l: Dictionary in game.bloom_links():
		var route := ValleyGame.link_route(l)
		var pts: Array = []
		for v in route:
			pts.append(vertex_pos(v, SEAM_H + 0.06))
		lines.append(pts)
	_trails.mesh = textile.tube_mesh(lines, 0.07)


## The hidden visitor, standing on a hex of the pattern that brought it.
func add_visitor(id: String, h: Vector2i, animate: bool) -> void:
	var node := Node3D.new()
	node.position = hex_pos(h, SEAM_H + PUFF * 0.8)
	node.rotation.y = -PI / 5.0
	node.add_child(FeltAnimal.build(textile, id, 1.3))
	var label := Label3D.new()
	label.text = data.animals.get(id, {}).get("name", id)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.pixel_size = 0.005
	label.outline_size = 12
	label.modulate = Color(0.45, 0.2, 0.32)
	label.outline_modulate = Color(1, 0.98, 0.92)
	label.position = Vector3(0, 1.4, 0)
	node.add_child(label)
	_animals.add_child(node)
	if animate:
		node.scale = Vector3.ONE * 0.01
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.4)
		tw.tween_property(node, "scale", Vector3.ONE, 0.7)


func add_animal(id: String, corridor: Array, animate: bool) -> void:
	if corridor.is_empty():
		return
	var animal: Dictionary = game.animal(id)
	var at := _animal_spot(animal, corridor)
	var spot := vertex_pos(at, SEAM_H)
	# Animals that love the cliff perch on top of it, next to their bloom.
	if animal.get("needs", {}).get("near", "") == "cliff":
		var best := INF
		for h: Vector2i in game.obstacles:
			var d := hex_pos(h).distance_to(spot)
			if game.obstacles[h] == "cliff" and d < best:
				best = d
				spot = hex_pos(h, CLIFF_H)
	var node := Node3D.new()
	node.position = spot
	node.add_child(FeltAnimal.build(textile, id))
	var label := Label3D.new()
	label.text = animal.get("name", id)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.pixel_size = 0.005
	label.outline_size = 12
	label.modulate = Color(0.2, 0.18, 0.15)
	label.outline_modulate = Color(1, 0.98, 0.92)
	label.position = Vector3(0, 1.1, 0)
	node.add_child(label)
	_animals.add_child(node)
	if animate:
		node.scale = Vector3.ONE * 0.01
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.6)
		tw.tween_property(node, "scale", Vector3.ONE, 0.6)


## A bloom in the corridor touching the animal's biome, not used by another
## animal yet; falls back to any bloom in the corridor.
func _animal_spot(animal: Dictionary, corridor: Array) -> Vector3i:
	# Stand on a bloom that shows what the animal wanted: its biome, a bloom
	# by the obstacle it likes, or the bloom it asked for.
	var needs: Dictionary = animal.get("needs", {})
	var fallback: Vector3i = corridor[corridor.size() / 2]
	for v: Vector3i in corridor:
		if _animal_spots.has(v):
			continue
		var trio: Array = data.blooms_by_id[game.blooms[v]].trio
		var fits := true
		if needs.has("biome"):
			fits = trio.has(needs.biome)
		elif needs.has("near"):
			fits = game.is_near_obstacle(v, needs.near)
		elif needs.has("bloom"):
			fits = game.blooms[v] == needs.bloom
		if fits:
			_animal_spots[v] = true
			return v
	return fallback
