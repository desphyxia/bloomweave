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

- three.js + TypeScript + Vite.
- Keep hex grid math, game rules/scoring and rendering in separate modules;
  rules must be testable without a browser.
- Biomes, bloom trios, influence pairs, valleys and pile composition are data
  (JSON), not hardcoded.
- Axial hex coordinates; any vertex returns its three surrounding hexes.
