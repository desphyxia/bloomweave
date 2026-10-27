# Bloomweave

A calm, single-player hex tile-placement game. Restore a valley by placing
trefoil pieces (three hexes around one corner) into fixed plots. Corners where
three pieces bring together three different biomes bloom, and chains of linked
blooms become wildlife corridors that animals move into.

The design lives in [DESIGN.md](DESIGN.md).

## Play the prototype

The web build is published to GitHub Pages on every push to `master`.

- **Tap a glowing plot** to try the current piece there; tap it again (or
  press **Turn**) to rotate it. **Mirror** flips it.
- **Place** puts it down. Flowers show where corners will bloom.
- Each bloom gives a seed. Spend seeds to set a piece aside, swap the next
  piece in, or look further ahead.
- Drag to orbit, scroll or pinch to zoom. Keys: R turn, F mirror,
  Enter place, Esc cancel.

## Develop

Requires [Godot 4.7](https://godotengine.org/download) (standard build, not
.NET).

```bash
# Run the rules tests headless (gdUnit4)
GODOT_BIN=/path/to/godot scripts/run_tests.sh

# Balance check: 200 runs with a simple greedy player
/path/to/godot --headless --path . -s res://tools/simulate.gd

# Web export (needs the web export templates; see below)
/path/to/godot --headless --path . --export-release "Web" build/web/index.html
```

Fetch only the web export templates (about 20 MB instead of the full archive):

```bash
scripts/fetch_web_templates.py 4.7.2
```

### Layout

- `src/core` — hex grid and plot grid math (axial coordinates, vertex lookups)
- `src/rules` — game rules: pieces, data loading, Valley mode (no engine nodes)
- `src/view` — 3D board, camera, HUD
- `data` — biomes, blooms, animals, influence pairs, valleys (JSON)
- `tests` — gdUnit4 tests for core and rules
- `tools` — balance simulation and screenshot helpers

### GitHub Pages

The workflow in `.github/workflows/pages.yml` runs the tests, exports the web
build and deploys it. In the repository settings, set **Pages → Source** to
**GitHub Actions** once.
