extends GdUnitTestSuite


func _sample_hexes() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for q in range(-4, 5):
		for r in range(-4, 5):
			out.append(Vector2i(q, r))
	return out


func test_distance() -> void:
	assert_int(Hex.distance(Vector2i(0, 0), Vector2i(0, 0))).is_equal(0)
	assert_int(Hex.distance(Vector2i(0, 0), Vector2i(2, -1))).is_equal(2)
	assert_int(Hex.distance(Vector2i(-2, 3), Vector2i(1, -1))).is_equal(4)
	for d in Hex.DIRECTIONS:
		assert_int(Hex.distance(Vector2i.ZERO, d)).is_equal(1)


func test_world_round_trip() -> void:
	for h in _sample_hexes():
		assert_that(Hex.from_world(Hex.to_world(h, 1.3), 1.3)).is_equal(h)


func test_neighbor_across_edge_matches_corner_layout() -> void:
	# The neighbour across edge i lies in the direction of the edge midpoint.
	for i in 6:
		var mid := (Hex.corner_offset(i) + Hex.corner_offset(i + 1)) / 2.0
		var n := Hex.to_world(Hex.DIRECTIONS[i])
		assert_float(mid.normalized().dot(n.normalized())).is_equal_approx(1.0, 0.0001)


func test_vertex_hexes_are_mutually_adjacent() -> void:
	for h in _sample_hexes():
		for kind in [Hex.UP, Hex.DOWN]:
			var hs := Hex.vertex_hexes(Vector3i(h.x, h.y, kind))
			assert_int(Hex.distance(hs[0], hs[1])).is_equal(1)
			assert_int(Hex.distance(hs[1], hs[2])).is_equal(1)
			assert_int(Hex.distance(hs[0], hs[2])).is_equal(1)


func test_every_corner_has_one_key_seen_from_each_hex() -> void:
	for h in _sample_hexes():
		var vs := Hex.hex_vertices(h)
		var unique := {}
		for v in vs:
			unique[v] = true
			var hs := Hex.vertex_hexes(v)
			assert_bool(hs.has(h)).is_true()
			# The same corner seen from the other two hexes gives the same key.
			for other in hs:
				assert_int(Hex.corner_index(other, v)).is_not_equal(-1)
		assert_int(unique.size()).is_equal(6)


func test_corner_vertex_position_matches_corner_offset() -> void:
	for h in _sample_hexes():
		for i in 6:
			var expected := Hex.to_world(h) + Hex.corner_offset(i)
			var actual := Hex.vertex_world(Hex.corner_vertex(h, i))
			assert_float(expected.distance_to(actual)).is_less(0.0001)
