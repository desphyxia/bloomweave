class_name PlotGrid
extends RefCounted
## The fixed grid of trefoil-shaped plots laid over the hex grid.
##
## A plot is identified by its base hex b, where (b.q - b.r) mod 3 == 0.
## Its three hexes are b + (0,0), b + (1,0), b + (0,1), in that "slot" order,
## and they meet at the plot's confluence: vertex (b.q, b.r, UP).
## Every hex belongs to exactly one plot, so the plots tile the grid.
##
## Vertex kinds, by how many different plots touch them:
##   CONFLUENCE (1 plot), SEAM (2 plots), WEAVE (3 plots).

const OFFSETS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]

const CONFLUENCE := 1
const SEAM := 2
const WEAVE := 3


static func is_base(b: Vector2i) -> bool:
	return posmod(b.x - b.y, 3) == 0


## Base hex of the plot that contains hex `h`.
static func plot_of(h: Vector2i) -> Vector2i:
	return h - OFFSETS[posmod(h.x - h.y, 3)]


## The plot's three hexes in slot order.
static func plot_hexes(base: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for o in OFFSETS:
		out.append(base + o)
	return out


static func confluence(base: Vector2i) -> Vector3i:
	return Vector3i(base.x, base.y, Hex.UP)


## The six plots sharing an edge with this plot, in a stable order.
static func plot_neighbors(base: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for h in plot_hexes(base):
		for n in Hex.neighbors(h):
			var p := plot_of(n)
			if p != base and not out.has(p):
				out.append(p)
	return out


## Plot distance: steps through edge-sharing plots.
static func plot_distance(a: Vector2i, b: Vector2i) -> int:
	if a == b:
		return 0
	var seen := {a: true}
	var frontier: Array[Vector2i] = [a]
	var steps := 0
	while not frontier.is_empty():
		steps += 1
		var next: Array[Vector2i] = []
		for p in frontier:
			for n in plot_neighbors(p):
				if n == b:
					return steps
				if not seen.has(n):
					seen[n] = true
					next.append(n)
		frontier = next
	return -1


## All plots within `radius` plot steps of `center` (center included).
static func plots_within(center: Vector2i, radius: int) -> Array[Vector2i]:
	var seen := {center: true}
	var out: Array[Vector2i] = [center]
	var frontier: Array[Vector2i] = [center]
	for _i in radius:
		var next: Array[Vector2i] = []
		for p in frontier:
			for n in plot_neighbors(p):
				if not seen.has(n):
					seen[n] = true
					out.append(n)
					next.append(n)
		frontier = next
	return out


static func vertex_kind(v: Vector3i) -> int:
	var plots := {}
	for h in Hex.vertex_hexes(v):
		plots[plot_of(h)] = true
	return plots.size()


## The six weave points that touch a plot.
static func plot_weave_points(base: Vector2i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for h in plot_hexes(base):
		for v in hex_weave_points(h):
			if not out.has(v):
				out.append(v)
	return out


## The two weave points on a hex's border.
static func hex_weave_points(h: Vector2i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for v in Hex.hex_vertices(h):
		if vertex_kind(v) == WEAVE:
			out.append(v)
	return out


## The seam corner between the two weave points of hex `h` on their short
## side (two border edges apart). This is where a corridor trail turns.
static func trail_corner(h: Vector2i) -> Vector3i:
	var corners := Hex.hex_vertices(h)
	var idx: Array[int] = []
	for i in 6:
		if vertex_kind(corners[i]) == WEAVE:
			idx.append(i)
	assert(idx.size() == 2)
	var gap := posmod(idx[1] - idx[0], 6)
	var mid := idx[0] + 1 if gap == 2 else idx[1] + 1
	return corners[posmod(mid, 6)]
