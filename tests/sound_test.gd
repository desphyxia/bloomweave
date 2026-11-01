extends GdUnitTestSuite
## The sound director: every listed sound exists, the landscape drives the
## nature layers, and the mutes reach the buses.


func test_every_listed_sound_exists() -> void:
	for name: String in SoundDirector.SOUNDS:
		assert_bool(ResourceLoader.exists("res://sounds/%s.wav" % name)).override_failure_message(name).is_true()
	for name: String in SoundDirector.CALLS.values():
		assert_bool(SoundDirector.SOUNDS.has(name)).override_failure_message(name).is_true()


func test_landscape_and_mutes() -> void:
	var s: SoundDirector = auto_free(SoundDirector.new())
	add_child(s)
	assert_int(s._streams.size()).is_equal(SoundDirector.SOUNDS.size())
	s.set_landscape({"heath": 0.3, "forest": 0.2}, false)
	assert_float(s._layer_target["wind"]).is_greater(SoundDirector.SILENT)
	assert_float(s._layer_target["water"]).is_equal(SoundDirector.SILENT)
	assert_float(s._birdiness).is_greater(0.0)
	s.set_landscape({}, true)
	assert_float(s._layer_target["water"]).is_greater(SoundDirector.SILENT)
	var music_was := s.music_on
	var effects_was := s.effects_on
	s.set_music(false)
	assert_bool(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music"))).is_true()
	s.set_effects(false)
	assert_bool(AudioServer.is_bus_mute(AudioServer.get_bus_index("Effects"))).is_true()
	s.set_music(music_was)
	s.set_effects(effects_was)
