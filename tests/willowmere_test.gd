extends GdUnitTestSuite
## Level 2: a horseshoe of plots round a lake, Deep Wood, otters by the lake
## and badgers.

var data: GameData


func before() -> void:
	data = GameData.load_dir()


func _game() -> ValleyGame:
	return ValleyGame.new(data, data.valley("willowmere"), 7)


func test_outline_and_lake() -> void:
	var g := _game()
	assert_int(g.plots.size()).is_equal(23)
	assert_int(g.pile.size()).is_equal(22)
	assert_bool(g.is_in_valley(Vector2i.ZERO)).is_false()
	assert_int(g.obstacles.size()).is_equal(3)
	assert_str(g.obstacles[Vector2i.ZERO]).is_equal("lake")
	assert_bool(g.placed.has(Vector2i(2, -4))).is_true()   # landmark
	assert_bool(g.can_place(Vector2i.ZERO)).is_false()


func test_recipes_are_per_valley() -> void:
	var g := _game()
	assert_str(g.bloom_for(["forest", "forest", "forest"]).get("id", "")).is_equal("deep_wood")
	assert_int(g.recipes().size()).is_equal(5)
	var first := ValleyGame.new(data, data.valley("first_valley"), 1)
	assert_dict(first.bloom_for(["forest", "forest", "forest"])).is_empty()
	assert_int(first.recipes().size()).is_equal(4)


func test_deep_wood_blooms_from_three_forest_hexes() -> void:
	var g := _game()
	# Fill the two plots next to the landmark that share a corner with a third
	# plot, all forest, then the third: its shared corner is three forests.
	var a := Vector2i(1, -2)
	var b := Vector2i(3, -3)
	assert_bool(g.can_place(a)).is_true()
	g.set_pile([["forest", "forest", "forest"], ["forest", "forest", "forest"], ["forest", "forest", "forest"]])
	var r1 := g.place(a, ["forest", "forest", "forest"])
	var r2 := g.place(b, ["forest", "forest", "forest"])
	var made := []
	for r: Dictionary in [r1, r2]:
		for bl: Dictionary in r.blooms:
			made.append(bl.bloom)
	# Landmark has one forest hex; somewhere around it forests meet.
	var third := Vector2i(2, -1)
	var r3 := g.place(third, ["forest", "forest", "forest"])
	for bl: Dictionary in r3.blooms:
		made.append(bl.bloom)
	assert_bool(made.has("deep_wood")).is_true()


func test_otters_want_blooms_by_the_lake() -> void:
	var g := _game()
	var near: Array[Vector3i] = []
	var far: Array[Vector3i] = []
	for base in g.plots:
		for v in PlotGrid.plot_weave_points(base):
			if near.has(v) or far.has(v):
				continue
			(near if g.is_near_obstacle(v, "lake") else far).append(v)
	assert_int(near.size()).is_greater_equal(2)
	var corridor: Array = [near[0], near[1], far[0], far[1], far[2]]
	for v: Vector3i in corridor:
		g.blooms[v] = "fern_hollow"
	assert_bool(g.animal_satisfied_by("otter", corridor)).is_true()
	assert_bool(g.animal_satisfied_by("otter", [far[0], far[1], far[2], far[3], far[4]])).is_false()
	var checks := g.animal_checks("otter", corridor)
	assert_str(checks[1].label).is_equal("by the lake")


func test_badgers_want_two_deep_woods() -> void:
	var g := _game()
	var spots: Array[Vector3i] = []
	for base in g.plots:
		for v in PlotGrid.plot_weave_points(base):
			if not spots.has(v):
				spots.append(v)
	var corridor := spots.slice(0, 4)
	for v: Vector3i in corridor:
		g.blooms[v] = "fern_hollow"
	assert_bool(g.animal_satisfied_by("badger", corridor)).is_false()
	g.blooms[corridor[0]] = "deep_wood"
	g.blooms[corridor[1]] = "deep_wood"
	assert_bool(g.animal_satisfied_by("badger", corridor)).is_true()


func test_stars() -> void:
	var g := _game()
	assert_dict(g.stars()).is_equal({"restored": false, "residents": false, "visitor": false})
	g.settled = {"otter": [], "badger": []}
	assert_bool(g.stars().residents).is_true()
	assert_int(g.star_count()).is_equal(1)
