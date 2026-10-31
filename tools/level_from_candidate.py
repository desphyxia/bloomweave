"""Save a chosen generated candidate as a Progression level.

Usage: python3 tools/level_from_candidate.py candidates.json <seed>
Writes data/valleys/<id>.json from the candidate and adds the level to the
end of data/progression.json (if it isn't there yet).
"""
import json
import re
import sys


def compact(text):
    # Keep [q, r] pairs and hill rows on one line.
    text = re.sub(r"\[\s+(-?[\d.]+),\s+(-?[\d.]+)\s+\]", r"[\1, \2]", text)
    return re.sub(r"\[\s+(-?[\d.]+),\s+(-?[\d.]+),\s+(-?[\d.]+),\s+(-?[\d.]+)\s+\]", r"[\1, \2, \3, \4]", text)


ORDER = ["id", "name", "intro", "biomes", "outline", "obstacles", "landmark", "blooms", "pile",
         "animals", "visitor", "bloom_order", "scoring", "seed_costs", "look_ahead_count",
         "terrain", "generated_from"]


def tidy(value):
    # Whole numbers back to ints (Godot writes 3 as 3.0).
    if isinstance(value, float) and value.is_integer():
        return int(value)
    if isinstance(value, list):
        return [tidy(v) for v in value]
    if isinstance(value, dict):
        return {k: tidy(v) for k, v in value.items()}
    return value


def main():
    cands = json.load(open(sys.argv[1]))
    seed = int(sys.argv[2])
    cand = next(c for c in cands if c["seed"] == seed)
    valley = cand["valley"]
    valley["generated_from"] = {"seed": seed, "metrics": cand["metrics"]}
    valley = tidy(valley)
    valley = {k: valley[k] for k in ORDER if k in valley} | {k: v for k, v in valley.items() if k not in ORDER}
    path = "data/valleys/%s.json" % valley["id"]
    with open(path, "w") as f:
        f.write(compact(json.dumps(valley, indent=2)) + "\n")
    prog = json.load(open("data/progression.json"))
    if valley["id"] not in prog["levels"]:
        prog["levels"].append(valley["id"])
        with open("data/progression.json", "w") as f:
            f.write(json.dumps(prog, indent=2) + "\n")
    print("wrote", path)


if __name__ == "__main__":
    main()
