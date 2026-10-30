class_name ValleyGame
extends RefCounted
## Rules for one valley: a fixed outline of plots (a radius, or a list of
## plots), optional obstacle plots (a lake...) that pieces can't fill, a
## landmark piece, and exactly enough pieces to fill every other plot.
## Pure logic with no scene or node dependencies, so it is testable headless.

var data: GameData
var valley: Dictionary
var center := Vector2i.ZERO
var plots: Array[Vector2i] = []
var obstacles := {}      # hex (Vector2i) -> obstacle kind ("lake", ...)
var board := {}          # hex (Vector2i) -> biome id
var placed := {}         # plot base (Vector2i) -> true
var pile: Array = []     # pieces still to place; pile[0] is the current piece
var reserve: Array = []  # the set-aside piece, or [] when the slot is empty
var seeds := 0
var blooms := {}         # weave point (Vector3i) -> bloom id
var bloom_points := 0    # points earned from blooms (with combo bonuses)
var settled := {}        # animal id -> Array of weave points (its corridor)
var look_ahead_active := false
var turn := 0
var rng := RandomNumberGenerator.new()
var game_seed := 0      # shown on screen so a valley can be replayed exactly

var _plot_set := {}
var _recipes := {}       # bloom id -> true, the blooms this valley allows
var _residents: Array[String] = []
var _animals := {}       # id -> animal with this valley's needs applied


func _init(p_data: GameData, p_valley: Dictionary, rng_seed: int = -1) -> void:
	data = p_data
	valley = p_valley
	if rng_seed < 0:
		var r := RandomNumberGenerator.new()
		r.randomize()
		rng_seed = r.randi_range(100000, 999999)
	game_seed = rng_seed
	rng.seed = rng_seed
	center = landmark_plot(valley)
	plots = outline_plots(valley)
	for p in plots:
		_plot_set[p] = true
	for o: Dictionary in valley.get("obstacles", []):
		for b: Array in o.get("plots", []):
			for h in PlotGrid.plot_hexes(Vector2i(int(b[0]), int(b[1]))):
				obstacles[h] = str(o.get("kind", "lake"))
	for id: String in valley_bloom_ids(data, valley):
		_recipes[id] = true
	for entry: Variant in valley.get("animals", []):
		var a := _resolve_animal(entry)
		_residents.append(a.id)
		_animals[a.id] = a
	_put(center, valley.landmark.biomes)
	pile = _build_pile()


## The valley's plots: `outline.plots` (a list of plot bases) or every plot
## within `outline.radius` steps of the landmark.
static func outline_plots(v: Dictionary) -> Array[Vector2i]:
	var outline: Dictionary = v.get("outline", {})
	if outline.has("plots"):
		var out: Array[Vector2i] = []
		for b: Array in outline.plots:
			out.append(Vector2i(int(b[0]), int(b[1])))
		return out
	return PlotGrid.plots_within(landmark_plot(v), int(outline.get("radius", 2)))


static func landmark_plot(v: Dictionary) -> Vector2i:
	var at: Array = v.get("landmark", {}).get("plot", [0, 0])
	return Vector2i(int(at[0]), int(at[1]))


static func obstacle_plots(v: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for o: Dictionary in v.get("obstacles", []):
		for b: Array in o.get("plots", []):
			out.append(Vector2i(int(b[0]), int(b[1])))
	return out


## The bloom recipes a valley uses: its `blooms` list, or by default every
## all-different trio of its biomes that has a bloom.
static func valley_bloom_ids(d: GameData, v: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if v.has("blooms"):
		for id: String in v.blooms:
			out.append(id)
		return out
	var biomes: Array = v.get("biomes", [])
	for bl: Dictionary in d.blooms_by_id.values():
		var fits := Piece.kind(bl.trio) == Piece.DISTINCT
		for b: String in bl.trio:
			fits = fits and biomes.has(b)
		if fits:
			out.append(bl.id)
	return out


## The blooms this valley allows, in data order.
func recipes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for bl: Dictionary in data.blooms_by_id.values():
		if _recipes.has(bl.id):
			out.append(bl)
	return out


## The bloom a trio (clockwise around a corner) makes in this valley, or {}.
func bloom_for(trio: Array) -> Dictionary:
	var bloom := data.bloom_for(trio, clockwise_blooms())
	return bloom if not bloom.is_empty() and _recipes.has(bloom.id) else {}


# --- Pieces -------------------------------------------------------------------

func _build_pile() -> Array:
	var mix: Dictionary = valley.pile
	if mix.has("weights"):
		return _build_weighted_pile(mix)
	var biome_pool: Array = valley.biomes
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


## Like _build_pile, but biomes are drawn by `pile.weights` (biome -> weight,
## default 1), e.g. more forest so Deep Wood can grow.
func _build_weighted_pile(mix: Dictionary) -> Array:
	var out := []
	for _i in int(mix.get("distinct", 0)):
		var piece := []
		while piece.size() < 3:
			piece.append(_weighted_biome(mix.weights, piece))
		_shuffle(piece)
		out.append(piece)
	for _i in int(mix.get("double", 0)):
		var a := _weighted_biome(mix.weights, [])
		var piece := [a, a, _weighted_biome(mix.weights, [a])]
		_shuffle(piece)
		out.append(piece)
	for _i in int(mix.get("single", 0)):
		var a := _weighted_biome(mix.weights, [])
		out.append([a, a, a])
	_shuffle(out)
	return out


func _weighted_biome(weights: Dictionary, exclude: Array) -> String:
	var total := 0.0
	for b: String in valley.biomes:
		if not exclude.has(b):
			total += float(weights.get(b, 1.0))
	var roll := rng.randf() * total
	for b: String in valley.biomes:
		if exclude.has(b):
			continue
		roll -= float(weights.get(b, 1.0))
		if roll <= 0.0:
			return b
	for b: String in valley.biomes:
		if not exclude.has(b):
			return b
	return valley.biomes[0]


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
		var bloom := bloom_for(trio)
		if not bloom.is_empty():
			out.append({"vertex": v, "bloom": bloom.id})
	return out


## Whether this valley's blooms need their biomes in clockwise order.
func clockwise_blooms() -> bool:
	return valley.get("bloom_order", "any") == "clockwise"


## Place the current piece, arranged as `arranged` (slot order), on `base`.
## Returns {"ok", "blooms", "points", "settled", "seeds_gained",
## "finished", "completed", "perfect"}.
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
	var points := combo_points(new_blooms.size())
	bloom_points += points
	var perfect := is_perfect(completed, new_blooms.size())
	if perfect:
		seeds += int(valley.get("scoring", {}).get("perfect_seeds", 0))
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
		"perfect": perfect,
		"points": points,
	}


## Points for `n` blooms made by one placement. Each extra bloom in the same
## placement is worth `combo_step` more than the one before:
## with bloom 2 and step 1 -> 1 bloom 2, 2 blooms 5, 3 blooms 9, 6 blooms 27.
func combo_points(n: int) -> int:
	var scoring: Dictionary = valley.get("scoring", {})
	var base := int(scoring.get("bloom", 1))
	var step := int(scoring.get("combo_step", 0))
	return n * base + step * n * (n - 1) / 2


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


## A perfect piece makes all six bloom spots around it bloom. That is only
## possible when it fills a gap with every neighbouring plot already placed.
static func is_perfect(completed: int, bloomed: int) -> bool:
	return completed == 6 and bloomed == 6


## Corners waiting for their last hex: two hexes are filled, the third is an
## empty hex in the valley. Each entry: {"vertex", "hex" (the empty one),
## "needs" (biomes that would make it bloom, in data order)}. A corner whose
## two biomes can no longer bloom has an empty "needs" list.
func open_corners() -> Array:
	var out := []
	var seen := {}
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
				if not bloom_for(trio).is_empty():
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


## How many blooms in a corridor sit next to an obstacle of `kind` (one of
## the bloom's hexes borders it, e.g. on the lake shore).
func blooms_near(corridor: Array, kind: String) -> int:
	var n := 0
	for v: Vector3i in corridor:
		if is_near_obstacle(v, kind):
			n += 1
	return n


func is_near_obstacle(v: Vector3i, kind: String) -> bool:
	for h in Hex.vertex_hexes(v):
		for nb in Hex.neighbors(h):
			if obstacles.get(nb, "") == kind:
				return true
	return false


## How many blooms in a corridor are the bloom `bloom_id`.
func blooms_of(corridor: Array, bloom_id: String) -> int:
	var n := 0
	for v: Vector3i in corridor:
		if blooms[v] == bloom_id:
			n += 1
	return n


## The resident animals' ids, in the valley's order.
func residents() -> Array[String]:
	return _residents


## A resident with this valley's needs applied. Valleys list animals by id,
## or as {"id", "needs", "description"} to change what that animal asks for.
func animal(id: String) -> Dictionary:
	return _animals.get(id, data.animals.get(id, {}))


func _resolve_animal(entry: Variant) -> Dictionary:
	if entry is String:
		return data.animals[entry]
	var e: Dictionary = entry
	var a: Dictionary = data.animals[e.id].duplicate(true)
	for k: String in e:
		a[k] = e[k]
	return a


## Each of an animal's needs measured on a corridor, as
## [{"label", "have", "need"}] (blooms first). A corridor satisfies the animal
## when every `have` reaches its `need`.
func animal_checks(id: String, corridor: Array) -> Array:
	var needs: Dictionary = animal(id).get("needs", {})
	var out := [{"label": "blooms", "have": corridor.size(), "need": int(needs.get("min_blooms", 1))}]
	if needs.has("biome"):
		out.append({"label": str(needs.biome), "have": blooms_touching(corridor, needs.biome),
			"need": int(needs.get("min_biome_blooms", 1))})
	if needs.has("near"):
		out.append({"label": "by the %s" % needs.near, "have": blooms_near(corridor, needs.near),
			"need": int(needs.get("min_near_blooms", 1))})
	if needs.has("bloom"):
		var bl: Dictionary = data.blooms_by_id.get(needs.bloom, {})
		out.append({"label": str(bl.get("name", needs.bloom)), "have": blooms_of(corridor, needs.bloom),
			"need": int(needs.get("min_bloom_count", 1))})
	return out


func animal_satisfied_by(id: String, corridor: Array) -> bool:
	for c: Dictionary in animal_checks(id, corridor):
		if c.have < c.need:
			return false
	return true


## Settle any resident animal whose needs are now met. Returns their ids.
func check_animals() -> Array:
	var out := []
	var groups := corridors()
	for id: String in _residents:
		if settled.has(id):
			continue
		for g: Array in groups:
			if animal_satisfied_by(id, g):
				settled[id] = g
				seeds += int(animal(id).get("seeds", 0))
				out.append(id)
				break
	return out


## The animal's best corridor so far, as animal_checks entries: the corridor
## that meets the most of its needs (counting partial progress).
func animal_progress(id: String) -> Array:
	var best: Array = animal_checks(id, [])
	var best_score := -1.0
	for g: Array in corridors():
		var checks := animal_checks(id, g)
		var score := 0.0
		for c: Dictionary in checks:
			score += minf(float(c.have) / maxf(float(c.need), 1.0), 1.0)
		if score > best_score:
			best_score = score
			best = checks
	return best


# --- Stars ----------------------------------------------------------------------

## A level's three stars: the valley restored, all residents settled, the
## hidden visitor found (not in the game yet, so always false).
func stars() -> Dictionary:
	return {
		"restored": is_finished(),
		"residents": settled.size() == _residents.size() and not _residents.is_empty(),
		"visitor": false,
	}


func star_count() -> int:
	var n := 0
	for k: String in stars():
		if stars()[k]:
			n += 1
	return n


# --- Score --------------------------------------------------------------------

func score_breakdown() -> Dictionary:
	var scoring: Dictionary = valley.get("scoring", {})
	var bloom_pts := bloom_points
	var animal_pts := 0
	for id: String in settled:
		animal_pts += int(animal(id).get("points", 0))
	var per_point := int(scoring.get("seeds_per_point", 0))
	var seed_pts := seeds / per_point if per_point > 0 else 0
	return {
		"blooms": bloom_pts,
		"animals": animal_pts,
		"seeds": seed_pts,
		"total": bloom_pts + animal_pts + seed_pts,
	}
