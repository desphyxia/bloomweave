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
