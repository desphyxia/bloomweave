extends SceneTree
## Dev tool: plays some turns, then reports draw calls with parts of the
## scene hidden, to see where the cost is.
## Run: xvfb-run godot --path . --rendering-driver opengl3 -s res://tools/perf_probe.gd -- [turns] [--level id]

func _draws() -> int:
	for _f in 4:
		await process_frame
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)


func _init() -> void:
	root.size = Vector2i(430, 932)
	var args := OS.get_cmdline_user_args()
	var at := args.find("--level")
	if at >= 0:
		args = args.slice(0, at) + args.slice(at + 2)
	var turns := int(args[0]) if args.size() > 0 else 12
	var main: Node = load("res://src/view/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var g: ValleyGame = main.game
	for i in turns:
		if g.is_finished():
			break
		var best_plot := g.legal_plots()[0]
		var best_arr: Array = g.current_piece()
		var best_n := -1
		for p in g.legal_plots():
			for a in Piece.distinct_arrangements(g.current_piece()):
				var n := g.preview(p, a).size()
				if n > best_n:
					best_n = n; best_plot = p; best_arr = a
		main.selected = best_plot
		main.arrangement = best_arr
		main._place()
	for _f in 60:
		await process_frame
	var total: int = await _draws()
	var parts := {}
	var board: BoardView = main.board
	for child in board.get_children():
		var n3 := child as Node3D
		if n3 == null:
			continue
		n3.visible = false
		parts[String(child.name)] = total - await _draws()
		n3.visible = true
	main.scenery.visible = false
	parts["scenery"] = total - await _draws()
	main.scenery.visible = true
	var sun: DirectionalLight3D
	for c in main.get_children():
		if c is DirectionalLight3D:
			sun = c
	sun.shadow_enabled = false
	parts["shadows"] = total - await _draws()
	sun.shadow_enabled = true
	print("PERF total draws: ", total, "  placed: ", g.placed.size())
	var keys := parts.keys()
	keys.sort_custom(func(a, b): return parts[a] > parts[b])
	for k in keys:
		print("PERF   %-10s %d" % [k, parts[k]])
	quit()
