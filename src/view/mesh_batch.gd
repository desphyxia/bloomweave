class_name MeshBatch
extends RefCounted
## Merges many small meshes into one mesh with one surface per material, so a
## whole board of details costs a handful of draw calls instead of hundreds.
## Each added mesh can carry a vertex colour (the fabric, satin and thread
## shaders multiply it in), so tinted copies can still share one material.
## A batch can keep growing: add the new pieces, then commit again. Transforms
## run natively on whole arrays and indices are kept, so this stays quick.

var _groups := {}  # material instance id -> _Group
## When set, coloured materials are swapped for their white twins and the
## colour moves into the vertices (see Textile.neutral).
var textile: Textile

static var _src := {}  # "mesh id|surface" -> [v, n, uv, index]


func add(mesh: Mesh, xf: Transform3D, color: Color = Color.WHITE, mat: Material = null) -> void:
	if mesh == null:
		return
	# Normals use the inverse-transpose (hills are stretched); the mesh stores
	# them compressed, which normalises them.
	var rot := Transform3D(xf.basis.inverse().transposed(), Vector3.ZERO)
	var plain := xf.basis.is_equal_approx(Basis())
	for s in mesh.get_surface_count():
		var m: Material = mat if mat else mesh.surface_get_material(s)
		var tint := color
		if textile:
			var nm := textile.neutral(m)
			m = nm[0]
			tint = color * (nm[1] as Color)
		var key := m.get_instance_id() if m else 0
		if not _groups.has(key):
			_groups[key] = _Group.new(m)
		(_groups[key] as _Group).append(_source(mesh, s), xf, rot, plain, tint)


## A mesh of everything added so far (one surface per material).
func commit() -> ArrayMesh:
	if _groups.is_empty():
		return null
	var mesh := ArrayMesh.new()
	for key in _groups:
		var g: _Group = _groups[key]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = g.v
		arrays[Mesh.ARRAY_NORMAL] = g.n
		arrays[Mesh.ARRAY_TEX_UV] = g.uv
		arrays[Mesh.ARRAY_COLOR] = g.c
		arrays[Mesh.ARRAY_INDEX] = g.i
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, g.mat)
	return mesh


## [vertices, normals, uvs, indices] of one surface, filled in where missing.
static func _source(mesh: Mesh, surface: int) -> Array:
	var key := "%d|%d" % [mesh.get_instance_id(), surface]
	if _src.has(key):
		return _src[key]
	var arr := mesh.surface_get_arrays(surface)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array
	if arr[Mesh.ARRAY_NORMAL] != null:
		n = arr[Mesh.ARRAY_NORMAL]
	else:
		n.resize(v.size())
		n.fill(Vector3.UP)
	var uv: PackedVector2Array
	if arr[Mesh.ARRAY_TEX_UV] != null:
		uv = arr[Mesh.ARRAY_TEX_UV]
	else:
		uv.resize(v.size())
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(v.size()))
	var out := [v, n, uv, idx]
	_src[key] = out
	return out


## The growing arrays for one material. Members, so appends happen in place.
class _Group:
	var mat: Material
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var c := PackedColorArray()
	var i := PackedInt32Array()

	func _init(p_mat: Material) -> void:
		mat = p_mat

	func append(src: Array, xf: Transform3D, rot: Transform3D, plain: bool, tint: Color) -> void:
		var sv: PackedVector3Array = src[0]
		var sn: PackedVector3Array = src[1]
		var si: PackedInt32Array = src[3]
		var base := v.size()
		v.append_array(xf * sv)
		n.append_array(sn if plain else rot * sn)
		uv.append_array(src[2])
		var tints := PackedColorArray()
		tints.resize(sv.size())
		tints.fill(tint)
		c.append_array(tints)
		var start := i.size()
		i.resize(start + si.size())
		for k in si.size():
			i[start + k] = si[k] + base
