extends GdUnitTestSuite
## Hidden visitors: a secret pattern brings a third animal and the third star.

var data: GameData


func before() -> void:
	data = GameData.load_dir()


func test_grouse_comes_for_a_wide_patch_of_heath() -> void:
	var g := ValleyGame.new(data, data.valley("first_valley"), 1)
	assert_str(g.visitor().id).is_equal("grouse")
	var need := int(g.visitor().pattern.min_hexes)
	# Grow one joined patch of heath out from the landmark, one piece at a time.
	var found := ""
	var seeds_before := 0
	for _i in 6:
		seeds_before = g.seeds
		g.set_pile([["heath", "heath", "heath"]])
		var r := g.place(g.legal_plots()[0], ["heath", "heath", "heath"])
		if r.visitor != "":
			found = r.visitor
			break
	assert_str(found).is_equal("grouse")
	assert_bool(g.visitor_found).is_true()
	assert_int(g.largest_patch("heath").size()).is_greater_equal(need)
	assert_str(g.board[g.visitor_spot]).is_equal("heath")
	assert_int(g.seeds - seeds_before).is_greater_equal(int(g.visitor().seeds))
	assert_bool(g.stars().visitor).is_true()
	assert_int(g.score_breakdown().animals).is_equal(int(g.visitor().points))
	# It only comes once.
	assert_str(g.check_visitor()).is_equal("")


func test_patch_must_be_joined() -> void:
	var g := ValleyGame.new(data, data.valley("first_valley"), 1)
	g.board[Vector2i(10, 0)] = "heath"
	g.board[Vector2i(12, 0)] = "heath"
	g.board[Vector2i(13, 0)] = "heath"
	assert_int(g.largest_patch("heath").size()).is_equal(2)


func test_heron_counts_wetland_on_the_lake_shore() -> void:
	var g := ValleyGame.new(data, data.valley("willowmere"), 1)
	assert_str(g.visitor().id).is_equal("heron")
	var shore: Array[Vector2i] = []
	for base in g.plots:
		for h in PlotGrid.plot_hexes(base):
			for nb in Hex.neighbors(h):
				if g.obstacles.get(nb, "") == "lake" and not shore.has(h):
					shore.append(h)
	var need := int(g.visitor().pattern.min_hexes)
	assert_int(shore.size()).is_greater_equal(need)
	for i in need - 1:
		g.board[shore[i]] = "wetland"
	g.board[shore[need - 1]] = "forest"
	assert_int(g.visitor_progress().have).is_equal(need - 1)
	assert_str(g.check_visitor()).is_equal("")
	g.board[shore[need - 1]] = "wetland"
	assert_str(g.check_visitor()).is_equal("heron")
	assert_int(g.star_count()).is_equal(1)
