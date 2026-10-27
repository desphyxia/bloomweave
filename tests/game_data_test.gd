extends GdUnitTestSuite


func test_shipped_data_is_valid() -> void:
	var d := GameData.load_dir()
	assert_array(d.validate()).is_empty()
	assert_array(d.validate_valley(d.valley("first_valley"))).is_empty()
	assert_int(d.biome_ids.size()).is_equal(4)
	assert_int(d.blooms_by_id.size()).is_equal(4)


func test_bloom_lookup_ignores_order() -> void:
	var d := GameData.load_dir()
	assert_str(d.bloom_for(["wetland", "forest", "meadow"]).get("id", "")).is_equal("fern_hollow")
	assert_str(d.bloom_for(["heath", "wetland", "meadow"]).get("id", "")).is_equal("cotton_grass_moor")


func test_same_biome_trios_do_not_bloom() -> void:
	var d := GameData.load_dir()
	assert_dict(d.bloom_for(["forest", "forest", "meadow"])).is_empty()
	assert_dict(d.bloom_for(["heath", "heath", "heath"])).is_empty()


func test_validate_catches_bad_valley() -> void:
	var d := GameData.load_dir()
	var v := d.valley("first_valley").duplicate(true)
	v.pile.distinct = 3
	v.animals = ["unicorn"]
	assert_int(d.validate_valley(v).size()).is_equal(2)
