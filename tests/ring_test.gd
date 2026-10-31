extends GdUnitTestSuite
## Hedgehogs want a corridor that rings a piece.

var data: GameData


func before() -> void:
	data = GameData.load_dir()


func test_six_blooms_round_a_piece_ring_it() -> void:
	var g := ValleyGame.new(data, data.valley("first_valley"), 1)
	# A piece in the middle ring of the valley, with all six bloom spots
	# around it bloomed.
	var piece: Vector2i = PlotGrid.plot_neighbors(g.center)[0]
	g.placed[piece] = true
	var ring: Array = []
	for v in PlotGrid.plot_weave_points(piece):
		g.blooms[v] = "fern_hollow"
		ring.append(v)
	assert_bool(g.rings_a_piece(ring)).is_true()
	# Five of the six are an open arc: no ring.
	var arc: Array = ring.slice(0, 5)
	for v: Vector3i in ring:
		g.blooms.erase(v)
	for v: Vector3i in arc:
		g.blooms[v] = "fern_hollow"
	assert_bool(g.rings_a_piece(arc)).is_false()


func test_ring_need_shows_in_checks() -> void:
	var g := ValleyGame.new(data, data.valley("first_valley"), 1)
	var piece: Vector2i = PlotGrid.plot_neighbors(g.center)[0]
	g.placed[piece] = true
	var ring: Array = []
	for v in PlotGrid.plot_weave_points(piece):
		g.blooms[v] = "fern_hollow"
		ring.append(v)
	var hedgehog := {"id": "hedgehog_test", "needs": {"min_blooms": 6, "ring": true}}
	g._animals["hedgehog_test"] = hedgehog
	var checks := g.animal_checks("hedgehog_test", ring)
	assert_str(checks[1].label).is_equal("ring round a piece")
	assert_int(checks[1].have).is_equal(1)
	assert_bool(g.animal_satisfied_by("hedgehog_test", ring)).is_true()


func test_long_corridor_can_stand_in_for_a_ring() -> void:
	var g := ValleyGame.new(data, data.valley("first_valley"), 1)
	g._animals["h"] = {"id": "h", "needs": {"min_blooms": 6, "ring": true, "ring_or_blooms": 8}}
	var spots: Array = []
	for base in g.plots:
		for v in PlotGrid.plot_weave_points(base):
			if not spots.has(v):
				spots.append(v)
	var line: Array = spots.slice(0, 7)
	assert_bool(g.animal_satisfied_by("h", line)).is_false()
	assert_bool(g.animal_satisfied_by("h", spots.slice(0, 8))).is_true()
