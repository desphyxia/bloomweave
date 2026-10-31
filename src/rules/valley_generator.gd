class_name ValleyGenerator
extends RefCounted
## Carves valley shapes out of generated terrain: hills and ridges are
## domes on the ground, and the valley is the low ground between them,
## found by "filling it with water" from the lowest spot near the middle
## until it holds the wanted number of plots. Pure logic (no nodes), so
## the level tool and tests can run it headless.
##
## generate() returns {"plots": [Vector2i], "landmark": Vector2i,
## "hills": [[x, z, radius, height]], "obstacles": [{"kind", "plots"}]} in
## world units (hex size 1). The hills never cover a valley hex, so the
## scenery can draw exactly them.

const HILL_CLEARANCE := 1.2   # gap between a hill's foot and the nearest valley hex centre


## `plot_count` is the target size; the result can differ by a plot or two
## after smoothing. `cliff_plots` > 0 raises a rock ridge of that many plots
## in a line inside the valley (on its highest ground), partly splitting it
## into two basins that stay joined round the ridge's ends.
static func generate(rng_seed: int, plot_count: int, cliff_plots: int = 0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var hills := _make_hills(rng, plot_count)
	var candidates := PlotGrid.plots_within(Vector2i.ZERO, _search_radius(plot_count))
	var height := {}
	for p in candidates:
		height[p] = _plot_height(p, hills)
	var start := _lowest_near_middle(candidates, height)
	var valley := _fill(start, plot_count + cliff_plots, height)
	valley = _smooth(valley, start, plot_count + cliff_plots, height)
	var obstacles := []
	var covered := valley.duplicate()
	if cliff_plots > 0:
		var ridge := _ridge(valley, start, cliff_plots, height, rng)
		if not ridge.is_empty():
			for p in ridge:
				valley.erase(p)
			obstacles.append({"kind": "cliff", "plots": ridge})
	return {
		"plots": valley,
		"landmark": start,
		"hills": _clear_hills(hills, covered),
		"obstacles": obstacles,
	}


const LINE_STEPS: Array[Vector2i] = [Vector2i(2, -1), Vector2i(1, 1), Vector2i(-1, 2)]


## The best straight line of `length` plots for a ridge: all inside and
## mostly surrounded by the valley, not the landmark or next to it, keeping
## the rest of the valley in one piece; highest ground first.
static func _ridge(valley: Array[Vector2i], start: Vector2i, length: int, height: Dictionary, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var inside := {}
	for p in valley:
		inside[p] = true
	var near_start := PlotGrid.plot_neighbors(start)
	var best: Array[Vector2i] = []
	var best_score := -INF
	for p in valley:
		for step in LINE_STEPS:
			var line: Array[Vector2i] = []
			for k in length:
				line.append(p + step * k)
			var ok := true
			var score := 0.0
			for q in line:
				if not inside.has(q) or q == start or near_start.has(q):
					ok = false
					break
				var n := 0
				for r in PlotGrid.plot_neighbors(q):
					if inside.has(r):
						n += 1
				if n < 4:
					ok = false
					break
				score += float(height[q])
			if not ok:
				continue
			score += rng.randf() * 0.01
			if score > best_score and _joined_without(inside, line, start):
				best_score = score
				best = line
	return best


static func _joined_without(inside: Dictionary, removed: Array[Vector2i], start: Vector2i) -> bool:
	var seen := {start: true}
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		for q in PlotGrid.plot_neighbors(p):
			if inside.has(q) and not removed.has(q) and not seen.has(q):
				seen[q] = true
				stack.append(q)
	return seen.size() == inside.size() - removed.size()


## How many plots of the valley have all six neighbours inside it, and how
## many bloom spots (weave points with all three plots inside) it has.
static func stats(plots: Array[Vector2i]) -> Dictionary:
	var inside := {}
	for p in plots:
		inside[p] = true
	var interior := 0
	var weave := {}
	for p in plots:
		var n := 0
		for q in PlotGrid.plot_neighbors(p):
			if inside.has(q):
				n += 1
		if n == 6:
			interior += 1
		for v in PlotGrid.plot_weave_points(p):
			var ok := true
			for h in Hex.vertex_hexes(v):
				ok = ok and inside.has(PlotGrid.plot_of(h))
			if ok:
				weave[v] = true
	return {"plots": plots.size(), "interior": interior, "bloom_spots": weave.size()}


# --- Terrain ----------------------------------------------------------------------

## Domes: a broken ring of hills round the middle plus one or two ridges
## (chains of domes) reaching inwards, which give the valley arms and bays.
static func _make_hills(rng: RandomNumberGenerator, plot_count: int) -> Array:
	var scale := sqrt(plot_count / 20.0)
	var hills := []
	var ring := rng.randi_range(9, 13)
	for i in ring:
		var a := TAU * i / ring + rng.randf_range(-0.25, 0.25)
		var d := rng.randf_range(9.0, 14.0) * scale
		hills.append([cos(a) * d, sin(a) * d, rng.randf_range(4.0, 7.0) * scale, rng.randf_range(2.0, 4.5)])
	for _r in rng.randi_range(1, 3):
		var a := rng.randf() * TAU
		var from := rng.randf_range(11.0, 15.0) * scale
		var to := rng.randf_range(3.0, 6.5) * scale
		var bend := rng.randf_range(-0.5, 0.5)
		var steps := 4
		for k in steps:
			var t := float(k) / (steps - 1)
			var d := lerpf(from, to, t)
			var aa := a + bend * t
			hills.append([cos(aa) * d, sin(aa) * d, rng.randf_range(2.6, 3.6) * scale, rng.randf_range(1.6, 3.0)])
	# A couple of loose knolls anywhere.
	for _k in rng.randi_range(0, 2):
		var a := rng.randf() * TAU
		var d := rng.randf_range(4.0, 10.0) * scale
		hills.append([cos(a) * d, sin(a) * d, rng.randf_range(2.0, 3.0) * scale, rng.randf_range(1.2, 2.2)])
	return hills


static func _ground_height(p: Vector2, hills: Array) -> float:
	var h := 0.03 * p.length()   # a gentle bowl, so the valley stays near the middle
	for hill: Array in hills:
		var d := p.distance_to(Vector2(hill[0], hill[1]))
		var r: float = hill[2]
		if d < r:
			h = maxf(h, float(hill[3]) * sqrt(1.0 - (d / r) * (d / r)))
	return h


static func _plot_height(base: Vector2i, hills: Array) -> float:
	var sum := 0.0
	for h in PlotGrid.plot_hexes(base):
		sum += _ground_height(Hex.to_world(h), hills)
	return sum / 3.0


static func _search_radius(plot_count: int) -> int:
	return int(ceil(sqrt(plot_count / 3.0))) + 4


static func _lowest_near_middle(candidates: Array[Vector2i], height: Dictionary) -> Vector2i:
	var best := Vector2i.ZERO
	var best_h := INF
	for p in candidates:
		if Hex.to_world(p).length() > 4.5:
			continue
		if height[p] < best_h:
			best_h = height[p]
			best = p
	return best


# --- Carving -----------------------------------------------------------------------

## Flood outwards from `start`, always taking the lowest plot on the edge,
## counting plots that already touch more of the valley as a little lower
## (so the valley stays chunky instead of running out in one-plot strings).
const SNUG := 0.35   # height bonus per valley neighbour


static func _fill(start: Vector2i, plot_count: int, height: Dictionary) -> Array[Vector2i]:
	var valley: Array[Vector2i] = [start]
	var inside := {start: true}
	var edge := {}
	for q in PlotGrid.plot_neighbors(start):
		if height.has(q):
			edge[q] = true
	while valley.size() < plot_count and not edge.is_empty():
		var best: Vector2i = edge.keys()[0]
		var best_key := INF
		for q: Vector2i in edge:
			var n := 0
			for r in PlotGrid.plot_neighbors(q):
				if inside.has(r):
					n += 1
			var key: float = height[q] - SNUG * n
			if key < best_key:
				best_key = key
				best = q
		edge.erase(best)
		inside[best] = true
		valley.append(best)
		for q in PlotGrid.plot_neighbors(best):
			if height.has(q) and not inside.has(q):
				edge[q] = true
	return valley


## Fill one-plot inlets and holes (an outside plot with 4+ valley
## neighbours), then trim the highest dangling plots (1 neighbour) back to
## about the wanted size. Keeps the valley in one piece.
static func _smooth(valley: Array[Vector2i], start: Vector2i, plot_count: int, height: Dictionary) -> Array[Vector2i]:
	var inside := {}
	for p in valley:
		inside[p] = true
	for _pass in 3:
		var added := false
		for p: Vector2i in inside.keys():
			for q in PlotGrid.plot_neighbors(p):
				if inside.has(q) or not height.has(q):
					continue
				var n := 0
				for r in PlotGrid.plot_neighbors(q):
					if inside.has(r):
						n += 1
				if n >= 4:
					inside[q] = true
					added = true
		if not added:
			break
	while inside.size() > plot_count + 1:
		var worst := Vector2i.ZERO
		var worst_h := -INF
		for p: Vector2i in inside:
			if p == start:
				continue
			var n := 0
			for q in PlotGrid.plot_neighbors(p):
				if inside.has(q):
					n += 1
			if n <= 2 and height[p] > worst_h and _still_joined(inside, p, start):
				worst_h = height[p]
				worst = p
		if worst_h == -INF:
			break
		inside.erase(worst)
	var out: Array[Vector2i] = []
	for p: Vector2i in inside:
		out.append(p)
	out.sort()
	return out


static func _still_joined(inside: Dictionary, without: Vector2i, start: Vector2i) -> bool:
	var seen := {start: true}
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		for q in PlotGrid.plot_neighbors(p):
			if q != without and inside.has(q) and not seen.has(q):
				seen[q] = true
				stack.append(q)
	return seen.size() == inside.size() - 1


## Shrink (or drop) hills so none reaches over the valley.
static func _clear_hills(hills: Array, valley: Array[Vector2i]) -> Array:
	var centres: Array[Vector2] = []
	for p in valley:
		for h in PlotGrid.plot_hexes(p):
			centres.append(Hex.to_world(h))
	var out := []
	for hill: Array in hills:
		var c := Vector2(hill[0], hill[1])
		var nearest := INF
		for v in centres:
			nearest = minf(nearest, c.distance_to(v))
		var r := minf(float(hill[2]), nearest - HILL_CLEARANCE)
		if r < 1.8:
			continue
		out.append([snappedf(c.x, 0.01), snappedf(c.y, 0.01), snappedf(r, 0.01), snappedf(float(hill[3]) * clampf(r / float(hill[2]), 0.6, 1.0), 0.01)])
	return out
