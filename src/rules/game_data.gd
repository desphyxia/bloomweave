class_name GameData
extends RefCounted
## All data-driven game content: biomes, blooms, animals, influence pairs and
## valleys. Loaded from JSON in res://data, or built from dictionaries in tests.

var biomes := {}       # id -> {id, name, color}
var biome_ids: Array[String] = []
var blooms := {}       # trio key -> {id, name, trio, color}
var blooms_by_id := {} # id -> bloom
var animals := {}      # id -> animal
var influence_pairs: Array = []
var valleys := {}      # id -> valley
var data_dir := "res://data"


static func load_dir(dir: String = "res://data") -> GameData:
	var d := GameData.new()
	d.data_dir = dir
	d.setup(
		_read_json(dir + "/biomes.json").get("biomes", []),
		_read_json(dir + "/blooms.json").get("blooms", []),
		_read_json(dir + "/animals.json").get("animals", []),
		_read_json(dir + "/influence.json").get("pairs", []))
	return d


func setup(p_biomes: Array, p_blooms: Array, p_animals: Array, p_influence: Array = []) -> void:
	for b: Dictionary in p_biomes:
		biomes[b.id] = b
		biome_ids.append(b.id)
	for bl: Dictionary in p_blooms:
		blooms[trio_key(bl.trio)] = bl
		blooms_by_id[bl.id] = bl
	for a: Dictionary in p_animals:
		animals[a.id] = a
	influence_pairs = p_influence


func valley(id: String) -> Dictionary:
	if not valleys.has(id):
		valleys[id] = _read_json("%s/valleys/%s.json" % [data_dir, id])
	return valleys[id]


static func trio_key(trio: Array) -> String:
	var t := trio.duplicate()
	t.sort()
	return "+".join(t)


## The bloom a trio of biomes makes, or {} if none. Only trios of three
## different biomes bloom (same-biome blooms are out of the prototype).
func bloom_for(trio: Array) -> Dictionary:
	if Piece.kind(trio) != Piece.DISTINCT:
		return {}
	return blooms.get(trio_key(trio), {})


func biome_color(id: String) -> Color:
	return Color(biomes.get(id, {}).get("color", "#888888"))


## Problems with the data, as readable strings. Empty means valid.
func validate() -> Array[String]:
	var errors: Array[String] = []
	for bl: Dictionary in blooms_by_id.values():
		if bl.trio.size() != 3 or Piece.kind(bl.trio) != Piece.DISTINCT:
			errors.append("Bloom %s needs three different biomes." % bl.id)
		for b: String in bl.trio:
			if not biomes.has(b):
				errors.append("Bloom %s uses unknown biome %s." % [bl.id, b])
	for a: Dictionary in animals.values():
		var needs: Dictionary = a.get("needs", {})
		if needs.has("biome") and not biomes.has(needs.biome):
			errors.append("Animal %s needs unknown biome %s." % [a.id, needs.biome])
	return errors


func validate_valley(v: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for b: String in v.get("biomes", []):
		if not biomes.has(b):
			errors.append("Valley %s uses unknown biome %s." % [v.get("id"), b])
	var plot_count := PlotGrid.plots_within(Vector2i.ZERO, int(v.outline.radius)).size()
	var pile: Dictionary = v.get("pile", {})
	var pieces := int(pile.get("distinct", 0)) + int(pile.get("double", 0)) + int(pile.get("single", 0))
	if pieces != plot_count - 1:
		errors.append("Valley %s has %d plots but %d pieces (needs plots - 1)." % [v.get("id"), plot_count, pieces])
	var landmark: Array = v.get("landmark", {}).get("biomes", [])
	if landmark.size() != 3 or Piece.kind(landmark) != Piece.DISTINCT:
		errors.append("Valley %s landmark needs three different biomes." % v.get("id"))
	for a: String in v.get("animals", []):
		if not animals.has(a):
			errors.append("Valley %s lists unknown animal %s." % [v.get("id"), a])
	return errors


static func _read_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Could not read %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Bad JSON in %s" % path)
		return {}
	return parsed
