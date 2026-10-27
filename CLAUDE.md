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
