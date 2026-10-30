extends GdUnitTestSuite
## Merging meshes for fewer draw calls (view helper, but plain enough to test).


func _box() -> BoxMesh:
	return BoxMesh.new()


func test_merges_by_material_and_keeps_indices() -> void:
	var t := Textile.new()
	var b := MeshBatch.new()
	b.textile = t
	var box := _box()
	var src_len := box.get_mesh_arrays()[Mesh.ARRAY_VERTEX].size() as int
	b.add(box, Transform3D(Basis(), Vector3(1, 0, 0)), Color.WHITE, t.fabric(Color.RED))
	b.add(box, Transform3D(Basis(), Vector3(3, 0, 0)), Color.WHITE, t.fabric(Color.BLUE))
	var mesh := b.commit()
	# Red and blue fabric share one white material: one surface, colour per vertex.
	assert_int(mesh.get_surface_count()).is_equal(1)
	var arr := mesh.surface_get_arrays(0)
	assert_int((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()).is_equal(src_len * 2)
	assert_object(arr[Mesh.ARRAY_INDEX]).is_not_null()
	var colors: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	assert_bool(colors[0].is_equal_approx(Color.RED)).is_true()
	assert_bool(colors[colors.size() - 1].is_equal_approx(Color.BLUE)).is_true()
	assert_float((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array)[src_len].x).is_greater(2.0)


func test_chunks_commit_every_chunk() -> void:
	var cb: ChunkedBatch = auto_free(ChunkedBatch.new())
	cb.per_chunk = 2
	for i in 5:
		cb.next_item()
		cb.add(_box(), Transform3D(Basis(), Vector3(i, 0, 0)))
	cb.commit()
	assert_int(cb.get_child_count()).is_equal(3)
	for c in cb.get_children():
		assert_object((c as MeshInstance3D).mesh).is_not_null()
