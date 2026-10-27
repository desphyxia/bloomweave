class_name Hex
extends RefCounted
## Flat-top hex grid math in axial coordinates (q, r), stored as Vector2i.
##
## Layout in 2D world space (y grows "down", which maps to +z in 3D):
##   x = 1.5 * size * q
##   y = sqrt(3) * size * (r + q / 2)
## Corner i sits at angle 60° * i from the hex centre. Edge i runs from
## corner i to corner i + 1, and DIRECTIONS[i] is the neighbour across it.
## So corner i touches the hex itself plus neighbours DIRECTIONS[i - 1]
## and DIRECTIONS[i].
##
## A vertex (corner) is where exactly three hexes meet. It is stored as
## Vector3i(q, r, kind):
##   kind UP   (0): hexes (q, r), (q + 1, r), (q, r + 1)
##   kind DOWN (1): hexes (q + 1, r), (q, r + 1), (q + 1, r + 1)
## Every vertex of the grid has exactly one such key.

const UP := 0
const DOWN := 1
const SQRT3 := 1.7320508075688772

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1),
]


static func neighbor(h: Vector2i, direction: int) -> Vector2i:
	return h + DIRECTIONS[posmod(direction, 6)]


static func neighbors(h: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRECTIONS:
		out.append(h + d)
	return out


static func distance(a: Vector2i, b: Vector2i) -> int:
	var d := a - b
	return (absi(d.x) + absi(d.y) + absi(d.x + d.y)) / 2


static func to_world(h: Vector2i, size: float = 1.0) -> Vector2:
	return Vector2(1.5 * size * h.x, SQRT3 * size * (h.y + h.x / 2.0))


static func corner_offset(corner: int, size: float = 1.0) -> Vector2:
	var angle := deg_to_rad(60.0 * corner)
	return Vector2(cos(angle), sin(angle)) * size


## Nearest hex to a 2D world point.
static func from_world(p: Vector2, size: float = 1.0) -> Vector2i:
	var q := (2.0 / 3.0 * p.x) / size
	var r := (-1.0 / 3.0 * p.x + SQRT3 / 3.0 * p.y) / size
	return _round_axial(q, r)


static func _round_axial(qf: float, rf: float) -> Vector2i:
	var sf := -qf - rf
	var q := roundf(qf)
	var r := roundf(rf)
	var s := roundf(sf)
	var dq := absf(q - qf)
	var dr := absf(r - rf)
	var ds := absf(s - sf)
	if dq > dr and dq > ds:
		q = -r - s
	elif dr > ds:
		r = -q - s
	return Vector2i(int(q), int(r))


# --- Vertices ---------------------------------------------------------------

## The three hexes around a vertex.
static func vertex_hexes(v: Vector3i) -> Array[Vector2i]:
	var b := Vector2i(v.x, v.y)
	if v.z == UP:
		return [b, b + Vector2i(1, 0), b + Vector2i(0, 1)]
	return [b + Vector2i(1, 0), b + Vector2i(0, 1), b + Vector2i(1, 1)]


## Vertex key of corner `corner` (0..5) of hex `h`.
static func corner_vertex(h: Vector2i, corner: int) -> Vector3i:
	var a := h + DIRECTIONS[posmod(corner - 1, 6)]
	var b := h + DIRECTIONS[posmod(corner, 6)]
	return vertex_of([h, a, b])


## Vertex key for three mutually adjacent hexes. Returns Vector3i.ZERO
## with z = -1 if they don't meet at one vertex.
static func vertex_of(hexes: Array[Vector2i]) -> Vector3i:
	for m in hexes:
		if _same_set(hexes, vertex_hexes(Vector3i(m.x, m.y, UP))):
			return Vector3i(m.x, m.y, UP)
		var base := m - Vector2i(1, 1)
		if _same_set(hexes, vertex_hexes(Vector3i(base.x, base.y, DOWN))):
			return Vector3i(base.x, base.y, DOWN)
	return Vector3i(0, 0, -1)


## The six vertex keys of a hex, in corner order 0..5.
static func hex_vertices(h: Vector2i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for i in 6:
		out.append(corner_vertex(h, i))
	return out


## Which corner (0..5) of hex `h` vertex `v` is, or -1 if not on `h`.
static func corner_index(h: Vector2i, v: Vector3i) -> int:
	for i in 6:
		if corner_vertex(h, i) == v:
			return i
	return -1


static func vertex_world(v: Vector3i, size: float = 1.0) -> Vector2:
	var sum := Vector2.ZERO
	for h in vertex_hexes(v):
		sum += to_world(h, size)
	return sum / 3.0


static func _same_set(a: Array[Vector2i], b: Array[Vector2i]) -> bool:
	if a.size() != b.size():
		return false
	for x in a:
		if not b.has(x):
			return false
	return true
