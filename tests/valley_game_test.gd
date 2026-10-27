extends GdUnitTestSuite

var data: GameData


func before() -> void:
	data = GameData.load_dir()


func _game(rng_seed: int = 1) -> ValleyGame:
	return ValleyGame.new(data, data.valley("first_valley"), rng_seed)


## A chain of `n` weave points where each shares a hex with the next.
func _chain(start: Vector3i, n: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = [start]
	while out.size() < n:
		var last: Vector3i = out[-1]
		var grew := false
		for h in Hex.vertex_hexes(last):
			for w in PlotGrid.hex_weave_points(h):
				if not out.has(w):
					out.append(w)
					grew = true
					break
			if grew:
				break
		assert_bool(grew).is_true()
	return out


func test_setup() -> void:
	var g := _game()
	assert_int(g.plots.size()).is_equal(19)
	assert_bool(g.placed.has(Vector2i.ZERO)).is_true()
	assert_int(g.pile.size()).is_equal(18)
	var kinds := {}
	for p: Array in g.pile:
		kinds[Piece.kind(p)] = kinds.get(Piece.kind(p), 0) + 1
	assert_int(kinds.get(Piece.DISTINCT, 0)).is_equal(14)
	assert_int(kinds.get(Piece.DOUBLE, 0)).is_equal(4)
	assert_int(g.legal_plots().size()).is_equal(6)
	assert_int(g.seeds).is_equal(0)


func test_rejects_illegal_placements() -> void:
	var g := _game()
	var piece := g.current_piece()
	var far: Vector2i
	for p in g.plots:
		if PlotGrid.plot_distance(Vector2i.ZERO, p) == 2:
			far = p
			break
	assert_bool(g.place(far, piece).ok).is_false()
	assert_bool(g.place(Vector2i.ZERO, piece).ok).is_false()
	var near := g.legal_plots()[0]
	var wrong := ["heath", "heath", "heath"]
	if Piece.same_biomes(wrong, piece):
		wrong = ["forest", "forest", "forest"]
	assert_bool(g.place(near, wrong).ok).is_false()
	assert_bool(g.place(near, piece).ok).is_true()
	assert_int(g.pile.size()).is_equal(17)


func test_preview_matches_placement_and_awards_seeds() -> void:
	var g := _game(7)
	g.place(g.legal_plots()[0], g.current_piece())
	var found := false
	for p in g.legal_plots():
		for a in Piece.distinct_arrangements(g.current_piece()):
			var pv := g.preview(p, a)
			if pv.is_empty():
				continue
			var result := g.place(p, a)
			assert_bool(result.ok).is_true()
			assert_int(result.blooms.size()).is_equal(pv.size())
			assert_int(g.blooms.size()).is_equal(pv.size())
			assert_int(g.seeds).is_equal(pv.size())
			found = true
			break
		if found:
			break
	assert_bool(found).is_true()


func test_seed_actions() -> void:
	var g := _game()
	g.seeds = 10
	var first := g.current_piece()
	var second: Array = g.pile[1]
	var third: Array = g.pile[2]

	assert_bool(g.swap()).is_true()
	assert_array(g.current_piece()).is_equal(second)
	assert_int(g.seeds).is_equal(9)

	assert_bool(g.set_aside()).is_true()
	assert_array(g.reserve).is_equal(second)
	assert_array(g.current_piece()).is_equal(first)
	assert_int(g.seeds).is_equal(8)
	assert_bool(g.can_set_aside()).is_false()

	assert_bool(g.use_reserve()).is_true()
	assert_array(g.current_piece()).is_equal(second)
	assert_array(g.pile[1]).is_equal(first)
	assert_int(g.seeds).is_equal(8)

	assert_int(g.upcoming().size()).is_equal(1)
	assert_bool(g.look_ahead()).is_true()
	assert_int(g.seeds).is_equal(6)
	assert_int(g.upcoming().size()).is_equal(3)
	assert_array(g.upcoming()[1]).is_equal(third)
	g.place(g.legal_plots()[0], g.current_piece())
	assert_bool(g.look_ahead_active).is_false()


func test_seed_actions_need_seeds() -> void:
	var g := _game()
	assert_bool(g.swap()).is_false()
	assert_bool(g.set_aside()).is_false()
	assert_bool(g.look_ahead()).is_false()
	g.seeds = 1
	assert_bool(g.look_ahead()).is_false()


func test_reserved_piece_comes_back_at_the_end() -> void:
	var g := _game()
	g.seeds = 1
	g.set_aside()
	while g.pile.size() > 0:
		var r := g.place(g.legal_plots()[0], g.current_piece())
		assert_bool(r.ok).is_true()
	assert_bool(g.is_finished()).is_true()
	assert_array(g.reserve).is_empty()


func test_blooms_sharing_a_hex_form_one_corridor() -> void:
	var g := _game()
	var chain := _chain(Vector3i(2, -1, Hex.DOWN), 3)
	for v in chain:
		g.blooms[v] = "fern_hollow"
	var far := Vector3i(20, 20, Hex.UP)
	if PlotGrid.vertex_kind(far) != PlotGrid.WEAVE:
		far = Vector3i(20, 20, Hex.DOWN)
	g.blooms[far] = "misty_carr"
	var groups := g.corridors()
	assert_int(groups.size()).is_equal(2)
	var sizes := [groups[0].size(), groups[1].size()]
	sizes.sort()
	assert_array(sizes).is_equal([1, 3])
	# A chain of 3 has 2 links, or 3 if the blooms also close a small loop.
	assert_int(g.bloom_links().size()).is_between(2, 3)
	for l: Dictionary in g.bloom_links():
		var route := ValleyGame.link_route(l)
		assert_int(route.size()).is_equal(3)
		assert_int(PlotGrid.vertex_kind(route[1])).is_equal(PlotGrid.SEAM)


func test_animals_settle_when_needs_are_met() -> void:
	var g := _game()
	var chain := _chain(Vector3i(2, -1, Hex.DOWN), 6)
	for i in 4:
		g.blooms[chain[i]] = "fern_hollow"  # forest + meadow + wetland
	var settled := g.check_animals()
	assert_array(settled).is_equal(["otter"])
	assert_int(g.seeds).is_equal(2)
	for i in range(4, 6):
		g.blooms[chain[i]] = "foxglove_glade"  # forest + meadow + heath
	settled = g.check_animals()
	assert_array(settled).is_equal(["deer"])
	assert_int(g.seeds).is_equal(4)
	assert_array(g.check_animals()).is_empty()


func test_deer_need_enough_forest_blooms() -> void:
	var g := _game()
	var chain := _chain(Vector3i(2, -1, Hex.DOWN), 6)
	for v in chain:
		g.blooms[v] = "cotton_grass_moor"  # no forest
	assert_bool(g.check_animals().has("deer")).is_false()
	assert_int(g.animal_progress("deer").blooms).is_equal(6)
	assert_int(g.animal_progress("deer").biome_blooms).is_equal(0)


func test_score_breakdown() -> void:
	var g := _game()
	g.blooms[Vector3i(2, -1, Hex.DOWN)] = "fern_hollow"
	g.settled["otter"] = []
	g.seeds = 3
	var s := g.score_breakdown()
	assert_int(s.blooms).is_equal(2)
	assert_int(s.animals).is_equal(10)
	assert_int(s.seeds).is_equal(3)
	assert_int(s.total).is_equal(15)


func test_full_games_keep_rules_consistent() -> void:
	for rng_seed in range(12):
		var g := _game(100 + rng_seed)
		var spent := 0
		var animal_seeds := 0
		var steps := 0
		while not g.is_finished():
			steps += 1
			assert_int(steps).is_less(40)
			# Sometimes use seed actions.
			if g.can_swap() and steps % 3 == 0:
				spent += g.cost("swap")
				g.swap()
			if g.can_set_aside() and steps % 5 == 0:
				spent += g.cost("set_aside")
				g.set_aside()
			if g.can_use_reserve() and steps % 7 == 0:
				g.use_reserve()
			# Greedy: the placement that makes the most blooms.
			var best_plot := g.legal_plots()[0]
			var best_arr: Array = g.current_piece()
			var best_n := -1
			for p in g.legal_plots():
				for a in Piece.distinct_arrangements(g.current_piece()):
					var n := g.preview(p, a).size()
					if n > best_n:
						best_n = n
						best_plot = p
						best_arr = a
			var r := g.place(best_plot, best_arr)
			assert_bool(r.ok).is_true()
			for id: String in r.settled:
				animal_seeds += int(data.animals[id].seeds)
		assert_int(g.placed.size()).is_equal(19)
		assert_int(g.board.size()).is_equal(57)
		assert_int(g.pieces_left()).is_equal(0)
		assert_int(g.seeds).is_equal(g.blooms.size() + animal_seeds - spent)
		_assert_blooms_consistent(g)


## Every bloom has a valid trio, and every complete weave point with a valid
## trio has bloomed.
func _assert_blooms_consistent(g: ValleyGame) -> void:
	var checked := {}
	for base in g.plots:
		for v in PlotGrid.plot_weave_points(base):
			if checked.has(v):
				continue
			checked[v] = true
			var trio := []
			for h in Hex.vertex_hexes(v):
				if g.board.has(h):
					trio.append(g.board[h])
			if trio.size() < 3:
				assert_bool(g.blooms.has(v)).is_false()
				continue
			var bloom := data.bloom_for(trio)
			if bloom.is_empty():
				assert_bool(g.blooms.has(v)).is_false()
			else:
				assert_str(g.blooms.get(v, "")).is_equal(bloom.id)
