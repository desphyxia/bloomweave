extends GdUnitTestSuite
## The terrain-carved valley generator.


func test_same_seed_same_valley() -> void:
	var a := ValleyGenerator.generate(42, 26)
	var b := ValleyGenerator.generate(42, 26)
	assert_array(a.plots).is_equal(b.plots)
	assert_array(a.hills).is_equal(b.hills)


func test_valleys_are_whole_and_clear_of_hills() -> void:
	for s in range(5):
		var g := ValleyGenerator.generate(100 + s, 26)
		var plots: Array[Vector2i] = g.plots
		assert_int(plots.size()).is_between(24, 28)
		assert_bool(plots.has(g.landmark)).is_true()
		# One piece: every plot reachable from the landmark.
		var inside := {}
		for p in plots:
			inside[p] = true
			assert_bool(PlotGrid.is_base(p)).is_true()
		var seen := {g.landmark: true}
		var stack: Array[Vector2i] = [g.landmark]
		while not stack.is_empty():
			var p: Vector2i = stack.pop_back()
			for q in PlotGrid.plot_neighbors(p):
				if inside.has(q) and not seen.has(q):
					seen[q] = true
					stack.append(q)
		assert_int(seen.size()).is_equal(plots.size())
		# No hill reaches over a valley hex.
		for hill: Array in g.hills:
			for p in plots:
				for h in PlotGrid.plot_hexes(p):
					assert_float(Vector2(hill[0], hill[1]).distance_to(Hex.to_world(h))).is_greater(float(hill[2]))


func test_stats_count_bloom_spots() -> void:
	var round_valley := PlotGrid.plots_within(Vector2i.ZERO, 2)
	var st := ValleyGenerator.stats(round_valley)
	assert_int(st.plots).is_equal(19)
	assert_int(st.bloom_spots).is_equal(24)
	assert_int(st.interior).is_equal(7)
