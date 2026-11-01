class_name SoundDirector
extends Node
## All of the game's sound, made in code (see tools/make_sounds.gd):
##   - music: an endless, slow folk tune from plucked strings over a soft
##     drone, wandering a pentatonic scale, never quite repeating
##   - nature: wind, water and meadow hum that swell as their biomes fill the
##     valley, and birdsong that grows with forest and hedgerow
##   - effects: a fabric rustle when a piece lands, a chime per bloom (rising
##     in a combo), a flourish for a perfect piece, and a call plus a little
##     motif when an animal moves in
## Two buses, Music (music) and Effects (effects and nature), muted
## separately; the choice is saved on the device. Browsers start sound on the
## first tap.

const SETTINGS := "user://settings.json"
const SCALE := ["pluck_d3", "pluck_e3", "pluck_fs3", "pluck_a3", "pluck_b3",
	"pluck_d4", "pluck_e4", "pluck_fs4", "pluck_a4", "pluck_b4", "pluck_d5"]
const BEAT := 0.62           # seconds per beat of the tune
const SILENT := -60.0
## Every sound tools/make_sounds.gd writes (listed, not scanned, so the web
## build finds them the same way).
const SOUNDS := ["pluck_d3", "pluck_e3", "pluck_fs3", "pluck_a3", "pluck_b3",
	"pluck_d4", "pluck_e4", "pluck_fs4", "pluck_a4", "pluck_b4", "pluck_d5",
	"chime_1", "chime_2", "chime_3", "chime_4", "chime_5", "chime_6",
	"drone", "wind", "water", "meadow", "bird_0", "bird_1", "bird_2", "bird_3",
	"place", "owl", "squeak", "whistle"]

var music_on := true
var effects_on := true

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _layers := {}            # name -> AudioStreamPlayer (looping)
var _layer_target := {}      # name -> volume_db it is easing toward
var _drone: AudioStreamPlayer
var _degree := 5             # where the tune is on the scale
var _beat_timer := 0.0
var _bird_timer := 3.0
var _birdiness := 0.0        # 0..1, how much birdsong
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for bus in ["Music", "Effects"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	_load_settings()
	for name: String in SOUNDS:
		var path := "res://sounds/%s.wav" % name
		if ResourceLoader.exists(path):
			_streams[name] = load(path)
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_drone = _looping("drone", "Music")
	_drone.volume_db = -17.0
	for name in ["wind", "water", "meadow"]:
		_layers[name] = _looping(name, "Effects")
		_layer_target[name] = SILENT
	_apply_mutes()


func _looping(name: String, bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.volume_db = SILENT
	var s: Variant = _streams.get(name)
	if s is AudioStreamWAV:
		var w: AudioStreamWAV = (s as AudioStreamWAV).duplicate()
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
		p.stream = w
	add_child(p)
	if p.stream:
		p.play()
	return p


func _process(delta: float) -> void:
	# Layers ease toward their targets so the valley's sound swells gently.
	for name: String in _layers:
		var p: AudioStreamPlayer = _layers[name]
		p.volume_db = move_toward(p.volume_db, _layer_target[name], delta * 6.0)
	# The tune: on each beat, maybe a note, wandering the scale.
	_beat_timer -= delta
	if _beat_timer <= 0.0:
		_beat_timer += BEAT
		_beat()
	# Birdsong, more often the more woods and hedges there are.
	if _birdiness > 0.02:
		_bird_timer -= delta
		if _bird_timer <= 0.0:
			_bird_timer = _rng.randf_range(2.0, 6.0) / (0.3 + _birdiness)
			play("bird_%d" % _rng.randi_range(0, 3), -14.0 + 6.0 * _birdiness, _rng.randf_range(0.9, 1.15), "Effects")


func _beat() -> void:
	if _rng.randf() < 0.42:
		return  # rests keep it calm
	var step: int = [-2, -1, -1, 0, 1, 1, 2][_rng.randi_range(0, 6)]
	_degree = clampi(_degree + step, 0, SCALE.size() - 1)
	# Drift back toward the middle of the range.
	if _degree > 8 and _rng.randf() < 0.4:
		_degree -= 2
	elif _degree < 2 and _rng.randf() < 0.4:
		_degree += 2
	play(SCALE[_degree], -9.0 + _rng.randf_range(-2.0, 1.0), 1.0, "Music")
	# Now and then a low note or a third underneath, like a second hand.
	if _rng.randf() < 0.18:
		play(SCALE[maxi(_degree - 5, 0)], -13.0, 1.0, "Music")
	elif _rng.randf() < 0.12:
		play(SCALE[maxi(_degree - 2, 0)], -14.0, 1.0, "Music")


## Play a one-shot by name.
func play(name: String, db: float = 0.0, pitch: float = 1.0, bus: String = "Effects") -> void:
	var s: Variant = _streams.get(name)
	if s == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = s
	p.volume_db = db
	p.pitch_scale = pitch
	p.bus = bus
	p.play()


# --- Game events -----------------------------------------------------------------

func piece_placed() -> void:
	play("place", -4.0, _rng.randf_range(0.92, 1.08))


## One chime per bloom, climbing the scale through a combo.
func blooms(count: int, perfect: bool) -> void:
	for i in count:
		var delay := 0.22 + i * 0.16
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			play("chime_%d" % mini(i + 1, 6), -6.0))
	if perfect:
		for i in 6:
			get_tree().create_timer(0.3 + count * 0.16 + i * 0.09).timeout.connect(func() -> void:
				play("chime_%d" % (6 - i), -9.0, 2.0))


const CALLS := {"owls": "owl", "eagles": "whistle", "heron": "whistle", "grouse": "bird_3",
	"kingfisher": "bird_2", "reed_warblers": "bird_0", "otter": "squeak", "hedgehogs": "squeak",
	"dormouse": "squeak"}


## An animal moved in (or a visitor came): its call, then a little motif.
func animal(id: String, visitor: bool) -> void:
	var call: String = CALLS.get(id, "")
	if call != "" and _streams.has(call):
		get_tree().create_timer(0.5).timeout.connect(func() -> void: play(call, -6.0))
	var motif: Array = [1, 3, 5] if not visitor else [1, 3, 5, 6, 5]
	for i in motif.size():
		get_tree().create_timer(0.9 + i * 0.15).timeout.connect(func() -> void:
			play("chime_%d" % motif[i], -8.0))


## Set the nature layers from how much of each biome the valley holds
## (fractions of the valley's hexes, 0..1) and whether it has a lake.
func set_landscape(fill: Dictionary, lake: bool) -> void:
	var levels := {
		"wind": float(fill.get("heath", 0.0)),
		"water": float(fill.get("wetland", 0.0)) + (0.15 if lake else 0.0),
		"meadow": float(fill.get("meadow", 0.0)),
	}
	for name: String in levels:
		var x := clampf(levels[name] * 3.0, 0.0, 1.0)
		_layer_target[name] = SILENT if x <= 0.01 else lerpf(-34.0, -15.0, x)
	_birdiness = clampf((float(fill.get("forest", 0.0)) + float(fill.get("hedgerow", 0.0))) * 2.5, 0.0, 1.0)


## A quieter landscape for the region map: just a little of everything.
func set_map_mood() -> void:
	set_landscape({"forest": 0.15, "meadow": 0.12, "wetland": 0.1, "heath": 0.08}, true)


# --- Mutes -----------------------------------------------------------------------

func set_music(on: bool) -> void:
	music_on = on
	_apply_mutes()
	_save_settings()


func set_effects(on: bool) -> void:
	effects_on = on
	_apply_mutes()
	_save_settings()


func _apply_mutes() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not music_on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Effects"), not effects_on)


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS))
	if typeof(parsed) == TYPE_DICTIONARY:
		music_on = bool(parsed.get("music", true))
		effects_on = bool(parsed.get("effects", true))


func _save_settings() -> void:
	var f := FileAccess.open(SETTINGS, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"music": music_on, "effects": effects_on}))
