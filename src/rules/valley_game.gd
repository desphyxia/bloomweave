class_name ValleyGame
extends RefCounted
## Rules for one run of Valley mode: a fixed outline of plots, a landmark
## piece in the centre, and exactly enough pieces to fill every other plot.
## Pure logic with no scene or node dependencies, so it is testable headless.

var data: GameData
var valley: Dictionary
var center := Vector2i.ZERO
var plots: Array[Vector2i] = []
var board := {}          # hex (Vector2i) -> biome id
var placed := {}         # plot base (Vector2i) -> true
var pile: Array = []     # pieces still to place; pile[0] is the current piece
var reserve: Array = []  # the set-aside piece, or [] when the slot is empty
var seeds := 0
var blooms := {}         # weave point (Vector3i) -> bloom id
var settled := {}        # animal id -> Array of weave points (its corridor)
var look_ahead_active := false
var turn := 0
var rng := RandomNumberGenerator.new()

var _plot_set := {}


func _init(p_data: GameData, p_valley: Dictionary, rng_seed: int = -1) -> void:
	data = p_data
	valley = p_valley
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	plots = PlotGrid.plots_within(center, int(valley.outline.radius))
	for p in plots:
		_plot_set[p] = true
	_put(center, valley.landmark.biomes)
	pile = _build_pile()


# --- Pieces -------------------------------------------------------------------

func _build_pile() -> Array:
	var biome_pool: Array = valley.biomes
	var mix: Dictionary = valley.pile
	var out := []
	for _i in int(mix.get("distinct", 0)):
		var b := biome_pool.duplicate()
		_shuffle(b)
		out.append(b.slice(0, 3))
	for _i in int(mix.get("double", 0)):
		var b := biome_pool.duplicate()
		_shuffle(b)
		var piece := [b[0], b[0], b[1]]
		_shuffle(piece)
		out.append(piece)
	for _i in int(mix.get("single", 0)):
		var a: String = biome_pool[rng.randi_range(0, biome_pool.size() - 1)]
		out.append([a, a, a])
	_shuffle(out)
	return out


## Replace the pile (for tests and scripted valleys).
func set_pile(pieces: Array) -> void:
	pile = pieces.duplicate(true)


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t


func current_piece() -> Array:
	return pile[0] if not pile.is_empty() else []


## The upcoming pieces the player may see (1 normally, more with look-ahead).
func upcoming() -> Array:
	var count := int(valley.get("look_ahead_count", 3)) if look_ahead_active else 1
	return pile.slice(1, 1 + count)


func pieces_left() -> int:
	return pile.size() + (1 if not reserve.is_empty() else 0)


func is_finished() -> bool:
	return placed.size() == plots.size()


# --- Placement ----------------------------------------------------------------

func is_in_valley(base: Vector2i) -> bool:
	return _plot_set.has(base)


func is_empty(base: Vector2i) -> bool:
	return is_in_valley(base) and not placed.has(base)


func can_place(base: Vector2i) -> bool:
	if not is_empty(base) or pile.is_empty():
		return false
	for n in PlotGrid.plot_neighbors(base):
		if placed.has(n):
			return true
	return false


func legal_plots() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p in plots:
		if can_place(p):
			out.append(p)
	return out


## Blooms that placing `arranged` on `base` would create, without changing
## anything. Each entry: {"vertex": Vector3i, "bloom": bloom id}.
func preview(base: Vector2i, arranged: Array) -> Array:
	var out := []
	var hexes := PlotGrid.plot_hexes(base)
	for v in PlotGrid.plot_weave_points(base):
		var trio := []
		for h in Hex.vertex_hexes_clockwise(v):
			var slot := hexes.find(h)
			if slot >= 0:
				trio.append(arranged[slot])
			elif board.has(h):
				trio.append(board[h])
		if trio.size() < 3:
			continue
		var bloom := data.bloom_for(trio, clockwise_blooms())
		if not bloom.is_empty():
			out.append({"vertex": v, "bloom": bloom.id})
	return out


## Whether this valley's blooms need their biomes in clockwise order.
func clockwise_blooms() -> bool:
	return valley.get("bloom_order", "any") == "clockwise"


## Place the current piece, arranged as `arranged` (slot order), on `base`.
## Returns {"ok", "blooms", "settled", "seeds_gained", "finished"}.
func place(base: Vector2i, arranged: Array) -> Dictionary:
	if not can_place(base) or not Piece.same_biomes(arranged, current_piece()):
		return {"ok": false}
	var seeds_before := seeds
	var new_blooms := preview(base, arranged)
	var completed := completed_corners(base)
	_put(base, arranged)
	pile.pop_front()
	turn += 1
	look_ahead_active = false
	for b: Dictionary in new_blooms:
		blooms[b.vertex] = b.bloom
		seeds += 1
	if pile.is_empty() and not reserve.is_empty():
		pile.append(reserve)
		reserve = []
	var newly_settled := check_animals()
	return {
		"ok": true,
		"blooms": new_blooms,
		"settled": newly_settled,
		"seeds_gained": seeds - seeds_before,
		"finished": is_finished(),
		"completed": completed,
		"perfect": is_perfect(completed, new_blooms.size()),
	}


## How many corners placing a piece on `base` would complete (corners whose
## other two hexes are already filled).
func completed_corners(base: Vector2i) -> int:
	var hexes := PlotGrid.plot_hexes(base)
	var n := 0
	for v in PlotGrid.plot_weave_points(base):
		var filled := 0
		for h in Hex.vertex_hexes(v):
			if board.has(h) and not hexes.has(h):
				filled += 1
		if filled == 2:
			n += 1
	return n


## A perfect piece completes at least two corners and every one of them
## blooms (like Dorfromantik's perfect placement, but for corners).
static func is_perfect(completed: int, bloomed: int) -> bool:
	return completed >= 2 and bloomed == completed


## Corners waiting for their last hex: two hexes are filled, the third is an
## empty hex in the valley. Each entry: {"vertex", "hex" (the empty one),
## "needs" (biomes that would make it bloom, in data order)}. A corner whose
## two biomes can no longer bloom has an empty "needs" list.
func open_corners() -> Array:
	var out := []
	var seen := {}
	var clockwise := clockwise_blooms()
	for base in plots:
		if placed.has(base):
			continue
		for v in PlotGrid.plot_weave_points(base):
			if seen.has(v):
				continue
			seen[v] = true
			var ring := Hex.vertex_hexes_clockwise(v)
			var missing := -1
			var filled := 0
			for i in 3:
				if board.has(ring[i]):
					filled += 1
				else:
					missing = i
			if filled != 2:
				continue
			var needs := []
			for b: String in valley.biomes:
				var trio := []
				for i in 3:
					trio.append(b if i == missing else board[ring[i]])
				if not data.bloom_for(trio, clockwise).is_empty():
					needs.append(b)
			out.append({"vertex": v, "hex": ring[missing], "needs": needs})
	return out


func _put(base: Vector2i, arranged: Array) -> void:
	var hexes := PlotGrid.plot_hexes(base)
	for i in 3:
		board[hexes[i]] = arranged[i]
	placed[base] = true


# --- Seeds --------------------------------------------------------------------

func cost(action: String) -> int:
	return int(valley.get("seed_costs", {}).get(action, 1))


func can_set_aside() -> bool:
	return reserve.is_empty() and pile.size() >= 2 and seeds >= cost("set_aside")


func set_aside() -> bool:
	if not can_set_aside():
		return false
	seeds -= cost("set_aside")
	reserve = pile.pop_front()
	return true


func can_use_reserve() -> bool:
	return not reserve.is_empty()


## Bring the reserved piece back as the current piece (free). The piece that
## was current becomes the next one.
func use_reserve() -> bool:
	if not can_use_reserve():
		return false
	pile.push_front(reserve)
	reserve = []
	return true


func can_swap() -> bool:
	return pile.size() >= 2 and seeds >= cost("swap")


func swap() -> bool:
	if not can_swap():
		return false
	seeds -= cost("swap")
	var t: Variant = pile[0]
	pile[0] = pile[1]
	pile[1] = t
	return true


func can_look_ahead() -> bool:
	return not look_ahead_active and pile.size() > 2 and seeds >= cost("look_ahead")


func look_ahead() -> bool:
	if not can_look_ahead():
		return false
	seeds -= cost("look_ahead")
	look_ahead_active = true
	return true


# --- Corridors and animals ----------------------------------------------------

## Links between blooms that share a hex. Each: {"a", "b", "hex"}.
func bloom_links() -> Array:
	var out := []
	var seen := {}
	for v: Vector3i in blooms:
		for h in Hex.vertex_hexes(v):
			for w in PlotGrid.hex_weave_points(h):
				if w == v or not blooms.has(w):
					continue
				var a := v if str(v) < str(w) else w
				var b := w if a == v else v
				var key := str(a) + str(b)
				if seen.has(key):
					continue
				seen[key] = true
				out.append({"a": a, "b": b, "hex": h})
	return out


## The trail for one link: bloom -> seam corner -> bloom, along hex borders.
static func link_route(link: Dictionary) -> Array[Vector3i]:
	return [link.a, PlotGrid.trail_corner(link.hex), link.b]


## Corridors: groups of blooms connected by links (any length, may branch).
func corridors() -> Array:
	var adj := {}
	for v: Vector3i in blooms:
		adj[v] = []
	for l: Dictionary in bloom_links():
		adj[l.a].append(l.b)
		adj[l.b].append(l.a)
	var seen := {}
	var out := []
	for v: Vector3i in blooms:
		if seen.has(v):
			continue
		var group: Array[Vector3i] = []
		var stack: Array[Vector3i] = [v]
		seen[v] = true
		while not stack.is_empty():
			var x: Vector3i = stack.pop_back()
			group.append(x)
			for y: Vector3i in adj[x]:
				if not seen.has(y):
					seen[y] = true
					stack.append(y)
		out.append(group)
	return out


## How many blooms in a corridor have `biome` in their trio.
func blooms_touching(corridor: Array, biome: String) -> int:
	var n := 0
	for v: Vector3i in corridor:
		if data.blooms_by_id[blooms[v]].trio.has(biome):
			n += 1
	return n


func animal_satisfied_by(animal: Dictionary, corridor: Array) -> bool:
	var needs: Dictionary = animal.get("needs", {})
	if corridor.size() < int(needs.get("min_blooms", 1)):
		return false
	if needs.has("biome"):
		return blooms_touching(corridor, needs.biome) >= int(needs.get("min_biome_blooms", 1))
	return true


## Settle any resident animal whose needs are now met. Returns their ids.
func check_animals() -> Array:
	var out := []
	var groups := corridors()
	for id: String in valley.get("animals", []):
		if settled.has(id):
			continue
		var animal: Dictionary = data.animals[id]
		for g: Array in groups:
			if animal_satisfied_by(animal, g):
				settled[id] = g
				seeds += int(animal.get("seeds", 0))
				out.append(id)
				break
	return out


## The animal's best corridor so far: {"blooms", "biome_blooms"}.
func animal_progress(id: String) -> Dictionary:
	var animal: Dictionary = data.animals[id]
	var biome: String = animal.get("needs", {}).get("biome", "")
	var best := {"blooms": 0, "biome_blooms": 0}
	for g: Array in corridors():
		var bb := blooms_touching(g, biome) if biome != "" else g.size()
		if g.size() + bb > best.blooms + best.biome_blooms:
			best = {"blooms": g.size(), "biome_blooms": bb}
	return best


# --- Score --------------------------------------------------------------------

func score_breakdown() -> Dictionary:
	var scoring: Dictionary = valley.get("scoring", {})
	var bloom_pts := blooms.size() * int(scoring.get("bloom", 1))
	var animal_pts := 0
	for id: String in settled:
		animal_pts += int(data.animals[id].get("points", 0))
	var per_point := int(scoring.get("seeds_per_point", 0))
	var seed_pts := seeds / per_point if per_point > 0 else 0
	return {
		"blooms": bloom_pts,
		"animals": animal_pts,
		"seeds": seed_pts,
		"total": bloom_pts + animal_pts + seed_pts,
	}
