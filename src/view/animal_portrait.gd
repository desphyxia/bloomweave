class_name AnimalPortrait
extends SubViewportContainer
## A small picture of a felt animal for the journal: the same figure as on
## the board, rendered once in its own little world with a transparent
## background. Empty `id` draws a "?" instead.

var id := ""
var textile: Textile


func _ready() -> void:
	stretch = true
	custom_minimum_size = Vector2(64, 64)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if id == "":
		return
	var vp := SubViewport.new()
	vp.own_world_3d = true          # never draws the game world behind it
	vp.transparent_bg = true
	vp.size = Vector2i(128, 128)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.95, 0.93, 0.88)
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 0.6
	vp.add_child(sun)
	var figure := FeltAnimal.build(textile, id, 1.0)
	figure.rotation.y = -0.6
	vp.add_child(figure)
	# Frame the figure whatever its size: an otter is low, a heron tall.
	var box := _bounds(figure)
	var cam := Camera3D.new()
	cam.fov = 30.0
	var r := box.size.length() * 0.5
	var dist := r / tan(deg_to_rad(cam.fov * 0.5)) * 1.05
	var centre := box.get_center()
	cam.position = centre + Vector3(0.0, 0.35, 1.0).normalized() * dist
	vp.add_child(cam)
	cam.look_at(centre, Vector3.UP)


static func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for c in root.get_children():
		var mi := c as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var b := root.transform * (mi.transform * mi.mesh.get_aabb())
		box = b if first else box.merge(b)
		first = false
	return box


func _draw() -> void:
	if id != "":
		return
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.4
	draw_circle(c, r, Color(0.86, 0.83, 0.75))
	draw_arc(c, r, 0.0, TAU, 40, Color(0.55, 0.5, 0.42), 1.5, true)
	var font := get_theme_default_font()
	var fs := int(r * 1.2)
	var w := font.get_string_size("?", HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	draw_string(font, Vector2(c.x - w / 2.0, c.y + fs * 0.35), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.45, 0.4, 0.34))
