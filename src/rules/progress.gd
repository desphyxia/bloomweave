class_name Progress
extends RefCounted
## Progression: the stars and best score earned on each level, which levels
## are open, and the journal's discoveries (blooms grown, residents settled,
## visitors found). Finishing a level opens the next one. Saved as JSON
## (user://progress.json; the web build keeps it in the browser).

const PATH := "user://progress.json"
const NO_STARS := {"restored": false, "residents": false, "visitor": false}

var levels: Array = []   # level ids, in order
var records := {}        # id -> {"stars": {...}, "best": int}
var found := {"blooms": {}, "residents": {}, "visitors": {}}  # kind -> id -> first level
var journal_unseen := false  # something new since the journal was last opened
var path := PATH
## Development: every level counts as open (stars are still kept as earned).
var unlock_all := false


func _init(p_levels: Array = [], p_path: String = PATH) -> void:
	levels = p_levels
	path = p_path


static func load_from(p_levels: Array, p_path: String = PATH) -> Progress:
	var p := Progress.new(p_levels, p_path)
	if FileAccess.file_exists(p_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(p_path))
		if typeof(parsed) == TYPE_DICTIONARY:
			p.records = parsed.get("levels", {})
			var f: Dictionary = parsed.get("found", {})
			for kind: String in p.found:
				p.found[kind] = f.get(kind, {})
			p.journal_unseen = bool(parsed.get("journal_unseen", false))
	return p


func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"levels": records, "found": found, "journal_unseen": journal_unseen}, "  "))


## Keep what a finished (or abandoned) game earned: stars are only ever
## added, the best score only goes up. Returns {"new_stars", "best"}.
func record(id: String, game: ValleyGame) -> Dictionary:
	var old := stars(id)
	var earned := game.stars()
	var merged := {}
	var new_stars := 0
	for k: String in NO_STARS:
		merged[k] = bool(old.get(k, false)) or bool(earned.get(k, false))
		if merged[k] and not old.get(k, false):
			new_stars += 1
	var rec: Dictionary = records.get(id, {})
	var score: int = game.score_breakdown().total if game.is_finished() else 0
	var best := score > int(rec.get("best", 0))
	records[id] = {"stars": merged, "best": maxi(score, int(rec.get("best", 0)))}
	return {"new_stars": new_stars, "best": best}


func stars(id: String) -> Dictionary:
	return records.get(id, {}).get("stars", NO_STARS)


func star_count(id: String) -> int:
	var n := 0
	for k: String in NO_STARS:
		if stars(id).get(k, false):
			n += 1
	return n


func total_stars() -> int:
	var n := 0
	for id: String in levels:
		n += star_count(id)
	return n


func best(id: String) -> int:
	return int(records.get(id, {}).get("best", 0))


## The first level is always open; each later one opens when the level
## before it has been restored.
func is_unlocked(id: String) -> bool:
	var i := levels.find(id)
	if unlock_all:
		return i >= 0
	if i <= 0:
		return i == 0
	return bool(stars(levels[i - 1]).get("restored", false))


func next_level(id: String) -> String:
	var i := levels.find(id)
	return levels[i + 1] if i >= 0 and i + 1 < levels.size() else ""


## Note a discovery. Returns true the first time (and marks the journal as
## having something new).
func discover(kind: String, id: String, level: String) -> bool:
	if found[kind].has(id):
		return false
	found[kind][id] = level
	journal_unseen = true
	return true


func is_found(kind: String, id: String) -> bool:
	return found[kind].has(id)


## The level where something was first found ("" if not yet).
func found_in(kind: String, id: String) -> String:
	return str(found[kind].get(id, ""))
