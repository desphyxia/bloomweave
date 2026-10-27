extends SceneTree
## Balance check: plays valleys with a simple greedy player and prints stats.
## Run: godot --headless --path . -s res://tools/simulate.gd

func _init() -> void:
	var data := GameData.load_dir()
	var runs := 200
	var totals := {"blooms": 0, "score": 0, "otter": 0, "deer": 0, "seeds": 0}
	for i in runs:
		var g := ValleyGame.new(data, data.valley("first_valley"), i)
		while not g.is_finished():
			var best_plot := g.legal_plots()[0]
			var best_arr: Array = g.current_piece()
			var best_n := -1
			for p in g.legal_plots():
				for a in Piece.distinct_arrangements(g.current_piece()):
					var n := g.preview(p, a).size()
					if n > best_n:
						best_n = n
						best_plot = p
						best_arr = a
			g.place(best_plot, best_arr)
		totals.blooms += g.blooms.size()
		totals.score += g.score_breakdown().total
		totals.seeds += g.seeds
		for id in g.settled:
			totals[id] += 1
	print("runs=%d avg blooms=%.1f (of 24 corners) avg score=%.1f avg seeds=%.1f otters settle %d%% deer settle %d%%" % [
		runs, totals.blooms / float(runs), totals.score / float(runs), totals.seeds / float(runs),
		100 * totals.otter / runs, 100 * totals.deer / runs])
	quit()
