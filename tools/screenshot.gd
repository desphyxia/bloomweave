extends SceneTree
## Dev tool: loads the main scene, plays some turns automatically and saves
## a screenshot. Needs a display (e.g. xvfb-run).
## Run: godot --path . -s res://tools/screenshot.gd -- <out.png> <turns> [w h] [distance]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://shot.png"
	var turns := int(args[1]) if args.size() > 1 else 8
	var w := int(args[2]) if args.size() > 2 else 1280
	var h := int(args[3]) if args.size() > 3 else 800
	root.size = Vector2i(w, h)
	var main: Node = load("res://src/view/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var game: ValleyGame = main.game
	for i in turns:
		if game.is_finished():
			break
		var best_plot := game.legal_plots()[0]
		var best_arr: Array = game.current_piece()
		var best_n := -1
		for p in game.legal_plots():
			for a in Piece.distinct_arrangements(game.current_piece()):
				var n := game.preview(p, a).size()
				if n > best_n:
					best_n = n
					best_plot = p
					best_arr = a
		main.selected = best_plot
		main.arrangement = best_arr
		main._place()
		for _f in 3:
			await process_frame
	# Leave one piece selected to show the ghost preview.
	if not game.is_finished():
		main.selected = game.legal_plots()[0]
		main._update()
	if args.size() > 4:
		main.rig.distance = float(args[4])
		main.rig._apply()
	for _f in 90:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("saved ", out)
	quit()
