class_name Autoplay
extends RefCounted
## A simple test player for balance tools: each turn it takes the placement
## that makes the most blooms (with `seek`, it goes for the hidden visitor's
## pattern first). It never spends seeds.


static func play(data: GameData, valley: Dictionary, rng_seed: int, seek: bool = false) -> ValleyGame:
	var g := ValleyGame.new(data, valley, rng_seed)
	while not g.is_finished():
		var best_plot := g.legal_plots()[0]
		var best_arr: Array = g.current_piece()
		var best_n := -1
		for p in g.legal_plots():
			for a in Piece.distinct_arrangements(g.current_piece()):
				var n := g.preview(p, a).size()
				if seek and not g.visitor_found:
					n += 10 * _pattern_after(g, p, a)
				if n > best_n:
					best_n = n
					best_plot = p
					best_arr = a
		g.place(best_plot, best_arr)
	return g


## The visitor pattern's progress if `arranged` went on `base` (tries it on
## the board and takes it back).
static func _pattern_after(g: ValleyGame, base: Vector2i, arranged: Array) -> int:
	var hexes := PlotGrid.plot_hexes(base)
	for i in 3:
		g.board[hexes[i]] = arranged[i]
	var have: int = g.visitor_progress().have
	for h in hexes:
		g.board.erase(h)
	return have
