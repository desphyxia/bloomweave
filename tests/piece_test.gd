extends GdUnitTestSuite


func test_arrangement_counts() -> void:
	assert_int(Piece.distinct_arrangements(["forest", "meadow", "wetland"]).size()).is_equal(6)
	assert_int(Piece.distinct_arrangements(["forest", "forest", "meadow"]).size()).is_equal(3)
	assert_int(Piece.distinct_arrangements(["heath", "heath", "heath"]).size()).is_equal(1)


func test_rotation_cycles_and_mirror_swaps() -> void:
	var p := ["a", "b", "c"]
	assert_array(Piece.arrange(p, 0, false)).is_equal(["a", "b", "c"])
	assert_array(Piece.arrange(p, 1, false)).is_equal(["c", "a", "b"])
	assert_array(Piece.arrange(p, 3, false)).is_equal(["a", "b", "c"])
	assert_array(Piece.arrange(p, 0, true)).is_equal(["a", "c", "b"])


func test_kind() -> void:
	assert_str(Piece.kind(["a", "b", "c"])).is_equal(Piece.DISTINCT)
	assert_str(Piece.kind(["a", "a", "c"])).is_equal(Piece.DOUBLE)
	assert_str(Piece.kind(["a", "a", "a"])).is_equal(Piece.SINGLE)


func test_same_biomes() -> void:
	assert_bool(Piece.same_biomes(["a", "b", "c"], ["c", "a", "b"])).is_true()
	assert_bool(Piece.same_biomes(["a", "a", "c"], ["a", "c", "c"])).is_false()
