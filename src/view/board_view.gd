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
var _buds: Node3D
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
	for n in ["_slots", "_tiles", "_blooms", "_buds", "_animals", "_ghost", "_seams"]:
		var node := Node3D.new()
		node.name = n.trim_prefix("_")
		add_child(node)
		set(n, node)
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
	for parent in [_slots, _tiles, _blooms, _buds, _animals, _ghost, _seams]:
		for c in parent.get_children():
			c.queue_free()
	for base: Vector2i in game.placed:
		var arranged := []
		for h in PlotGrid.plot_hexes(base):
			arranged.append(game.board[h])
		add_piece(base, arranged, false)
	for v: Vector3i in game.blooms:
		add_bloom(v, game.blooms[v], false)
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
func _inset_plot_shape() -> PackedVector2Array:
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
	var inset := Geometry2D.offset_polygon(loop, -SLOT_INSET, Geometry2D.JOIN_MITER)
	return inset[0] if not inset.is_empty() else loop


static func _signed_area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a / 2.0


## A flat slab in the shape of `outline`, SLOT_H thick.
func _plot_cloth_mesh(outline: PackedVector2Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := Geometry2D.triangulate_polygon(outline)
	# Wind the top so it faces up whichever way the outline runs.
	var order := [0, 1, 2] if _signed_area(outline) > 0.0 else [0, 2, 1]
	for i in range(0, tris.size(), 3):
		for k in order:
			var v := outline[tris[i + k]]
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(v.x, SLOT_H, v.y))
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var n := Vector3(b.y - a.y, 0, -(b.x - a.x)).normalized()
		var quad := [Vector3(a.x, SLOT_H, a.y), Vector3(b.x, SLOT_H, b.y), Vector3(b.x, 0, b.y), Vector3(a.x, 0, a.y)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.add_vertex(quad[idx])
	return st.commit()


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
		var f := _make_flower(b.vertex, b.bloom, biome_of, true)
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
	var f := _make_flower(v, bloom_id, {}, false)
	f.position = vertex_pos(v, SEAM_H + FLOWER_LIFT)
	_blooms.add_child(f)
	if animate:
		var full := f.scale
		f.scale = Vector3.ONE * 0.01
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.25)
		tw.tween_property(f, "scale", full, 0.5)


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


func add_animal(id: String, corridor: Array, animate: bool) -> void:
	if corridor.is_empty():
		return
	var animal: Dictionary = data.animals.get(id, {})
	var spot := vertex_pos(_animal_spot(animal, corridor), SEAM_H)
	var node := Node3D.new()
	node.position = spot
	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	var col := Color(0.62, 0.44, 0.28) if id == "deer" else Color(0.36, 0.27, 0.21)
	if id == "deer":
		bm.radius = 0.14
		bm.height = 0.55
		hm.radius = 0.11
		hm.height = 0.22
		body.position = Vector3(0, 0.45, 0)
		head.position = Vector3(0.26, 0.68, 0)
	else:
		bm.radius = 0.1
		bm.height = 0.5
		hm.radius = 0.09
		hm.height = 0.18
		body.position = Vector3(0, 0.22, 0)
		head.position = Vector3(0.26, 0.28, 0)
	var felt := {"fuzz": 0.4, "weave_strength": 0.0, "rough": 1.0}
	body.mesh = bm
	body.rotation.z = PI / 2.0
	body.material_override = textile.fabric(col, felt)
	head.mesh = hm
	head.material_override = textile.fabric(col.lightened(0.12), felt)
	node.add_child(body)
	node.add_child(head)
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
	var biome: String = animal.get("needs", {}).get("biome", "")
	var fallback: Vector3i = corridor[corridor.size() / 2]
	for v: Vector3i in corridor:
		if _animal_spots.has(v):
			continue
		var trio: Array = data.blooms_by_id[game.blooms[v]].trio
		if biome == "" or trio.has(biome):
			_animal_spots[v] = true
			return v
	return fallback
