extends SceneTree
## Balance check: plays valleys with a simple greedy player and prints stats.
## Run: godot --headless --path . -s res://tools/simulate.gd -- [valley_id] [runs] [seek]
## With "seek", the player goes for the hidden visitor's pattern first
## (then blooms), to check the visitor is reachable on purpose.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var valley_id := args[0] if args.size() > 0 else "first_valley"
	var runs := int(args[1]) if args.size() > 1 else 200
	var seek := args.size() > 2 and args[2] == "seek"
	var data := GameData.load_dir()
	var valley := data.valley(valley_id)
	var totals := {"blooms": 0, "score": 0, "seeds": 0, "stars": 0, "visitor": 0, "patch": 0}
	var settled := {}
	var by_bloom := {}
	for i in runs:
		var g := ValleyGame.new(data, valley, i)
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
		totals.blooms += g.blooms.size()
		totals.score += g.score_breakdown().total
		totals.seeds += g.seeds
		totals.stars += g.star_count()
		totals.visitor += 1 if g.visitor_found else 0
		totals.patch += g.visitor_progress().have
		for id: String in g.settled:
			settled[id] = settled.get(id, 0) + 1
		for v: Vector3i in g.blooms:
			by_bloom[g.blooms[v]] = by_bloom.get(g.blooms[v], 0) + 1
	var animals := []
	for id: String in ValleyGame.new(data, valley, 0).residents():
		animals.append("%s %d%%" % [id, 100 * settled.get(id, 0) / runs])
	var kinds := []
	for id: String in by_bloom:
		kinds.append("%s %.1f" % [id, by_bloom[id] / float(runs)])
	print("%s: runs=%d avg blooms=%.1f score=%.1f seeds=%.1f stars=%.2f | settle: %s | visitor by chance %d%% (pattern avg %.1f) | per run: %s" % [
		valley_id, runs, totals.blooms / float(runs), totals.score / float(runs), totals.seeds / float(runs),
		totals.stars / float(runs), ", ".join(animals), 100 * totals.visitor / runs, totals.patch / float(runs), ", ".join(kinds)])
	quit()


## The visitor pattern's progress if `arranged` went on `base` (tries it on
## the board and takes it back).
func _pattern_after(g: ValleyGame, base: Vector2i, arranged: Array) -> int:
	var hexes := PlotGrid.plot_hexes(base)
	for i in 3:
		g.board[hexes[i]] = arranged[i]
	var have: int = g.visitor_progress().have
	for h in hexes:
		g.board.erase(h)
	return have
