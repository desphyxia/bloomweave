class_name BoardView
extends Node3D
## Draws the valley: empty plots, placed pieces, plot borders, blooms,
## corridor trails, animals and the placement ghost. Holds no game rules.

const HEX_SIZE := 1.0
const TILE_H := 0.25
const SLOT_H := 0.04

const BORDER_COLOR := Color(0.2, 0.24, 0.2)
const TRAIL_COLOR := Color(0.76, 0.27, 0.42)
const SLOT_COLOR := Color(0.85, 0.82, 0.74)
const LEGAL_COLOR := Color(0.99, 0.96, 0.86)

var game: ValleyGame
var data: GameData

var _mats := {}
var _prism: ArrayMesh
var _slot_mesh: ArrayMesh
var _slots: Node3D
var _tiles: Node3D
var _blooms: Node3D
var _animals: Node3D
var _ghost: Node3D
var _borders: MeshInstance3D
var _trails: MeshInstance3D
var _time := 0.0
var _animal_spots := {}  # weave point -> true, so animals don't overlap


func _ready() -> void:
	_prism = _make_prism(HEX_SIZE * 0.995, TILE_H)
	_slot_mesh = _make_prism(HEX_SIZE * 0.9, SLOT_H)
	for n in ["_slots", "_tiles", "_blooms", "_animals", "_ghost"]:
		var node := Node3D.new()
		node.name = n.trim_prefix("_")
		add_child(node)
		set(n, node)
	_borders = MeshInstance3D.new()
	_trails = MeshInstance3D.new()
	add_child(_borders)
	add_child(_trails)


func _process(delta: float) -> void:
	_time += delta
	if _ghost.get_child_count() > 0:
		_ghost.position.y = 0.32 + sin(_time * 3.0) * 0.05


func setup(p_game: ValleyGame) -> void:
	game = p_game
	data = game.data
	_animal_spots.clear()
	for parent in [_slots, _tiles, _blooms, _animals, _ghost]:
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
	_refresh_borders()
	_refresh_trails()


# --- Coordinates -------------------------------------------------------------

static func hex_pos(h: Vector2i, y: float = 0.0) -> Vector3:
	var p := Hex.to_world(h, HEX_SIZE)
	return Vector3(p.x, y, p.y)


static func vertex_pos(v: Vector3i, y: float = TILE_H) -> Vector3:
	var p := Hex.vertex_world(v, HEX_SIZE)
	return Vector3(p.x, y, p.y)


## The plot under a point on the tile-top plane, or null.
func plot_at(world: Vector3) -> Variant:
	var h := Hex.from_world(Vector2(world.x, world.z), HEX_SIZE)
	var base := PlotGrid.plot_of(h)
	return base if game.is_in_valley(base) else null


# --- Slots and pieces --------------------------------------------------------

func _refresh_slots() -> void:
	for c in _slots.get_children():
		c.queue_free()
	var legal := {}
	for p in game.legal_plots():
		legal[p] = true
	for base in game.plots:
		if game.placed.has(base):
			continue
		var col := LEGAL_COLOR if legal.has(base) else SLOT_COLOR
		for h in PlotGrid.plot_hexes(base):
			var mi := MeshInstance3D.new()
			mi.mesh = _slot_mesh
			mi.material_override = _mat(col)
			mi.position = hex_pos(h)
			_slots.add_child(mi)


func add_piece(base: Vector2i, arranged: Array, animate: bool) -> void:
	var piece := Node3D.new()
	_tiles.add_child(piece)
	var hexes := PlotGrid.plot_hexes(base)
	for i in 3:
		piece.add_child(_make_tile(hexes[i], arranged[i], 1.0))
	if animate:
		piece.position.y = 0.6
		piece.scale = Vector3(0.9, 0.9, 0.9)
		var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(piece, "position:y", 0.0, 0.35)
		tw.tween_property(piece, "scale", Vector3.ONE, 0.35)


func _make_tile(h: Vector2i, biome: String, alpha: float) -> Node3D:
	var tile := Node3D.new()
	tile.position = hex_pos(h)
	var mi := MeshInstance3D.new()
	mi.mesh = _prism
	var col := data.biome_color(biome)
	mi.material_override = _mat(col, alpha, 0.35 if biome == "wetland" else 0.9)
	tile.add_child(mi)
	_decorate(tile, h, biome, alpha)
	return tile


## Small shapes so biomes read without relying on colour alone.
func _decorate(tile: Node3D, h: Vector2i, biome: String, alpha: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(h)
	match biome:
		"forest":
			for i in 3:
				var cone := MeshInstance3D.new()
				var m := CylinderMesh.new()
				m.top_radius = 0.0
				m.bottom_radius = 0.2
				m.height = 0.5
				m.radial_segments = 8
				cone.mesh = m
				cone.material_override = _mat(Color(0.25, 0.45, 0.27), alpha)
				var a := TAU * i / 3.0 + rng.randf() * 0.6
				cone.position = Vector3(cos(a) * 0.42, TILE_H + 0.25, sin(a) * 0.42)
				tile.add_child(cone)
		"heath":
			for i in 4:
				var tuft := MeshInstance3D.new()
				var m := SphereMesh.new()
				m.radius = 0.13
				m.height = 0.16
				tuft.mesh = m
				tuft.material_override = _mat(Color(0.47, 0.31, 0.55), alpha)
				var a := TAU * i / 4.0 + rng.randf()
				tuft.position = Vector3(cos(a) * 0.45, TILE_H + 0.04, sin(a) * 0.45)
				tile.add_child(tuft)
		"meadow":
			for i in 5:
				var fl := MeshInstance3D.new()
				var m := SphereMesh.new()
				m.radius = 0.035
				m.height = 0.07
				fl.mesh = m
				fl.material_override = _mat(Color(0.98, 0.93, 0.62), alpha)
				var a := rng.randf() * TAU
				var d := 0.2 + rng.randf() * 0.4
				fl.position = Vector3(cos(a) * d, TILE_H + 0.03, sin(a) * d)
				tile.add_child(fl)
		"wetland":
			var pool := MeshInstance3D.new()
			var m := CylinderMesh.new()
			m.top_radius = 0.32
			m.bottom_radius = 0.32
			m.height = 0.02
			pool.mesh = m
			pool.material_override = _mat(Color(0.55, 0.78, 0.88), alpha, 0.1)
			pool.position = Vector3(rng.randf_range(-0.15, 0.15), TILE_H + 0.01, rng.randf_range(-0.15, 0.15))
			tile.add_child(pool)


# --- Ghost (placement preview) ----------------------------------------------

func set_ghost(base: Vector2i, arranged: Array, preview: Array) -> void:
	clear_ghost()
	var hexes := PlotGrid.plot_hexes(base)
	for i in 3:
		_ghost.add_child(_make_tile(hexes[i], arranged[i], 0.8))
	for b: Dictionary in preview:
		var f := _make_flower(b.bloom, 0.9)
		f.position = vertex_pos(b.vertex, TILE_H + 0.05)
		f.scale = Vector3.ONE * 1.5
		_ghost.add_child(f)


func clear_ghost() -> void:
	for c in _ghost.get_children():
		_ghost.remove_child(c)
		c.queue_free()


# --- Blooms, trails, animals --------------------------------------------------

func add_bloom(v: Vector3i, bloom_id: String, animate: bool) -> void:
	var f := _make_flower(bloom_id, 1.0)
	f.position = vertex_pos(v, TILE_H + 0.02)
	_blooms.add_child(f)
	if animate:
		f.scale = Vector3.ONE * 0.01
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.25)
		tw.tween_property(f, "scale", Vector3.ONE * 1.35, 0.5)


func _make_flower(bloom_id: String, alpha: float) -> Node3D:
	var bloom: Dictionary = data.blooms_by_id.get(bloom_id, {})
	var petal_col := Color(bloom.get("color", "#ffffff"))
	var flower := Node3D.new()
	flower.scale = Vector3.ONE * 1.35
	var leaf := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.24
	lm.bottom_radius = 0.2
	lm.height = 0.04
	lm.radial_segments = 10
	leaf.mesh = lm
	leaf.material_override = _mat(Color(0.3, 0.5, 0.28), alpha)
	leaf.position.y = 0.02
	flower.add_child(leaf)
	var petal_mesh := SphereMesh.new()
	petal_mesh.radius = 0.11
	petal_mesh.height = 0.12
	for i in 5:
		var p := MeshInstance3D.new()
		p.mesh = petal_mesh
		p.material_override = _mat(petal_col, alpha)
		var a := TAU * i / 5.0
		p.position = Vector3(cos(a) * 0.13, 0.06, sin(a) * 0.13)
		flower.add_child(p)
	var c := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.08
	cm.height = 0.12
	c.mesh = cm
	c.material_override = _mat(Color(0.95, 0.71, 0.2), alpha)
	c.position.y = 0.09
	flower.add_child(c)
	return flower


func _refresh_trails() -> void:
	var segs: Array = []
	for l: Dictionary in game.bloom_links():
		var route := ValleyGame.link_route(l)
		for i in route.size() - 1:
			segs.append([vertex_pos(route[i], TILE_H + 0.015), vertex_pos(route[i + 1], TILE_H + 0.015)])
	_trails.mesh = _ribbons(segs, 0.13, true)
	_trails.material_override = _mat(TRAIL_COLOR)


func _refresh_borders() -> void:
	var segs: Array = []
	for base: Vector2i in game.placed:
		for h in PlotGrid.plot_hexes(base):
			for i in 6:
				var across := Hex.neighbor(h, i)
				if PlotGrid.plot_of(across) == base:
					continue
				var a := hex_pos(h, TILE_H + 0.01) + _corner3(i)
				var b := hex_pos(h, TILE_H + 0.01) + _corner3(i + 1)
				segs.append([a, b])
	_borders.mesh = _ribbons(segs, 0.05, false)
	_borders.material_override = _mat(BORDER_COLOR)


func add_animal(id: String, corridor: Array, animate: bool) -> void:
	if corridor.is_empty():
		return
	var animal: Dictionary = data.animals.get(id, {})
	var spot := vertex_pos(_animal_spot(animal, corridor), TILE_H)
	var node := Node3D.new()
	node.position = spot + Vector3(0.0, 0.0, 0.0)
	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	var col := Color(0.6, 0.42, 0.27) if id == "deer" else Color(0.32, 0.24, 0.19)
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
		body.position = Vector3(0, 0.2, 0)
		head.position = Vector3(0.26, 0.26, 0)
	body.mesh = bm
	body.rotation.z = PI / 2.0
	body.material_override = _mat(col)
	head.mesh = hm
	head.material_override = _mat(col.lightened(0.1))
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


# --- Meshes and materials ----------------------------------------------------

static func _corner3(i: int) -> Vector3:
	var c := Hex.corner_offset(i, HEX_SIZE)
	return Vector3(c.x, 0.0, c.y)


func _make_prism(radius: float, height: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top: Array[Vector3] = []
	for i in 6:
		var c := Hex.corner_offset(i, radius)
		top.append(Vector3(c.x, height, c.y))
	for i in 6:
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(0, height, 0))
		st.set_normal(Vector3.UP)
		st.add_vertex(top[(i + 1) % 6])
		st.set_normal(Vector3.UP)
		st.add_vertex(top[i])
	for i in 6:
		var a := top[i]
		var b := top[(i + 1) % 6]
		var a0 := Vector3(a.x, 0, a.z)
		var b0 := Vector3(b.x, 0, b.z)
		var n := ((a + b) / 2.0 * Vector3(1, 0, 1)).normalized()
		for v in [a, b, b0, a, b0, a0]:
			st.set_normal(n)
			st.add_vertex(v)
	return st.commit()


## Flat ribbons along segments (each [from, to]), with round-ish joints.
func _ribbons(segs: Array, width: float, joints: bool) -> ArrayMesh:
	if segs.is_empty():
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s: Array in segs:
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		var dir := (b - a).normalized()
		var side := Vector3(-dir.z, 0, dir.x) * width / 2.0
		var ext := dir * (width / 2.0 if joints else width / 4.0)
		var p := [a - ext + side, b + ext + side, b + ext - side, a - ext - side]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.add_vertex(p[idx])
	return st.commit()


func _mat(col: Color, alpha: float = 1.0, roughness: float = 0.9) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [col.to_html(), alpha, roughness]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	m.roughness = roughness
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m
