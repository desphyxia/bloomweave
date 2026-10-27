# Bloomweave — Design Doc

_Living document. Updated as decisions are made during design sessions._

## Pitch

A calm, single-player hex tile-placement game. The player restores a valley by
placing **trefoils** (three hexes meeting at one vertex) on a flat-top hex grid.
Biomes sit on whole hexes, and vertices where three complementary biomes meet
**bloom** into flowers and wildlife. No combat, no timers.

---

## Decided

- Single-player, calm, no combat, no timers.
- Flat-top hex grid, axial coordinates.
- Pieces are trefoils: three hexes around one shared vertex (the "confluence").
- Biomes belong to whole hexes, not edges (a deliberate difference from
  Dorfromantik's edge matching).
- Starting biomes: forest, meadow, wetland, rock.
- Tech (for later): three.js + TypeScript + Vite. Hex math, rules/scoring and
  rendering in separate modules; rules testable without a browser. Biomes,
  influence tables, bloom trios and pile composition are data (JSON).

## Draft rules (not yet confirmed)

- Draw the next trefoil from a finite pile; rotate in 120° steps; may mirror;
  place it touching the existing map.
- Adjacent biomes spread influence (e.g. wetland feeds forest, rock shelters
  meadow).
- A vertex blooms when its three hexes form a complementary trio
  (e.g. forest + wetland + meadow). Blooms give points, bonus pieces and visuals.
- Run ends when the pile is empty; score unlocks new biomes over time.

## Open questions

### Geometry and placement
- A trefoil's own confluence is fixed when it's drawn. Should it be able to
  bloom, or do only vertices formed *between* pieces count?
- 120° rotation alone keeps the piece's triangle pointing one way. Does
  mirroring flip it, so the piece can sit on either vertex type?
- **Goal: no holes.** Freeform placement leaves 1–2 hex gaps no trefoil can
  fill. Options considered:
  - *More 3-hex shapes (line, bend, triangle — "Tetris"-style).* Adds variety
    but does **not** fix holes: any piece bigger than one hex can still leave
    a 1-hex gap. Also raises orientations from 3 to 6 per shape.
  - *Fixed plot grid (proposed).* The grid is pre-split into trefoil-shaped
    plots, and every piece fills exactly one plot, so holes are impossible.
    Fits the 120° + mirror rule exactly: mirroring across the piece's own
    symmetry axis keeps its shape and only swaps two biomes, so 3 rotations ×
    mirror = all 6 biome arrangements. Math: hex `(q,r)` belongs to the plot
    whose base `(q0,r0)` has `q0 ≡ r0 (mod 3)`; the offsets `(0,0)`, `(1,0)`,
    `(0,1)` make up the plot. Vertices then come in three kinds: confluences
    (inside one piece), seams (two pieces) and **weave points** (three
    different pieces).
  - *Fillers.* Single-hex bonus pieces, or enclosed gaps that heal by
    themselves into a feature (spring, pond). Softens holes but doesn't
    prevent them.
- Can a trefoil repeat a biome (e.g. forest, forest, meadow)?

### Core loop
- What makes each placement a real decision?

### Scoring and economy
- How blooms score; how bonus pieces are earned; how to keep a run's length
  from snowballing.

### Biome interactions
- What "influence" does mechanically, and whether it overlaps with blooms.

### Requests / goals
- Optional goals: form, frequency, rewards.

### Difficulty and run length
- Target session length; how pile size and difficulty scale.

### Progression and unlocks
- What score unlocks, and whether unlocks add depth or just variety.

### Atmosphere
- Visual style, sound, pacing.

## Dorfromantik comparison

| Area | Dorfromantik | Bloomweave (current draft) | Risk |
|---|---|---|---|
| Tile | Single hex, 6 edge segments | Trefoil of 3 whole-hex biomes | Distinct |
| Matching | Edges match edges | Trios meet at vertices | Distinct |
| Run end | Stack runs out | Pile runs out | **Close** |
| Extending the run | Perfect placements and quests add tiles | Blooms add bonus pieces | **Close** |
| Meta | Score unlocks tiles and biomes | Score unlocks biomes | **Close** |
| Mood | Cozy, pastoral | Cozy, restoration | Close (genre-typical) |

The pieces and matching rules are clearly different. The **economy loop**
(finite stack, earn more pieces by placing well, score unlocks content) is
currently Dorfromantik's loop almost exactly. To revisit.
