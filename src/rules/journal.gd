class_name Journal
extends RefCounted
## What the journal can list: every bloom, resident and hidden visitor used
## by the Progression levels, each with the levels it appears in. Which of
## them the player has found is kept by Progress.

const KINDS := ["blooms", "residents", "visitors"]


## {"blooms": [...], "residents": [...], "visitors": [...]}, each entry
## {"id", "levels": [level ids in order]}, in data order.
static func entries(data: GameData) -> Dictionary:
	var where := {"blooms": {}, "residents": {}, "visitors": {}}
	for level: String in data.levels:
		var v := data.valley(level)
		for id: String in ValleyGame.valley_bloom_ids(data, v):
			_add(where.blooms, id, level)
		for entry: Variant in v.get("animals", []):
			_add(where.residents, entry if entry is String else str(entry.id), level)
		if v.has("visitor"):
			_add(where.visitors, v.visitor, level)
	var out := {"blooms": [], "residents": [], "visitors": []}
	for bl: Dictionary in data.blooms_by_id.values():
		if where.blooms.has(bl.id):
			out.blooms.append({"id": bl.id, "levels": where.blooms[bl.id]})
	for a: Dictionary in data.animals.values():
		var kind := "visitors" if a.get("hidden", false) else "residents"
		if where[kind].has(a.id):
			out[kind].append({"id": a.id, "levels": where[kind][a.id]})
	return out


static func _add(map: Dictionary, id: String, level: String) -> void:
	if not map.has(id):
		map[id] = []
	if not map[id].has(level):
		map[id].append(level)
