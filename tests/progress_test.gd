extends GdUnitTestSuite

const TEST_PATH := "user://progress_test.json"
var data: GameData


func before() -> void:
	data = GameData.load_dir()


func after() -> void:
	DirAccess.remove_absolute(TEST_PATH)


func _finished_game(id: String, settle_all: bool) -> ValleyGame:
	var g := ValleyGame.new(data, data.valley(id), 3)
	while not g.is_finished():
		g.place(g.legal_plots()[0], g.current_piece())
	if settle_all:
		for a: String in g.residents():
			g.settled[a] = []
	return g


func test_first_level_open_next_opens_when_restored() -> void:
	var p := Progress.new(data.levels, TEST_PATH)
	assert_array(data.levels.slice(0, 2)).is_equal(["first_valley", "willowmere"])
	assert_bool(p.is_unlocked("first_valley")).is_true()
	assert_bool(p.is_unlocked("willowmere")).is_false()
	var half := ValleyGame.new(data, data.valley("first_valley"), 3)
	p.record("first_valley", half)
	assert_bool(p.is_unlocked("willowmere")).is_false()
	p.record("first_valley", _finished_game("first_valley", false))
	assert_bool(p.is_unlocked("willowmere")).is_true()
	assert_str(p.next_level("first_valley")).is_equal("willowmere")
	assert_str(p.next_level(data.levels[-1])).is_equal("")


func test_dev_mode_opens_every_level() -> void:
	var p := Progress.new(data.levels, TEST_PATH)
	assert_bool(p.is_unlocked(data.levels[-1])).is_false()
	p.unlock_all = true
	for id: String in data.levels:
		assert_bool(p.is_unlocked(id)).is_true()
	assert_bool(p.is_unlocked("no_such_level")).is_false()
	assert_int(p.total_stars()).is_equal(0)


func test_stars_only_add_up_and_save() -> void:
	var p := Progress.new(data.levels, TEST_PATH)
	var r := p.record("first_valley", _finished_game("first_valley", true))
	assert_int(r.new_stars).is_equal(2)
	assert_int(p.star_count("first_valley")).is_equal(2)
	var best := p.best("first_valley")
	assert_int(best).is_greater(0)
	# A worse game later keeps the stars and the best score.
	r = p.record("first_valley", _finished_game("first_valley", false))
	assert_int(r.new_stars).is_equal(0)
	assert_int(p.star_count("first_valley")).is_equal(2)
	assert_int(p.best("first_valley")).is_equal(best)
	p.save()
	var loaded := Progress.load_from(data.levels, TEST_PATH)
	assert_int(loaded.star_count("first_valley")).is_equal(2)
	assert_int(loaded.total_stars()).is_equal(2)
	assert_bool(loaded.is_unlocked("willowmere")).is_true()


func test_discoveries_are_kept_once_and_saved() -> void:
	var p := Progress.new(data.levels, TEST_PATH)
	assert_bool(p.journal_unseen).is_false()
	assert_bool(p.discover("blooms", "fern_hollow", "first_valley")).is_true()
	assert_bool(p.discover("blooms", "fern_hollow", "willowmere")).is_false()
	assert_str(p.found_in("blooms", "fern_hollow")).is_equal("first_valley")
	assert_bool(p.journal_unseen).is_true()
	p.discover("visitors", "heron", "willowmere")
	p.save()
	var loaded := Progress.load_from(data.levels, TEST_PATH)
	assert_bool(loaded.is_found("visitors", "heron")).is_true()
	assert_bool(loaded.is_found("residents", "otter")).is_false()
	assert_bool(loaded.journal_unseen).is_true()


func test_journal_lists_what_the_levels_use() -> void:
	var e := Journal.entries(data)
	var bloom_ids: Array = e.blooms.map(func(x: Dictionary) -> String: return x.id)
	assert_bool(bloom_ids.has("deep_wood")).is_true()
	assert_bool(bloom_ids.has("fern_hollow")).is_true()
	for b: Dictionary in e.blooms:
		if b.id == "deep_wood":
			assert_array(b.levels).contains(["willowmere"])
			assert_bool(b.levels.has("first_valley")).is_false()
		if b.id == "fern_hollow":
			assert_int(b.levels.size()).is_equal(data.levels.size())
	var visitors: Array = e.visitors.map(func(x: Dictionary) -> String: return x.id)
	assert_array(visitors).contains(["grouse", "heron", "hare"])
	var residents: Array = e.residents.map(func(x: Dictionary) -> String: return x.id)
	assert_bool(residents.has("hare")).is_false()
	assert_bool(residents.has("badger")).is_true()


func test_regions_and_star_gate() -> void:
	assert_int(data.regions.size()).is_greater_equal(2)
	var first: Dictionary = data.regions[0]
	assert_array(first.levels).is_equal(data.levels)
	var p := Progress.new(data.levels, TEST_PATH)
	assert_bool(p.region_open(data.regions, 0)).is_true()
	assert_bool(p.region_open(data.regions, 1)).is_false()
	# Give every level of the first region two stars: past the gate.
	for id: String in first.levels:
		p.records[id] = {"stars": {"restored": true, "residents": true, "visitor": false}, "best": 1}
	assert_int(p.region_stars(first)).is_equal(first.levels.size() * 2)
	assert_bool(p.region_open(data.regions, 1)).is_true()


func test_restored_board_is_kept() -> void:
	var p := Progress.new(data.levels, TEST_PATH)
	assert_dict(p.board("first_valley")).is_empty()
	var g := _finished_game("first_valley", false)
	p.record("first_valley", g)
	var b := p.board("first_valley")
	assert_int(b.size()).is_equal(g.board.size())
	for h: Vector2i in g.board:
		assert_str(b[h]).is_equal(g.board[h])
	p.save()
	assert_int(Progress.load_from(data.levels, TEST_PATH).board("first_valley").size()).is_equal(g.board.size())
