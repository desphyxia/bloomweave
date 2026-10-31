extends SceneTree
## Renders the game icon in the game's own textile look: one trefoil piece of
## forest, meadow and wetland (puffy fabric patches with their felt details
## and stitched seams) with a Fern Hollow bloom at its heart, on cream linen.
## Run (needs a display): xvfb-run godot --path . --rendering-driver opengl3
##   --resolution 512x512 -s res://tools/render_icon.gd -- icon.png

const SIZE := 512
const YAW := deg_to_rad(30.0)


func _init() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "icon.png"
	root.size = Vector2i(SIZE, SIZE)
	var data := GameData.load_dir()
	var textile := Textile.new()
	var world := Node3D.new()
	root.add_child(world)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#f3efe4")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.95, 0.93, 0.88)
	e.ambient_light_energy = 0.34
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 0.46
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	world.add_child(sun)

	# Cream linen backing cloth.
	var cloth := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	cloth.mesh = plane
	cloth.position.y = -0.01
	cloth.material_override = textile.fabric(Color("#d9c7a9"), {"weave_scale": 10.0, "weave_strength": 0.14, "fuzz": 0.08, "rough": 1.0})
	world.add_child(cloth)

	var biomes := ["forest", "wetland", "meadow"]
	var hexes := PlotGrid.plot_hexes(Vector2i.ZERO)
	var patch := textile.patch_mesh(BoardView.HEX_SIZE, BoardView.SEAM_H, BoardView.PUFF)
	var decor := BiomeDecor.new(textile, BoardView.SEAM_H, BoardView.PUFF)
	var centre := Vector3.ZERO
	for i in 3:
		var h: Vector2i = hexes[i]
		var b: Dictionary = data.biomes[biomes[i]]
		var mi := MeshInstance3D.new()
		mi.mesh = patch
		mi.position = BoardView.hex_pos(h)
		mi.material_override = textile.fabric(data.biome_color(biomes[i]), b.get("fabric", {}))
		world.add_child(mi)
		var d := MeshInstance3D.new()
		d.mesh = decor.build(h, biomes[i], false)
		d.position = mi.position
		world.add_child(d)
		centre += mi.position / 3.0
	# Running stitches round the piece and between its patches.
	var segs: Array = []
	for h in hexes:
		for k in 6:
			var a := Hex.corner_offset(k, BoardView.HEX_SIZE)
			var c := Hex.corner_offset(k + 1, BoardView.HEX_SIZE)
			var p := BoardView.hex_pos(h, BoardView.SEAM_H + 0.012)
			segs.append([p + Vector3(a.x, 0, a.y), p + Vector3(c.x, 0, c.y)])
	world.add_child(textile.stitches(segs, 3, 0.15, 0.03, BoardView.SEAM_THREAD))

	# The bloom at the piece's heart, petals pointing at each biome.
	var heart := Hex.vertex_world(PlotGrid.confluence(Vector2i.ZERO), BoardView.HEX_SIZE)
	var petals := []
	for i in 3:
		var dir := Hex.to_world(hexes[i], BoardView.HEX_SIZE) - heart
		petals.append([snappedf(dir.angle(), 0.01), data.biome_color(biomes[i])])
	var flower := MeshInstance3D.new()
	flower.mesh = textile.recipe_flower_mesh(petals, Color(data.blooms_by_id.fern_hollow.color), false, 0.12)
	flower.scale = Vector3.ONE * 2.6
	flower.position = Vector3(heart.x, BoardView.SEAM_H + 0.3, heart.y)
	world.add_child(flower)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.9
	var look := Vector3(heart.x, 0.0, heart.y)
	# Turned a little so the hexes point up, like the original logo.
	var from := look + Vector3(0.0, 10.0, 5.2).rotated(Vector3.UP, YAW)
	cam.transform = Transform3D(Basis.looking_at(look - from, Vector3.UP), from)
	world.add_child(cam)
	cam.current = true

	for _f in 8:
		await process_frame
	await create_timer(0.5).timeout
	root.get_texture().get_image().save_png(out)
	print("wrote ", out)
	quit()
