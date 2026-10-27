extends GdUnitTestSuite


func _sample_hexes() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for q in range(-5, 6):
		for r in range(-5, 6):
			out.append(Vector2i(q, r))
	return out


func _sample_plots() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for h in _sample_hexes():
		if PlotGrid.is_base(h):
			out.append(h)
	return out


func test_every_hex_belongs_to_exactly_one_plot() -> void:
	for h in _sample_hexes():
		var base := PlotGrid.plot_of(h)
		assert_bool(PlotGrid.is_base(base)).is_true()
		assert_bool(PlotGrid.plot_hexes(base).has(h)).is_true()


func test_plot_hexes_meet_at_confluence() -> void:
	for base in _sample_plots():
		var hs := Hex.vertex_hexes(PlotGrid.confluence(base))
		for h in PlotGrid.plot_hexes(base):
			assert_bool(hs.has(h)).is_true()


func test_each_plot_has_six_neighbours() -> void:
	for base in _sample_plots():
		assert_int(PlotGrid.plot_neighbors(base).size()).is_equal(6)


func test_vertex_kinds_per_plot() -> void:
	# Each plot touches 1 confluence, 6 seams and 6 weave points.
	for base in _sample_plots():
		var counts := {PlotGrid.CONFLUENCE: 0, PlotGrid.SEAM: 0, PlotGrid.WEAVE: 0}
		var seen := {}
		for h in PlotGrid.plot_hexes(base):
			for v in Hex.hex_vertices(h):
				if not seen.has(v):
					seen[v] = true
					counts[PlotGrid.vertex_kind(v)] += 1
		assert_int(counts[PlotGrid.CONFLUENCE]).is_equal(1)
		assert_int(counts[PlotGrid.SEAM]).is_equal(6)
		assert_int(counts[PlotGrid.WEAVE]).is_equal(6)
		assert_int(PlotGrid.plot_weave_points(base).size()).is_equal(6)


func test_each_hex_has_two_weave_points_two_edges_apart() -> void:
	for h in _sample_hexes():
		var ws := PlotGrid.hex_weave_points(h)
		assert_int(ws.size()).is_equal(2)
		var gap := posmod(Hex.corner_index(h, ws[1]) - Hex.corner_index(h, ws[0]), 6)
		assert_bool(gap == 2 or gap == 4).is_true()


func test_trail_corner_is_a_seam_on_a_piece_border() -> void:
	for h in _sample_hexes():
		var c := PlotGrid.trail_corner(h)
		assert_int(PlotGrid.vertex_kind(c)).is_equal(PlotGrid.SEAM)
		var i := Hex.corner_index(h, c)
		# Both trail edges (into and out of the corner) border another plot.
		for edge in [posmod(i - 1, 6), i]:
			var across := Hex.neighbor(h, edge)
			assert_that(PlotGrid.plot_of(across)).is_not_equal(PlotGrid.plot_of(h))
		# And the corner sits between the hex's two weave points.
		var ws := PlotGrid.hex_weave_points(h)
		for w in ws:
			var d := posmod(Hex.corner_index(h, w) - i, 6)
			assert_bool(d == 1 or d == 5).is_true()


func test_plots_within_radius() -> void:
	assert_int(PlotGrid.plots_within(Vector2i.ZERO, 0).size()).is_equal(1)
	assert_int(PlotGrid.plots_within(Vector2i.ZERO, 1).size()).is_equal(7)
	assert_int(PlotGrid.plots_within(Vector2i.ZERO, 2).size()).is_equal(19)
	for p in PlotGrid.plots_within(Vector2i.ZERO, 2):
		assert_bool(PlotGrid.plot_distance(Vector2i.ZERO, p) <= 2).is_true()
