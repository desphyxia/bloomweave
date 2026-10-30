extends Node3D
## Connects the rules (ValleyGame) with the board, camera and HUD.

const VALLEY_ID := "first_valley"

var data: GameData
var game: ValleyGame
var board: BoardView
var scenery: Scenery
var rig: CameraRig
var hud: Hud

var selected: Variant = null  # plot base (Vector2i) or null
var arrangement: Array = []   # the current piece as it would be placed
var _first_turn := true

func _ready() -> void:
	data = GameData.load_dir()
	_setup_scene()
	_new_game()
	get_window().size_changed.connect(_on_resize)
	_on_resize()


## Keep the interface readable on phones: a smaller virtual canvas when the
## screen's short side is phone-sized, and a camera that fits the width in
## portrait.
func _on_resize() -> void:
	var win := get_window()
	var px := Vector2(win.size)
	var dpr := maxf(DisplayServer.screen_get_scale(), 1.0)
	var css_short := minf(px.x, px.y) / dpr
	var phone := css_short < 600.0
	# A larger virtual canvas on phones = everything (text included) a bit smaller.
	var base := 580 if phone else 800
	win.content_scale_size = Vector2i(base, base)
	# Fill rate is the main cost on phones: draw 3D at most 2 device pixels per
	# CSS pixel (about half the pixels on a 3x iPhone). The interface stays sharp.
	win.scaling_3d_scale = clampf(2.0 / dpr, 0.5, 1.0)
	RenderingServer.directional_shadow_atlas_set_size(2048 if phone else 4096, true)
	hud.set_compact(phone)
	rig.fit(px.x / maxf(px.y, 1.0))


func _setup_scene() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.56, 0.72, 0.86)
	sky_mat.sky_horizon_color = Color(0.93, 0.91, 0.84)
	sky_mat.ground_horizon_color = Color(0.86, 0.86, 0.78)
	sky_mat.ground_bottom_color = Color(0.6, 0.66, 0.5)
	sky_mat.sun_angle_max = 0.0
	sky_mat.sun_curve = 0.01
	var sky := Sky.new()
	sky.sky_material = sky_mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.95, 0.93, 0.88)
	e.ambient_light_energy = 0.34
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 0.46
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	add_child(sun)

	scenery = Scenery.new()
	add_child(scenery)
	board = BoardView.new()
	add_child(board)

	rig = CameraRig.new()
	add_child(rig)
	rig.tapped.connect(_on_tapped)
	rig.long_pressed.connect(_on_long_pressed)

	hud = Hud.new()
	add_child(hud)
	hud.action.connect(_on_action)


func _new_game() -> void:
	game = ValleyGame.new(data, data.valley(VALLEY_ID), _requested_seed())
	selected = null
	arrangement = game.current_piece()
	_first_turn = true
	board.setup(game)
	scenery.setup(game)
	hud.setup(game)
	hud.set_costs(game.valley.get("seed_costs", {}))
	_update()


## A game number to replay: `?seed=123456` in the web page address, or
## `-- --seed 123456` on the command line. Used for the first game only.
var _seed_used := false


func _requested_seed() -> int:
	if _seed_used:
		return -1
	_seed_used = true
	var value := ""
	if OS.has_feature("web"):
		var v: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('seed') || ''")
		value = str(v) if v != null else ""
	var args := OS.get_cmdline_user_args()
	var i := args.find("--seed")
	if i >= 0 and i + 1 < args.size():
		value = args[i + 1]
	return int(value) if value.is_valid_int() else -1


func _arranged() -> Array:
	if not Piece.same_biomes(arrangement, game.current_piece()):
		arrangement = game.current_piece()
	return arrangement


func _update() -> void:
	var preview := []
	if selected != null:
		preview = game.preview(selected, _arranged())
		board.set_ghost(selected, _arranged(), preview)
	else:
		board.clear_ghost()
	hud.refresh(_arranged(), selected != null, preview.size())


func _on_tapped(screen_pos: Vector2) -> void:
	if game.is_finished():
		return
	var hit: Variant = rig.pick(screen_pos, BoardView.TILE_H)
	if hit == null:
		return
	var base: Variant = board.plot_at(hit)
	if base == null or not game.can_place(base):
		selected = null
	elif selected == base:
		_turn()
		return
	else:
		selected = base
		if _first_turn:
			hud.hide_hint()
	_update()


## Press and hold a plot to place the piece there, as it is shown.
func _on_long_pressed(screen_pos: Vector2) -> void:
	if game.is_finished():
		return
	var hit: Variant = rig.pick(screen_pos, BoardView.TILE_H)
	if hit == null:
		return
	var base: Variant = board.plot_at(hit)
	if base != null and game.can_place(base):
		selected = base
		_place()


func _turn() -> void:
	arrangement = Piece.arrange(_arranged(), 1, false)
	_update()


func _mirror() -> void:
	arrangement = Piece.arrange(_arranged(), 0, true)
	_update()


func _place() -> void:
	if selected == null:
		return
	var base: Vector2i = selected
	var arranged := _arranged()
	var result := game.place(base, arranged)
	if not result.ok:
		return
	_first_turn = false
	hud.hide_hint()
	selected = null
	arrangement = game.current_piece()
	board.clear_ghost()
	board.add_piece(base, arranged, true)
	var names := []
	for b: Dictionary in result.blooms:
		board.add_bloom(b.vertex, b.bloom, true)
		names.append(data.blooms_by_id[b.bloom].name)
	for id: String in result.settled:
		board.add_animal(id, game.settled[id], true)
		scenery.on_settled(id)
	board.refresh()
	scenery.refresh()
	if result.perfect:
		board.celebrate(base)
	var perfect := "Perfect piece! All six bloomed  +%d seeds\n" % int(game.valley.scoring.get("perfect_seeds", 0)) if result.perfect else ""
	if not result.settled.is_empty():
		var who := []
		for id: String in result.settled:
			who.append(data.animals[id].name)
		hud.toast("%s%s moved in!  +%d seeds" % [perfect, " and ".join(who), result.seeds_gained])
	elif not names.is_empty():
		var combo := "  ·  %d at once!" % names.size() if names.size() > 1 else ""
		hud.toast("%s%s bloomed  +%d points%s" % [perfect, ", ".join(names), result.points, combo])
	_update()
	if result.finished:
		scenery.on_finished()
		hud.show_end()


func _on_action(id: String) -> void:
	match id:
		"rotate":
			_turn()
		"mirror":
			_mirror()
		"place":
			_place()
		"cancel":
			selected = null
			_update()
		"set_aside":
			if game.set_aside():
				_reset_arrangement()
		"use_reserve":
			if game.use_reserve():
				_reset_arrangement()
		"swap":
			if game.swap():
				_reset_arrangement()
		"look_ahead":
			game.look_ahead()
			_update()
		"restart":
			_new_game()


func _reset_arrangement() -> void:
	arrangement = game.current_piece()
	_update()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_R:
			_turn()
		KEY_F, KEY_M:
			_mirror()
		KEY_ENTER, KEY_SPACE, KEY_KP_ENTER:
			_place()
		KEY_ESCAPE:
			selected = null
			_update()
