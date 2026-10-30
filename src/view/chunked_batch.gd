class_name ChunkedBatch
extends Node3D
## Merged meshes in chunks of a few items (pieces or blooms), so adding one
## only rebuilds its chunk: a few draw calls per chunk, and the cost of an
## update stays small however full the board gets.

var per_chunk := 6
var textile: Textile
var cast_shadows := true

var _batch: MeshBatch
var _mi: MeshInstance3D
var _items := 0
var _dirty := false


func clear() -> void:
	for c in get_children():
		c.queue_free()
	_batch = null
	_mi = null
	_items = 0
	_dirty = false


## Start the next item; geometry added after this belongs to it.
func next_item() -> void:
	if _batch == null or _items >= per_chunk:
		commit()  # finish the full chunk before starting the next
		_batch = MeshBatch.new()
		_batch.textile = textile
		_mi = MeshInstance3D.new()
		if not cast_shadows:
			_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_mi)
		_items = 0
	_items += 1


func add(mesh: Mesh, xf: Transform3D, color: Color = Color.WHITE, mat: Material = null) -> void:
	if _batch == null:
		next_item()
	_batch.add(mesh, xf, color, mat)
	_dirty = true


## Rebuild the chunk that changed.
func commit() -> void:
	if _dirty:
		_mi.mesh = _batch.commit()
		_dirty = false
