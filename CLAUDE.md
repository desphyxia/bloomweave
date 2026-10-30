# Bloomweave

Calm hex tile-placement game. The design lives in `DESIGN.md`. Keep it up to
date as decisions are made, with "Decided" kept separate from "Open
questions".

## Working with the user

- **Always ask design questions through a questionnaire** (the multiple-choice
  question tool), not as questions in plain text. Put the recommended option
  first and mark it "(Recommended)". Keep each questionnaire to a few related
  questions.

## Tech (when building starts)

- Godot 4 (latest stable 4.x) + GDScript. Not C#.
- Prototype: web export to GitHub Pages. Compatibility renderer; thread
  support off in the web export (GitHub Pages can't send the needed headers).
- Keep hex grid math, game rules/scoring and rendering separate; rules are
  plain GDScript classes with no scene/node dependencies, tested headless
  with gdUnit4.
- Biomes, bloom trios, influence pairs, valleys and pile composition are data
  (JSON), not hardcoded.
- Axial hex coordinates; any vertex returns its three surrounding hexes.

## Commands

- Tests: `GODOT_BIN=/path/to/godot scripts/run_tests.sh`
- Balance sim: `godot --headless --path . -s res://tools/simulate.gd -- [valley_id] [runs] [seek]`
  (`seek` = the player goes for the hidden visitor first)
- Screenshot (needs a display, e.g. `xvfb-run`):
  `godot --path . --rendering-driver opengl3 --resolution 1280x800 -s res://tools/screenshot.gd -- out.png 10 [--level id]`
- Draw-call breakdown (needs a display):
  `godot --path . --rendering-driver opengl3 -s res://tools/perf_probe.gd -- 13`
- Web export: `godot --headless --path . --export-release "Web" build/web/index.html`
  (templates: `scripts/fetch_web_templates.py 4.7.2`)
