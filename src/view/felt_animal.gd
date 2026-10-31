class_name FeltAnimal
extends RefCounted
## Little felt figures for settled animals, used on the board and on the hills.

const FELT := {"fuzz": 0.4, "weave_strength": 0.0, "rough": 1.0}

# id -> body colour, head colour, body radius, body length, body height,
# head radius, head position
const LOOKS := {
	"deer":   [Color(0.62, 0.44, 0.28), Color(0.7, 0.53, 0.36), 0.14, 0.55, 0.45, 0.11, Vector3(0.26, 0.68, 0)],
	"otter":  [Color(0.36, 0.27, 0.21), Color(0.45, 0.36, 0.29), 0.10, 0.50, 0.22, 0.09, Vector3(0.26, 0.28, 0)],
	"badger": [Color(0.46, 0.45, 0.43), Color(0.95, 0.94, 0.9), 0.13, 0.48, 0.2, 0.095, Vector3(0.27, 0.24, 0)],
}


static func build(textile: Textile, id: String, size: float = 1.0) -> Node3D:
	if id == "eagles":
		return _eagle(textile, size)
	if id == "wildcat":
		return _wildcat(textile, size)
	if id == "grouse" or id == "heron":
		return _bird(textile, id, size)
	if id == "bees":
		return _bees(textile, size)
	if id == "hare":
		return _hare(textile, size)
	var look: Array = LOOKS.get(id, LOOKS.otter)
	var node := Node3D.new()
	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = float(look[2]) * size
	bm.height = float(look[3]) * size
	body.mesh = bm
	body.rotation.z = PI / 2.0
	body.position.y = float(look[4]) * size
	body.material_override = textile.fabric(look[0], FELT)
	node.add_child(body)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = float(look[5]) * size
	hm.height = float(look[5]) * 2.0 * size
	head.mesh = hm
	head.position = (look[6] as Vector3) * size
	head.material_override = textile.fabric(look[1], FELT)
	node.add_child(head)
	if id == "badger":
		# Two dark stripes over the white face.
		for side in [-1.0, 1.0]:
			var stripe := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.5
			sm.height = 1.0
			stripe.mesh = sm
			stripe.scale = Vector3(0.2, 0.06, 0.045) * size
			stripe.position = head.position + Vector3(0.0, 0.055, side * 0.032) * size
			stripe.material_override = textile.fabric(Color(0.16, 0.15, 0.14), FELT)
			node.add_child(stripe)
	return node


static func _part(textile: Textile, node: Node3D, mesh: Mesh, color: Color, at: Vector3, scale: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.scale = scale
	mi.material_override = textile.fabric(color, FELT)
	node.add_child(mi)


## Birds for the hidden visitors: a plump red grouse, a tall grey heron.
static func _bird(textile: Textile, id: String, size: float) -> Node3D:
	var node := Node3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	var stick := CylinderMesh.new()
	stick.top_radius = 0.5
	stick.bottom_radius = 0.5
	stick.height = 1.0
	stick.radial_segments = 6
	var beak := Color(0.9, 0.7, 0.25)
	if id == "grouse":
		var brown := Color(0.5, 0.26, 0.17)
		_part(textile, node, ball, brown, Vector3(0, 0.16, 0) * size, Vector3(0.36, 0.26, 0.26) * size)
		_part(textile, node, ball, brown.darkened(0.15), Vector3(-0.17, 0.2, 0) * size, Vector3(0.12, 0.16, 0.14) * size)
		_part(textile, node, ball, brown.lightened(0.08), Vector3(0.16, 0.32, 0) * size, Vector3.ONE * 0.16 * size)
		# The red eyebrows.
		for side in [-1.0, 1.0]:
			_part(textile, node, ball, Color(0.85, 0.12, 0.1), Vector3(0.19, 0.38, side * 0.05) * size, Vector3(0.07, 0.03, 0.03) * size)
		_part(textile, node, ball, Color(0.2, 0.17, 0.12), Vector3(0.25, 0.31, 0) * size, Vector3(0.06, 0.03, 0.035) * size)
	else:
		var grey := Color(0.66, 0.68, 0.7)
		for side in [-1.0, 1.0]:
			_part(textile, node, stick, beak.darkened(0.2), Vector3(0, 0.18, side * 0.04) * size, Vector3(0.02, 0.36, 0.02) * size)
		_part(textile, node, ball, grey, Vector3(0, 0.44, 0) * size, Vector3(0.34, 0.2, 0.18) * size)
		_part(textile, node, ball, grey.darkened(0.2), Vector3(-0.14, 0.46, 0) * size, Vector3(0.16, 0.12, 0.14) * size)
		_part(textile, node, stick, Color(0.92, 0.92, 0.9), Vector3(0.14, 0.62, 0) * size, Vector3(0.05, 0.26, 0.05) * size)
		_part(textile, node, ball, Color(0.95, 0.95, 0.93), Vector3(0.17, 0.77, 0) * size, Vector3.ONE * 0.1 * size)
		_part(textile, node, ball, Color(0.15, 0.15, 0.17), Vector3(0.15, 0.8, 0) * size, Vector3(0.08, 0.03, 0.06) * size)
		_part(textile, node, stick, beak, Vector3(0.27, 0.76, 0) * size, Vector3(0.02, 0.16, 0.02) * size)
		(node.get_child(node.get_child_count() - 1) as Node3D).rotation.z = PI / 2.0
	return node


## A little swarm: three striped felt bees hovering at different heights.
static func _bees(textile: Textile, size: float) -> Node3D:
	var node := Node3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	for i in 3:
		var at := Vector3(cos(i * 2.1) * 0.18, 0.35 + i * 0.12, sin(i * 2.1) * 0.18) * size
		_part(textile, node, ball, Color(0.96, 0.78, 0.18), at, Vector3(0.14, 0.1, 0.1) * size)
		_part(textile, node, ball, Color(0.16, 0.14, 0.12), at + Vector3(-0.03, 0, 0) * size, Vector3(0.04, 0.105, 0.105) * size)
		for side in [-1.0, 1.0]:
			_part(textile, node, ball, Color(0.95, 0.97, 1.0), at + Vector3(0, 0.05, side * 0.05) * size, Vector3(0.07, 0.02, 0.06) * size)
	return node


## A brown hare sitting up, with long ears.
static func _hare(textile: Textile, size: float) -> Node3D:
	var node := Node3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	var brown := Color(0.62, 0.46, 0.3)
	_part(textile, node, ball, brown, Vector3(0, 0.2, 0) * size, Vector3(0.34, 0.3, 0.24) * size)
	_part(textile, node, ball, brown.lightened(0.08), Vector3(0.14, 0.38, 0) * size, Vector3(0.17, 0.15, 0.14) * size)
	for side in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		ear.mesh = ball
		ear.scale = Vector3(0.06, 0.26, 0.04) * size
		ear.position = Vector3(0.1, 0.56, side * 0.04) * size
		ear.rotation.z = 0.25
		ear.material_override = textile.fabric(brown.darkened(0.1), FELT)
		node.add_child(ear)
	_part(textile, node, ball, Color(0.95, 0.94, 0.9), Vector3(-0.17, 0.16, 0) * size, Vector3.ONE * 0.09 * size)
	return node


## A golden eagle perched with half-open wings.
static func _eagle(textile: Textile, size: float) -> Node3D:
	var node := Node3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	var brown := Color(0.42, 0.28, 0.17)
	_part(textile, node, ball, brown, Vector3(0, 0.3, 0) * size, Vector3(0.26, 0.4, 0.24) * size)
	_part(textile, node, ball, Color(0.78, 0.58, 0.28), Vector3(0.04, 0.58, 0) * size, Vector3.ONE * 0.17 * size)
	_part(textile, node, ball, Color(0.95, 0.75, 0.25), Vector3(0.14, 0.56, 0) * size, Vector3(0.09, 0.05, 0.05) * size)
	for side in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		wing.mesh = ball
		wing.scale = Vector3(0.36, 0.08, 0.3) * size
		wing.position = Vector3(-0.04, 0.42, side * 0.2) * size
		wing.rotation.x = side * 0.5
		wing.material_override = textile.fabric(brown.darkened(0.15), FELT)
		node.add_child(wing)
	_part(textile, node, ball, brown.darkened(0.25), Vector3(-0.2, 0.14, 0) * size, Vector3(0.18, 0.06, 0.12) * size)
	return node


## A grey-brown tabby wildcat with a thick, ringed tail.
static func _wildcat(textile: Textile, size: float) -> Node3D:
	var node := Node3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	var tabby := Color(0.55, 0.5, 0.42)
	var dark := Color(0.22, 0.2, 0.18)
	_part(textile, node, ball, tabby, Vector3(0, 0.2, 0) * size, Vector3(0.44, 0.24, 0.22) * size)
	_part(textile, node, ball, tabby.lightened(0.06), Vector3(0.25, 0.34, 0) * size, Vector3(0.18, 0.16, 0.17) * size)
	for side in [-1.0, 1.0]:
		_part(textile, node, ball, tabby, Vector3(0.26, 0.44, side * 0.05) * size, Vector3(0.04, 0.07, 0.05) * size)
	for k in 4:
		var t := float(k) / 3.0
		var at := Vector3(-0.24 - t * 0.16, 0.2 + t * 0.06, 0) * size
		_part(textile, node, ball, dark if k % 2 == 1 else tabby, at, Vector3(0.1, 0.09, 0.09) * size)
	for k in 3:
		_part(textile, node, ball, dark, Vector3(-0.1 + k * 0.1, 0.32, 0) * size, Vector3(0.03, 0.03, 0.22) * size)
	return node
