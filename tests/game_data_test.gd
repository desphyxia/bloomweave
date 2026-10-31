extends GdUnitTestSuite


func test_shipped_data_is_valid() -> void:
	var d := GameData.load_dir()
	assert_array(d.validate()).is_empty()
	assert_int(d.levels.size()).is_greater_equal(3)
	for id: String in d.levels:
		assert_array(d.validate_valley(d.valley(id))).is_empty()
	assert_int(d.biome_ids.size()).is_equal(4)
	assert_int(d.blooms_by_id.size()).is_equal(5)


func test_bloom_lookup_ignores_order() -> void:
	var d := GameData.load_dir()
	assert_str(d.bloom_for(["wetland", "forest", "meadow"]).get("id", "")).is_equal("fern_hollow")
	assert_str(d.bloom_for(["heath", "wetland", "meadow"]).get("id", "")).is_equal("cotton_grass_moor")


func test_clockwise_lookup_needs_listed_order() -> void:
	var d := GameData.load_dir()
	# Fern Hollow is listed forest -> meadow -> wetland.
	assert_str(d.bloom_for(["forest", "meadow", "wetland"], true).get("id", "")).is_equal("fern_hollow")
	assert_str(d.bloom_for(["wetland", "forest", "meadow"], true).get("id", "")).is_equal("fern_hollow")
	assert_dict(d.bloom_for(["forest", "wetland", "meadow"], true)).is_empty()
	# Without the rule, any order matches.
	assert_str(d.bloom_for(["forest", "wetland", "meadow"]).get("id", "")).is_equal("fern_hollow")


func test_same_biome_trios_bloom_only_with_a_recipe() -> void:
	var d := GameData.load_dir()
	assert_str(d.bloom_for(["forest", "forest", "forest"]).get("id", "")).is_equal("deep_wood")
	assert_str(d.bloom_for(["forest", "forest", "forest"], true).get("id", "")).is_equal("deep_wood")
	assert_dict(d.bloom_for(["forest", "forest", "meadow"])).is_empty()
	assert_dict(d.bloom_for(["heath", "heath", "heath"])).is_empty()


func test_clockwise_two_plus_one_recipe_matches_any_rotation() -> void:
	var d := GameData.new()
	d.setup([{"id": "a"}, {"id": "b"}], [{"id": "x", "trio": ["a", "a", "b"]}], [])
	for t: Array in [["a", "a", "b"], ["a", "b", "a"], ["b", "a", "a"]]:
		assert_str(d.bloom_for(t, true).get("id", "")).is_equal("x")


func test_validate_catches_bad_valley() -> void:
	var d := GameData.load_dir()
	var v := d.valley("first_valley").duplicate(true)
	v.pile.distinct = 3
	v.animals = ["unicorn"]
	assert_int(d.validate_valley(v).size()).is_equal(2)


func test_validate_catches_bad_outline() -> void:
	var d := GameData.load_dir()
	var v := d.valley("willowmere").duplicate(true)
	v.obstacles[0].plots = [[2, -4]]        # on top of the landmark plot
	v.landmark.plot = [9, 0]                # outside the outline
	v.blooms.append("moonflower")
	assert_int(d.validate_valley(v).size()).is_equal(3)
