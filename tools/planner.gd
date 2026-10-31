class_name Planner
extends RefCounted
## A planning test player, closer to how a thoughtful person plays than
## Autoplay's "most blooms now". It values a board by:
##   - points from blooms (with combos)
##   - progress toward each resident's ask (corridor length, biome, blooms by
##     an obstacle, specific blooms, how close a ring round a piece is) and a
##     big bonus once settled
##   - progress toward the hidden visitor's pattern (it knows the secret, as a
##     player who read the riddle might)
##   - corners that can still bloom, minus corners that never can
##   - a little for seeds
## Each turn it tries every placement, then looks one piece further for its
## best few, and spends seeds on swap / set aside when that clearly helps.

const BEAM := 4          # best moves that get a look one piece further
const SETTLED := 16.0
const PROGRESS := 9.0
const LIVE_CORNER := 0.6
const DEAD_CORNER := 1.2
const SEED := 0.4


## `visitor_focus` > 1 makes it chase the hidden visitor's pattern harder
## (a player who has solved the riddle and is going for the third star).
static var visitor_focus := 1.0


static func play(data: GameData, valley: Dictionary, rng_seed: int, focus: float = 1.0) -> ValleyGame:
	visitor_focus = focus
	var g := ValleyGame.new(data, valley, rng_seed)
	while not g.is_finished():
		_use_seeds(g)
		var mv := best_move(g, true)
		g.place(mv.plot, mv.arr)
	return g


## The best placement of the current piece: {"plot", "arr", "value"}.
static func best_move(g: ValleyGame, look_further: bool) -> Dictionary:
	var moves := []
	for p in g.legal_plots():
		for a in Piece.distinct_arrangements(g.current_piece()):
			var c := g.clone()
			c.place(p, a)
			moves.append({"plot": p, "arr": a, "value": value(c), "after": c})
	moves.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x.value > y.value)
	if not look_further or g.pile.size() < 2:
		return moves[0]
	var top := moves.slice(0, BEAM)
	for m: Dictionary in top:
		var after: ValleyGame = m.after
		if after.is_finished() or after.pile.is_empty() or after.legal_plots().is_empty():
			continue
		m.value = best_move(after, false).value
	top.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x.value > y.value)
	return top[0]


## Swap in the next piece, bring back the set-aside one, or set the current
## one aside, when that gives a clearly better move.
static func _use_seeds(g: ValleyGame) -> void:
	var here: float = best_move(g, false).value
	if g.can_use_reserve():
		var c := g.clone()
		c.use_reserve()
		if best_move(c, false).value > here + 1.0:
			g.use_reserve()
			return
	if g.can_swap():
		var c := g.clone()
		c.swap()
		if best_move(c, false).value > here + 2.5:
			g.swap()
			return
	if g.can_set_aside() and here < value(g) + 0.5:
		var c := g.clone()
		c.set_aside()
		if not c.pile.is_empty() and best_move(c, false).value > here + 2.0:
			g.set_aside()


static func value(g: ValleyGame) -> float:
	var v := float(g.bloom_points) + SEED * g.seeds
	var ring := _ring_closeness(g)
	var groups := g.corridors()
	for id: String in g.residents():
		if g.settled.has(id):
			v += SETTLED
		else:
			v += PROGRESS * _resident_progress(g, id, ring, groups)
	var visitor := g.visitor()
	if not visitor.is_empty():
		if g.visitor_found:
			v += SETTLED
		else:
			var pr := g.visitor_progress()
			v += PROGRESS * visitor_focus * minf(float(pr.have) / maxf(pr.need, 1.0), 1.0)
	for corner: Dictionary in g.open_corners():
		v += LIVE_CORNER if not corner.needs.is_empty() else -DEAD_CORNER
	return v


## 0..1: how far the best corridor is toward the animal's ask (each part
## counts equally). Rings use how close any piece is to being ringed.
static func _resident_progress(g: ValleyGame, id: String, ring: float, groups: Array) -> float:
	var needs: Dictionary = g.animal(id).get("needs", {})
	var best := 0.0
	for corridor: Array in groups:
		var parts: Array[float] = [_part(corridor.size(), int(needs.get("min_blooms", 1)))]
		if needs.has("biome"):
			parts.append(_part(g.blooms_touching(corridor, needs.biome), int(needs.get("min_biome_blooms", 1))))
		if needs.has("near"):
			parts.append(_part(g.blooms_near(corridor, needs.near), int(needs.get("min_near_blooms", 1))))
		if needs.has("bloom"):
			parts.append(_part(g.blooms_of(corridor, needs.bloom), int(needs.get("min_bloom_count", 1))))
		if needs.get("ring", false):
			parts.append(ring)
		var sum := 0.0
		for x in parts:
			sum += x
		best = maxf(best, sum / parts.size())
	return best


static func _part(have: int, need: int) -> float:
	return minf(float(have) / maxf(float(need), 1.0), 1.0)


## 0..1: the most bloomed corners round any placed piece, out of six.
static func _ring_closeness(g: ValleyGame) -> float:
	var best := 0
	for base: Vector2i in g.placed:
		var n := 0
		for v in PlotGrid.plot_weave_points(base):
			if g.blooms.has(v):
				n += 1
		best = maxi(best, n)
	return best / 6.0
