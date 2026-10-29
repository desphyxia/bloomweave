# Bloomweave

A calm, single-player hex tile-placement game. Restore a valley by placing
trefoil pieces (three hexes around one corner) into fixed plots. Corners where
three pieces bring together three different biomes bloom, and chains of linked
blooms become wildlife corridors that animals move into.

The design lives in [DESIGN.md](DESIGN.md).

## Play the prototype

The web build is published to GitHub Pages on every push to `master`.
The info panel shows the build (commit) id; each deploy gives the game data
file a new name so browsers always load the latest version.

The info panel also shows the **game number** (e.g. `game #424242`). Add
`?seed=424242` to the page address to replay exactly that valley (same
pieces in the same order); handy when reporting a bug.

- **Tap a glowing plot** to try the current piece there; tap it again (or
  press **Turn**) to rotate it. **Mirror** flips it.
- **Place** puts it down. Flowers show where corners will bloom.
- A corner blooms when its three hexes hold one of the bloom recipes (the
  Blooms panel). **Buds** on open corners show which biome(s) the last hex
  needs. Later valleys can require the biomes in **clockwise** order.
- Complete two or more corners and make them all bloom for a **perfect piece**.
- Each bloom gives a seed. Spend seeds to set a piece aside, swap the next
  piece in, or look further ahead.
- **Touch:** drag with one finger to pan. With two fingers, pinch to zoom,
  twist to rotate, or move both up or down to tilt. Each two-finger gesture
  does one of these, picked by your first clear movement.
- **Mouse:** left-drag to pan, right-drag to rotate, scroll to zoom.
- **Keys:** R turn, F mirror, Enter place, Esc cancel, Q / E rotate view.

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
