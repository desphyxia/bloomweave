extends SceneTree
## Level pipeline, step 1: generate candidate valleys from a template, play
## each with the test player, and save shapes + scores for a shortlist.
## Run: godot --headless --path . -s res://tools/generate_levels.gd -- <template> <count> <runs> <out.json>
##   template: a file in tools/level_templates (without .json)
## Then pick from the shortlist and save the chosen one as a level with
## `tools/level_from_candidate.py`.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var template_id := args[0]
	var count := int(args[1]) if args.size() > 1 else 30
	var runs := int(args[2]) if args.size() > 2 else 12
	var out_path := args[3] if args.size() > 3 else "user://candidates.json"
	var data := GameData.load_dir()
	var template: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/level_templates/%s.json" % template_id))
	var results := []
	for i in count:
		var gen_seed := 1000 + i
		var gen := ValleyGenerator.generate(gen_seed, int(template.target_plots), int(template.get("cliff_plots", 0)))
		if int(template.get("cliff_plots", 0)) > 0 and gen.obstacles.is_empty():
			print("seed %d: no room for the cliff" % gen_seed)
			continue
		var valley := level_from(template, gen)
		var errors := data.validate_valley(valley)
		if not errors.is_empty():
			print("seed %d invalid: %s" % [gen_seed, errors])
			continue
		var stats := ValleyGenerator.stats(gen.plots)
		var m := _measure(data, valley, runs)
		m.merge(stats)
		m.seed = gen_seed
		m.score = _score(m)
		var plots := []
		for p: Vector2i in gen.plots:
			plots.append([p.x, p.y])
		results.append({"seed": gen_seed, "metrics": m, "plots": plots,
			"landmark": [gen.landmark.x, gen.landmark.y], "hills": gen.hills,
			"obstacles": valley.get("obstacles", []), "valley": valley})
		print("seed %d: plots %d spots %d blooms %.1f settle %s visitor %d%%/%d%% score %.2f" % [
			gen_seed, stats.plots, stats.bloom_spots, m.blooms, m.settle, m.visitor_chance, m.visitor_sought, m.score])
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.metrics.score > b.metrics.score)
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(results, "  "))
	print("wrote %d candidates to %s" % [results.size(), out_path])
	quit()


## A valley dictionary from the template and a generated shape.
static func level_from(template: Dictionary, gen: Dictionary) -> Dictionary:
	var v := template.duplicate(true)
	v.erase("target_plots")
	v.erase("pile_share")
	v.erase("cliff_plots")
	if not gen.obstacles.is_empty():
		var obstacles := []
		for o: Dictionary in gen.obstacles:
			var ps := []
			for p: Vector2i in o.plots:
				ps.append([p.x, p.y])
			obstacles.append({"kind": o.kind, "plots": ps})
		v.obstacles = obstacles
	var plots := []
	for p: Vector2i in gen.plots:
		plots.append([p.x, p.y])
	v.outline = {"plots": plots}
	v.landmark.plot = [gen.landmark.x, gen.landmark.y]
	v.terrain = {"hills": gen.hills}
	var pieces: int = gen.plots.size() - 1
	var doubles := int(round(pieces * float(template.get("pile_share", {}).get("double", 0.22))))
	v.pile = {"distinct": pieces - doubles, "double": doubles, "single": 0}
	return v


static func _measure(data: GameData, valley: Dictionary, runs: int) -> Dictionary:
	var blooms := 0
	var settled := {}
	var chance := 0
	var sought := 0
	for i in runs:
		var g := Autoplay.play(data, valley, i)
		blooms += g.blooms.size()
		chance += 1 if g.visitor_found else 0
		for id: String in g.settled:
			settled[id] = settled.get(id, 0) + 1
		var s := Autoplay.play(data, valley, i, true)
		sought += 1 if s.visitor_found else 0
	var settle := {}
	for id: String in ValleyGame.new(data, valley, 0).residents():
		settle[id] = 100 * settled.get(id, 0) / runs
	return {"blooms": blooms / float(runs), "settle": settle,
		"visitor_chance": 100 * chance / runs, "visitor_sought": 100 * sought / runs}


## Higher is better: residents settle often but not always for the greedy
## player (about 50-80%), the visitor is rare by luck and reachable on
## purpose, and the shape has plenty of bloom spots for its size.
static func _score(m: Dictionary) -> float:
	var s := 0.0
	for id: String in m.settle:
		s -= absf(m.settle[id] - 65.0) / 100.0
	s -= maxf(0.0, m.visitor_chance - 10.0) / 100.0
	s -= maxf(0.0, 60.0 - m.visitor_sought) / 100.0
	s += float(m.bloom_spots) / maxf(float(m.plots), 1.0)
	return s
